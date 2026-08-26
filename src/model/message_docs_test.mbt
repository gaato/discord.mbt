// Source: discord/discord-api-docs @ 845fcaa38e1653d19420311a8e42635eca8de7e5
// Documentation excerpts are attributed under CC-BY-SA 4.0.
// Page: developers/resources/message.mdx
// Skipped blocks from this page:
// - line 736, Default Settings for Allowed Mentions — allowed-mentions request defaults.
// - line 744, Default Settings for Allowed Mentions — allowed-mentions request defaults.
// - lines 765-823, Allowed Mentions Examples — covered by allowed_mentions_test.mbt.
// - line 882, Example Shared Client Theme — standalone fragment covered in
//   model_todo_docs_test.mbt.
// - line 928, Search Guild Messages — search-index error response rather than a message.
// - line 1103, Example Request Body (application/json) — message request body.

///|
test "discord docs: example message (line 167)" {
  let fixture =
    #|{
    #|  "reactions": [
    #|    {
    #|      "count": 1,
    #|      "count_details": {
    #|         "burst": 0,
    #|         "normal": 1
    #|      },
    #|      "me": false,
    #|      "me_burst": false,
    #|      "emoji": {
    #|         "id": null,
    #|         "name": "🔥"
    #|      },
    #|      "burst_colors": []
    #|    }
    #|  ],
    #|  "attachments": [],
    #|  "tts": false,
    #|  "embeds": [],
    #|  "timestamp": "2017-07-11T17:27:07.299000+00:00",
    #|  "mention_everyone": false,
    #|  "id": "334385199974967042",
    #|  "pinned": false,
    #|  "edited_timestamp": null,
    #|  "author": {
    #|    "username": "Mason",
    #|    "discriminator": "9999",
    #|    "id": "53908099506183680",
    #|    "avatar": "a_bab14f271d565501444b2ca3be944b25"
    #|  },
    #|  "mention_roles": [],
    #|  "content": "Supa Hot",
    #|  "channel_id": "290926798999357250",
    #|  "mentions": [],
    #|  "type": 0
    #|}
  let first : @model.Message = @json.from_json(@json.parse(fixture))
  let second : @model.Message = @json.from_json(first.to_json())
  assert_eq("\{Repr(first)}", "\{Repr(second)}")
  inspect(first.id.to_string(), content="334385199974967042")
  assert_eq(first.content, "Supa Hot")
}

///|
test "discord docs: example crossposted message (line 210)" {
  let fixture =
    #|{
    #|  "reactions": [
    #|    {
    #|      "count": 1,
    #|      "count_details": {
    #|         "burst": 0,
    #|         "normal": 1
    #|      },
    #|      "me": false,
    #|      "me_burst": false,
    #|      "emoji": {
    #|         "id": null,
    #|         "name": "🔥"
    #|      },
    #|      "burst_colors": []
    #|    }
    #|  ],
    #|  "attachments": [],
    #|  "tts": false,
    #|  "embeds": [],
    #|  "timestamp": "2017-07-11T17:27:07.299000+00:00",
    #|  "mention_everyone": false,
    #|  "id": "334385199974967042",
    #|  "pinned": false,
    #|  "edited_timestamp": null,
    #|  "author": {
    #|    "username": "Mason",
    #|    "discriminator": "9999",
    #|    "id": "53908099506183680",
    #|    "avatar": "a_bab14f271d565501444b2ca3be944b25"
    #|  },
    #|  "mention_roles": [],
    #|  "mention_channels": [
    #|    {
    #|      "id": "278325129692446722",
    #|      "guild_id": "278325129692446720",
    #|      "name": "big-news",
    #|      "type": 5
    #|    }
    #|  ],
    #|  "content": "Big news! In this <#278325129692446722> channel!",
    #|  "channel_id": "290926798999357250",
    #|  "mentions": [],
    #|  "type": 0,
    #|  "flags": 2,
    #|  "message_reference": {
    #|    "type": 0,
    #|    "channel_id": "278325129692446722",
    #|    "guild_id": "278325129692446720",
    #|    "message_id": "306588351130107906"
    #|  }
    #|}
  let first : @model.Message = @json.from_json(@json.parse(fixture))
  let second : @model.Message = @json.from_json(first.to_json())
  assert_eq("\{Repr(first)}", "\{Repr(second)}")
  inspect(first.id.to_string(), content="334385199974967042")
  inspect(first.mention_channels.unwrap_or([]).length(), content="1")
}
