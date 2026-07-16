///|
fn cached_event(name : String, fixture : String) -> @model.Event raise {
  @model.dispatch_event(name, @json.parse(fixture))
}

///|
fn guild_create_fixture() -> String {
  (
    #|{
    #|  "id": "100",
    #|  "name": "Cache Guild",
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
    #|    {"id":"301","name":"admin","color":0,"hoist":false,"position":1,"permissions":"8","managed":false,"mentionable":false},
    #|    {"id":"302","name":"writer","color":0,"hoist":false,"position":1,"permissions":"2048","managed":false,"mentionable":false}
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
    #|  "member_count": 3,
    #|  "voice_states": [
    #|    {"channel_id":"400","user_id":"202","session_id":"voice","deaf":false,"mute":false,"self_deaf":false,"self_mute":false,"suppress":false,"request_to_speak_timestamp":null}
    #|  ],
    #|  "members": [
    #|    {"user":{"id":"200","username":"owner","discriminator":"0","avatar":null},"nick":null,"roles":[],"joined_at":"2025-06-01T10:00:00Z","deaf":false,"mute":false},
    #|    {"user":{"id":"201","username":"admin","discriminator":"0","avatar":null},"nick":null,"roles":["301"],"joined_at":"2025-06-01T10:00:00Z","deaf":false,"mute":false},
    #|    {"user":{"id":"202","username":"writer","discriminator":"0","avatar":null},"nick":null,"roles":["302"],"joined_at":"2025-06-01T10:00:00Z","deaf":false,"mute":false}
    #|  ],
    #|  "channels": [
    #|    {"id":"400","type":0,"name":"general","permission_overwrites":[
    #|      {"id":"100","type":0,"allow":"0","deny":"2048"},
    #|      {"id":"202","type":1,"allow":"2048","deny":"0"}
    #|    ]}
    #|  ],
    #|  "threads": [
    #|    {"id":"401","type":11,"parent_id":"400","name":"thread"}
    #|  ],
    #|  "presences": [
    #|    {"user":{"id":"202"},"status":"online","activities":[],"client_status":{"web":"online"}}
    #|  ],
    #|  "stage_instances": [],
    #|  "guild_scheduled_events": [],
    #|  "soundboard_sounds": []
    #|}
  )
}

///|
fn message_fixture(id : String, content : String) -> String {
  "{\"id\":\"" +
  id +
  "\",\"channel_id\":\"400\",\"guild_id\":\"100\",\"author\":{\"id\":\"202\",\"username\":\"writer\",\"discriminator\":\"0\",\"avatar\":null},\"content\":\"" +
  content +
  "\",\"timestamp\":\"2025-06-01T10:00:00Z\",\"edited_timestamp\":null,\"tts\":false,\"mention_everyone\":false,\"mentions\":[],\"mention_roles\":[],\"attachments\":[],\"embeds\":[],\"pinned\":false,\"type\":0}"
}

