///|
/// Selects which Gateway shards this process owns.
pub(all) enum ShardConfig {
  /// Use Discord's recommended shard count and run every shard locally.
  Auto
  /// Run one shard from a larger logical shard set. This is the default and
  /// preserves the pre-manager single-shard executor behavior.
  Single(id~ : Int32, count~ : Int32)
  /// Run shard ids `0..<count` in this process.
  Fixed(count~ : Int32)
  /// Run only `ids` while identifying them with the shared logical `count`.
  Range(ids~ : Array[Int32], count~ : Int32)
} derive(Debug)

///|
priv struct ResolvedShardConfig {
  ids : Array[Int32]
  count : Int32
  gateway_url : String
  max_concurrency : Int32
  /// Saved sessions that fit this layout, keyed by shard id.
  resume : Map[Int32, BotSession]
}

///|
priv struct ManagedShard {
  id : Int32
  shard : @gateway.Shard
  mut context : GatewayCtx?
}

///|
priv enum ManagedShardEvent {
  Shard(owner~ : ManagedShard, event~ : @gateway.ShardEvent)
  /// A shard is held before IDENTIFY; `Bot::run` ends with this error.
  IdentifyRefused(Error)
}

///|
/// Why `ids` out of `count` shards is not a layout Discord accepts, or `None`.
fn shard_layout_problem(ids : Array[Int32], count : Int32) -> String? {
  if count <= 0 {
    return Some("shard count must be positive")
  }
  if ids.is_empty() {
    return Some("at least one shard id must be selected")
  }
  let seen : Map[Int32, Bool] = Map([])
  for id in ids {
    if id < 0 || id >= count {
      return Some("shard id \{id} is outside 0..<\{count}")
    }
    if seen.get(id) == Some(true) {
      return Some("duplicate shard id \{id}")
    }
    seen[id] = true
  }
  None
}

///|
/// The shard ids and count a selection names without asking Discord, or
/// `None` for `Auto`. A negative `Fixed` count selects no shards.
fn ShardConfig::static_layout(self : ShardConfig) -> (Array[Int32], Int32)? {
  match self {
    Auto => None
    Single(id~, count~) => Some(([id], count))
    Fixed(count~) => Some((Array::makei(count.max(0), id => id), count))
    Range(ids~, count~) => Some((ids.copy(), count))
  }
}

///|
/// The error for starting `required` new sessions under `limit`, or `None`
/// when the limit allows them. Exceeding it resets the bot token.
fn session_start_refusal(
  limit : @model.SessionStartLimit,
  required~ : Int32,
) -> BotError? {
  if required > limit.remaining {
    Some(
      SessionStartLimitExceeded(
        required~,
        remaining=limit.remaining,
        reset_after_ms=limit.reset_after,
      ),
    )
  } else {
    None
  }
}

///|
/// Check a layout Discord supplied at run time (`Auto` shard counts).
fn validate_gateway_layout(
  ids : Array[Int32],
  count : Int32,
) -> Unit raise BotError {
  if shard_layout_problem(ids, count) is Some(message) {
    raise InvalidGatewayInfo(message~)
  }
}

///|
async fn BotCore::gateway_bot_info(
  self : BotCore,
  client : @dhttp.Client,
) -> @model.GatewayBotInfo raise @dhttp.DiscordHttpError {
  match self.gateway_bot_info_.val {
    Some(info) => info
    None => client.get_gateway_bot()
  }
}

///|
fn[X] BotCore::start_managed_shard(
  self : BotCore,
  group : @async.TaskGroup[X],
  token~ : String,
  intents~ : @model.Intents,
  gateway_url~ : String,
  shard_id~ : Int32,
  shard_count~ : Int32,
  identify_queue~ : &@queue.IdentifyQueue,
  event_filter~ : (@model.EventKind) -> Bool,
  resume? : @gateway.Session,
) -> @gateway.Shard {
  @gateway.Shard::start(
    group,
    token~,
    intents~,
    capabilities=self.capabilities_,
    presence?=self.presence_,
    gateway_url~,
    shard_id~,
    shard_count~,
    identify_queue~,
    event_filter~,
    connector?=self.connector_.val,
    compress=self.compress_,
    telemetry=event => self.emit_telemetry(event),
    clock=self.clock_.val,
    resume?,
  )
}

///|
async fn BotCore::resolve_shards(
  self : BotCore,
  client : @dhttp.Client,
) -> ResolvedShardConfig {
  match self.shards_ {
    Single(id~, count~) => {
      let ids = [id]
      validate_gateway_layout(ids, count)
      let gateway_url = match self.gateway_url_ {
        Some(url) => url
        None => client.get_gateway()
      }
      {
        ids,
        count,
        gateway_url,
        max_concurrency: 1,
        resume: self.sessions_for_layout(ids, count),
      }
    }
    Auto | Fixed(_) | Range(..) => {
      let info = self.gateway_bot_info(client)
      let (ids, count) = match self.shards_.static_layout() {
        Some(layout) => layout
        None => (Array::makei(info.shards.max(0), id => id), info.shards)
      }
      validate_gateway_layout(ids, count)
      if info.session_start_limit.max_concurrency <= 0 {
        raise BotError::InvalidGatewayInfo(
          message="gateway max_concurrency must be positive",
        )
      }
      let resume = self.sessions_for_layout(ids, count)
      // A shard with a saved session sends RESUME, which does not consume the
      // identify allowance; only a rejected RESUME falls back to IDENTIFY.
      let required = ids.filter(id => !resume.contains(id)).length()
      if session_start_refusal(info.session_start_limit, required~)
        is Some(error) {
        raise error
      }
      {
        ids,
        count,
        gateway_url: self.gateway_url_.unwrap_or(info.url),
        max_concurrency: info.session_start_limit.max_concurrency,
        resume,
      }
    }
  }
}

///|
/// The saved sessions usable for the selected shards. A RESUME keeps the
/// guild assignment of the READY it was recorded under, so a snapshot from
/// another shard layout is dropped with a warning and its shard identifies.
fn BotCore::sessions_for_layout(
  self : BotCore,
  ids : Array[Int32],
  count : Int32,
) -> Map[Int32, BotSession] {
  let usable : Map[Int32, BotSession] = Map([])
  for id in ids {
    guard self.resume_.get(id) is Some(saved) else { continue }
    let recorded = saved.ready.shard.unwrap_or([0, 1])
    if recorded is [recorded_id, recorded_count] &&
      recorded_id == id &&
      recorded_count == count {
      usable[id] = saved
    } else {
      self.app_.warn(
        @app.Executor(
          source="gateway",
          message="ignoring saved session for shard \{id}: its READY was recorded for shard [\{recorded.map(part => part.to_string()).join(", ")}] but the bot resolved shard [\{id}, \{count}], so the shard identifies instead",
        ),
      )
    }
  }
  usable
}

///|
async fn close_shards(shards : Array[@gateway.Shard]) -> Unit noraise {
  for shard in shards {
    shard.close()
  }
}
