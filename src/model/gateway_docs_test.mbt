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
// - line 1423, Example Activity — activity and presence objects are not modeled.
// - line 1436, Example Activity with Rich Presence — activity and presence objects are not modeled.

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
