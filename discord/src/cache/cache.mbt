///|
/// Selects which gateway resources an in-memory cache retains.
///
/// Guilds, channels, roles, members, users, and voice states are enabled by
/// default. Presences and messages are opt-in because they are high-churn and
/// can dominate memory use on larger bots.
pub struct CacheResources {
  priv guilds_ : Bool
  priv channels_ : Bool
  priv roles_ : Bool
  priv members_ : Bool
  priv users_ : Bool
  priv voice_states_ : Bool
  priv presences_ : Bool
  priv messages_ : Bool
}

///|
/// Select the retained resources individually; unspecified flags keep
/// their defaults (all on except presences and messages).
pub fn CacheResources::CacheResources(
  guilds~ : Bool = true,
  channels~ : Bool = true,
  roles~ : Bool = true,
  members~ : Bool = true,
  users~ : Bool = true,
  voice_states~ : Bool = true,
  presences~ : Bool = false,
  messages~ : Bool = false,
) -> CacheResources {
  {
    guilds_: guilds,
    channels_: channels,
    roles_: roles,
    members_: members,
    users_: users,
    voice_states_: voice_states,
    presences_: presences,
    messages_: messages,
  }
}

///|
/// Retain every resource, including high-churn presences and messages.
pub fn CacheResources::all() -> CacheResources {
  CacheResources(presences=true, messages=true)
}

///|
/// Retain nothing; enable resources from this baseline for a minimal
/// cache.
pub fn CacheResources::none() -> CacheResources {
  CacheResources(
    guilds=false,
    channels=false,
    roles=false,
    members=false,
    users=false,
    voice_states=false,
  )
}

///|
/// The default selection (see `CacheResources`).
pub fn CacheResources::default() -> CacheResources {
  CacheResources()
}

///|
/// Bounds one cached resource by entry count, lifetime, or both.
///
/// Negative limits clamp to zero. A `max_entries` of zero retains nothing,
/// while a `ttl_ms` of zero makes entries expire immediately. TTL deadlines
/// are fixed when an entry is written and are never extended by reads; expiry
/// is enforced lazily without background timers.
pub struct CacheLimit {
  priv max_entries_ : Int32?
  priv ttl_ms_ : Int64?
}

///|
/// Create an optional entry-count and TTL limit for one resource.
pub fn CacheLimit::CacheLimit(
  max_entries? : Int32,
  ttl_ms? : Int64,
) -> CacheLimit {
  {
    max_entries_: max_entries.map(value => value.max(0)),
    ttl_ms_: ttl_ms.map(value => value.max(0L)),
  }
}

///|
/// Per-resource bounds for an in-memory cache.
///
/// Guild, channel, and user limits are global. Role, member, voice-state, and
/// presence limits apply independently per guild; message limits apply
/// independently per channel. Everything keyed by a guild or channel leaves
/// with it: when a cached guild or channel is deleted, evicted by its entry
/// limit, or expires, its roles, members, voice states, presences, channels,
/// and messages go too, and per-guild and per-channel maps are dropped once
/// empty. All structures are therefore bounded by the configured limits,
/// except the unavailable-guild flags, which are bounded by the number of
/// guilds the bot is in. State for a guild or channel the cache does not hold
/// (its retention is off, or the event arrived after it left) still obeys its
/// per-guild or per-channel limit and goes when the guild or channel is
/// deleted. TTLs use fixed, non-sliding deadlines set at write time and are
/// enforced lazily without background timers.
pub struct CacheLimits {
  priv guilds_ : CacheLimit
  priv channels_ : CacheLimit
  priv users_ : CacheLimit
  priv roles_ : CacheLimit
  priv members_ : CacheLimit
  priv voice_states_ : CacheLimit
  priv presences_ : CacheLimit
  priv messages_ : CacheLimit
}

///|
/// Configure limits for each resource. Messages retain at most 100 entries
/// per channel by default; other resources are unbounded by default.
pub fn CacheLimits::CacheLimits(
  guilds~ : CacheLimit = CacheLimit(),
  channels~ : CacheLimit = CacheLimit(),
  users~ : CacheLimit = CacheLimit(),
  roles~ : CacheLimit = CacheLimit(),
  members~ : CacheLimit = CacheLimit(),
  voice_states~ : CacheLimit = CacheLimit(),
  presences~ : CacheLimit = CacheLimit(),
  messages~ : CacheLimit = CacheLimit(max_entries=100),
) -> CacheLimits {
  {
    guilds_: guilds,
    channels_: channels,
    users_: users,
    roles_: roles,
    members_: members,
    voice_states_: voice_states,
    presences_: presences,
    messages_: messages,
  }
}

