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
  guilds? : Bool = true,
  channels? : Bool = true,
  roles? : Bool = true,
  members? : Bool = true,
  users? : Bool = true,
  voice_states? : Bool = true,
  presences? : Bool = false,
  messages? : Bool = false,
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
  priv max_entries_ : Int?
  priv ttl_ms_ : Int64?
}

///|
/// Create an optional entry-count and TTL limit for one resource.
pub fn CacheLimit::CacheLimit(
  max_entries? : Int,
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
/// independently per channel. The unavailable-guild flags and the
/// channel-to-guild index are small bookkeeping state and remain unbounded.
/// TTLs use fixed, non-sliding deadlines set at write time and are enforced
/// lazily without background timers.
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
  guilds? : CacheLimit = CacheLimit(),
  channels? : CacheLimit = CacheLimit(),
  users? : CacheLimit = CacheLimit(),
  roles? : CacheLimit = CacheLimit(),
  members? : CacheLimit = CacheLimit(),
  voice_states? : CacheLimit = CacheLimit(),
  presences? : CacheLimit = CacheLimit(),
  messages? : CacheLimit = CacheLimit(max_entries=100),
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
/// Deadlines are non-decreasing in insertion order (`put` appends with a
/// fresh deadline; `replace_existing` keeps the original), so removing the
/// expired insertion-order prefix removes every expired entry.
fn[K : Hash + Eq, V] TimedMap::sweep(self : TimedMap[K, V]) -> Unit {
  while self.entries_.iter().head() is Some((expired_key, timed)) &&
        timed.deadline is Some(deadline) &&
        deadline <= (self.now_)() {
    self.entries_.remove(expired_key) |> ignore
  }
}

///|
fn[K : Hash + Eq, V] TimedMap::put(
  self : TimedMap[K, V],
  key : K,
  value : V,
) -> Unit {
  self.sweep()
  guard self.limit_.max_entries_ != Some(0) else { return }
  self.entries_.remove(key) |> ignore
  self.entries_[key] = {
    value,
    deadline: self.limit_.ttl_ms_.map(ttl => (self.now_)() + ttl),
  }
  if self.limit_.max_entries_ is Some(max_entries) {
    while self.entries_.length() > max_entries {
      let (oldest_key, _) = self.entries_.iter().head().unwrap()
      self.entries_.remove(oldest_key) |> ignore
    }
  }
}

///|
fn[K : Hash + Eq, V] TimedMap::replace_existing(
  self : TimedMap[K, V],
  key : K,
  value : V,
) -> Unit {
  guard self.entries_.get(key) is Some(timed) else { return }
  if timed.deadline is Some(deadline) && deadline <= (self.now_)() {
    self.entries_.remove(key) |> ignore
    return
  }
  self.entries_[key] = { value, deadline: timed.deadline, }
}

///|
fn[K : Hash + Eq, V] TimedMap::get(self : TimedMap[K, V], key : K) -> V? {
  guard self.entries_.get(key) is Some(timed) else { return None }
  if timed.deadline is Some(deadline) && deadline <= (self.now_)() {
    self.entries_.remove(key) |> ignore
    return None
  }
  Some(timed.value)
}

///|
fn[K : Hash + Eq, V] TimedMap::remove(self : TimedMap[K, V], key : K) -> Unit {
  self.entries_.remove(key) |> ignore
}

///|
fn[K : Hash + Eq, V] TimedMap::values(self : TimedMap[K, V]) -> Array[V] {
  self.sweep()
  [
    for timed in self.entries_.values() => timed.value
  ]
}

///|
fn[K : Hash + Eq, V] TimedMap::entries(self : TimedMap[K, V]) -> Array[(K, V)] {
  self.sweep()
  [
    for key, timed in self.entries_ => (key, timed.value)
  ]
}

///|
fn[K : Hash + Eq, K2 : Hash + Eq, V] bucket(
  outer : Map[K, TimedMap[K2, V]],
  key : K,
  limit : CacheLimit,
  now : () -> Int64,
) -> TimedMap[K2, V] {
  match outer.get(key) {
    Some(value) => value
    None => {
      let value = TimedMap::new(limit, now)
      outer[key] = value
      value
    }
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
/// A gateway-driven, resource-selective in-memory cache.
///
/// `update` is the only mutation entry point. Entity getters return the model
/// value retained by the cache; callers should treat it as immutable. List
/// getters always allocate a new outer array so callers cannot mutate the
/// cache's collections.
pub struct InMemoryCache {
  priv resources_ : CacheResources
  priv limits_ : CacheLimits
  priv now_ : () -> Int64
  priv guilds_ : TimedMap[@model.GuildId, @model.Guild]
  priv unavailable_guilds_ : Map[@model.GuildId, Bool]
  priv channels_ : TimedMap[@model.ChannelId, @model.Channel]
  priv channel_guilds_ : Map[@model.ChannelId, @model.GuildId]
  priv roles_ : Map[@model.GuildId, TimedMap[@model.RoleId, @model.Role]]
  priv members_ : Map[
    @model.GuildId,
    TimedMap[@model.UserId, @model.GuildMember],
  ]
  priv users_ : TimedMap[@model.UserId, @model.User]
  priv voice_states_ : Map[
    @model.GuildId,
    TimedMap[@model.UserId, @model.VoiceState],
  ]
  priv presences_ : Map[
    @model.GuildId,
    TimedMap[@model.UserId, @model.PresenceUpdateEvent],
  ]
  priv messages_ : Map[
    @model.ChannelId,
    TimedMap[@model.MessageId, @model.Message],
  ]
}

///|
/// Create an empty cache retaining the selected `resources` under the
/// per-resource `limits`. Feed it gateway events via `Bot::attach_cache` (or
/// call `update` manually). TTL deadlines are fixed at write time and expiry
/// is enforced lazily without background timers.
pub fn InMemoryCache::InMemoryCache(
  resources~ : CacheResources,
  limits? : CacheLimits = CacheLimits(),
  now? : () -> Int64 = @clock.now_ms,
) -> InMemoryCache {
  {
    resources_: resources,
    limits_: limits,
    now_: now,
    guilds_: TimedMap::new(limits.guilds_, now),
    unavailable_guilds_: Map([]),
    channels_: TimedMap::new(limits.channels_, now),
    channel_guilds_: Map([]),
    roles_: Map([]),
    members_: Map([]),
    users_: TimedMap::new(limits.users_, now),
    voice_states_: Map([]),
    presences_: Map([]),
    messages_: Map([]),
  }
}

///|
fn InMemoryCache::store_user(self : InMemoryCache, user : @model.User) -> Unit {
  if self.resources_.users_ {
    self.users_.put(user.id, user)
  }
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
      bucket(self.members_, guild_id, self.limits_.members_, self.now_).put(
        user.id,
        cached_member,
      )
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
    let cached = TimedMap::new(self.limits_.roles_, self.now_)
    for role in roles {
      cached.put(role.id, role)
    }
    self.roles_[guild_id] = cached
  }
}

///|
fn InMemoryCache::store_channel(
  self : InMemoryCache,
  channel : @model.Channel,
  guild_id? : @model.GuildId,
) -> Unit {
  if prefer_update(
      channel.guild_id,
      prefer_update(guild_id, self.channel_guilds_.get(channel.id)),
    )
    is Some(resolved_guild_id) {
    self.channel_guilds_[channel.id] = resolved_guild_id
  }
  if self.resources_.channels_ {
    self.channels_.put(channel.id, channel)
  }
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
  let guild_presences = bucket(
    self.presences_,
    resolved_guild_id,
    self.limits_.presences_,
    self.now_,
  )
  let previous = guild_presences.get(user_id)
  guild_presences.put(user_id, {
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
    Null =>
      if self.voice_states_.get(resolved_guild_id) is Some(states) {
        states.remove(voice_state.user_id)
      }
    Value(_) =>
      bucket(
        self.voice_states_,
        resolved_guild_id,
        self.limits_.voice_states_,
        self.now_,
      ).put(voice_state.user_id, voice_state)
  }
}

///|
fn InMemoryCache::store_message(
  self : InMemoryCache,
  message : @model.Message,
  guild_id : @model.GuildId?,
) -> Unit {
  self.store_user(message.author)
  if guild_id is Some(resolved_guild_id) {
    self.channel_guilds_[message.channel_id] = resolved_guild_id
  }
  guard self.resources_.messages_ else { return }
  bucket(self.messages_, message.channel_id, self.limits_.messages_, self.now_).put(
    message.id,
    message,
  )
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
  if guild_id is Some(resolved_guild_id) {
    self.channel_guilds_[message.channel_id] = resolved_guild_id
  }
  guard self.resources_.messages_ else { return }
  guard self.messages_.get(message.channel_id) is Some(channel_messages) else {
    return
  }
  channel_messages.replace_existing(message.id, message)
}

///|
fn InMemoryCache::delete_message(
  self : InMemoryCache,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
) -> Unit {
  guard self.resources_.messages_ else { return }
  if self.messages_.get(channel_id) is Some(messages) {
    messages.remove(message_id)
  }
}

///|
fn InMemoryCache::remove_channel(
  self : InMemoryCache,
  channel_id : @model.ChannelId,
) -> Unit {
  self.channels_.remove(channel_id)
  self.channel_guilds_.remove(channel_id) |> ignore
  self.messages_.remove(channel_id) |> ignore
}

///|
fn InMemoryCache::remove_guild(
  self : InMemoryCache,
  guild_id : @model.GuildId,
) -> Unit {
  self.guilds_.remove(guild_id)
  self.unavailable_guilds_.remove(guild_id) |> ignore
  self.roles_.remove(guild_id) |> ignore
  self.members_.remove(guild_id) |> ignore
  self.voice_states_.remove(guild_id) |> ignore
  self.presences_.remove(guild_id) |> ignore
  let removed_channels : Array[@model.ChannelId] = []
  for channel_id, channel_guild_id in self.channel_guilds_ {
    if channel_guild_id == guild_id {
      removed_channels.push(channel_id)
    }
  }
  for channel_id in removed_channels {
    self.remove_channel(channel_id)
  }
}

///|
fn InMemoryCache::seed_available_guild(
  self : InMemoryCache,
  available : @model.AvailableGuildCreateEvent,
) -> Unit {
  let guild_id = available.guild.id
  self.unavailable_guilds_.remove(guild_id) |> ignore
  if self.resources_.guilds_ {
    self.guilds_.put(guild_id, available.guild)
  }
  self.store_roles(guild_id, available.guild.roles)
  if self.resources_.members_ {
    self.members_[guild_id] = TimedMap::new(self.limits_.members_, self.now_)
  }
  for cached_member in available.members {
    self.store_member(guild_id, cached_member)
  }
  for channel in available.channels {
    self.store_channel(channel, guild_id~)
  }
  for thread in available.threads {
    self.store_channel(thread, guild_id~)
  }
  if self.resources_.voice_states_ {
    self.voice_states_[guild_id] = TimedMap::new(
      self.limits_.voice_states_,
      self.now_,
    )
  }
  for voice_state in available.voice_states {
    self.store_voice_state(voice_state, guild_id~)
  }
  if self.resources_.presences_ {
    self.presences_[guild_id] = TimedMap::new(
      self.limits_.presences_,
      self.now_,
    )
  }
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
fn InMemoryCache::sync_threads(
  self : InMemoryCache,
  sync : @model.ThreadListSyncEvent,
) -> Unit {
  guard self.resources_.channels_ else { return }
  let removed : Array[@model.ChannelId] = []
  for entry in self.channels_.entries() {
    let (channel_id, channel) = entry
    guard self.channel_guilds_.get(channel_id) == Some(sync.guild_id) &&
      is_thread(channel) else {
      continue
    }
    let should_remove = match sync.channel_ids {
      None => true
      Some(parent_ids) =>
        match channel.parent_id {
          Some(Value(parent_id)) => parent_ids.contains(parent_id)
          _ => false
        }
    }
    if should_remove {
      removed.push(channel_id)
    }
  }
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
  match event {
    GuildCreate(Available(available)) => self.seed_available_guild(available)
    GuildCreate(Unavailable(guild)) =>
      if self.resources_.guilds_ {
        self.unavailable_guilds_[guild.id] = true
      }
    GuildUpdate(guild) => {
      self.unavailable_guilds_.remove(guild.id) |> ignore
      if self.resources_.guilds_ {
        self.guilds_.put(guild.id, guild)
      }
      self.store_roles(guild.id, guild.roles)
    }
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
      bucket(self.roles_, event.guild_id, self.limits_.roles_, self.now_).put(
        event.role.id,
        event.role,
      )
    }
    GuildRoleDelete(event) =>
      if self.roles_.get(event.guild_id) is Some(roles) {
        roles.remove(event.role_id)
      }
    GuildMemberAdd(event) =>
      self.store_member(event.guild_id, event.guild_member)
    GuildMemberRemove(event) => {
      self.store_user(event.user)
      if self.members_.get(event.guild_id) is Some(members) {
        members.remove(event.user.id)
      }
      if self.voice_states_.get(event.guild_id) is Some(states) {
        states.remove(event.user.id)
      }
      if self.presences_.get(event.guild_id) is Some(presences) {
        presences.remove(event.user.id)
      }
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
  self.guilds_.get(id)
}

///|
/// All cached guilds.
pub fn InMemoryCache::guilds(self : InMemoryCache) -> Array[@model.Guild] {
  self.guilds_.values()
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
  self.channels_.get(id)
}

///|
/// All cached channels and threads.
pub fn InMemoryCache::channels(self : InMemoryCache) -> Array[@model.Channel] {
  self.channels_.values()
}

///|
/// The cached role, if retained.
pub fn InMemoryCache::role(
  self : InMemoryCache,
  guild_id : @model.GuildId,
  role_id : @model.RoleId,
) -> @model.Role? {
  self.roles_.get(guild_id).bind(roles => roles.get(role_id))
}

///|
/// All cached roles of a guild.
pub fn InMemoryCache::roles(
  self : InMemoryCache,
  guild_id : @model.GuildId,
) -> Array[@model.Role] {
  self.roles_.get(guild_id).map(roles => roles.values()).unwrap_or([])
}

///|
/// The cached guild member, if retained.
pub fn InMemoryCache::member(
  self : InMemoryCache,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
) -> @model.GuildMember? {
  self.members_.get(guild_id).bind(members => members.get(user_id))
}

///|
/// All cached members of a guild (only members seen in events unless
/// the privileged `GUILD_MEMBERS` intent fills the cache).
pub fn InMemoryCache::members(
  self : InMemoryCache,
  guild_id : @model.GuildId,
) -> Array[@model.GuildMember] {
  self.members_.get(guild_id).map(members => members.values()).unwrap_or([])
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
  self.voice_states_.get(guild_id).bind(states => states.get(user_id))
}

///|
/// All cached voice states of a guild.
pub fn InMemoryCache::voice_states(
  self : InMemoryCache,
  guild_id : @model.GuildId,
) -> Array[@model.VoiceState] {
  self.voice_states_.get(guild_id).map(states => states.values()).unwrap_or([])
}

///|
/// The cached presence of a user in a guild, if presences are retained.
pub fn InMemoryCache::presence(
  self : InMemoryCache,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
) -> @model.PresenceUpdateEvent? {
  self.presences_.get(guild_id).bind(presences => presences.get(user_id))
}

///|
/// All cached presences of a guild.
pub fn InMemoryCache::presences(
  self : InMemoryCache,
  guild_id : @model.GuildId,
) -> Array[@model.PresenceUpdateEvent] {
  self.presences_
  .get(guild_id)
  .map(presences => presences.values())
  .unwrap_or([])
}

///|
/// The cached message, if still retained.
pub fn InMemoryCache::message(
  self : InMemoryCache,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
) -> @model.Message? {
  self.messages_.get(channel_id).bind(messages => messages.get(message_id))
}

///|
/// Cached messages of a channel, oldest first, capped by the messages limit.
pub fn InMemoryCache::messages(
  self : InMemoryCache,
  channel_id : @model.ChannelId,
) -> Array[@model.Message] {
  self.messages_.get(channel_id).map(m => m.values()).unwrap_or([])
}

///|
/// Computes guild-level permissions from the cached guild, member, and roles.
pub fn InMemoryCache::permissions(
  self : InMemoryCache,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
) -> @model.Permissions? {
  guard self.resources_.guilds_ &&
    self.resources_.members_ &&
    self.resources_.roles_ else {
    return None
  }
  guard self.guild(guild_id) is Some(guild) &&
    self.member(guild_id, user_id) is Some(cached_member) &&
    self.roles_.get(guild_id) is Some(roles) &&
    roles.get(guild_id.cast()) is Some(everyone) else {
    return None
  }
  let role_permissions : Array[@model.Permissions] = []
  for role_id in cached_member.roles {
    guard roles.get(role_id) is Some(role) else {
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
  guard self.resources_.channels_ else { return None }
  guard self.permissions(guild_id, user_id) is Some(base) &&
    self.member(guild_id, user_id) is Some(cached_member) &&
    self.channel(channel_id) is Some(channel) &&
    self.channel_guilds_.get(channel_id) == Some(guild_id) else {
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
