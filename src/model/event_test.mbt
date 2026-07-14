///|
test "guild member add decodes flattened member payload" {
  let fixture =
    #|{
    #|  "guild_id": "100",
    #|  "user": {
    #|    "id": "200",
    #|    "username": "Nelly",
    #|    "discriminator": "0",
    #|    "global_name": "Nelly",
    #|    "avatar": null
    #|  },
    #|  "nick": null,
    #|  "roles": ["300"],
    #|  "joined_at": "2024-01-02T03:04:05.000000+00:00",
    #|  "premium_since": null,
    #|  "deaf": false,
    #|  "mute": false,
    #|  "flags": 1,
    #|  "unknown_future_field": true
    #|}
  let event = @model.dispatch_event("GUILD_MEMBER_ADD", @json.parse(fixture))
  debug_inspect(
    event,
    content=(
      #|GuildMemberAdd(
      #|  {
      #|    guild_id: 100,
      #|    guild_member: {
      #|      user: Some(
      #|        {
      #|          id: 200,
      #|          username: "Nelly",
      #|          discriminator: "0",
      #|          global_name: Some(Value("Nelly")),
      #|          avatar: Null,
      #|          bot: None,
      #|          system: None,
      #|          mfa_enabled: None,
      #|          banner: None,
      #|          accent_color: None,
      #|          locale: None,
      #|          verified: None,
      #|          email: None,
      #|          flags: None,
      #|          premium_type: None,
      #|          public_flags: None,
      #|          avatar_decoration: None,
      #|          avatar_decoration_data: None,
      #|          collectibles: None,
      #|          primary_guild: None,
      #|        },
      #|      ),
      #|      nick: Some(Null),
      #|      avatar: None,
      #|      banner: None,
      #|      roles: [300],
      #|      joined_at: Value("2024-01-02T03:04:05.000000+00:00"),
      #|      premium_since: Some(Null),
      #|      deaf: Some(false),
      #|      mute: Some(false),
      #|      flags: Some(1),
      #|      pending: None,
      #|      permissions: None,
      #|      communication_disabled_until: None,
      #|      avatar_decoration_data: None,
      #|      collectibles: None,
      #|    },
      #|  },
      #|)
    ),
  )
}

///|
test "message reaction add decodes typed payload" {
  let fixture =
    #|{
    #|  "user_id": "200",
    #|  "channel_id": "400",
    #|  "message_id": "500",
    #|  "guild_id": "100",
    #|  "emoji": {"id": null, "name": "🔥"},
    #|  "message_author_id": "201",
    #|  "burst": true,
    #|  "burst_colors": ["#ff0000", "#ffaa00"],
    #|  "type": 1
    #|}
  let event = @model.dispatch_event(
    "MESSAGE_REACTION_ADD",
    @json.parse(fixture),
  )
  debug_inspect(
    event,
    content=(
      #|MessageReactionAdd(
      #|  {
      #|    user_id: 200,
      #|    channel_id: 400,
      #|    message_id: 500,
      #|    guild_id: Some(100),
      #|    guild_member: None,
      #|    emoji: {
      #|      id: Some(Null),
      #|      name: Value("🔥"),
      #|      animated: None,
      #|      roles: None,
      #|      user: None,
      #|      require_colons: None,
      #|      managed: None,
      #|      available: None,
      #|    },
      #|    message_author_id: Some(201),
      #|    burst: true,
      #|    burst_colors: Some(["#ff0000", "#ffaa00"]),
      #|    typ: 1,
      #|  },
      #|)
    ),
  )
}