///|
/// The default per-resource limits (see `CacheLimits`).
pub fn CacheLimits::default() -> CacheLimits {
  CacheLimits()
}

///|
priv struct Timed[V] {
  value : V
  deadline : Int64?
}

///|
/// Entries the map drops on its own, because they expired or exceed the entry
/// limit, are reported to the `evicted` callback of the operation that
/// dropped them. A map whose keys own other cached state must pass one.
priv struct TimedMap[K, V] {
  entries_ : Map[K, Timed[V]]
  limit_ : CacheLimit
  now_ : () -> Int64
}

///|
fn[K : Hash + Eq, V] TimedMap::new(
  limit : CacheLimit,
  now : () -> Int64,
) -> TimedMap[K, V] {
  { entries_: Map([]), limit_: limit, now_: now, }
}

///|
fn[K, V] TimedMap::is_expired(self : TimedMap[K, V], timed : Timed[V]) -> Bool {
  timed.deadline is Some(deadline) && deadline <= (self.now_)()
}

///|
fn[K : Hash + Eq, V] TimedMap::evict(
  self : TimedMap[K, V],
  key : K,
  evicted : (K) -> Unit,
) -> Unit {
  self.entries_.remove(key) |> ignore
  evicted(key)
}

///|
/// Deadlines are non-decreasing in insertion order (`put` appends with a
/// fresh deadline; `replace_existing` keeps the original), so removing the
/// expired insertion-order prefix removes every expired entry.
fn[K : Hash + Eq, V] TimedMap::sweep(
  self : TimedMap[K, V],
  evicted~ : (K) -> Unit = _ => (),
) -> Unit {
  while self.entries_.iter().head() is Some((expired_key, timed)) &&
        self.is_expired(timed) {
    self.evict(expired_key, evicted)
  }
}

///|
fn[K : Hash + Eq, V] TimedMap::put(
  self : TimedMap[K, V],
  key : K,
  value : V,
  evicted~ : (K) -> Unit = _ => (),
) -> Unit {
  self.sweep(evicted~)
  guard self.limit_.max_entries_ != Some(0) else { return }
  self.entries_.remove(key) |> ignore
  self.entries_[key] = {
    value,
    deadline: self.limit_.ttl_ms_.map(ttl => (self.now_)() + ttl),
  }
  if self.limit_.max_entries_ is Some(max_entries) {
    while self.entries_.length() > max_entries {
      let (oldest_key, _) = self.entries_.iter().head().unwrap()
      self.evict(oldest_key, evicted)
    }
  }
}

///|
fn[K : Hash + Eq, V] TimedMap::replace_existing(
  self : TimedMap[K, V],
  key : K,
  value : V,
  evicted~ : (K) -> Unit = _ => (),
) -> Unit {
  guard self.entries_.get(key) is Some(timed) else { return }
  if self.is_expired(timed) {
    self.evict(key, evicted)
    return
  }
  self.entries_[key] = { value, deadline: timed.deadline, }
}

///|
fn[K : Hash + Eq, V] TimedMap::get(
  self : TimedMap[K, V],
  key : K,
  evicted~ : (K) -> Unit = _ => (),
) -> V? {
  guard self.entries_.get(key) is Some(timed) else { return None }
  if self.is_expired(timed) {
    self.evict(key, evicted)
    return None
  }
  Some(timed.value)
}

///|
fn[K : Hash + Eq, V] TimedMap::remove(self : TimedMap[K, V], key : K) -> Unit {
  self.entries_.remove(key) |> ignore
}

///|
fn[K : Hash + Eq, V] TimedMap::values(
  self : TimedMap[K, V],
  evicted~ : (K) -> Unit = _ => (),
) -> Array[V] {
  self.sweep(evicted~)
  [
    for timed in self.entries_.values() => timed.value
  ]
}

///|
/// Keys of every stored entry matching `pred`, expired or not.
fn[K, V] TimedMap::keys_where(
  self : TimedMap[K, V],
  pred : (V) -> Bool,
) -> Array[K] {
  let keys = []
  for key, timed in self.entries_ {
    if pred(timed.value) {
      keys.push(key)
    }
  }
  keys
}

