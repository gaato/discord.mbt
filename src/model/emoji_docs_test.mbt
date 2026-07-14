// Source: discord/discord-api-docs @ 845fcaa38e1653d19420311a8e42635eca8de7e5
// Documentation excerpts are attributed under CC-BY-SA 4.0.
// Page: developers/resources/emoji.mdx
// Skipped blocks from this page:
// - line 182, List Application Emojis — the application-emoji response wrapper is not modeled.

///|
test "discord docs: emoji example (line 57)" {
  let fixture =
    #|{
    #|  "id": "41771983429993937",
    #|  "name": "LUL",
    #|  "roles": ["41771983429993000", "41771983429993111"],
    #|  "user": {
    #|    "username": "Luigi",
    #|    "discriminator": "0002",
    #|    "id": "96008815106887111",
    #|    "avatar": "5500909a3274e1812beb4e8de6631111",
    #|    "public_flags": 131328
    #|  },
    #|  "require_colons": true,
    #|  "managed": false,
    #|  "animated": false
    #|}
  let first : @model.Emoji = @json.from_json(@json.parse(fixture))
  let second : @model.Emoji = @json.from_json(first.to_json())
  assert_eq("\{to_repr(first)}", "\{to_repr(second)}")
  assert_true(first.name == @model.Nullable::Value("LUL"))
  assert_true(first.animated == Some(false))
}

///|
test "discord docs: standard emoji example (line 78)" {
  let fixture =
    #|{
    #|  "id": null,
    #|  "name": "🔥"
    #|}
  let first : @model.Emoji = @json.from_json(@json.parse(fixture))
  let second : @model.Emoji = @json.from_json(first.to_json())
  assert_eq("\{to_repr(first)}", "\{to_repr(second)}")
  assert_true(first.id == Some(@model.Nullable::Null))
  assert_true(first.name == @model.Nullable::Value("🔥"))
}

///|
test "discord docs: custom emoji examples (line 96)" {
  let fixture =
    #|{
    #|  "id": "41771983429993937",
    #|  "name": "LUL",
    #|  "animated": true
    #|}
  let first : @model.Emoji = @json.from_json(@json.parse(fixture))
  let second : @model.Emoji = @json.from_json(first.to_json())
  assert_eq("\{to_repr(first)}", "\{to_repr(second)}")
  assert_true(first.name == @model.Nullable::Value("LUL"))
  assert_true(first.animated == Some(true))
}

///|
test "discord docs: custom emoji examples (line 104)" {
  let fixture =
    #|{
    #|  "id": "41771983429993937",
    #|  "name": null
    #|}
  let first : @model.Emoji = @json.from_json(@json.parse(fixture))
  let second : @model.Emoji = @json.from_json(first.to_json())
  assert_eq("\{to_repr(first)}", "\{to_repr(second)}")
  assert_true(first.name == @model.Nullable::Null)
  assert_true(first.id is Some(@model.Nullable::Value(_)))
}
