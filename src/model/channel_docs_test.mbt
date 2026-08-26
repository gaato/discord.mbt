// Source: discord/discord-api-docs @ 845fcaa38e1653d19420311a8e42635eca8de7e5
// Documentation excerpts are attributed under CC-BY-SA 4.0.
// Page: developers/resources/channel.mdx
// Skipped blocks from this page:
// - line 162, Example Guild Voice Channel — invalid JSON (trailing comma).

///|
test "discord docs: example guild text channel (line 121)" {
  let fixture =
    #|{
    #|  "id": "41771983423143937",
    #|  "guild_id": "41771983423143937",
    #|  "name": "general",
    #|  "type": 0,
    #|  "position": 6,
    #|  "permission_overwrites": [],
    #|  "rate_limit_per_user": 2,
    #|  "nsfw": true,
    #|  "topic": "24/7 chat about how to gank Mike #2",
    #|  "last_message_id": "155117677105512449",
    #|  "parent_id": "399942396007890945",
    #|  "default_auto_archive_duration": 60
    #|}
  let first : @model.Channel = @json.from_json(@json.parse(fixture))
  let second : @model.Channel = @json.from_json(first.to_json())
  assert_eq("\{Repr(first)}", "\{Repr(second)}")
  inspect(first.id.to_string(), content="41771983423143937")
  inspect(first.typ.to_int(), content="0")
}

///|
test "discord docs: example guild announcement channel (line 143)" {
  let fixture =
    #|{
    #|  "id": "41771983423143937",
    #|  "guild_id": "41771983423143937",
    #|  "name": "important-news",
    #|  "type": 5,
    #|  "position": 6,
    #|  "permission_overwrites": [],
    #|  "nsfw": true,
    #|  "topic": "Rumors about Half Life 3",
    #|  "last_message_id": "155117677105512449",
    #|  "parent_id": "399942396007890945",
    #|  "default_auto_archive_duration": 60
    #|}
  let first : @model.Channel = @json.from_json(@json.parse(fixture))
  let second : @model.Channel = @json.from_json(first.to_json())
  assert_eq("\{Repr(first)}", "\{Repr(second)}")
  assert_true(first.name == Some(Value("important-news")))
  inspect(first.typ.to_int(), content="5")
}

///|
test "discord docs: example dm channel (line 183)" {
  let fixture =
    #|{
    #|  "last_message_id": "3343820033257021450",
    #|  "type": 1,
    #|  "id": "319674150115610528",
    #|  "recipients": [
    #|    {
    #|      "username": "test",
    #|      "discriminator": "9999",
    #|      "id": "82198898841029460",
    #|      "avatar": "33ecab261d4681afa4d85a04691c4a01"
    #|    }
    #|  ]
    #|}
  let first : @model.Channel = @json.from_json(@json.parse(fixture))
  let second : @model.Channel = @json.from_json(first.to_json())
  assert_eq("\{Repr(first)}", "\{Repr(second)}")
  inspect(first.id.to_string(), content="319674150115610528")
  inspect(first.recipients.unwrap_or([]).length(), content="1")
}

///|
test "discord docs: example group dm channel (line 202)" {
  let fixture =
    #|{
    #|  "name": "Some test channel",
    #|  "icon": null,
    #|  "recipients": [
    #|    {
    #|      "username": "test",
    #|      "discriminator": "9999",
    #|      "id": "82198898841029460",
    #|      "avatar": "33ecab261d4681afa4d85a04691c4a01"
    #|    },
    #|    {
    #|      "username": "test2",
    #|      "discriminator": "9999",
    #|      "id": "82198810841029460",
    #|      "avatar": "33ecab261d4681afa4d85a10691c4a01"
    #|    }
    #|  ],
    #|  "last_message_id": "3343820033257021450",
    #|  "type": 3,
    #|  "id": "319674150115710528",
    #|  "owner_id": "82198810841029460"
    #|}
  let first : @model.Channel = @json.from_json(@json.parse(fixture))
  let second : @model.Channel = @json.from_json(first.to_json())
  assert_eq("\{Repr(first)}", "\{Repr(second)}")
  assert_true(first.name == Some(Value("Some test channel")))
  inspect(first.recipients.unwrap_or([]).length(), content="2")
}

///|
test "discord docs: example channel category (line 230)" {
  let fixture =
    #|{
    #|  "permission_overwrites": [],
    #|  "name": "Test",
    #|  "parent_id": null,
    #|  "nsfw": false,
    #|  "position": 0,
    #|  "guild_id": "290926798629997250",
    #|  "type": 4,
    #|  "id": "399942396007890945"
    #|}
  let first : @model.Channel = @json.from_json(@json.parse(fixture))
  let second : @model.Channel = @json.from_json(first.to_json())
  assert_eq("\{Repr(first)}", "\{Repr(second)}")
  inspect(first.id.to_string(), content="399942396007890945")
  inspect(first.typ.to_int(), content="4")
}

///|
test "discord docs: example thread channel (line 256)" {
  let fixture =
    #|{
    #|  "id": "41771983423143937",
    #|  "guild_id": "41771983423143937",
    #|  "parent_id": "41771983423143937",
    #|  "owner_id": "41771983423143937",
    #|  "name": "don't buy dota-2",
    #|  "type": 11,
    #|  "last_message_id": "155117677105512449",
    #|  "message_count": 1,
    #|  "member_count": 5,
    #|  "rate_limit_per_user": 2,
    #|  "thread_metadata": {
    #|    "archived": false,
    #|    "auto_archive_duration": 1440,
    #|    "archive_timestamp": "2021-04-12T23:40:39.855793+00:00",
    #|    "locked": false
    #|  },
    #|  "total_message_sent": 1
    #|}
  let first : @model.Channel = @json.from_json(@json.parse(fixture))
  let second : @model.Channel = @json.from_json(first.to_json())
  assert_eq("\{Repr(first)}", "\{Repr(second)}")
  inspect(first.id.to_string(), content="41771983423143937")
  inspect(first.typ.to_int(), content="11")
}