///|
/// One owner's entries of a per-guild or per-channel resource. A per-channel
/// bucket also records the channel's guild, so the guild's departure finds it
/// even when the channel itself is not cached.
priv struct Bucket[K, V] {
  mut guild_id : @model.GuildId?
  entries : TimedMap[K, V]
}

///|
/// A resource kept in one bounded map per owner (guild or channel). Every
/// operation drops the bucket it leaves empty, so the outer map holds only
/// owners with retained entries.
priv struct Buckets[O, K, V] {
  buckets_ : Map[O, Bucket[K, V]]
  limit_ : CacheLimit
  now_ : () -> Int64
}

///|
fn[O : Hash + Eq, K, V] Buckets::new(
  limit : CacheLimit,
  now : () -> Int64,
) -> Buckets[O, K, V] {
  { buckets_: Map([]), limit_: limit, now_: now, }
}

///|
fn[O : Hash + Eq, K, V] Buckets::drop_if_empty(
  self : Buckets[O, K, V],
  owner : O,
  bucket : Bucket[K, V],
) -> Unit {
  if bucket.entries.entries_.is_empty() {
    self.buckets_.remove(owner) |> ignore
  }
}

///|
fn[O : Hash + Eq, K : Hash + Eq, V] Buckets::get(
  self : Buckets[O, K, V],
  owner : O,
  key : K,
) -> V? {
  guard self.buckets_.get(owner) is Some(bucket) else { return None }
  let value = bucket.entries.get(key)
  self.drop_if_empty(owner, bucket)
  value
}

///|
fn[O : Hash + Eq, K : Hash + Eq, V] Buckets::values(
  self : Buckets[O, K, V],
  owner : O,
) -> Array[V] {
  guard self.buckets_.get(owner) is Some(bucket) else { return [] }
  let values = bucket.entries.values()
  self.drop_if_empty(owner, bucket)
  values
}

///|
fn[O : Hash + Eq, K : Hash + Eq, V] Buckets::put(
  self : Buckets[O, K, V],
  owner : O,
  key : K,
  value : V,
  guild_id? : @model.GuildId,
) -> Unit {
  let bucket = match self.buckets_.get(owner) {
    Some(bucket) => bucket
    None => {
      let bucket = {
        guild_id: None,
        entries: TimedMap::new(self.limit_, self.now_),
      }
      self.buckets_[owner] = bucket
      bucket
    }
  }
  bucket.guild_id = prefer_update(guild_id, bucket.guild_id)
  bucket.entries.put(key, value)
  self.drop_if_empty(owner, bucket)
}

///|
fn[O : Hash + Eq, K : Hash + Eq, V] Buckets::replace_existing(
  self : Buckets[O, K, V],
  owner : O,
  key : K,
  value : V,
  guild_id? : @model.GuildId,
) -> Unit {
  guard self.buckets_.get(owner) is Some(bucket) else { return }
  bucket.guild_id = prefer_update(guild_id, bucket.guild_id)
  bucket.entries.replace_existing(key, value)
  self.drop_if_empty(owner, bucket)
}

///|
fn[O : Hash + Eq, K : Hash + Eq, V] Buckets::remove(
  self : Buckets[O, K, V],
  owner : O,
  key : K,
) -> Unit {
  guard self.buckets_.get(owner) is Some(bucket) else { return }
  bucket.entries.remove(key)
  self.drop_if_empty(owner, bucket)
}

///|
fn[O : Hash + Eq, K, V] Buckets::drop(
  self : Buckets[O, K, V],
  owner : O,
) -> Unit {
  self.buckets_.remove(owner) |> ignore
}

///|
/// Drops every bucket recorded as belonging to `guild_id`.
fn[O : Hash + Eq, K, V] Buckets::drop_guild(
  self : Buckets[O, K, V],
  guild_id : @model.GuildId,
) -> Unit {
  let owners = []
  for owner, bucket in self.buckets_ {
    if bucket.guild_id == Some(guild_id) {
      owners.push(owner)
    }
  }
  for owner in owners {
    self.buckets_.remove(owner) |> ignore
  }
}

///|
fn[T] prefer_update(value : T?, previous : T?) -> T? {
  match value {
    Some(_) => value
    None => previous
  }
}

///|
fn is_thread(channel : @model.Channel) -> Bool {
  match channel.typ {
    AnnouncementThread | PublicThread | PrivateThread => true
    _ => false
  }
}

///|
/// A retained channel with its guild, which gateway payloads omit for the
/// channels and threads nested in GUILD_CREATE.
priv struct CachedChannel {
  channel : @model.Channel
  guild_id : @model.GuildId?
}

