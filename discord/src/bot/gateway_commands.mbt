///|
/// Members and optional presence/not-found fragments collected from all chunks.
pub(all) struct FetchedMembers {
  members : Array[@model.GuildMember]
  presences : Array[@model.PresenceUpdateEvent]
  not_found : Array[Json]
} derive(Debug)

///|
/// Broadcast presence to all locally managed shards. Shards in other processes
/// are not reached. Attempts every local shard, then raises the first error.
pub async fn GatewayCtx::update_presence(
  self : GatewayCtx,
  presence : @model.UpdatePresence,
) -> Unit {
  let mut first_error : Error? = None
  for shard in self.shards_ {
    shard.update_presence(presence) catch {
      error => if first_error is None { first_error = Some(error) }
    }
  }
  if first_error is Some(error) {
    raise error
  }
}

///|
fn GatewayCtx::guild_shard(
  self : GatewayCtx,
  guild_id : @model.GuildId,
) -> @gateway.Shard raise BotError {
  let shard_id = guild_shard_id(guild_id, self.shard_count_)
  guard self.shard_routes_.get(shard_id) is Some(shard) else {
    raise ShardNotManaged(shard_id~)
  }
  shard
}

///|
/// Validate and route a member request; raises `ShardNotManaged` for remote shards.
pub async fn GatewayCtx::request_guild_members(
  self : GatewayCtx,
  request : @model.RequestGuildMembers,
) -> Unit {
  self.guild_shard(request.guild_id).request_guild_members(request)
}

///|
/// Group guild ids by owning shard. Every owner is checked before any send;
/// raises `ShardNotManaged` if any guild belongs to another process.
pub async fn GatewayCtx::request_soundboard_sounds(
  self : GatewayCtx,
  request : @model.RequestSoundboardSounds,
) -> Unit {
  let groups : Map[Int32, Array[@model.GuildId]] = Map([])
  for guild_id in request.guild_ids {
    let shard_id = guild_shard_id(guild_id, self.shard_count_)
    self.guild_shard(guild_id) |> ignore
    match groups.get(shard_id) {
      Some(ids) => ids.push(guild_id)
      None => groups[shard_id] = [guild_id]
    }
  }
  for shard_id, guild_ids in groups {
    self.shard_routes_[shard_id].request_soundboard_sounds({ guild_ids, })
  }
}

///|
/// Route an ephemeral channel-info request; raises `ShardNotManaged` for remote shards.
pub async fn GatewayCtx::request_channel_info(
  self : GatewayCtx,
  request : @model.RequestChannelInfo,
) -> Unit {
  self.guild_shard(request.guild_id).request_channel_info(request)
}

///|
let member_request_nonce : Ref[UInt64] = Ref(0)

///|
/// Whether a RATE_LIMITED event answers this member request: opcode 8 for
/// the guild, with this nonce or none at all.
fn rate_limit_matches(
  event : @model.GatewayRateLimitedEvent,
  guild_id : @model.GuildId,
  nonce : String,
) -> Bool {
  guard event.opcode == 8 && event.meta is { "guild_id": value, .. } else {
    return false
  }
  let matched = (@json.from_json(value) : @model.GuildId) catch {
    _ => return false
  }
  matched == guild_id &&
  (match event.meta {
    { "nonce": String(value), .. } => value == nonce
    { "nonce": _, .. } => false
    _ => true
  })
}

///|
/// Fetch every matching member chunk with a process-unique nonce. Requires
/// GUILD_MEMBERS for `All` and GUILD_PRESENCES when requesting presences.
/// The deadline includes sending; raises `GatewayRequestTimeout` on timeout,
/// `GatewayRateLimited` for a matching RATE_LIMITED response, and
/// `ShardNotManaged` for a remote shard. All expectations are cancelled on exit.
pub async fn GatewayCtx::fetch_guild_members(
  self : GatewayCtx,
  guild_id : @model.GuildId,
  select : @model.MemberSelect,
  presences~ : Bool = false,
  timeout_ms~ : Int32 = 10000,
) -> FetchedMembers {
  member_request_nonce.val += 1
  let nonce = "members-\{member_request_nonce.val}"
  let chunks = self.collector_.register(
    Events::guild_members_chunk(),
    event => event.guild_id == guild_id && event.nonce == Some(nonce),
    persistent=true,
  )
  defer chunks.cancel()
  let limited = self.expect_event(Events::rate_limited(), event => {
    rate_limit_matches(event, guild_id, nonce)
  })
  defer limited.cancel()
  let result = @transport.with_timeout_opt(
    self.collector_.clock.val,
    timeout_ms,
    () => {
      @async.with_task_group(group => {
        group.spawn_bg(no_wait=true, () => {
          if limited.waiter.queue.get() is RateLimited(event) {
            raise GatewayRateLimited(
              opcode=event.opcode,
              retry_after_ms=(event.retry_after * 1000.0).ceil().to_int64(),
            )
          }
        })
        self.request_guild_members({
          guild_id,
          select,
          presences,
          nonce: Some(nonce),
        })
        let collected = MemberChunks::new()
        for ;; {
          if chunks.waiter.queue.get() is GuildMembersChunk(chunk) &&
            collected.add(chunk) is Some(fetched) {
            group.return_immediately(fetched)
          }
        }
      })
    },
  )
  guard result is Some(result) else { raise GatewayRequestTimeout }
  result
}
