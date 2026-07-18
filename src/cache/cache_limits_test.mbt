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
fn limit_message_fixture(id : String, content : String) -> String {
  (
    #|{"id":"MESSAGE_ID","channel_id":"400","guild_id":"100","author":{"id":"202","username":"writer","discriminator":"0","avatar":null},"content":"CONTENT","timestamp":"2025-06-01T10:00:00Z","edited_timestamp":null,"tts":false,"mention_everyone":false,"mentions":[],"mention_roles":[],"attachments":[],"embeds":[],"pinned":false,"type":0}
  )
  .replace(old="MESSAGE_ID", new=id)
  .replace(old="CONTENT", new=content)
}

///|
fn limit_guild_fixture() -> String {
  (
    #|{
    #|  "id": "100",
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
    #|    {"id":"100","name":"@everyone","color":0,"hoist":false,"position":0,"permissions":"1024","managed":false,"mentionable":false},
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
    #|  "voice_states": [],
    #|  "members": [
    #|    {"user":{"id":"201","username":"reader","discriminator":"0","avatar":null},"nick":null,"roles":["301"],"joined_at":"2025-06-01T10:00:00Z","deaf":false,"mute":false}
    #|  ],
    #|  "channels": [
    #|    {"id":"400","type":0,"name":"general","permission_overwrites":[]}
    #|  ],
    #|  "threads": [],
    #|  "presences": [],
    #|  "stage_instances": [],
    #|  "guild_scheduled_events": [],
    #|  "soundboard_sounds": []
    #|}
  )
}

///|
test "default message limit retains the newest 100 entries" {
  let cache = @cache.InMemoryCache(
    resources=@cache.CacheResources(messages=true),
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
    limits=@cache.CacheLimits(users=@cache.CacheLimit(max_entries=2)),
  )
  cache.update(limit_cached_event("USER_UPDATE", limit_user_fixture("1", "a")))
  cache.update(limit_cached_event("USER_UPDATE", limit_user_fixture("2", "b")))
  cache.update(limit_cached_event("USER_UPDATE", limit_user_fixture("1", "a2")))
  cache.update(limit_cached_event("USER_UPDATE", limit_user_fixture("3", "c")))
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
    limits=@cache.CacheLimits(users=@cache.CacheLimit(ttl_ms=1000L)),
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
    limits=@cache.CacheLimits(members=@cache.CacheLimit(ttl_ms=1000L)),
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
    cache.members(guild_id).map(member => member.user.unwrap().id.to_string()),
    content="[\"2\"]",
  )
}

///|
test "writes sweep expired messages before inserting" {
  let now = Ref(0L)
  let cache = @cache.InMemoryCache(
    resources=@cache.CacheResources(messages=true),
    limits=@cache.CacheLimits(messages=@cache.CacheLimit(ttl_ms=1000L)),
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
    resources=@cache.CacheResources(messages=true),
    limits=@cache.CacheLimits(
      messages=@cache.CacheLimit(max_entries=2, ttl_ms=1000L),
    ),
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
    limits=@cache.CacheLimits(members=@cache.CacheLimit(max_entries=1)),
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
    resources=@cache.CacheResources(presences=true, messages=true),
    limits=@cache.CacheLimits(
      presences=@cache.CacheLimit(ttl_ms=1000L),
      messages=@cache.CacheLimit(ttl_ms=1000L),
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
    limits=@cache.CacheLimits(
      channels=@cache.CacheLimit(ttl_ms=1000L),
      roles=@cache.CacheLimit(ttl_ms=1000L),
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
    limits=@cache.CacheLimits(users=@cache.CacheLimit(max_entries=-5)),
  )
  no_entries.update(
    limit_cached_event("USER_UPDATE", limit_user_fixture("1", "a")),
  )
  assert_eq(no_entries.users().length(), 0)
  let now = Ref(0L)
  let immediate_expiry = @cache.InMemoryCache(
    resources=@cache.CacheResources::default(),
    limits=@cache.CacheLimits(users=@cache.CacheLimit(ttl_ms=-1L)),
    now=() => now.val,
  )
  let user_id : @model.UserId = @model.Id::parse("2")
  immediate_expiry.update(
    limit_cached_event("USER_UPDATE", limit_user_fixture("2", "b")),
  )
  assert_true(immediate_expiry.user(user_id) is None)
}