///|
/// A gateway-driven, resource-selective in-memory cache.
///
/// `update` is the only mutation entry point. Entity getters return the model
/// value retained by the cache; callers should treat it as immutable. List
/// getters always allocate a new outer array so callers cannot mutate the
/// cache's collections.
pub struct InMemoryCache {
  priv resources_ : CacheResources
  priv guilds_ : TimedMap[@model.GuildId, @model.Guild]
  priv unavailable_guilds_ : Map[@model.GuildId, Bool]
  priv channels_ : TimedMap[@model.ChannelId, CachedChannel]
  priv roles_ : Buckets[@model.GuildId, @model.RoleId, @model.Role]
  priv members_ : Buckets[@model.GuildId, @model.UserId, @model.GuildMember]
  priv users_ : TimedMap[@model.UserId, @model.User]
  priv voice_states_ : Buckets[@model.GuildId, @model.UserId, @model.VoiceState]
  priv presences_ : Buckets[
    @model.GuildId,
    @model.UserId,
    @model.PresenceUpdateEvent,
  ]
  priv messages_ : Buckets[@model.ChannelId, @model.MessageId, @model.Message]
}

///|
/// Create an empty cache retaining the selected `resources` under the
/// per-resource `limits`. Feed it gateway events via `BotBuilder::attach_cache` (or
/// call `update` manually). TTL deadlines are fixed at write time and expiry
/// is enforced lazily without background timers.
pub fn InMemoryCache::InMemoryCache(
  resources~ : CacheResources,
  limits~ : CacheLimits = CacheLimits(),
  now~ : () -> Int64 = @clock.now_ms,
) -> InMemoryCache {
  {
    resources_: resources,
    guilds_: TimedMap::new(limits.guilds_, now),
    unavailable_guilds_: Map([]),
    channels_: TimedMap::new(limits.channels_, now),
    roles_: Buckets::new(limits.roles_, now),
    members_: Buckets::new(limits.members_, now),
    users_: TimedMap::new(limits.users_, now),
    voice_states_: Buckets::new(limits.voice_states_, now),
    presences_: Buckets::new(limits.presences_, now),
    messages_: Buckets::new(limits.messages_, now),
  }
}

///|
/// Releases everything keyed by a guild that left the cache: its per-guild
/// buckets, its channels, and the messages of its channels, cached or not.
/// The guild entry itself is the caller's: `remove_guild` deletes it, and the
/// guild map has already dropped it when it reports an eviction.
fn InMemoryCache::release_guild(
  self : InMemoryCache,
  guild_id : @model.GuildId,
) -> Unit {
  self.roles_.drop(guild_id)
  self.members_.drop(guild_id)
  self.voice_states_.drop(guild_id)
  self.presences_.drop(guild_id)
  self.messages_.drop_guild(guild_id)
  let channel_ids = self.channels_.keys_where(cached => {
    cached.guild_id == Some(guild_id)
  })
  for channel_id in channel_ids {
    self.remove_channel(channel_id)
  }
}

///|
/// Releases everything keyed by a channel that left the cache. As with
/// `release_guild`, the channel entry itself is the caller's.
fn InMemoryCache::release_channel(
  self : InMemoryCache,
  channel_id : @model.ChannelId,
) -> Unit {
  self.messages_.drop(channel_id)
}

///|
fn InMemoryCache::cached_channel(
  self : InMemoryCache,
  channel_id : @model.ChannelId,
) -> CachedChannel? {
  self.channels_.get(channel_id, evicted=evicted_id => {
    self.release_channel(evicted_id)
  })
}

///|
/// Releases the state of guilds and channels whose TTL has passed, so it does
/// not outlive them while nothing reads the guild or channel. Every read of
/// state owned by a guild or channel calls it first, so an expired owner's
/// state is never served.
fn InMemoryCache::expire_owners(self : InMemoryCache) -> Unit {
  self.guilds_.sweep(evicted=guild_id => self.release_guild(guild_id))
  self.channels_.sweep(evicted=channel_id => self.release_channel(channel_id))
}

///|
fn InMemoryCache::store_user(self : InMemoryCache, user : @model.User) -> Unit {
  if self.resources_.users_ {
    self.users_.put(user.id, user)
  }
}

