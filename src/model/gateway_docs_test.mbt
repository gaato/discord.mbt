// Source: discord/discord-api-docs @ 845fcaa38e1653d19420311a8e42635eca8de7e5
// Documentation excerpts are attributed under CC-BY-SA 4.0.
// Page: developers/events/gateway-events.mdx
// Skipped blocks from this page:
// - line 44, Example Gateway Event Payload — placeholder event name and empty dispatch data.
// - line 107, Example Identify — invalid JSON and a client Identify command.
// - line 154, Example Resume — client Resume command frame.
// - line 174, Example Heartbeat — client Heartbeat command frame.
// - line 216, Example Request Guild Members — client Request Guild Members command frame.
// - line 241, Example Request Soundboard Sounds — client Request Soundboard Sounds command frame.
// - line 265, Example Request Channel Info — client Request Channel Info command data.
// - line 289, Example Gateway Voice State Update — client Voice State Update command frame.
// - line 329, Example Gateway Presence Update — client Presence Update command frame.
// - line 447, Example Hello — the full Hello gateway envelope is not modeled.
// - line 486, Example Gateway Reconnect — Reconnect control envelope is not modeled.
// - line 506, Example Gateway Invalid Session — Invalid Session control envelope is not modeled.
// - line 1423, Example Activity — standalone activity block, covered through PRESENCE_UPDATE below.
// - line 1436, Example Activity with Rich Presence — rich-presence-only fields are intentionally deferred.

///|
test "discord docs: example voice server update payload (line 1539)" {
  let fixture =
    #|{
    #|  "token": "my_token",
    #|  "guild_id": "41771983423143937",
    #|  "endpoint": "sweetwater-12345.discord.media:2048"
    #|}
  let first : @model.VoiceServerUpdateEvent = @json.from_json(
    @json.parse(fixture),
  )
  let second : @model.VoiceServerUpdateEvent = @json.from_json(first.to_json())
  assert_eq("\{to_repr(first)}", "\{to_repr(second)}")
  inspect(first.guild_id.to_string(), content="41771983423143937")
  assert_true(
    first.endpoint ==
    @model.Nullable::Value("sweetwater-12345.discord.media:2048"),
  )
}

///|
test "discord docs: MESSAGE_UPDATE guild payload with MESSAGE_CREATE extra fields" {
  let fixture =
    #|{
    #|  "id": "120000000000000001",
    #|  "channel_id": "110000000000000001",
    #|  "guild_id": "100000000000000001",
    #|  "author": {
    #|    "id": "200000000000000001",
    #|    "username": "mason",
    #|    "discriminator": "0",
    #|    "global_name": "Mason",
    #|    "avatar": null
    #|  },
    #|  "member": {
    #|    "nick": "Mason",
    #|    "roles": ["300000000000000001"],
    #|    "joined_at": "2024-01-02T03:04:05.000000+00:00",
    #|    "premium_since": null,
    #|    "deaf": false,
    #|    "mute": false,
    #|    "flags": 0
    #|  },
    #|  "content": "edited: hello <@200000000000000002>",
    #|  "timestamp": "2025-06-01T10:00:00.000000+00:00",
    #|  "edited_timestamp": "2025-06-01T10:05:00.000000+00:00",
    #|  "tts": false,
    #|  "mention_everyone": false,
    #|  "mentions": [
    #|    {
    #|      "id": "200000000000000002",
    #|      "username": "ada",
    #|      "discriminator": "0",
    #|      "global_name": "Ada",
    #|      "avatar": null,
    #|      "member": {
    #|        "nick": "Ada",
    #|        "roles": ["300000000000000002"],
    #|        "joined_at": "2024-02-03T04:05:06.000000+00:00",
    #|        "premium_since": null,
    #|        "deaf": false,
    #|        "mute": false,
    #|        "flags": 0
    #|      }
    #|    }
    #|  ],
    #|  "mention_roles": [],
    #|  "attachments": [],
    #|  "embeds": [],
    #|  "pinned": false,
    #|  "type": 0,
    #|  "channel_type": 0
    #|}
  let event = @model.dispatch_event("MESSAGE_UPDATE", @json.parse(fixture))
  match event {
    @model.Event::MessageUpdate(message) => {
      inspect(message.id.to_string(), content="120000000000000001")
      inspect(message.mentions.length(), content="1")
      inspect(message.mentions[0].username, content="ada")
      assert_eq(message.content, "edited: hello <@200000000000000002>")
      assert_false(message.tts)
    }
    _ => fail("expected MESSAGE_UPDATE to decode as MessageUpdate")
  }
}

