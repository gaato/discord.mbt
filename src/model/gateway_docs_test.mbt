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