///|
fn InMemoryCache::store_guild(
  self : InMemoryCache,
  guild : @model.Guild,
) -> Unit {
  self.unavailable_guilds_.remove(guild.id) |> ignore
  if self.resources_.guilds_ {
    self.guilds_.put(guild.id, guild, evicted=guild_id => {
      self.release_guild(guild_id)
    })
  }
  self.store_roles(guild.id, guild.roles)
}

///|
fn InMemoryCache::store_member(
  self : InMemoryCache,
  guild_id : @model.GuildId,
  cached_member : @model.GuildMember,
) -> Unit {
  if cached_member.user is Some(user) {
    self.store_user(user)
    if self.resources_.members_ {
      self.members_.put(guild_id, user.id, cached_member)
    }
  }
}

///|
fn InMemoryCache::store_roles(
  self : InMemoryCache,
  guild_id : @model.GuildId,
  roles : Array[@model.Role],
) -> Unit {
  if self.resources_.roles_ {
    self.roles_.drop(guild_id)
    for role in roles {
      self.roles_.put(guild_id, role.id, role)
    }
  }
}

///|
fn InMemoryCache::store_channel(
  self : InMemoryCache,
  channel : @model.Channel,
  guild_id? : @model.GuildId,
) -> Unit {
  guard self.resources_.channels_ else { return }
  let previous = self.cached_channel(channel.id)
  self.channels_.put(
    channel.id,
    {
      channel,
      guild_id: prefer_update(
        channel.guild_id,
        prefer_update(guild_id, previous.bind(cached => cached.guild_id)),
      ),
    },
    evicted=channel_id => self.release_channel(channel_id),
  )
}

///|
fn InMemoryCache::store_presence(
  self : InMemoryCache,
  presence : @model.PresenceUpdateEvent,
  guild_id? : @model.GuildId,
) -> Unit {
  guard self.resources_.presences_ else { return }
  guard presence.user is Some(user) && user.id is Some(user_id) else { return }
  guard prefer_update(presence.guild_id, guild_id) is Some(resolved_guild_id) else {
    return
  }
  let previous = self.presences_.get(resolved_guild_id, user_id)
  self.presences_.put(resolved_guild_id, user_id, {
    user: prefer_update(presence.user, previous.bind(value => value.user)),
    guild_id: Some(resolved_guild_id),
    status: prefer_update(presence.status, previous.bind(value => value.status)),
    activities: prefer_update(
      presence.activities,
      previous.bind(value => value.activities),
    ),
    client_status: prefer_update(
      presence.client_status,
      previous.bind(value => value.client_status),
    ),
  })
}

///|
fn InMemoryCache::store_voice_state(
  self : InMemoryCache,
  voice_state : @model.VoiceState,
  guild_id? : @model.GuildId,
) -> Unit {
  if voice_state.guild_member is Some(cached_member) {
    guard prefer_update(voice_state.guild_id, guild_id) is Some(member_guild_id) else {
      return
    }
    self.store_member(member_guild_id, cached_member)
  }
  guard self.resources_.voice_states_ else { return }
  guard prefer_update(voice_state.guild_id, guild_id) is Some(resolved_guild_id) else {
    return
  }
  match voice_state.channel_id {
    Null => self.voice_states_.remove(resolved_guild_id, voice_state.user_id)
    Value(_) =>
      self.voice_states_.put(
        resolved_guild_id,
        voice_state.user_id,
        voice_state,
      )
  }
}

///|
fn InMemoryCache::store_message(
  self : InMemoryCache,
  message : @model.Message,
  guild_id : @model.GuildId?,
) -> Unit {
  self.store_user(message.author)
  guard self.resources_.messages_ else { return }
  self.messages_.put(message.channel_id, message.id, message, guild_id?)
}

///|
/// Replace a retained message without changing its eviction position.
/// A cache miss is intentionally left unfilled: an update does not establish
/// that an older message is among the channel's most recent messages.
fn InMemoryCache::update_message(
  self : InMemoryCache,
  message : @model.Message,
  guild_id : @model.GuildId?,
) -> Unit {
  self.store_user(message.author)
  guard self.resources_.messages_ else { return }
  self.messages_.replace_existing(
    message.channel_id,
    message.id,
    message,
    guild_id?,
  )
}

///|
fn InMemoryCache::delete_message(
  self : InMemoryCache,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
) -> Unit {
  self.messages_.remove(channel_id, message_id)
}

///|
fn InMemoryCache::remove_channel(
  self : InMemoryCache,
  channel_id : @model.ChannelId,
) -> Unit {
  self.channels_.remove(channel_id)
  self.release_channel(channel_id)
}