///|
test "discord docs: MESSAGE_UPDATE payload without guild-only extra fields" {
  let fixture =
    #|{
    #|  "id": "120000000000000002",
    #|  "channel_id": "110000000000000002",
    #|  "author": {
    #|    "id": "200000000000000003",
    #|    "username": "dm-user",
    #|    "discriminator": "0",
    #|    "global_name": null,
    #|    "avatar": null
    #|  },
    #|  "content": "edited in a DM",
    #|  "timestamp": "2025-06-02T10:00:00.000000+00:00",
    #|  "edited_timestamp": "2025-06-02T10:01:00.000000+00:00",
    #|  "tts": false,
    #|  "mention_everyone": false,
    #|  "mentions": [],
    #|  "mention_roles": [],
    #|  "attachments": [],
    #|  "embeds": [],
    #|  "pinned": false,
    #|  "type": 0,
    #|  "channel_type": 1
    #|}
  let event = @model.dispatch_event("MESSAGE_UPDATE", @json.parse(fixture))
  match event {
    @model.Event::MessageUpdate(message) => {
      inspect(message.id.to_string(), content="120000000000000002")
      inspect(message.content, content="edited in a DM")
      inspect(message.mentions.length(), content="0")
      assert_false(message.tts)
    }
    _ => fail("expected MESSAGE_UPDATE to decode as MessageUpdate")
  }
}

///|
test "discord docs: MESSAGE_CREATE guild payload with gateway extra fields" {
  let fixture =
    #|{
    #|  "id": "120000000000000003",
    #|  "channel_id": "110000000000000001",
    #|  "guild_id": "100000000000000001",
    #|  "author": {
    #|    "id": "200000000000000001",
    #|    "username": "mason",
    #|    "discriminator": "0",
    #|    "global_name": "Mason",
    #|    "avatar": null
    #|  },
    #|  "member": {
    #|    "nick": "Mason",
    #|    "roles": ["300000000000000001"],
    #|    "joined_at": "2024-01-02T03:04:05.000000+00:00",
    #|    "premium_since": null,
    #|    "deaf": false,
    #|    "mute": false,
    #|    "flags": 0
    #|  },
    #|  "content": "hello <@200000000000000002>",
    #|  "timestamp": "2025-06-01T10:00:00.000000+00:00",
    #|  "edited_timestamp": null,
    #|  "tts": false,
    #|  "mention_everyone": false,
    #|  "mentions": [
    #|    {
    #|      "id": "200000000000000002",
    #|      "username": "ada",
    #|      "discriminator": "0",
    #|      "global_name": "Ada",
    #|      "avatar": null,
    #|      "member": {
    #|        "nick": "Ada",
    #|        "roles": ["300000000000000002"],
    #|        "joined_at": "2024-02-03T04:05:06.000000+00:00",
    #|        "premium_since": null,
    #|        "deaf": false,
    #|        "mute": false,
    #|        "flags": 0
    #|      }
    #|    }
    #|  ],
    #|  "mention_roles": [],
    #|  "attachments": [],
    #|  "embeds": [],
    #|  "pinned": false,
    #|  "type": 0,
    #|  "channel_type": 0
    #|}
  let event = @model.dispatch_event("MESSAGE_CREATE", @json.parse(fixture))
  match event {
    @model.Event::MessageCreate(message) => {
      inspect(message.id.to_string(), content="120000000000000003")
      inspect(message.mentions.length(), content="1")
      inspect(message.mentions[0].username, content="ada")
      assert_eq(message.content, "hello <@200000000000000002>")
      assert_false(message.tts)
    }
    _ => fail("expected MESSAGE_CREATE to decode as MessageCreate")
  }
}

