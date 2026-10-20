///|
fn limit_cached_event(name : String, fixture : String) -> @model.Event raise {
  @model.dispatch_event(name, @json.parse(fixture))
}

///|
fn limit_user_fixture(id : String, username : String) -> String {
  (
    #|{"id":"USER_ID","username":"USERNAME","discriminator":"0","avatar":null}
  )
  .replace(old="USER_ID", new=id)
  .replace(old="USERNAME", new=username)
}

///|
fn limit_member_fixture(guild_id : String, user_id : String) -> String {
  (
    #|{"guild_id":"GUILD_ID","user":{"id":"USER_ID","username":"member-USER_ID","discriminator":"0","avatar":null},"roles":[],"joined_at":"2025-06-01T10:00:00Z"}
  )
  .replace(old="GUILD_ID", new=guild_id)
  .replace(old="USER_ID", new=user_id)
}

///|
fn limit_message_fixture(
  id : String,
  content : String,
  channel_id~ : String = "400",
  guild_id~ : String = "100",
) -> String {
  (
    #|{"id":"MESSAGE_ID","channel_id":"CHANNEL_ID","guild_id":"GUILD_ID","author":{"id":"202","username":"writer","discriminator":"0","avatar":null},"content":"CONTENT","timestamp":"2025-06-01T10:00:00Z","edited_timestamp":null,"tts":false,"mention_everyone":false,"mentions":[],"mention_roles":[],"attachments":[],"embeds":[],"pinned":false,"type":0}
  )
  .replace(old="MESSAGE_ID", new=id)
  .replace(old="CONTENT", new=content)
  .replace(old="CHANNEL_ID", new=channel_id)
  .replace(old="GUILD_ID", new=guild_id)
}

///|
fn limit_guild_fixture(
  guild_id~ : String = "100",
  channel_id~ : String = "400",
) -> String {
  (
    #|{
    #|  "id": "GUILD_ID",
    #|  "name": "Limited Guild",
    #|  "icon": null,
    #|  "splash": null,
    #|  "discovery_splash": null,
    #|  "owner_id": "200",
    #|  "afk_channel_id": null,
    #|  "afk_timeout": 300,
    #|  "verification_level": 1,
    #|  "default_message_notifications": 1,
    #|  "explicit_content_filter": 2,
    #|  "roles": [
    #|    {"id":"GUILD_ID","name":"@everyone","color":0,"hoist":false,"position":0,"permissions":"1024","managed":false,"mentionable":false},
    #|    {"id":"301","name":"reader","color":0,"hoist":false,"position":1,"permissions":"1024","managed":false,"mentionable":false}
    #|  ],
    #|  "emojis": [],
    #|  "features": [],
    #|  "mfa_level": 0,
    #|  "application_id": null,
    #|  "system_channel_id": null,
    #|  "system_channel_flags": 0,
    #|  "rules_channel_id": null,
    #|  "vanity_url_code": null,
    #|  "description": null,
    #|  "banner": null,
    #|  "premium_tier": 0,
    #|  "preferred_locale": "en-US",
    #|  "public_updates_channel_id": null,
    #|  "safety_alerts_channel_id": null,
    #|  "joined_at": "2025-06-01T10:00:00Z",
    #|  "large": false,
    #|  "unavailable": false,
    #|  "member_count": 1,
    #|  "voice_states": [
    #|    {"channel_id":"CHANNEL_ID","user_id":"201","session_id":"s","deaf":false,"mute":false,"self_deaf":false,"self_mute":false,"suppress":false,"request_to_speak_timestamp":null}
    #|  ],
    #|  "members": [
    #|    {"user":{"id":"201","username":"reader","discriminator":"0","avatar":null},"nick":null,"roles":["301"],"joined_at":"2025-06-01T10:00:00Z","deaf":false,"mute":false}
    #|  ],
    #|  "channels": [
    #|    {"id":"CHANNEL_ID","type":0,"name":"general","permission_overwrites":[]}
    #|  ],
    #|  "threads": [],
    #|  "presences": [{"user":{"id":"201"},"status":"online"}],
    #|  "stage_instances": [],
    #|  "guild_scheduled_events": [],
    #|  "soundboard_sounds": []
    #|}
  )
  .replace_all(old="GUILD_ID", new=guild_id)
  .replace_all(old="CHANNEL_ID", new=channel_id)
}