///|
test "guild role create decodes role and guild id" {
  let fixture =
    #|{
    #|  "guild_id": "100",
    #|  "role": {
    #|    "id": "300",
    #|    "name": "moderator",
    #|    "color": 3447003,
    #|    "hoist": true,
    #|    "position": 2,
    #|    "permissions": "8192",
    #|    "managed": false,
    #|    "mentionable": true,
    #|    "flags": 0
    #|  }
    #|}
  let event = @model.dispatch_event("GUILD_ROLE_CREATE", @json.parse(fixture))
  debug_inspect(
    event,
    content=(
      #|GuildRoleCreate(
      #|  {
      #|    guild_id: 100,
      #|    role: {
      #|      id: 300,
      #|      name: "moderator",
      #|      color: 3447003,
      #|      colors: None,
      #|      hoist: true,
      #|      icon: None,
      #|      unicode_emoji: None,
      #|      position: 2,
      #|      permissions: 8192,
      #|      managed: false,
      #|      mentionable: true,
      #|      tags: None,
      #|      flags: Some(0),
      #|    },
      #|  },
      #|)
    ),
  )
}

///|
test "bulk message delete decodes identifiers" {
  let fixture =
    #|{
    #|  "ids": ["500", "501", "502"],
    #|  "channel_id": "400",
    #|  "guild_id": "100"
    #|}
  let event = @model.dispatch_event("MESSAGE_DELETE_BULK", @json.parse(fixture))
  debug_inspect(
    event,
    content=(
      #|MessageDeleteBulk({ ids: [500, 501, 502], channel_id: 400, guild_id: Some(100) })
    ),
  )
}

///|
test "voice server update preserves nullable endpoint" {
  let fixture =
    #|{
    #|  "token": "voice-token",
    #|  "guild_id": "100",
    #|  "endpoint": null
    #|}
  let event = @model.dispatch_event("VOICE_SERVER_UPDATE", @json.parse(fixture))
  debug_inspect(
    event,
    content=(
      #|VoiceServerUpdate({ token: "voice-token", guild_id: 100, endpoint: Null })
    ),
  )
}

///|
test "guild audit log entry decodes flattened entry payload" {
  let fixture =
    #|{
    #|  "guild_id": "100",
    #|  "target_id": "400",
    #|  "changes": [
    #|    {"key": "name", "old_value": "old", "new_value": "new"}
    #|  ],
    #|  "user_id": "200",
    #|  "id": "600",
    #|  "action_type": 10,
    #|  "options": {"channel_id": "400"},
    #|  "reason": "cleanup"
    #|}
  let event = @model.dispatch_event(
    "GUILD_AUDIT_LOG_ENTRY_CREATE",
    @json.parse(fixture),
  )
  debug_inspect(
    event,
    content=(
      #|GuildAuditLogEntryCreate(
      #|  {
      #|    guild_id: 100,
      #|    entry: {
      #|      target_id: Value("400"),
      #|      changes: Some(
      #|        [
      #|          {
      #|            key: "name",
      #|            new_value: Some(String("new")),
      #|            old_value: Some(String("old")),
      #|          },
      #|        ],
      #|      ),
      #|      user_id: Value(200),
      #|      id: 600,
      #|      action_type: ChannelCreate,
      #|      options: Some(Object({ "channel_id": String("400") })),
      #|      reason: Some("cleanup"),
      #|    },
      #|  },
      #|)
    ),
  )
}

///|
test "dispatch names map to typed and unknown variants" {
  assert_true(
    @model.EventKind::of_name("VOICE_SERVER_UPDATE")
    is @model.EventKind::KVoiceServerUpdate,
  )
  assert_true(
    @model.EventKind::of_name("SOME_FUTURE_EVENT") is @model.EventKind::KUnknown,
  )
  let pins_fixture =
    #|{"channel_id":"400","guild_id":"100","last_pin_timestamp":null}
  let known = @model.dispatch_event(
    "CHANNEL_PINS_UPDATE",
    @json.parse(pins_fixture),
  )
  assert_true(known is @model.Event::ChannelPinsUpdate(_))
  let unknown_fixture =
    #|{"future":true,"value":99}
  let raw = @json.parse(unknown_fixture)
  let unknown = @model.dispatch_event("SOME_FUTURE_EVENT", raw)
  debug_inspect(
    unknown,
    content=(
      #|Unknown(
      #|  t="SOME_FUTURE_EVENT",
      #|  d=Object({ "future": True, "value": Number(99) }),
      #|)
    ),
  )
}
