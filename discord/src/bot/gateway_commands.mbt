///|
/// Members and optional presence/not-found fragments collected from all chunks.
pub(all) struct FetchedMembers {
  members : Array[@model.GuildMember]
  presences : Array[@model.PresenceUpdateEvent]
  not_found : Array[Json]
} derive(Debug)

///|
/// Broadcast presence to all locally managed shards. Shards in other processes
/// are not reached.
pub async fn GatewayCtx::update_presence(
  self : GatewayCtx,
  presence : @model.UpdatePresence,
) -> Unit {
  for shard in self.shards_ {
    shard.update_presence(presence)
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
    event.opcode == 8 &&
    (match event.meta {
      { "nonce": String(value), .. } => value == nonce
      _ => false
    })
  })
  defer limited.cancel()
  let result = @async.with_timeout_opt(timeout_ms, () => {
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
      let received : Map[Int32, @model.GuildMembersChunkEvent] = Map([])
      let mut count : Int32? = None
      for ;; {
        match chunks.waiter.queue.get() {
          GuildMembersChunk(chunk) => {
            if chunk.chunk_count <= 0 ||
              chunk.chunk_index < 0 ||
              chunk.chunk_index >= chunk.chunk_count {
              continue
            }
            if count is None {
              count = Some(chunk.chunk_count)
            }
            if count != Some(chunk.chunk_count) {
              continue
            }
            received[chunk.chunk_index] = chunk
            if received.length() == chunk.chunk_count {
              let members = []
              let presence_events = []
              let not_found = []
              for index in 0..<chunk.chunk_count {
                let part = received[index]
                members.append(part.members)
                if part.presences is Some(values) {
                  presence_events.append(values)
                }
                if part.not_found is Some(values) {
                  not_found.append(values)
                }
              }
              group.return_immediately(FetchedMembers::{
                members,
                presences: presence_events,
                not_found,
              })
            }
          }
          _ => ()
        }
      }
    })
  })
  guard result is Some(result) else { raise GatewayRequestTimeout }
  result
}