///|
fn InMemoryCache::remove_guild(
  self : InMemoryCache,
  guild_id : @model.GuildId,
) -> Unit {
  self.guilds_.remove(guild_id)
  self.unavailable_guilds_.remove(guild_id) |> ignore
  self.release_guild(guild_id)
}

///|
fn InMemoryCache::seed_available_guild(
  self : InMemoryCache,
  available : @model.AvailableGuildCreateEvent,
) -> Unit {
  let guild_id = available.guild.id
  self.store_guild(available.guild)
  self.members_.drop(guild_id)
  for cached_member in available.members {
    self.store_member(guild_id, cached_member)
  }
  for channel in available.channels {
    self.store_channel(channel, guild_id~)
  }
  for thread in available.threads {
    self.store_channel(thread, guild_id~)
  }
  self.voice_states_.drop(guild_id)
  for voice_state in available.voice_states {
    self.store_voice_state(voice_state, guild_id~)
  }
  self.presences_.drop(guild_id)
  for presence in available.presences {
    self.store_presence(presence, guild_id~)
  }
}

///|
fn InMemoryCache::update_member(
  self : InMemoryCache,
  update : @model.GuildMemberUpdateEvent,
) -> Unit {
  self.store_user(update.user)
  guard self.resources_.members_ else { return }
  let previous = self.member(update.guild_id, update.user.id)
  let cached_member = @model.GuildMember::{
    user: Some(update.user),
    nick: prefer_update(update.nick, previous.bind(value => value.nick)),
    avatar: Some(update.avatar),
    banner: previous.bind(value => value.banner),
    roles: update.roles,
    joined_at: update.joined_at,
    premium_since: prefer_update(
      update.premium_since,
      previous.bind(value => value.premium_since),
    ),
    deaf: prefer_update(update.deaf, previous.bind(value => value.deaf)),
    mute: prefer_update(update.mute, previous.bind(value => value.mute)),
    flags: prefer_update(update.flags, previous.bind(value => value.flags)),
    pending: prefer_update(
      update.pending,
      previous.bind(value => value.pending),
    ),
    permissions: previous.bind(value => value.permissions),
    communication_disabled_until: prefer_update(
      update.communication_disabled_until,
      previous.bind(value => value.communication_disabled_until),
    ),
    avatar_decoration_data: prefer_update(
      update.avatar_decoration_data,
      previous.bind(value => value.avatar_decoration_data),
    ),
    collectibles: previous.bind(value => value.collectibles),
  }
  self.store_member(update.guild_id, cached_member)
}

///|
/// Without retained channels the cache holds nothing keyed by a thread
/// except its messages, which a sync cannot attribute to a parent channel.
fn InMemoryCache::sync_threads(
  self : InMemoryCache,
  sync : @model.ThreadListSyncEvent,
) -> Unit {
  guard self.resources_.channels_ else { return }
  let removed = self.channels_.keys_where(cached => {
    guard cached.guild_id == Some(sync.guild_id) && is_thread(cached.channel) else {
      return false
    }
    match sync.channel_ids {
      None => true
      Some(parent_ids) =>
        cached.channel.parent_id is Some(Value(parent_id)) &&
        parent_ids.contains(parent_id)
    }
  })
  for channel_id in removed {
    self.remove_channel(channel_id)
  }
  for thread in sync.threads {
    self.store_channel(thread, guild_id=sync.guild_id)
  }
}

