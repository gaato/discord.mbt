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
/// is enforced lazily, without background timers: every read and event first
/// releases whatever has expired, with what it owns or holds.
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
/// Guild, channel, DM-channel, user, and recent-user limits are global. Role,
/// member, voice-state, and presence limits apply independently per guild;
/// message limits apply independently per channel. Everything keyed by a
/// guild or channel leaves with it: when a cached guild or channel is
/// deleted, evicted by its limit, or expires, its roles, members, voice
/// states, presences, channels, threads, and messages go too, and per-guild
/// and per-channel maps are dropped once empty. State for a guild or channel
/// the cache does not hold (its retention is off, or the event arrived after
/// it left) still obeys its per-guild or per-channel limit and goes when the
/// guild or channel is deleted.
///
/// Under the defaults every structure is bounded:
/// - guilds and unavailable-guild flags by the guilds the bot is in (a new
///   session's `READY` also drops the guilds it no longer lists);
/// - a guild's channels, roles, members, voice states, and presences by what
///   Discord holds per guild, times those guilds (a fresh `GUILD_CREATE`
///   drops the channels and threads it no longer lists);
/// - threads by the active threads of those guilds: a thread leaves when it
///   is deleted, archived, replaced by a thread list sync, or (private) when
///   the bot is removed from it;
/// - channels without a guild (DMs and group DMs) by `dm_channels`, 128,
///   evicting the least recently written with its messages;
/// - messages by `messages`, 100 per channel, times the channels above;
/// - users by the entries that hold them (members, the authors of cached
///   messages, and the current user), plus `recent_users`, the 128 most
///   recently seen users nothing holds.
///
/// Passing `CacheLimit()` for `dm_channels`, `recent_users`, or `messages`
/// lifts that bound. TTLs use fixed, non-sliding deadlines set at write time
/// (re-storing an entry sets a new one) and are enforced lazily without
/// background timers.
pub struct CacheLimits {
  priv guilds_ : CacheLimit
  priv channels_ : CacheLimit
  priv dm_channels_ : CacheLimit
  priv users_ : CacheLimit
  priv recent_users_ : CacheLimit
  priv roles_ : CacheLimit
  priv members_ : CacheLimit
  priv voice_states_ : CacheLimit
  priv presences_ : CacheLimit
  priv messages_ : CacheLimit
}