///|
test "default message limit retains the newest 100 entries" {
  let cache = @cache.InMemoryCache(
    resources=CacheResources(messages=true),
    limits=@cache.CacheLimits::default(),
  )
  let channel_id : @model.ChannelId = @model.Id::parse("400")
  for i in 0..<101 {
    let id = (500 + i).to_string()
    cache.update(
      limit_cached_event("MESSAGE_CREATE", limit_message_fixture(id, id)),
    )
  }
  assert_eq(cache.messages(channel_id).length(), 100)
  assert_true(cache.message(channel_id, @model.Id::parse("500")) is None)
  assert_true(cache.message(channel_id, @model.Id::parse("501")) is Some(_))
  assert_true(cache.message(channel_id, @model.Id::parse("600")) is Some(_))
}

///|
test "FIFO limits refresh position when an entity is re-stored" {
  let cache = @cache.InMemoryCache(
    resources=@cache.CacheResources::default(),
    limits=CacheLimits(users=CacheLimit(max_entries=2)),
  )
  // Members hold their users; `USER_UPDATE` concerns only the current user.
  for user_id in ["1", "2", "1", "3"] {
    cache.update(
      limit_cached_event(
        "GUILD_MEMBER_ADD",
        limit_member_fixture("100", user_id),
      ),
    )
  }
  assert_true(cache.user(@model.Id::parse("1")) is Some(_))
  assert_true(cache.user(@model.Id::parse("2")) is None)
  assert_true(cache.user(@model.Id::parse("3")) is Some(_))
  debug_inspect(
    cache.users().map(user => user.id.to_string()),
    content="[\"1\", \"3\"]",
  )
}

///|
test "single getters expire entries at the TTL boundary" {
  let now = Ref(0L)
  let cache = @cache.InMemoryCache(
    resources=@cache.CacheResources::default(),
    limits=CacheLimits(users=CacheLimit(ttl_ms=1000L)),
    now=() => now.val,
  )
  let user_id : @model.UserId = @model.Id::parse("1")
  cache.update(limit_cached_event("USER_UPDATE", limit_user_fixture("1", "a")))
  now.val = 999L
  assert_true(cache.user(user_id) is Some(_))
  now.val = 1000L
  assert_true(cache.user(user_id) is None)
  assert_eq(cache.users().length(), 0)
}

///|
test "list getters sweep only the expired insertion-order prefix" {
  let now = Ref(0L)
  let cache = @cache.InMemoryCache(
    resources=@cache.CacheResources::default(),
    limits=CacheLimits(members=CacheLimit(ttl_ms=1000L)),
    now=() => now.val,
  )
  let guild_id : @model.GuildId = @model.Id::parse("100")
  cache.update(
    limit_cached_event("GUILD_MEMBER_ADD", limit_member_fixture("100", "1")),
  )
  now.val = 600L
  cache.update(
    limit_cached_event("GUILD_MEMBER_ADD", limit_member_fixture("100", "2")),
  )
  now.val = 1100L
  debug_inspect(
    cache.members(guild_id).map(cached => cached.user.unwrap().id.to_string()),
    content="[\"2\"]",
  )
}

///|
test "writes sweep expired messages before inserting" {
  let now = Ref(0L)
  let cache = @cache.InMemoryCache(
    resources=CacheResources(messages=true),
    limits=CacheLimits(messages=CacheLimit(ttl_ms=1000L)),
    now=() => now.val,
  )
  let channel_id : @model.ChannelId = @model.Id::parse("400")
  cache.update(
    limit_cached_event("MESSAGE_CREATE", limit_message_fixture("500", "one")),
  )
  now.val = 1000L
  cache.update(
    limit_cached_event("MESSAGE_CREATE", limit_message_fixture("501", "two")),
  )
  debug_inspect(
    cache.messages(channel_id).map(message => message.id.to_string()),
    content="[\"501\"]",
  )
}

