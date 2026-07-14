// Source: discord/discord-api-docs @ 845fcaa38e1653d19420311a8e42635eca8de7e5
// Documentation excerpts are attributed under CC-BY-SA 4.0.
// Page: developers/resources/voice.mdx
// Skipped blocks from this page: none.

///|
test "discord docs: example voice state (line 37)" {
  let fixture =
    #|{
    #|  "channel_id": "157733188964188161",
    #|  "user_id": "80351110224678912",
    #|  "session_id": "90326bd25d71d39b9ef95b299e3872ff",
    #|  "deaf": false,
    #|  "mute": false,
    #|  "self_deaf": false,
    #|  "self_mute": true,
    #|  "suppress": false,
    #|  "request_to_speak_timestamp": "2021-03-31T18:45:31.297561+00:00"
    #|}
  let first : @model.VoiceState = @json.from_json(@json.parse(fixture))
  let second : @model.VoiceState = @json.from_json(first.to_json())
  assert_eq("\{to_repr(first)}", "\{to_repr(second)}")
  inspect(first.user_id.to_string(), content="80351110224678912")
  assert_true(first.self_mute)
}