///|
/// Applies one decoded gateway event. Unsupported events are intentionally
/// ignored for forward compatibility.
pub fn InMemoryCache::update(
  self : InMemoryCache,
  event : @model.Event,
) -> Unit {
  self.expire_owners()
  match event {
    GuildCreate(Available(available)) => self.seed_available_guild(available)
    GuildCreate(Unavailable(guild)) =>
      if self.resources_.guilds_ {
        self.unavailable_guilds_[guild.id] = true
      }
    GuildUpdate(guild) => self.store_guild(guild)
    GuildDelete(guild) =>
      if guild.unavailable {
        if self.resources_.guilds_ {
          self.unavailable_guilds_[guild.id] = true
        }
      } else {
        self.remove_guild(guild.id)
      }
    ChannelCreate(channel) | ChannelUpdate(channel) | ThreadUpdate(channel) =>
      self.store_channel(channel)
    ChannelDelete(channel) => self.remove_channel(channel.id)
    ThreadCreate(create) => self.store_channel(create.channel)
    ThreadDelete(delete) => self.remove_channel(delete.id)
    ThreadListSync(sync) => self.sync_threads(sync)
    GuildRoleCreate(event) | GuildRoleUpdate(event) => {
      guard self.resources_.roles_ else { return }
      self.roles_.put(event.guild_id, event.role.id, event.role)
    }
    GuildRoleDelete(event) => self.roles_.remove(event.guild_id, event.role_id)
    GuildMemberAdd(event) =>
      self.store_member(event.guild_id, event.guild_member)
    GuildMemberRemove(event) => {
      self.store_user(event.user)
      self.members_.remove(event.guild_id, event.user.id)
      self.voice_states_.remove(event.guild_id, event.user.id)
      self.presences_.remove(event.guild_id, event.user.id)
    }
    GuildMemberUpdate(event) => self.update_member(event)
    GuildMembersChunk(event) => {
      for cached_member in event.members {
        self.store_member(event.guild_id, cached_member)
      }
      if event.presences is Some(presences) {
        for presence in presences {
          self.store_presence(presence, guild_id=event.guild_id)
        }
      }
    }
    // A ban does not imply that Discord sent GUILD_MEMBER_REMOVE. Keep member
    // state until that authoritative event arrives.
    GuildBanAdd(event) | GuildBanRemove(event) => self.store_user(event.user)
    Ready(ready) => {
      self.store_user(ready.user)
      if self.resources_.guilds_ {
        for guild in ready.guilds {
          if guild.unavailable {
            self.unavailable_guilds_[guild.id] = true
          } else {
            self.unavailable_guilds_.remove(guild.id) |> ignore
          }
        }
      }
    }
    UserUpdate(user) => self.store_user(user)
    VoiceStateUpdate(voice_state) => self.store_voice_state(voice_state)
    PresenceUpdate(presence) => self.store_presence(presence)
    MessageCreate(event) => self.store_message(event.message, event.guild_id)
    MessageUpdate(event) => self.update_message(event.message, event.guild_id)
    MessageDelete(event) => self.delete_message(event.channel_id, event.id)
    MessageDeleteBulk(event) =>
      for id in event.ids {
        self.delete_message(event.channel_id, id)
      }
    _ => ()
  }
}

///|
/// The cached guild, if retained.
pub fn InMemoryCache::guild(
  self : InMemoryCache,
  id : @model.GuildId,
) -> @model.Guild? {
  self.guilds_.get(id, evicted=guild_id => self.release_guild(guild_id))
}

///|
/// All cached guilds.
pub fn InMemoryCache::guilds(self : InMemoryCache) -> Array[@model.Guild] {
  self.guilds_.values(evicted=guild_id => self.release_guild(guild_id))
}

///|
/// Whether the guild is currently marked unavailable by a `GUILD_DELETE`
/// outage notice.
pub fn InMemoryCache::is_guild_unavailable(
  self : InMemoryCache,
  id : @model.GuildId,
) -> Bool {
  self.unavailable_guilds_.get(id) == Some(true)
}

///|
/// Ids of guilds currently marked unavailable.
pub fn InMemoryCache::unavailable_guilds(
  self : InMemoryCache,
) -> Array[@model.GuildId] {
  self.unavailable_guilds_.keys().to_array()
}

///|
/// The cached channel or thread, if retained.
pub fn InMemoryCache::channel(
  self : InMemoryCache,
  id : @model.ChannelId,
) -> @model.Channel? {
  self.cached_channel(id).map(cached => cached.channel)
}

///|
/// All cached channels and threads.
pub fn InMemoryCache::channels(self : InMemoryCache) -> Array[@model.Channel] {
  self.channels_
  .values(evicted=channel_id => self.release_channel(channel_id))
  .map(cached => cached.channel)
}

///|
/// The cached role, if retained.
pub fn InMemoryCache::role(
  self : InMemoryCache,
  guild_id : @model.GuildId,
  role_id : @model.RoleId,
) -> @model.Role? {
  self.expire_owners()
  self.roles_.get(guild_id, role_id)
}

///|
/// All cached roles of a guild.
pub fn InMemoryCache::roles(
  self : InMemoryCache,
  guild_id : @model.GuildId,
) -> Array[@model.Role] {
  self.expire_owners()
  self.roles_.values(guild_id)
}

