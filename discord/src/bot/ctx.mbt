///|
/// Gateway-only services passed to event and service handlers after READY.
#warnings("-unused_field")
pub struct GatewayCtx {
  priv app_ : @app.AppCtx
  priv mut ready_ : @model.Ready
  priv intents_ : @model.Intents
  priv shard_ : @gateway.Shard
  priv shards_ : Array[@gateway.Shard]
  priv shard_routes_ : Map[Int32, @gateway.Shard]
  priv shard_count_ : Int32
  priv cache_ : @cache.InMemoryCache?
  priv framework_ : @framework.Framework
  priv collector_ : EventCollector
  priv shutdown_requested_ : Ref[Bool]
}

///|
/// The transport-neutral application context for REST access.
pub fn GatewayCtx::app(self : GatewayCtx) -> @app.AppCtx {
  self.app_
}

///|
/// The latest READY payload for this gateway session.
pub fn GatewayCtx::ready(self : GatewayCtx) -> @model.Ready {
  self.ready_
}

///|
/// The latest heartbeat round-trip time for this context's shard. Unlike
/// `AppCtx::latency_ms()`, this is the exact shard value rather than the mean
/// across shards with measured latency.
pub fn GatewayCtx::latency_ms(self : GatewayCtx) -> Int64? {
  self.shard_.latency_ms()
}

///|
/// The cache attached with `BotBuilder::attach_cache`, or `None` when no cache is
/// attached.
pub fn GatewayCtx::cache(self : GatewayCtx) -> @cache.InMemoryCache? {
  self.cache_
}

///|
/// Access the underlying gateway shard.
pub fn GatewayCtx::shard_raw(self : GatewayCtx) -> @gateway.Shard {
  self.shard_
}

///|
/// Access the underlying interaction framework.
pub fn GatewayCtx::framework_raw(self : GatewayCtx) -> @framework.Framework {
  self.framework_
}

///|
/// Bind a channel id to the gateway REST client.
pub fn GatewayCtx::channel_ref(
  self : GatewayCtx,
  channel_id : @model.ChannelId,
) -> @dhttp.ChannelRef {
  self.app_.http().channel_ref(channel_id)
}

///|
/// Resolve a channel with a cache-first lookup, including cached threads.
/// Cache misses (including a disabled channels resource) fall back to REST.
/// This favors speed; use `channel_ref(id).fetch()` when the latest channel
/// state is required. A REST result is deliberately not written back because
/// gateway events are the cache's only mutation entry point.
///
/// `MessageCreateEvent.channel_type` is commonly absent, so resolving the
/// channel makes thread detection straightforward:
///
/// ```mbt nocheck
/// let channel = ctx.resolve_channel(event.message.channel_id)
///
/// let is_thread = match channel.typ {
///   AnnouncementThread | PublicThread | PrivateThread => true
///   _ => false
/// }
/// ```
pub async fn GatewayCtx::resolve_channel(
  self : GatewayCtx,
  channel_id : @model.ChannelId,
) -> @model.Channel raise @dhttp.DiscordHttpError {
  if self.cache_ is Some(cache) {
    if cache.channel(channel_id) is Some(channel) {
      return channel
    }
  }
  self.channel_ref(channel_id).fetch()
}

///|
/// Bind a guild id to the gateway REST client.
pub fn GatewayCtx::guild_ref(
  self : GatewayCtx,
  guild_id : @model.GuildId,
) -> @dhttp.GuildRef {
  self.app_.http().guild_ref(guild_id)
}

///|
/// Bind a guild/user id pair to the gateway REST client.
pub fn GatewayCtx::member_ref(
  self : GatewayCtx,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
) -> @dhttp.MemberRef {
  self.app_.http().member_ref(guild_id, user_id)
}

///|
/// Bind a user id to the gateway REST client.
pub fn GatewayCtx::user_ref(
  self : GatewayCtx,
  user_id : @model.UserId,
) -> @dhttp.UserRef {
  self.app_.http().user_ref(user_id)
}

