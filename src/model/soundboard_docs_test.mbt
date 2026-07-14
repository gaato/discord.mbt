// Source: discord/discord-api-docs @ 845fcaa38e1653d19420311a8e42635eca8de7e5
// Documentation excerpts are attributed under CC-BY-SA 4.0.
// Page: developers/resources/soundboard.mdx
// Skipped blocks from this page: none.

///|
test "discord docs: example default soundboard sound (line 36)" {
  let fixture =
    #|{
    #|  "name": "quack",
    #|  "sound_id": "1",
    #|  "volume": 1.0,
    #|  "emoji_id": null,
    #|  "emoji_name": "🦆",
    #|  "available": true
    #|}
  let first : @model.SoundboardSound = @json.from_json(@json.parse(fixture))
  let second : @model.SoundboardSound = @json.from_json(first.to_json())
  assert_eq("\{to_repr(first)}", "\{to_repr(second)}")
  inspect(first.sound_id.to_string(), content="1")
  assert_eq(first.name, "quack")
}

///|
test "discord docs: example guild soundboard sound (line 50)" {
  let fixture =
    #|{
    #|  "name": "Yay",
    #|  "sound_id": "1106714396018884649",
    #|  "volume": 1,
    #|  "emoji_id": "989193655938064464",
    #|  "emoji_name": null,
    #|  "guild_id": "613425648685547541",
    #|  "available": true
    #|}
  let first : @model.SoundboardSound = @json.from_json(@json.parse(fixture))
  let second : @model.SoundboardSound = @json.from_json(first.to_json())
  assert_eq("\{to_repr(first)}", "\{to_repr(second)}")
  inspect(first.sound_id.to_string(), content="1106714396018884649")
  assert_eq(first.name, "Yay")
}