///|
/// The cached guild member, if retained.
pub fn InMemoryCache::member(
  self : InMemoryCache,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
) -> @model.GuildMember? {
  self.expire_owners()
  self.members_.get(guild_id, user_id)
}

///|
/// All cached members of a guild (only members seen in events unless
/// the privileged `GUILD_MEMBERS` intent fills the cache).
pub fn InMemoryCache::members(
  self : InMemoryCache,
  guild_id : @model.GuildId,
) -> Array[@model.GuildMember] {
  self.expire_owners()
  self.members_.values(guild_id)
}

///|
/// The cached user, if retained.
pub fn InMemoryCache::user(
  self : InMemoryCache,
  id : @model.UserId,
) -> @model.User? {
  self.users_.get(id)
}

///|
/// All cached users.
pub fn InMemoryCache::users(self : InMemoryCache) -> Array[@model.User] {
  self.users_.values()
}

///|
/// The cached voice state of a user in a guild, if any.
pub fn InMemoryCache::voice_state(
  self : InMemoryCache,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
) -> @model.VoiceState? {
  self.expire_owners()
  self.voice_states_.get(guild_id, user_id)
}

///|
/// All cached voice states of a guild.
pub fn InMemoryCache::voice_states(
  self : InMemoryCache,
  guild_id : @model.GuildId,
) -> Array[@model.VoiceState] {
  self.expire_owners()
  self.voice_states_.values(guild_id)
}

///|
/// The cached presence of a user in a guild, if presences are retained.
pub fn InMemoryCache::presence(
  self : InMemoryCache,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
) -> @model.PresenceUpdateEvent? {
  self.expire_owners()
  self.presences_.get(guild_id, user_id)
}

///|
/// All cached presences of a guild.
pub fn InMemoryCache::presences(
  self : InMemoryCache,
  guild_id : @model.GuildId,
) -> Array[@model.PresenceUpdateEvent] {
  self.expire_owners()
  self.presences_.values(guild_id)
}

///|
/// The cached message, if still retained.
pub fn InMemoryCache::message(
  self : InMemoryCache,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
) -> @model.Message? {
  self.expire_owners()
  self.messages_.get(channel_id, message_id)
}

///|
/// Cached messages of a channel, oldest first, capped by the messages limit.
pub fn InMemoryCache::messages(
  self : InMemoryCache,
  channel_id : @model.ChannelId,
) -> Array[@model.Message] {
  self.expire_owners()
  self.messages_.values(channel_id)
}

///|
/// Computes guild-level permissions from the cached guild, member, and roles.
pub fn InMemoryCache::permissions(
  self : InMemoryCache,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
) -> @model.Permissions? {
  self.expire_owners()
  guard self.resources_.guilds_ &&
    self.resources_.members_ &&
    self.resources_.roles_ else {
    return None
  }
  guard self.guild(guild_id) is Some(guild) &&
    self.member(guild_id, user_id) is Some(cached_member) &&
    self.roles_.get(guild_id, guild_id.cast()) is Some(everyone) else {
    return None
  }
  let role_permissions : Array[@model.Permissions] = []
  for role_id in cached_member.roles {
    guard self.roles_.get(guild_id, role_id) is Some(role) else {
      // Returning a partial permission set would be unsafe: a missing cached
      // role may grant ADMINISTRATOR or another permission.
      return None
    }
    role_permissions.push(role.permissions)
  }
  Some(
    @util.base_permissions(
      is_owner=guild.owner_id == user_id,
      everyone_permissions=everyone.permissions,
      role_permissions~,
    ),
  )
}

///|
/// Computes channel permissions using the cached base resources and channel
/// overwrites. Returns `None` when any required cache resource is disabled or
/// absent.
pub fn InMemoryCache::permissions_in(
  self : InMemoryCache,
  guild_id : @model.GuildId,
  channel_id : @model.ChannelId,
  user_id : @model.UserId,
) -> @model.Permissions? {
  self.expire_owners()
  guard self.resources_.channels_ else { return None }
  guard self.permissions(guild_id, user_id) is Some(base) &&
    self.member(guild_id, user_id) is Some(cached_member) &&
    self.cached_channel(channel_id)
    is Some({ channel, guild_id: channel_guild_id, }) &&
    channel_guild_id == Some(guild_id) else {
    return None
  }
  Some(
    @util.channel_permissions(
      base~,
      guild_id~,
      member_id=user_id,
      role_ids=cached_member.roles,
      overwrites=channel.permission_overwrites.unwrap_or([]),
    ),
  )
}