///|
test "entry limits apply after expired messages are swept" {
  let now = Ref(0L)
  let cache = @cache.InMemoryCache(
    resources=CacheResources(messages=true),
    limits=CacheLimits(messages=CacheLimit(max_entries=2, ttl_ms=1000L)),
    now=() => now.val,
  )
  let channel_id : @model.ChannelId = @model.Id::parse("400")
  cache.update(
    limit_cached_event("MESSAGE_CREATE", limit_message_fixture("500", "one")),
  )
  now.val = 500L
  cache.update(
    limit_cached_event("MESSAGE_CREATE", limit_message_fixture("501", "two")),
  )
  now.val = 1100L
  cache.update(
    limit_cached_event("MESSAGE_CREATE", limit_message_fixture("502", "three")),
  )
  debug_inspect(
    cache.messages(channel_id).map(message => message.id.to_string()),
    content="[\"501\", \"502\"]",
  )
}

///|
test "per-guild member limits are independent" {
  let cache = @cache.InMemoryCache(
    resources=@cache.CacheResources::default(),
    limits=CacheLimits(members=CacheLimit(max_entries=1)),
  )
  let first_guild : @model.GuildId = @model.Id::parse("100")
  let second_guild : @model.GuildId = @model.Id::parse("101")
  cache.update(
    limit_cached_event("GUILD_MEMBER_ADD", limit_member_fixture("100", "1")),
  )
  cache.update(
    limit_cached_event("GUILD_MEMBER_ADD", limit_member_fixture("101", "2")),
  )
  assert_eq(cache.members(first_guild).length(), 1)
  assert_eq(cache.members(second_guild).length(), 1)
}

///|
test "expired entries are not resurrected by partial updates" {
  let now = Ref(0L)
  let cache = @cache.InMemoryCache(
    resources=CacheResources(presences=true, messages=true),
    limits=CacheLimits(
      presences=CacheLimit(ttl_ms=1000L),
      messages=CacheLimit(ttl_ms=1000L),
    ),
    now=() => now.val,
  )
  let guild_id : @model.GuildId = @model.Id::parse("100")
  let user_id : @model.UserId = @model.Id::parse("202")
  let channel_id : @model.ChannelId = @model.Id::parse("400")
  let message_id : @model.MessageId = @model.Id::parse("500")
  cache.update(
    limit_cached_event("MESSAGE_CREATE", limit_message_fixture("500", "one")),
  )
  now.val = 1000L
  cache.update(
    limit_cached_event("MESSAGE_UPDATE", limit_message_fixture("500", "edited")),
  )
  assert_true(cache.message(channel_id, message_id) is None)
  cache.update(
    limit_cached_event(
      "PRESENCE_UPDATE",
      (
        #|{"guild_id":"100","user":{"id":"202"},"status":"online","activities":[],"client_status":{"web":"online"}}
      ),
    ),
  )
  now.val = 2000L
  cache.update(
    limit_cached_event(
      "PRESENCE_UPDATE",
      (
        #|{"guild_id":"100","user":{"id":"202"}}
      ),
    ),
  )
  guard cache.presence(guild_id, user_id) is Some(presence) else {
    fail("expected the partial presence")
  }
  assert_true(presence.status is None)
  assert_true(presence.activities is None)
  assert_true(presence.client_status is None)
}

///|
test "expired roles make permissions unavailable" {
  let now = Ref(0L)
  let cache = @cache.InMemoryCache(
    resources=@cache.CacheResources::all(),
    limits=CacheLimits(
      channels=CacheLimit(ttl_ms=1000L),
      roles=CacheLimit(ttl_ms=1000L),
    ),
    now=() => now.val,
  )
  let guild_id : @model.GuildId = @model.Id::parse("100")
  let user_id : @model.UserId = @model.Id::parse("201")
  cache.update(limit_cached_event("GUILD_CREATE", limit_guild_fixture()))
  assert_true(cache.permissions(guild_id, user_id) is Some(_))
  now.val = 1000L
  assert_true(cache.permissions(guild_id, user_id) is None)
  cache.update(
    limit_cached_event(
      "THREAD_LIST_SYNC",
      (
        #|{"guild_id":"100","threads":[],"members":[]}
      ),
    ),
  )
  assert_eq(cache.channels().length(), 0)
}

///|
test "negative cache limits clamp to zero" {
  let no_entries = @cache.InMemoryCache(
    resources=@cache.CacheResources::default(),
    limits=CacheLimits(users=CacheLimit(max_entries=-5)),
  )
  no_entries.update(
    limit_cached_event("USER_UPDATE", limit_user_fixture("1", "a")),
  )
  assert_eq(no_entries.users().length(), 0)
  let now = Ref(0L)
  let immediate_expiry = @cache.InMemoryCache(
    resources=@cache.CacheResources::default(),
    limits=CacheLimits(users=CacheLimit(ttl_ms=-1L)),
    now=() => now.val,
  )
  let user_id : @model.UserId = @model.Id::parse("2")
  immediate_expiry.update(
    limit_cached_event("USER_UPDATE", limit_user_fixture("2", "b")),
  )
  assert_true(immediate_expiry.user(user_id) is None)
}

