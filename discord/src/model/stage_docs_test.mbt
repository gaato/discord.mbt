// Source: discord/discord-api-docs @ 845fcaa38e1653d19420311a8e42635eca8de7e5
// Documentation excerpts are attributed under CC-BY-SA 4.0.
// Page: developers/resources/stage-instance.mdx
// Skipped blocks from this page: none.

///|
test "discord docs: example stage instance (line 39)" {
  let fixture =
    #|{
    #|  "id": "840647391636226060",
    #|  "guild_id": "197038439483310086",
    #|  "channel_id": "733488538393510049",
    #|  "topic": "Testing Testing, 123",
    #|  "privacy_level": 1,
    #|  "discoverable_disabled": false,
    #|  "guild_scheduled_event_id": "947656305244532806"
    #|}
  let first : @model.StageInstance = @json.from_json(@json.parse(fixture))
  let second : @model.StageInstance = @json.from_json(first.to_json())
  assert_eq("\{Repr(first)}", "\{Repr(second)}")
  inspect(first.id.to_string(), content="840647391636226060")
  inspect(first.privacy_level.to_int(), content="1")
}