///|
/// Bind a message-create event's message to the gateway REST client.
pub fn GatewayCtx::message_ref(
  self : GatewayCtx,
  event : @model.MessageCreateEvent,
) -> @dhttp.MessageRef {
  self.app_.http().ref_of_message(event.message)
}

///|
/// Bind a message model to the gateway REST client.
pub fn GatewayCtx::ref_of_message(
  self : GatewayCtx,
  message : @model.Message,
) -> @dhttp.MessageRef {
  self.app_.http().ref_of_message(message)
}

///|
/// Wait for the next click on the component `route.custom_id(state)`
/// identifies, optionally only from `user`. A gateway event has no invoking
/// user, so unlike the interaction contexts' `from` filter this one defaults to
/// anyone. Returns `None` on timeout; raises `CustomIdError` when the state
/// does not encode. The returned context has not been answered and skips the
/// automatic defer: respond to it within three seconds. For an id not built by
/// a route, use `framework_raw().wait_for_component(custom_id~)`.
pub async fn[A] GatewayCtx::wait_for_component(
  self : GatewayCtx,
  route : @app.ComponentRoute[A],
  state : A,
  user? : @model.UserId,
  timeout_ms? : Int32,
) -> @framework.ComponentCtx? {
  self.framework_.wait_for_component(
    custom_id=route.custom_id(state),
    user?,
    timeout_ms?,
  )
}

///|
/// Wait for the next gateway event of `event_type` that satisfies `predicate`.
/// The event remains visible to other collectors and registered handlers.
/// Returns `None` on timeout. The caller must enable an intent capable of
/// delivering the requested event when it is not already subscribed.
pub async fn[T] GatewayCtx::wait_for(
  self : GatewayCtx,
  event_type : EventType[T],
  predicate : (T) -> Bool,
  timeout_ms? : Int32,
) -> T? {
  self.expect_event(event_type, predicate).wait(timeout_ms?)
}

///|
/// Expect the next gateway event of `event_type` that satisfies `predicate`.
/// The expectation is registered now, so create it before sending the command
/// that makes Discord dispatch the event, then `wait` for it. Like `wait_for`,
/// the event stays visible to other collectors and registered handlers.
pub fn[T] GatewayCtx::expect_event(
  self : GatewayCtx,
  event_type : EventType[T],
  predicate : (T) -> Bool,
) -> PendingEvent[T] {
  self.collector_.register(event_type, predicate)
}

///|
/// The intents this bot identified with.
pub fn GatewayCtx::intents(self : GatewayCtx) -> @model.Intents {
  self.intents_
}

///|
/// Send opcode 4 (Update Voice State) on the shard that owns
/// `state.guild_id`, which need not be this context's shard. Raises
/// `BotError::ShardNotManaged` when that shard runs in another process.
pub async fn GatewayCtx::update_voice_state(
  self : GatewayCtx,
  state : @model.UpdateVoiceState,
) -> Unit {
  let shard_id = guild_shard_id(state.guild_id, self.shard_count_)
  guard self.shard_routes_.get(shard_id) is Some(shard) else {
    raise BotError::ShardNotManaged(shard_id~)
  }
  shard.update_voice_state(state)
}

///|
/// The shard Discord assigns a guild to: `(guild_id >> 22) % shard_count`.
fn guild_shard_id(
  guild_id : @model.Id[@model.GuildMarker],
  shard_count : Int32,
) -> Int32 {
  ((guild_id.value() >> 22) % shard_count.to_uint64()).to_int()
}

///|
/// Request a graceful stop. Closing every managed shard wakes the run loop;
/// the task group then waits for already-started handlers before returning.
pub async fn GatewayCtx::shutdown(self : GatewayCtx) -> Unit {
  self.shutdown_requested_.val = true
  close_shards(self.shards_)
}