///|
fn limit_channel_fixture(id : String) -> String {
  (
    #|{"id":"CHANNEL_ID","type":0,"guild_id":"100","name":"general","permission_overwrites":[]}
  ).replace(old="CHANNEL_ID", new=id)
}

///|
/// Counts what the cache still serves for a guild and one of its channels.
/// The guild and channel are read last so the counts see dependent state as
/// it was before any read of the owner itself.
fn limit_footprint(
  cache : @cache.InMemoryCache,
  guild_id : String,
  channel_id : String,
) -> String raise {
  let guild_id : @model.GuildId = @model.Id::parse(guild_id)
  let channel_id : @model.ChannelId = @model.Id::parse(channel_id)
  let roles = cache.roles(guild_id).length()
  let members = cache.members(guild_id).length()
  let voice_states = cache.voice_states(guild_id).length()
  let presences = cache.presences(guild_id).length()
  let messages = cache.messages(channel_id).length()
  let channel = if cache.channel(channel_id) is Some(_) { 1 } else { 0 }
  let guild = if cache.guild(guild_id) is Some(_) { 1 } else { 0 }
  "guild=\{guild} roles=\{roles} members=\{members} voice_states=\{voice_states} presences=\{presences} channel=\{channel} messages=\{messages}"
}

///|
test "a guild evicted by its entry limit releases its dependent state" {
  let released = "guild=0 roles=0 members=0 voice_states=0 presences=0 channel=0 messages=0"
  for
    case in [
      (
        @cache.CacheResources::all(),
        "guild=1 roles=2 members=1 voice_states=1 presences=1 channel=1 messages=1",
      ),
      (
        // Messages of uncached channels still belong to their guild.
        CacheResources(channels=false, presences=true, messages=true),
        "guild=1 roles=2 members=1 voice_states=1 presences=1 channel=0 messages=1",
      ),
    ] {
    let (resources, retained) = case
    let cache = @cache.InMemoryCache(
      resources~,
      limits=CacheLimits(guilds=CacheLimit(max_entries=1)),
    )
    cache.update(limit_cached_event("GUILD_CREATE", limit_guild_fixture()))
    cache.update(
      limit_cached_event("MESSAGE_CREATE", limit_message_fixture("500", "one")),
    )
    assert_eq(limit_footprint(cache, "100", "400"), retained)
    cache.update(
      limit_cached_event(
        "GUILD_CREATE",
        limit_guild_fixture(guild_id="101", channel_id="401"),
      ),
    )
    cache.update(
      limit_cached_event(
        "MESSAGE_CREATE",
        limit_message_fixture("501", "two", channel_id="401", guild_id="101"),
      ),
    )
    assert_eq(limit_footprint(cache, "100", "400"), released)
    assert_eq(limit_footprint(cache, "101", "401"), retained)
  }
}

///|
test "a channel evicted by its entry limit releases its messages" {
  let cache = @cache.InMemoryCache(
    resources=CacheResources(messages=true),
    limits=CacheLimits(channels=CacheLimit(max_entries=1)),
  )
  let first : @model.ChannelId = @model.Id::parse("400")
  let second : @model.ChannelId = @model.Id::parse("401")
  cache.update(
    limit_cached_event("CHANNEL_CREATE", limit_channel_fixture("400")),
  )
  cache.update(
    limit_cached_event("MESSAGE_CREATE", limit_message_fixture("500", "one")),
  )
  cache.update(
    limit_cached_event("CHANNEL_CREATE", limit_channel_fixture("401")),
  )
  cache.update(
    limit_cached_event(
      "MESSAGE_CREATE",
      limit_message_fixture("501", "two", channel_id="401"),
    ),
  )
  assert_true(cache.channel(first) is None)
  assert_eq(cache.messages(first).length(), 0)
  assert_true(cache.channel(second) is Some(_))
  assert_eq(cache.messages(second).length(), 1)
}