///|
test "guild create seeds selected resources and updates replace state" {
  let cache = @cache.InMemoryCache(resources=CacheResources::all())
  cache.update(cached_event("GUILD_CREATE", guild_create_fixture()))
  let guild_id : @model.GuildId = @model.Id::parse("100")
  let channel_id : @model.ChannelId = @model.Id::parse("400")
  let thread_id : @model.ChannelId = @model.Id::parse("401")
  let writer_id : @model.UserId = @model.Id::parse("202")
  let writer_role_id : @model.RoleId = @model.Id::parse("302")
  assert_true(cache.guild(guild_id) is Some(_))
  assert_true(cache.channel(channel_id) is Some(_))
  assert_true(cache.channel(thread_id) is Some(_))
  assert_true(cache.role(guild_id, writer_role_id) is Some(_))
  assert_true(cache.member(guild_id, writer_id) is Some(_))
  assert_true(cache.user(writer_id) is Some(_))
  assert_true(cache.voice_state(guild_id, writer_id) is Some(_))
  assert_true(cache.presence(guild_id, writer_id) is Some(_))

  cache.update(
    cached_event(
      "GUILD_UPDATE",
      guild_create_fixture().replace(
        old="\"name\": \"Cache Guild\"",
        new="\"name\": \"Updated Guild\"",
      ),
    ),
  )
  guard cache.guild(guild_id) is Some(updated_guild) else {
    fail("expected updated guild")
  }
  assert_eq(updated_guild.name, "Updated Guild")

  cache.update(
    cached_event(
      "CHANNEL_UPDATE", "{\"id\":\"400\",\"type\":0,\"guild_id\":\"100\",\"name\":\"renamed\"}",
    ),
  )
  guard cache.channel(channel_id) is Some(channel) else {
    fail("expected updated channel")
  }
  assert_true(channel.name == Some(Value("renamed")))

  cache.update(
    cached_event(
      "GUILD_ROLE_UPDATE", "{\"guild_id\":\"100\",\"role\":{\"id\":\"302\",\"name\":\"publisher\",\"color\":0,\"hoist\":false,\"position\":1,\"permissions\":\"3072\",\"managed\":false,\"mentionable\":false}}",
    ),
  )
  guard cache.role(guild_id, writer_role_id) is Some(role) else {
    fail("expected updated role")
  }
  assert_eq(role.name, "publisher")

  cache.update(
    cached_event(
      "GUILD_MEMBER_UPDATE", "{\"guild_id\":\"100\",\"roles\":[\"302\"],\"user\":{\"id\":\"202\",\"username\":\"writer\",\"discriminator\":\"0\",\"avatar\":null},\"nick\":\"Writer\",\"avatar\":null,\"joined_at\":\"2025-06-01T10:00:00Z\"}",
    ),
  )
  guard cache.member(guild_id, writer_id) is Some(updated_member) else {
    fail("expected updated member")
  }
  assert_true(updated_member.nick == Some(Value("Writer")))

  cache.update(
    cached_event(
      "GUILD_BAN_ADD", "{\"guild_id\":\"100\",\"user\":{\"id\":\"202\",\"username\":\"writer\",\"discriminator\":\"0\",\"avatar\":null}}",
    ),
  )
  assert_true(cache.member(guild_id, writer_id) is Some(_))

  cache.update(
    cached_event(
      "VOICE_STATE_UPDATE", "{\"guild_id\":\"100\",\"channel_id\":null,\"user_id\":\"202\",\"session_id\":\"voice\",\"deaf\":false,\"mute\":false,\"self_deaf\":false,\"self_mute\":false,\"suppress\":false,\"request_to_speak_timestamp\":null}",
    ),
  )
  assert_true(cache.voice_state(guild_id, writer_id) is None)
  cache.update(
    cached_event(
      "PRESENCE_UPDATE", "{\"guild_id\":\"100\",\"user\":{\"id\":\"202\"},\"status\":\"idle\",\"activities\":[],\"client_status\":{}}",
    ),
  )
  guard cache.presence(guild_id, writer_id) is Some(presence) else {
    fail("expected updated presence")
  }
  assert_true(presence.status == Some(Idle))

  cache.update(
    cached_event(
      "THREAD_DELETE", "{\"id\":\"401\",\"guild_id\":\"100\",\"parent_id\":\"400\",\"type\":11}",
    ),
  )
  assert_true(cache.channel(thread_id) is None)
  cache.update(
    cached_event(
      "GUILD_MEMBER_REMOVE", "{\"guild_id\":\"100\",\"user\":{\"id\":\"202\",\"username\":\"writer\",\"discriminator\":\"0\",\"avatar\":null}}",
    ),
  )
  assert_true(cache.member(guild_id, writer_id) is None)
  // Users outlive guild membership.
  assert_true(cache.user(writer_id) is Some(_))
  cache.update(
    cached_event(
      "CHANNEL_DELETE", "{\"id\":\"400\",\"type\":0,\"guild_id\":\"100\"}",
    ),
  )
  assert_true(cache.channel(channel_id) is None)
}

///|
test "permissions use owner administrator and channel overwrites" {
  let cache = @cache.InMemoryCache(resources=CacheResources::all())
  cache.update(cached_event("GUILD_CREATE", guild_create_fixture()))
  let guild_id : @model.GuildId = @model.Id::parse("100")
  let channel_id : @model.ChannelId = @model.Id::parse("400")
  let owner_id : @model.UserId = @model.Id::parse("200")
  let admin_id : @model.UserId = @model.Id::parse("201")
  let writer_id : @model.UserId = @model.Id::parse("202")
  guard cache.permissions(guild_id, owner_id) is Some(owner) else {
    fail("expected owner permissions")
  }
  guard cache.permissions(guild_id, admin_id) is Some(admin) else {
    fail("expected administrator permissions")
  }
  assert_eq(owner.bits(), @util.all_permissions().bits())
  assert_eq(admin.bits(), @util.all_permissions().bits())
  guard cache.permissions_in(guild_id, channel_id, writer_id) is Some(writer) else {
    fail("expected channel permissions")
  }
  assert_true(writer.contains(@model.Permissions::view_channel()))
  // @everyone denies SEND_MESSAGES, then the member overwrite restores it.
  assert_true(writer.contains(@model.Permissions::send_messages()))
  cache.update(
    cached_event(
      "GUILD_ROLE_DELETE", "{\"guild_id\":\"100\",\"role_id\":\"301\"}",
    ),
  )
  // Missing role data must never produce an under-counted permission set.
  assert_true(cache.permissions(guild_id, admin_id) is None)
}