///|
test "discord docs: GUILD_CREATE available payload" {
  let fixture =
    #|{
    #|  "id": "100000000000000001",
    #|  "name": "MoonBit Guild",
    #|  "icon": null,
    #|  "splash": null,
    #|  "discovery_splash": null,
    #|  "owner_id": "200000000000000001",
    #|  "afk_channel_id": null,
    #|  "afk_timeout": 300,
    #|  "verification_level": 1,
    #|  "default_message_notifications": 1,
    #|  "explicit_content_filter": 2,
    #|  "roles": [],
    #|  "emojis": [],
    #|  "features": [],
    #|  "mfa_level": 0,
    #|  "application_id": null,
    #|  "system_channel_id": null,
    #|  "system_channel_flags": 0,
    #|  "rules_channel_id": null,
    #|  "vanity_url_code": null,
    #|  "description": "A realistic gateway guild payload",
    #|  "banner": null,
    #|  "premium_tier": 0,
    #|  "preferred_locale": "en-US",
    #|  "public_updates_channel_id": null,
    #|  "safety_alerts_channel_id": null,
    #|  "joined_at": "2025-06-01T10:00:00.000000+00:00",
    #|  "large": false,
    #|  "unavailable": false,
    #|  "member_count": 1,
    #|  "voice_states": [
    #|    {
    #|      "channel_id": "110000000000000001",
    #|      "user_id": "200000000000000001",
    #|      "session_id": "voice-session",
    #|      "deaf": false,
    #|      "mute": false,
    #|      "self_deaf": false,
    #|      "self_mute": false,
    #|      "self_stream": false,
    #|      "self_video": false,
    #|      "suppress": false,
    #|      "request_to_speak_timestamp": null
    #|    }
    #|  ],
    #|  "members": [
    #|    {
    #|      "user": {
    #|        "id": "200000000000000001",
    #|        "username": "moonbit-user",
    #|        "discriminator": "0",
    #|        "global_name": "MoonBit User",
    #|        "avatar": null
    #|      },
    #|      "nick": null,
    #|      "roles": [],
    #|      "joined_at": "2025-06-01T10:00:00.000000+00:00",
    #|      "premium_since": null,
    #|      "deaf": false,
    #|      "mute": false,
    #|      "flags": 0
    #|    }
    #|  ],
    #|  "channels": [
    #|    {"id": "110000000000000001", "type": 0, "name": "general"}
    #|  ],
    #|  "threads": [
    #|    {"id": "110000000000000002", "type": 11, "name": "roadmap"}
    #|  ],
    #|  "presences": [
    #|    {
    #|      "user": {"id": "200000000000000001"},
    #|      "guild_id": "100000000000000001",
    #|      "status": "online",
    #|      "activities": [],
    #|      "client_status": {"desktop": "online"}
    #|    }
    #|  ],
    #|  "stage_instances": [],
    #|  "guild_scheduled_events": [],
    #|  "soundboard_sounds": []
    #|}
  let event = @model.dispatch_event("GUILD_CREATE", @json.parse(fixture))
  match event {
    @model.Event::GuildCreate(@model.GuildCreateEvent::Available(available)) => {
      inspect(available.guild.id.to_string(), content="100000000000000001")
      inspect(available.member_count, content="1")
      inspect(available.channels.length(), content="1")
      inspect(available.threads.length(), content="1")
      inspect(available.presences.length(), content="1")
      assert_true(available.voice_states[0].guild_id is None)
    }
    _ => fail("expected available GUILD_CREATE payload")
  }
}

///|
test "discord docs: GUILD_CREATE unavailable payload" {
  let fixture =
    #|{"id":"100000000000000001","unavailable":true}
  let event = @model.dispatch_event("GUILD_CREATE", @json.parse(fixture))
  match event {
    @model.Event::GuildCreate(@model.GuildCreateEvent::Unavailable(unavailable)) => {
      inspect(unavailable.id.to_string(), content="100000000000000001")
      assert_true(unavailable.unavailable)
    }
    _ => fail("expected unavailable GUILD_CREATE payload")
  }
}