///|
/// The ways an expired owner is noticed: a read of the owner itself, a list
/// read of its kind, or any gateway event, which sweeps expired guilds and
/// channels first.
fn limit_expiry_triggers() -> Array[
  (String, (@cache.InMemoryCache) -> Unit raise),
] {
  [
    (
      "owner read",
      cache => {
        assert_true(cache.guild(@model.Id::parse("100")) is None)
        assert_true(cache.channel(@model.Id::parse("400")) is None)
      },
    ),
    (
      "list read",
      cache => {
        assert_eq(cache.guilds().length(), 0)
        assert_eq(cache.channels().length(), 0)
      },
    ),
    (
      "unrelated event",
      cache => {
        cache.update(
          limit_cached_event("USER_UPDATE", limit_user_fixture("9", "other")),
        )
      },
    ),
  ]
}

///|
test "an expired guild releases its dependent state" {
  for trigger in limit_expiry_triggers() {
    let (name, notice) = trigger
    let now = Ref(0L)
    let cache = @cache.InMemoryCache(
      resources=@cache.CacheResources::all(),
      limits=CacheLimits(guilds=CacheLimit(ttl_ms=1000L)),
      now=() => now.val,
    )
    cache.update(limit_cached_event("GUILD_CREATE", limit_guild_fixture()))
    cache.update(
      limit_cached_event("MESSAGE_CREATE", limit_message_fixture("500", "one")),
    )
    now.val = 1000L
    notice(cache)
    assert_eq(
      "\{name}: \{limit_footprint(cache, "100", "400")}",
      "\{name}: guild=0 roles=0 members=0 voice_states=0 presences=0 channel=0 messages=0",
    )
  }
}

///|
test "an expired channel releases its messages" {
  for trigger in limit_expiry_triggers() {
    let (name, notice) = trigger
    let now = Ref(0L)
    let cache = @cache.InMemoryCache(
      resources=CacheResources(messages=true),
      limits=CacheLimits(channels=CacheLimit(ttl_ms=1000L)),
      now=() => now.val,
    )
    let channel_id : @model.ChannelId = @model.Id::parse("400")
    cache.update(
      limit_cached_event("CHANNEL_CREATE", limit_channel_fixture("400")),
    )
    cache.update(
      limit_cached_event("MESSAGE_CREATE", limit_message_fixture("500", "one")),
    )
    now.val = 1000L
    notice(cache)
    assert_eq("\{name}: \{cache.messages(channel_id).length()}", "\{name}: 0")
  }
}

///|
test "reads of owned state honour an expired owner without any other event" {
  let now = Ref(0L)
  let cache = @cache.InMemoryCache(
    resources=@cache.CacheResources::all(),
    limits=CacheLimits(
      guilds=CacheLimit(ttl_ms=1000L),
      channels=CacheLimit(ttl_ms=1000L),
    ),
    now=() => now.val,
  )
  cache.update(limit_cached_event("GUILD_CREATE", limit_guild_fixture()))
  cache.update(
    limit_cached_event("MESSAGE_CREATE", limit_message_fixture("500", "one")),
  )
  let guild_id : @model.GuildId = @model.Id::parse("100")
  let channel_id : @model.ChannelId = @model.Id::parse("400")
  assert_true(cache.roles(guild_id).length() > 0)
  assert_true(cache.messages(channel_id).length() > 0)
  now.val = 1000L
  // Read the owned state first, before anything touches the guild or channel.
  assert_eq(cache.messages(channel_id).length(), 0)
  assert_true(cache.channel(channel_id) is None)
  assert_eq(cache.roles(guild_id).length(), 0)
  assert_eq(cache.members(guild_id).length(), 0)
}

///|
test "a channel outlives no expired guild on a channel read" {
  let now = Ref(0L)
  let cache = @cache.InMemoryCache(
    resources=@cache.CacheResources::all(),
    limits=CacheLimits(guilds=CacheLimit(ttl_ms=1000L)),
    now=() => now.val,
  )
  cache.update(limit_cached_event("GUILD_CREATE", limit_guild_fixture()))
  let channel_id : @model.ChannelId = @model.Id::parse("400")
  assert_true(cache.channel(channel_id) is Some(_))
  now.val = 1000L
  assert_true(cache.channel(channel_id) is None)
  assert_true(cache.channels().is_empty())
}