///|
test "message updates replace retained entries without changing eviction order" {
  let cache = @cache.InMemoryCache(
    resources=CacheResources::all(),
    max_messages_per_channel=2,
  )
  let channel_id : @model.ChannelId = @model.Id::parse("400")
  let first_id : @model.MessageId = @model.Id::parse("500")
  let second_id : @model.MessageId = @model.Id::parse("501")
  let third_id : @model.MessageId = @model.Id::parse("502")
  cache.update(cached_event("MESSAGE_CREATE", message_fixture("500", "one")))
  cache.update(cached_event("MESSAGE_CREATE", message_fixture("501", "two")))
  cache.update(cached_event("MESSAGE_UPDATE", message_fixture("500", "edited")))
  guard cache.message(channel_id, first_id) is Some(edited) else {
    fail("expected updated message")
  }
  assert_eq(edited.content, "edited")
  debug_inspect(
    cache.messages(channel_id).map(message => message.id.to_string()),
    content="[\"500\", \"501\"]",
  )
  cache.update(cached_event("MESSAGE_CREATE", message_fixture("502", "three")))
  assert_true(cache.message(channel_id, first_id) is None)
  assert_true(cache.message(channel_id, second_id) is Some(_))
  assert_true(cache.message(channel_id, third_id) is Some(_))
  debug_inspect(
    cache.messages(channel_id).map(message => message.id.to_string()),
    content="[\"501\", \"502\"]",
  )
  cache.update(
    cached_event(
      "MESSAGE_DELETE_BULK", "{\"ids\":[\"501\",\"502\"],\"channel_id\":\"400\",\"guild_id\":\"100\"}",
    ),
  )
  assert_eq(cache.messages(channel_id).length(), 0)
}

///|
test "message update cache misses are not inserted" {
  let cache = @cache.InMemoryCache(resources=CacheResources::all())
  let channel_id : @model.ChannelId = @model.Id::parse("400")
  let message_id : @model.MessageId = @model.Id::parse("599")
  cache.update(cached_event("MESSAGE_UPDATE", message_fixture("599", "old")))
  assert_true(cache.message(channel_id, message_id) is None)
  assert_eq(cache.messages(channel_id).length(), 0)
}

///|
test "disabled resources never retain events" {
  let cache = @cache.InMemoryCache(resources=CacheResources::none())
  cache.update(cached_event("GUILD_CREATE", guild_create_fixture()))
  cache.update(cached_event("MESSAGE_CREATE", message_fixture("500", "one")))
  let guild_id : @model.GuildId = @model.Id::parse("100")
  let channel_id : @model.ChannelId = @model.Id::parse("400")
  let message_id : @model.MessageId = @model.Id::parse("500")
  let user_id : @model.UserId = @model.Id::parse("202")
  assert_true(cache.guild(guild_id) is None)
  assert_true(cache.channel(channel_id) is None)
  assert_true(cache.user(user_id) is None)
  assert_true(cache.message(channel_id, message_id) is None)
  assert_true(cache.permissions(guild_id, user_id) is None)
}

///|
test "default resources exclude presence and message churn" {
  let cache = @cache.InMemoryCache(resources=CacheResources::default())
  cache.update(cached_event("GUILD_CREATE", guild_create_fixture()))
  cache.update(cached_event("MESSAGE_CREATE", message_fixture("500", "one")))
  let guild_id : @model.GuildId = @model.Id::parse("100")
  let channel_id : @model.ChannelId = @model.Id::parse("400")
  let message_id : @model.MessageId = @model.Id::parse("500")
  let user_id : @model.UserId = @model.Id::parse("202")
  assert_true(cache.guild(guild_id) is Some(_))
  assert_true(cache.user(user_id) is Some(_))
  assert_true(cache.presence(guild_id, user_id) is None)
  assert_true(cache.message(channel_id, message_id) is None)
}

///|
test "unavailable guilds retain data until a permanent delete" {
  let cache = @cache.InMemoryCache(resources=CacheResources::default())
  let guild_id : @model.GuildId = @model.Id::parse("100")
  cache.update(cached_event("GUILD_CREATE", guild_create_fixture()))
  cache.update(
    cached_event("GUILD_DELETE", "{\"id\":\"100\",\"unavailable\":true}"),
  )
  assert_true(cache.is_guild_unavailable(guild_id))
  assert_true(cache.guild(guild_id) is Some(_))
  let detached = cache.guilds()
  detached.push(cache.guild(guild_id).unwrap())
  assert_eq(cache.guilds().length(), 1)

  cache.update(cached_event("GUILD_CREATE", guild_create_fixture()))
  assert_false(cache.is_guild_unavailable(guild_id))
  cache.update(
    cached_event("GUILD_DELETE", "{\"id\":\"100\",\"unavailable\":false}"),
  )
  assert_true(cache.guild(guild_id) is None)
  assert_eq(cache.channels().length(), 0)
}