///|
test "discord docs: PRESENCE_UPDATE is lenient per field" {
  let fixture =
    #|{
    #|  "user": {"id": "200000000000000001"},
    #|  "guild_id": ["wrong type"],
    #|  "status": 42,
    #|  "activities": [
    #|    {
    #|      "name": "MoonBit",
    #|      "type": 0,
    #|      "created_at": 1750000000000,
    #|      "details": "Compiling"
    #|    }
    #|  ],
    #|  "client_status": {"desktop": "online", "mobile": false}
    #|}
  let event = @model.dispatch_event("PRESENCE_UPDATE", @json.parse(fixture))
  match event {
    @model.Event::PresenceUpdate(presence) => {
      guard presence.user is Some(user) else {
        fail("expected the partial user to decode")
      }
      guard user.id is Some(user_id) else {
        fail("expected the id-only partial user to decode")
      }
      inspect(user_id.to_string(), content="200000000000000001")
      assert_true(presence.guild_id is None)
      assert_true(presence.status is None)
      guard presence.activities is Some(activities) else {
        fail("expected valid activities to survive invalid sibling fields")
      }
      inspect(activities[0].name, content="MoonBit")
      guard presence.client_status is Some(client_status) else {
        fail("expected client status object")
      }
      assert_true(client_status.desktop == Some(@model.PresenceStatus::Online))
      assert_true(client_status.mobile is None)
    }
    _ => fail("expected PRESENCE_UPDATE payload")
  }
}

///|
test "discord docs: subscription dispatch payloads" {
  let fixture =
    #|{
    #|  "id": "1019653835926409216",
    #|  "user_id": "771129655544643584",
    #|  "sku_ids": ["1019475255913222144"],
    #|  "entitlement_ids": ["1019653849998299136"],
    #|  "renewal_sku_ids": ["1019475255913222144"],
    #|  "current_period_start": "2025-06-01T00:00:00.000000+00:00",
    #|  "current_period_end": "2025-07-01T00:00:00.000000+00:00",
    #|  "status": 0,
    #|  "canceled_at": null,
    #|  "country": "JP"
    #|}
  let payload = @json.parse(fixture)
  match @model.dispatch_event("SUBSCRIPTION_CREATE", payload) {
    @model.Event::SubscriptionCreate(subscription) =>
      inspect(subscription.user_id.to_string(), content="771129655544643584")
    _ => fail("expected SUBSCRIPTION_CREATE payload")
  }
  match @model.dispatch_event("SUBSCRIPTION_UPDATE", payload) {
    @model.Event::SubscriptionUpdate(subscription) =>
      inspect(subscription.status.to_int(), content="0")
    _ => fail("expected SUBSCRIPTION_UPDATE payload")
  }
  match @model.dispatch_event("SUBSCRIPTION_DELETE", payload) {
    @model.Event::SubscriptionDelete(subscription) =>
      inspect(subscription.sku_ids.length(), content="1")
    _ => fail("expected SUBSCRIPTION_DELETE payload")
  }
}

///|
test "discord docs: APPLICATION_COMMAND_PERMISSIONS_UPDATE payload" {
  let fixture =
    #|{
    #|  "id": "110000000000000001",
    #|  "application_id": "120000000000000001",
    #|  "guild_id": "100000000000000001",
    #|  "permissions": [
    #|    {"id": "300000000000000001", "type": 1, "permission": true},
    #|    {"id": "200000000000000001", "type": 2, "permission": false},
    #|    {"id": "110000000000000002", "type": 3, "permission": true}
    #|  ]
    #|}
  let event = @model.dispatch_event(
    "APPLICATION_COMMAND_PERMISSIONS_UPDATE",
    @json.parse(fixture),
  )
  match event {
    @model.Event::ApplicationCommandPermissionsUpdate(permissions) => {
      inspect(permissions.id.to_string(), content="110000000000000001")
      inspect(permissions.permissions.length(), content="3")
      inspect(permissions.permissions[2].typ.to_int(), content="3")
      assert_false(permissions.permissions[1].permission)
    }
    _ => fail("expected APPLICATION_COMMAND_PERMISSIONS_UPDATE payload")
  }
}
