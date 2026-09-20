///|
/// Gateway-only services passed to event and service handlers after READY.
pub struct GatewayCtx {
  priv app_ : @app.AppCtx
  priv mut ready_ : @model.Ready
  priv intents_ : @model.Intents
  priv shard_ : @gateway.Shard
  priv shards_ : Array[@gateway.Shard]
  priv cache_ : @cache.InMemoryCache?
  priv framework_ : @framework.Framework
  priv collector_ : EventCollector
  priv group_ : @async.TaskGroup[Unit]
  priv voice_connections_ : Map[
    @model.Id[@model.GuildMarker],
    @voice.VoiceConnection,
  ]
  priv voice_join_gates_ : Map[@model.Id[@model.GuildMarker], @async.Semaphore]
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
/// The cache attached with `Bot::attach_cache`, or `None` when no cache is
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
/// Wait for the next component interaction with an exact custom id, optionally
/// restricted to one invoking user.
pub async fn GatewayCtx::wait_for_component(
  self : GatewayCtx,
  custom_id~ : String,
  user? : @model.UserId,
  timeout_ms? : Int,
) -> @framework.ComponentCtx? {
  self.framework_.wait_for_component(custom_id~, user?, timeout_ms?)
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
  timeout_ms? : Int,
) -> T? {
  self.collector_.wait_for(event_type, predicate, timeout_ms?)
}

///|
/// Request a graceful stop. Closing every managed shard wakes the run loop;
/// the task group then waits for already-started handlers before returning.
pub async fn GatewayCtx::shutdown(self : GatewayCtx) -> Unit {
  self.shutdown_requested_.val = true
  close_shards(self.shards_)
}
