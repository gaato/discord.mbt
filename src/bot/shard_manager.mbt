///|
/// Selects which Gateway shards this process owns.
pub(all) enum ShardConfig {
  /// Use Discord's recommended shard count and run every shard locally.
  Auto
  /// Run one shard from a larger logical shard set. This is the default and
  /// preserves the pre-manager single-shard executor behavior.
  Single(id~ : Int, count~ : Int)
  /// Run shard ids `0..<count` in this process.
  Fixed(count~ : Int)
  /// Run only `ids` while identifying them with the shared logical `count`.
  Range(ids~ : Array[Int], count~ : Int)
} derive(Debug)

///|
priv struct ResolvedShardConfig {
  ids : Array[Int]
  count : Int
  gateway_url : String
  max_concurrency : Int
}

///|
priv struct ManagedShard {
  id : Int
  shard : @gateway.Shard
  mut context : GatewayCtx?
}

///|
priv struct ManagedShardEvent {
  owner : ManagedShard
  event : @gateway.ShardEvent
}

///|
fn validate_shard_ids(ids : Array[Int], count : Int) -> Unit raise BotError {
  if count <= 0 {
    raise BotError::InvalidShardConfig(message="shard count must be positive")
  }
  if ids.is_empty() {
    raise BotError::InvalidShardConfig(
      message="at least one shard id must be selected",
    )
  }
  let seen : Map[Int, Bool] = {}
  for id in ids {
    if id < 0 || id >= count {
      raise BotError::InvalidShardConfig(
        message="shard id \{id} is outside 0..<\{count}",
      )
    }
    if seen.get(id) == Some(true) {
      raise BotError::InvalidShardConfig(message="duplicate shard id \{id}")
    }
    seen[id] = true
  }
}

///|
async fn Bot::gateway_bot_info(
  self : Bot,
  client : @dhttp.Client,
) -> @model.GatewayBotInfo raise @dhttp.DiscordHttpError {
  match self.gateway_bot_info_.val {
    Some(info) => info
    None => client.get_gateway_bot()
  }
}

///|
fn[X] Bot::start_managed_shard(
  self : Bot,
  group : @async.TaskGroup[X],
  token~ : String,
  intents~ : @model.Intents,
  gateway_url~ : String,
  shard_id~ : Int,
  shard_count~ : Int,
  identify_queue~ : &@queue.IdentifyQueue,
  event_filter~ : (@model.EventKind) -> Bool,
) -> @gateway.Shard {
  match self.connector_.val {
    Some(connector) =>
      @gateway.Shard::start(
        group,
        token~,
        intents~,
        gateway_url~,
        shard_id~,
        shard_count~,
        identify_queue~,
        event_filter~,
        connector~,
        compress=self.compress_,
        telemetry=event => self.emit_telemetry(event),
      )
    None =>
      @gateway.Shard::start(
        group,
        token~,
        intents~,
        gateway_url~,
        shard_id~,
        shard_count~,
        identify_queue~,
        event_filter~,
        compress=self.compress_,
        telemetry=event => self.emit_telemetry(event),
      )
  }
}

///|
async fn Bot::resolve_shards(
  self : Bot,
  client : @dhttp.Client,
) -> ResolvedShardConfig {
  match self.shards_ {
    Single(id~, count~) => {
      let ids = [id]
      validate_shard_ids(ids, count)
      let gateway_url = match self.gateway_url_ {
        Some(url) => url
        None => client.get_gateway()
      }
      { ids, count, gateway_url, max_concurrency: 1 }
    }
    Auto | Fixed(_) | Range(..) => {
      let info = self.gateway_bot_info(client)
      let (ids, count) = match self.shards_ {
        Auto => {
          let ids = []
          for id in 0..<info.shards {
            ids.push(id)
          }
          (ids, info.shards)
        }
        Fixed(count~) => {
          let ids = []
          for id in 0..<count {
            ids.push(id)
          }
          (ids, count)
        }
        Range(ids~, count~) => (ids.copy(), count)
        Single(..) => abort("handled above")
      }
      validate_shard_ids(ids, count)
      if info.session_start_limit.max_concurrency <= 0 {
        raise BotError::InvalidShardConfig(
          message="gateway max_concurrency must be positive",
        )
      }
      if ids.length() > info.session_start_limit.remaining {
        raise BotError::SessionStartLimitExceeded(
          required=ids.length(),
          remaining=info.session_start_limit.remaining,
          reset_after_ms=info.session_start_limit.reset_after,
        )
      }
      {
        ids,
        count,
        gateway_url: self.gateway_url_.unwrap_or(info.url),
        max_concurrency: info.session_start_limit.max_concurrency,
      }
    }
  }
}

///|
async fn close_shards(shards : Array[@gateway.Shard]) -> Unit noraise {
  for shard in shards {
    shard.close()
  }
}