///|
/// Configure limits for each resource. Messages retain at most 100 entries
/// per channel, DM channels and recent users at most 128 each; other
/// resources have no limit beyond what keeps them bounded (see
/// `CacheLimits`). The `users` limit applies to held users only.
pub fn CacheLimits::CacheLimits(
  guilds~ : CacheLimit = CacheLimit(),
  channels~ : CacheLimit = CacheLimit(),
  dm_channels~ : CacheLimit = CacheLimit(max_entries=128),
  users~ : CacheLimit = CacheLimit(),
  recent_users~ : CacheLimit = CacheLimit(max_entries=128),
  roles~ : CacheLimit = CacheLimit(),
  members~ : CacheLimit = CacheLimit(),
  voice_states~ : CacheLimit = CacheLimit(),
  presences~ : CacheLimit = CacheLimit(),
  messages~ : CacheLimit = CacheLimit(max_entries=100),
) -> CacheLimits {
  {
    guilds_: guilds,
    channels_: channels,
    dm_channels_: dm_channels,
    users_: users,
    recent_users_: recent_users,
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
/// dropped them. A map whose entries own or hold other cached state must pass
/// one.
priv struct TimedMap[K, V] {
  entries_ : Map[K, Timed[V]]
  limit_ : CacheLimit
  now_ : () -> Int64
}

///|
/// What `TimedMap::put` did with the new value.
priv enum Put[V] {
  /// A zero entry limit: nothing was stored.
  Refused
  Inserted
  /// The value replaced the key's previous one.
  Replaced(V)
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
  timed : Timed[V],
  evicted : (K, V) -> Unit,
) -> Unit {
  self.entries_.remove(key)
  evicted(key, timed.value)
}

///|
/// Deadlines are non-decreasing in insertion order (`put` appends with a
/// fresh deadline; `replace_existing` keeps the original), so removing the
/// expired insertion-order prefix removes every expired entry.
fn[K : Hash + Eq, V] TimedMap::sweep(
  self : TimedMap[K, V],
  evicted~ : (K, V) -> Unit = (_, _) => (),
) -> Unit {
  while self.entries_.iter().head() is Some((expired_key, timed)) &&
        self.is_expired(timed) {
    self.evict(expired_key, timed, evicted)
  }
}

///|
fn[K : Hash + Eq, V] TimedMap::put(
  self : TimedMap[K, V],
  key : K,
  value : V,
  evicted~ : (K, V) -> Unit = (_, _) => (),
) -> Put[V] {
  self.sweep(evicted~)
  guard self.limit_.max_entries_ != Some(0) else { return Refused }
  let previous = self.entries_.remove_and_get(key)
  self.entries_[key] = {
    value,
    deadline: self.limit_.ttl_ms_.map(ttl => (self.now_)() + ttl),
  }
  if self.limit_.max_entries_ is Some(max_entries) {
    while self.entries_.length() > max_entries {
      let (oldest_key, oldest) = self.entries_.iter().head().unwrap()
      self.evict(oldest_key, oldest, evicted)
    }
  }
  match previous {
    Some(timed) => Replaced(timed.value)
    None => Inserted
  }
}

///|
/// Replaces a live entry in place, returning the value it replaced; a missing
/// or expired key stores nothing.
fn[K : Hash + Eq, V] TimedMap::replace_existing(
  self : TimedMap[K, V],
  key : K,
  value : V,
  evicted~ : (K, V) -> Unit = (_, _) => (),
) -> V? {
  guard self.entries_.get(key) is Some(timed) else { return None }
  if self.is_expired(timed) {
    self.evict(key, timed, evicted)
    return None
  }
  self.entries_[key] = { value, deadline: timed.deadline, }
  Some(timed.value)
}

///|
fn[K : Hash + Eq, V] TimedMap::get(
  self : TimedMap[K, V],
  key : K,
  evicted~ : (K, V) -> Unit = (_, _) => (),
) -> V? {
  guard self.entries_.get(key) is Some(timed) else { return None }
  if self.is_expired(timed) {
    self.evict(key, timed, evicted)
    return None
  }
  Some(timed.value)
}

///|
/// Removes the entry, expired or not, returning its value.
fn[K : Hash + Eq, V] TimedMap::remove(self : TimedMap[K, V], key : K) -> V? {
  self.entries_.remove_and_get(key).map(timed => timed.value)
}

///|
fn[K : Hash + Eq, V] TimedMap::values(
  self : TimedMap[K, V],
  evicted~ : (K, V) -> Unit = (_, _) => (),
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
  pred : (K, V) -> Bool,
) -> Array[K] {
  let keys = []
  for key, timed in self.entries_ {
    if pred(key, timed.value) {
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
///
/// `entered_` sees every value that starts being stored and `left_` every
/// value that stops, whichever path removes it (replacement, removal, a
/// dropped bucket, the limit, or expiry), so a resource whose entries hold
/// users keeps the holder counts exact. `emptied_` sees each owner whose
/// bucket the removal of its last entry dropped.
///
/// With a TTL, `due_` indexes each bucket's earliest deadline, so `expire`
/// releases every expired entry while touching only the buckets that hold
/// one. Every non-empty bucket has an item no later than its earliest
/// deadline: one is pushed when a bucket gains its first entry and after each
/// pop, and removals only make a bucket's earliest deadline later. Items left
/// by dropped buckets are skipped when popped, and the heap is rebuilt from
/// the live buckets once such items outnumber them.
priv struct Buckets[O, K, V] {
  buckets_ : Map[O, Bucket[K, V]]
  limit_ : CacheLimit
  now_ : () -> Int64
  entered_ : (V) -> Unit
  left_ : (V) -> Unit
  emptied_ : (O) -> Unit
  due_ : DeadlineHeap[O]
}

///|
fn[O : Hash + Eq, K, V] Buckets::new(
  limit : CacheLimit,
  now : () -> Int64,
  entered~ : (V) -> Unit = _ => (),
  left~ : (V) -> Unit = _ => (),
  emptied~ : (O) -> Unit = _ => (),
) -> Buckets[O, K, V] {
  {
    buckets_: Map([]),
    limit_: limit,
    now_: now,
    entered_: entered,
    left_: left,
    emptied_: emptied,
    due_: DeadlineHeap::new(),
  }
}

///|
fn[O : Hash + Eq, K, V] Buckets::drop_if_empty(
  self : Buckets[O, K, V],
  owner : O,
  bucket : Bucket[K, V],
) -> Unit {
  if bucket.entries.entries_.is_empty() {
    self.buckets_.remove(owner)
    (self.emptied_)(owner)
    self.compact_due()
  }
}

///|
fn[K, V] Bucket::earliest_deadline(self : Bucket[K, V]) -> Int64? {
  match self.entries.entries_.iter().head() {
    Some((_, timed)) => timed.deadline
    None => None
  }
}

///|
/// Indexes the earliest deadline of `owner`'s bucket.
fn[O, K, V] Buckets::index_earliest(
  self : Buckets[O, K, V],
  owner : O,
  bucket : Bucket[K, V],
) -> Unit {
  guard bucket.earliest_deadline() is Some(deadline) else { return }
  self.due_.push(deadline, owner)
  self.compact_due()
}

///|
/// Rebuilds the deadline index from the live buckets once stale items, left
/// by refreshed or removed buckets, outnumber the bound: `2 × buckets + 16`.
/// Run wherever the index grows or a bucket goes, so an emptied cache does
/// not keep an index the size of its past peak.
fn[O, K, V] Buckets::compact_due(self : Buckets[O, K, V]) -> Unit {
  guard self.due_.length() > 2 * self.buckets_.length() + 16 else { return }
  self.due_.clear()
  for live_owner, live in self.buckets_ {
    if live.earliest_deadline() is Some(live_deadline) {
      self.due_.push(live_deadline, live_owner)
    }
  }
}

///|
/// Releases every expired entry, visiting only buckets that hold one.
fn[O : Hash + Eq, K : Hash + Eq, V] Buckets::expire(
  self : Buckets[O, K, V],
) -> Unit {
  let now = (self.now_)()
  while self.due_.pop_due(now) is Some(owner) {
    guard self.buckets_.get(owner) is Some(bucket) else { continue }
    bucket.entries.sweep(evicted=(_, old) => (self.left_)(old))
    self.drop_if_empty(owner, bucket)
    self.index_earliest(owner, bucket)
  }
}

///|
fn[O, K, V] Buckets::release(
  self : Buckets[O, K, V],
  bucket : Bucket[K, V],
) -> Unit {
  for _, timed in bucket.entries.entries_ {
    (self.left_)(timed.value)
  }
}

///|
fn[O : Hash + Eq, K : Hash + Eq, V] Buckets::get(
  self : Buckets[O, K, V],
  owner : O,
  key : K,
) -> V? {
  guard self.buckets_.get(owner) is Some(bucket) else { return None }
  let value = bucket.entries.get(key, evicted=(_, old) => (self.left_)(old))
  self.drop_if_empty(owner, bucket)
  value
}

///|
fn[O : Hash + Eq, K : Hash + Eq, V] Buckets::values(
  self : Buckets[O, K, V],
  owner : O,
) -> Array[V] {
  guard self.buckets_.get(owner) is Some(bucket) else { return [] }
  let values = bucket.entries.values(evicted=(_, old) => (self.left_)(old))
  self.drop_if_empty(owner, bucket)
  values
}

///|
/// Stores the value, reporting whether it was kept.
fn[O : Hash + Eq, K : Hash + Eq, V] Buckets::put(
  self : Buckets[O, K, V],
  owner : O,
  key : K,
  value : V,
  guild_id? : @model.GuildId,
) -> Bool {
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
  let was_empty = bucket.entries.entries_.is_empty()
  let stored = match
    bucket.entries.put(key, value, evicted=(_, old) => (self.left_)(old)) {
    Refused => false
    Inserted => {
      (self.entered_)(value)
      true
    }
    Replaced(old) => {
      (self.entered_)(value)
      (self.left_)(old)
      true
    }
  }
  if was_empty {
    self.index_earliest(owner, bucket)
  }
  self.drop_if_empty(owner, bucket)
  stored
}

///|
/// Replaces a retained value, reporting whether there was one.
fn[O : Hash + Eq, K : Hash + Eq, V] Buckets::replace_existing(
  self : Buckets[O, K, V],
  owner : O,
  key : K,
  value : V,
  guild_id? : @model.GuildId,
) -> Bool {
  guard self.buckets_.get(owner) is Some(bucket) else { return false }
  bucket.guild_id = prefer_update(guild_id, bucket.guild_id)
  let replaced = bucket.entries.replace_existing(key, value, evicted=(_, old) => {
    (self.left_)(old)
  })
  if replaced is Some(old) {
    (self.entered_)(value)
    (self.left_)(old)
  }
  self.drop_if_empty(owner, bucket)
  replaced is Some(_)
}

///|
fn[O : Hash + Eq, K : Hash + Eq, V] Buckets::remove(
  self : Buckets[O, K, V],
  owner : O,
  key : K,
) -> Unit {
  guard self.buckets_.get(owner) is Some(bucket) else { return }
  if bucket.entries.remove(key) is Some(old) {
    (self.left_)(old)
  }
  self.drop_if_empty(owner, bucket)
}

///|
fn[O : Hash + Eq, K, V] Buckets::drop(
  self : Buckets[O, K, V],
  owner : O,
) -> Unit {
  if self.buckets_.remove_and_get(owner) is Some(bucket) {
    self.release(bucket)
    self.compact_due()
  }
}

///|
/// Drops every bucket recorded as belonging to `guild_id` whose owner is not
/// kept by `keep`.
fn[O : Hash + Eq, K, V] Buckets::drop_guild(
  self : Buckets[O, K, V],
  guild_id : @model.GuildId,
  keep~ : (O) -> Bool = _ => false,
) -> Unit {
  let owners = []
  for owner, bucket in self.buckets_ {
    if bucket.guild_id == Some(guild_id) && !keep(owner) {
      owners.push(owner)
    }
  }
  for owner in owners {
    self.drop(owner)
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
/// cache's collections. Archived threads are not served: Discord stops
/// sending their events, so the cache drops them when they are archived;
/// fetch them over REST.
pub struct InMemoryCache {
  priv resources_ : CacheResources
  priv guilds_ : TimedMap[@model.GuildId, @model.Guild]
  priv unavailable_guilds_ : Map[@model.GuildId, Bool]
  priv channels_ : TimedMap[@model.ChannelId, CachedChannel]
  // Active threads, kept while channels or messages are retained.
  priv threads_ : Map[@model.ChannelId, ThreadEntry]
  // Channels without a guild holding cached state, in write order.
  priv dm_channels_ : TimedMap[@model.ChannelId, Unit]
  priv roles_ : Buckets[@model.GuildId, @model.RoleId, @model.Role]
  priv members_ : Buckets[@model.GuildId, @model.UserId, @model.GuildMember]
  priv users_ : UserStore
  priv voice_states_ : Buckets[@model.GuildId, @model.UserId, @model.VoiceState]
  priv presences_ : Buckets[
    @model.GuildId,
    @model.UserId,
    @model.PresenceUpdateEvent,
  ]
  priv messages_ : Buckets[@model.ChannelId, @model.MessageId, @model.Message]
  priv mut current_user_ : @model.UserId?
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
  let channels = TimedMap::new(limits.channels_, now)
  let dm_channels = TimedMap::new(limits.dm_channels_, now)
  let users = UserStore::new(
    enabled=resources.users_,
    held=limits.users_,
    recent=limits.recent_users_,
    now~,
  )
  {
    resources_: resources,
    guilds_: TimedMap::new(limits.guilds_, now),
    unavailable_guilds_: Map([]),
    channels_: channels,
    threads_: Map([]),
    dm_channels_: dm_channels,
    roles_: Buckets::new(limits.roles_, now),
    members_: Buckets::new(
      limits.members_,
      now,
      entered=cached_member => {
        if cached_member.user is Some(user) {
          users.hold(user)
        }
      },
      left=cached_member => {
        if cached_member.user is Some(user) {
          users.release(user.id)
        }
      },
    ),
    users_: users,
    voice_states_: Buckets::new(limits.voice_states_, now),
    presences_: Buckets::new(limits.presences_, now),
    messages_: Buckets::new(
      limits.messages_,
      now,
      entered=message => users.hold(message.author),
      left=message => users.release(message.author.id),
      // A DM whose last message went holds nothing unless its channel is
      // cached, and gives up its place in the DM limit.
      emptied=channel_id => {
        if !channels.entries_.contains(channel_id) {
          dm_channels.remove(channel_id) |> ignore
        }
      },
    ),
    current_user_: None,
  }
}

///|
/// Releases everything keyed by a guild that left the cache: its per-guild
/// buckets, its channels and threads, and the messages of its channels,
/// cached or not. The guild entry itself is the caller's: `remove_guild`
/// deletes it, and the guild map has already dropped it when it reports an
/// eviction.
fn InMemoryCache::release_guild(
  self : InMemoryCache,
  guild_id : @model.GuildId,
) -> Unit {
  self.roles_.drop(guild_id)
  self.members_.drop(guild_id)
  self.voice_states_.drop(guild_id)
  self.presences_.drop(guild_id)
  self.messages_.drop_guild(guild_id)
  self.forget_channels(guild_id, _ => false)
}

///|
/// Removes every cached channel and known thread of `guild_id` that `keep`
/// does not keep.
fn InMemoryCache::forget_channels(
  self : InMemoryCache,
  guild_id : @model.GuildId,
  keep : (@model.ChannelId) -> Bool,
) -> Unit {
  let channel_ids = self.channels_.keys_where((channel_id, cached) => {
    cached.guild_id == Some(guild_id) && !keep(channel_id)
  })
  for thread_id, entry in self.threads_ {
    if entry.guild_id == guild_id && !keep(thread_id) {
      channel_ids.push(thread_id)
    }
  }
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
  self.dm_channels_.remove(channel_id) |> ignore
}

///|
/// Releases a channel without a guild that fell out of the DM limit: its
/// channel entry and its messages.
fn InMemoryCache::release_dm(
  self : InMemoryCache,
  channel_id : @model.ChannelId,
) -> Unit {
  self.channels_.remove(channel_id) |> ignore
  self.release_channel(channel_id)
}

///|
/// Marks a channel without a guild as the most recently written, evicting
/// the least recently written beyond the DM limit. Reports whether the
/// channel's state is kept: a zero limit releases it at once.
fn InMemoryCache::touch_dm(
  self : InMemoryCache,
  channel_id : @model.ChannelId,
) -> Bool {
  let evicted = (dm_id, _) => self.release_dm(dm_id)
  match self.dm_channels_.put(channel_id, (), evicted~) {
    Refused => {
      self.release_dm(channel_id)
      false
    }
    Inserted | Replaced(_) => true
  }
}

///|
fn InMemoryCache::cached_channel(
  self : InMemoryCache,
  channel_id : @model.ChannelId,
) -> CachedChannel? {
  self.channels_.get(channel_id, evicted=(evicted_id, _) => {
    self.release_channel(evicted_id)
  })
}

///|
/// Releases every entry whose TTL has passed, with what it owns or holds:
/// expired guilds, channels, and DM channels take their state with them, and
/// expired members and messages release their users. Every public read and
/// `update` calls it first, so nothing expired is served or keeps anything
/// else cached, whichever structure the read looks at. It costs only the
/// expired entries: owner maps expire in insertion order, and buckets through
/// their deadline index.
fn InMemoryCache::expire(self : InMemoryCache) -> Unit {
  self.guilds_.sweep(evicted=(guild_id, _) => self.release_guild(guild_id))
  self.channels_.sweep(evicted=(channel_id, _) => {
    self.release_channel(channel_id)
  })
  self.dm_channels_.sweep(evicted=(channel_id, _) => self.release_dm(channel_id))
  self.roles_.expire()
  self.members_.expire()
  self.voice_states_.expire()
  self.presences_.expire()
  self.messages_.expire()
  self.users_.expire()
}

///|
/// Records the current user, which the cache holds while it is current.
fn InMemoryCache::set_current_user(
  self : InMemoryCache,
  user : @model.User,
) -> Unit {
  let previous = self.current_user_
  self.current_user_ = Some(user.id)
  self.users_.hold(user)
  if previous is Some(previous_id) {
    self.users_.release(previous_id)
  }
}

///|
fn InMemoryCache::store_guild(
  self : InMemoryCache,
  guild : @model.Guild,
) -> Unit {
  self.unavailable_guilds_.remove(guild.id)
  if self.resources_.guilds_ {
    self.guilds_.put(guild.id, guild, evicted=(guild_id, _) => {
      self.release_guild(guild_id)
    })
    |> ignore
  }
  self.store_roles(guild.id, guild.roles)
}

///|
/// Stores a member; a member the cache does not keep is a passing sighting
/// of its user.
fn InMemoryCache::store_member(
  self : InMemoryCache,
  guild_id : @model.GuildId,
  cached_member : @model.GuildMember,
) -> Unit {
  guard cached_member.user is Some(user) else { return }
  let stored = self.resources_.members_ &&
    self.members_.put(guild_id, user.id, cached_member)
  if !stored {
    self.users_.see(user)
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
      self.roles_.put(guild_id, role.id, role) |> ignore
    }
  }
}

///|
fn InMemoryCache::tracks_threads(self : InMemoryCache) -> Bool {
  self.resources_.channels_ || self.resources_.messages_
}

///|
fn InMemoryCache::store_channel(
  self : InMemoryCache,
  channel : @model.Channel,
  guild_id? : @model.GuildId,
) -> Unit {
  guard keeps_channel(channel) else {
    self.remove_channel(channel.id)
    return
  }
  let previous = self.cached_channel(channel.id)
  let resolved_guild_id = prefer_update(
    channel.guild_id,
    prefer_update(guild_id, previous.bind(cached => cached.guild_id)),
  )
  if is_thread(channel) &&
    resolved_guild_id is Some(thread_guild_id) &&
    self.tracks_threads() {
    self.threads_[channel.id] = ThreadEntry::of(channel, thread_guild_id)
  }
  guard self.resources_.channels_ else { return }
  self.channels_.put(channel.id, { channel, guild_id: resolved_guild_id, }, evicted=(
    channel_id,
    _,
  ) => self.release_channel(channel_id))
  |> ignore
  if resolved_guild_id is None {
    self.touch_dm(channel.id) |> ignore
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
  |> ignore
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
      |> ignore
  }
}

///|
/// Stores a message. One the cache does not keep is a passing sighting of
/// its author; one in a channel without a guild counts against the DM limit.
fn InMemoryCache::store_message(
  self : InMemoryCache,
  message : @model.Message,
  guild_id : @model.GuildId?,
) -> Unit {
  let guild_id = prefer_update(
    guild_id,
    self.cached_channel(message.channel_id).bind(cached => cached.guild_id),
  )
  let stored = self.resources_.messages_ &&
    self.messages_.put(message.channel_id, message.id, message, guild_id?)
  let guildless = self.messages_.buckets_.get(message.channel_id)
    is Some({ guild_id: None, .. })
  let kept = stored && (!guildless || self.touch_dm(message.channel_id))
  if !kept {
    self.users_.see(message.author)
  }
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
  let replaced = self.resources_.messages_ &&
    self.messages_.replace_existing(
      message.channel_id,
      message.id,
      message,
      guild_id?,
    )
  if !replaced {
    self.users_.see(message.author)
  }
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
/// Removes a channel or thread with everything keyed by it.
fn InMemoryCache::remove_channel(
  self : InMemoryCache,
  channel_id : @model.ChannelId,
) -> Unit {
  self.channels_.remove(channel_id) |> ignore
  self.threads_.remove(channel_id)
  self.release_channel(channel_id)
}

///|
fn InMemoryCache::remove_guild(
  self : InMemoryCache,
  guild_id : @model.GuildId,
) -> Unit {
  self.guilds_.remove(guild_id) |> ignore
  self.unavailable_guilds_.remove(guild_id)
  self.release_guild(guild_id)
}

///|
/// Replaces everything the cache holds for a guild with a fresh
/// `GUILD_CREATE`, which lists all its channels, active threads, and members
/// the bot can see: channels and threads it no longer lists (deleted or
/// archived while the guild was unavailable) go with their messages.
fn InMemoryCache::seed_available_guild(
  self : InMemoryCache,
  available : @model.AvailableGuildCreateEvent,
) -> Unit {
  let guild_id = available.guild.id
  self.store_guild(available.guild)
  let listed : Map[@model.ChannelId, Unit] = Map([])
  for channel in available.channels {
    listed[channel.id] = ()
  }
  for thread in available.threads {
    listed[thread.id] = ()
  }
  self.forget_channels(guild_id, channel_id => listed.contains(channel_id))
  self.messages_.drop_guild(guild_id, keep=channel_id => {
    listed.contains(channel_id)
  })
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
  guard self.resources_.members_ else {
    self.users_.see(update.user)
    return
  }
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
/// A sync lists every active thread under the parents it covers, so the
/// known threads it does not list are gone, with their messages, whether or
/// not channels are retained; the ones it lists keep theirs.
fn InMemoryCache::sync_threads(
  self : InMemoryCache,
  sync : @model.ThreadListSyncEvent,
) -> Unit {
  let listed : Set[@model.ChannelId] = Set::from_array(
    sync.threads.map(thread => thread.id),
  )
  let removed = []
  for thread_id, entry in self.threads_ {
    if synced_away(
        entry,
        listed.contains(thread_id),
        sync.guild_id,
        sync.channel_ids,
      ) {
      removed.push(thread_id)
    }
  }
  for thread_id in removed {
    self.remove_channel(thread_id)
  }
  for thread in sync.threads {
    self.store_channel(thread, guild_id=sync.guild_id)
  }
}

///|
fn InMemoryCache::update_thread_members(
  self : InMemoryCache,
  update : @model.ThreadMembersUpdateEvent,
) -> Unit {
  let private_ = self.threads_.get(update.id) is Some(entry) && entry.private_
  if loses_thread(update.removed_member_ids, self.current_user_, private_) {
    self.remove_channel(update.id)
  }
}

///|
/// Every guild the cache holds anything for.
fn InMemoryCache::known_guilds(
  self : InMemoryCache,
) -> Map[@model.GuildId, Unit] {
  let known : Map[@model.GuildId, Unit] = Map([])
  for guild_id, _ in self.guilds_.entries_ {
    known[guild_id] = ()
  }
  for guild_id, _ in self.unavailable_guilds_ {
    known[guild_id] = ()
  }
  for
    owners in [
      self.roles_.buckets_.keys(),
      self.members_.buckets_.keys(),
      self.voice_states_.buckets_.keys(),
      self.presences_.buckets_.keys(),
    ] {
    for guild_id in owners {
      known[guild_id] = ()
    }
  }
  for _, timed in self.channels_.entries_ {
    if timed.value.guild_id is Some(guild_id) {
      known[guild_id] = ()
    }
  }
  for _, entry in self.threads_ {
    known[entry.guild_id] = ()
  }
  for _, bucket in self.messages_.buckets_ {
    if bucket.guild_id is Some(guild_id) {
      known[guild_id] = ()
    }
  }
  known
}

///|
/// A new session's `READY` lists every guild of its shard: the guilds of
/// that shard it does not list were left while the bot was disconnected.
fn InMemoryCache::forget_unlisted_guilds(
  self : InMemoryCache,
  ready : @model.Ready,
) -> Unit {
  let listed : Map[@model.GuildId, Unit] = Map([])
  for guild in ready.guilds {
    listed[guild.id] = ()
  }
  for guild_id, _ in self.known_guilds() {
    if ready_covers(guild_id, ready.shard) && !listed.contains(guild_id) {
      self.remove_guild(guild_id)
    }
  }
}

///|
/// Applies one decoded gateway event. Unsupported events are intentionally
/// ignored for forward compatibility.
pub fn InMemoryCache::update(
  self : InMemoryCache,
  event : @model.Event,
) -> Unit {
  self.expire()
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
    ThreadMembersUpdate(update) => self.update_thread_members(update)
    GuildRoleCreate(event) | GuildRoleUpdate(event) => {
      guard self.resources_.roles_ else { return }
      self.roles_.put(event.guild_id, event.role.id, event.role) |> ignore
    }
    GuildRoleDelete(event) => self.roles_.remove(event.guild_id, event.role_id)
    GuildMemberAdd(event) =>
      self.store_member(event.guild_id, event.guild_member)
    GuildMemberRemove(event) => {
      self.members_.remove(event.guild_id, event.user.id)
      self.voice_states_.remove(event.guild_id, event.user.id)
      self.presences_.remove(event.guild_id, event.user.id)
      self.users_.see(event.user)
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
    GuildBanAdd(event) | GuildBanRemove(event) => self.users_.see(event.user)
    Ready(ready) => {
      self.set_current_user(ready.user)
      self.forget_unlisted_guilds(ready)
      if self.resources_.guilds_ {
        for guild in ready.guilds {
          if guild.unavailable {
            self.unavailable_guilds_[guild.id] = true
          } else {
            self.unavailable_guilds_.remove(guild.id)
          }
        }
      }
    }
    UserUpdate(user) => self.set_current_user(user)
    InteractionCreate(interaction) =>
      if prefer_update(
          interaction.user,
          interaction.guild_member.bind(cached_member => cached_member.user),
        )
        is Some(user) {
        self.users_.see(user)
      }
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
  self.expire()
  self.guilds_.get(id, evicted=(guild_id, _) => self.release_guild(guild_id))
}

///|
/// All cached guilds.
pub fn InMemoryCache::guilds(self : InMemoryCache) -> Array[@model.Guild] {
  self.expire()
  self.guilds_.values(evicted=(guild_id, _) => self.release_guild(guild_id))
}

///|
/// Whether the guild is currently marked unavailable by a `GUILD_DELETE`
/// outage notice.
pub fn InMemoryCache::is_guild_unavailable(
  self : InMemoryCache,
  id : @model.GuildId,
) -> Bool {
  self.expire()
  self.unavailable_guilds_.get(id) == Some(true)
}

///|
/// Ids of guilds currently marked unavailable.
pub fn InMemoryCache::unavailable_guilds(
  self : InMemoryCache,
) -> Array[@model.GuildId] {
  self.expire()
  self.unavailable_guilds_.keys().to_array()
}

///|
/// The cached channel or thread, if retained.
pub fn InMemoryCache::channel(
  self : InMemoryCache,
  id : @model.ChannelId,
) -> @model.Channel? {
  self.expire()
  self.cached_channel(id).map(cached => cached.channel)
}

///|
/// All cached channels and threads.
pub fn InMemoryCache::channels(self : InMemoryCache) -> Array[@model.Channel] {
  self.expire()
  self.channels_
  .values(evicted=(channel_id, _) => self.release_channel(channel_id))
  .map(cached => cached.channel)
}

///|
/// The cached role, if retained.
pub fn InMemoryCache::role(
  self : InMemoryCache,
  guild_id : @model.GuildId,
  role_id : @model.RoleId,
) -> @model.Role? {
  self.expire()
  self.roles_.get(guild_id, role_id)
}

///|
/// All cached roles of a guild.
pub fn InMemoryCache::roles(
  self : InMemoryCache,
  guild_id : @model.GuildId,
) -> Array[@model.Role] {
  self.expire()
  self.roles_.values(guild_id)
}

///|
/// The cached guild member, if retained.
pub fn InMemoryCache::member(
  self : InMemoryCache,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
) -> @model.GuildMember? {
  self.expire()
  self.members_.get(guild_id, user_id)
}

///|
/// All cached members of a guild (only members seen in events unless
/// the privileged `GUILD_MEMBERS` intent fills the cache).
pub fn InMemoryCache::members(
  self : InMemoryCache,
  guild_id : @model.GuildId,
) -> Array[@model.GuildMember] {
  self.expire()
  self.members_.values(guild_id)
}

///|
/// The cached user, if held by a cached entry or recently seen.
pub fn InMemoryCache::user(
  self : InMemoryCache,
  id : @model.UserId,
) -> @model.User? {
  self.expire()
  self.users_.get(id)
}

///|
/// All cached users: those held by cached entries, then the recently seen.
pub fn InMemoryCache::users(self : InMemoryCache) -> Array[@model.User] {
  self.expire()
  self.users_.values()
}

///|
/// The cached voice state of a user in a guild, if any.
pub fn InMemoryCache::voice_state(
  self : InMemoryCache,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
) -> @model.VoiceState? {
  self.expire()
  self.voice_states_.get(guild_id, user_id)
}

///|
/// All cached voice states of a guild.
pub fn InMemoryCache::voice_states(
  self : InMemoryCache,
  guild_id : @model.GuildId,
) -> Array[@model.VoiceState] {
  self.expire()
  self.voice_states_.values(guild_id)
}

///|
/// The cached presence of a user in a guild, if presences are retained.
pub fn InMemoryCache::presence(
  self : InMemoryCache,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
) -> @model.PresenceUpdateEvent? {
  self.expire()
  self.presences_.get(guild_id, user_id)
}

///|
/// All cached presences of a guild.
pub fn InMemoryCache::presences(
  self : InMemoryCache,
  guild_id : @model.GuildId,
) -> Array[@model.PresenceUpdateEvent] {
  self.expire()
  self.presences_.values(guild_id)
}

///|
/// The cached message, if still retained.
pub fn InMemoryCache::message(
  self : InMemoryCache,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
) -> @model.Message? {
  self.expire()
  self.messages_.get(channel_id, message_id)
}

///|
/// Cached messages of a channel, oldest first, capped by the messages limit.
pub fn InMemoryCache::messages(
  self : InMemoryCache,
  channel_id : @model.ChannelId,
) -> Array[@model.Message] {
  self.expire()
  self.messages_.values(channel_id)
}

///|
/// Computes guild-level permissions from the cached guild, member, and roles.
pub fn InMemoryCache::permissions(
  self : InMemoryCache,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
) -> @model.Permissions? {
  self.expire()
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
  self.expire()
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
