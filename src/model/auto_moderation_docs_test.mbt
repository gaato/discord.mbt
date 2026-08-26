// Source: discord/discord-api-docs @ 845fcaa38e1653d19420311a8e42635eca8de7e5
// Documentation excerpts are attributed under CC-BY-SA 4.0.
// Page: developers/resources/auto-moderation.mdx
// Skipped blocks from this page: none.

///|
test "discord docs: example auto moderation rule (line 36)" {
  let fixture =
    #|{
    #|  "id": "969707018069872670",
    #|  "guild_id": "613425648685547541",
    #|  "name": "Keyword Filter 1",
    #|  "creator_id": "423457898095789043",
    #|  "trigger_type": 1,
    #|  "event_type": 1,
    #|  "actions": [
    #|    {
    #|      "type": 1,
    #|      "metadata": { "custom_message": "Please keep financial discussions limited to the #finance channel" }
    #|    },
    #|    {
    #|      "type": 2,
    #|      "metadata": { "channel_id": "123456789123456789" }
    #|    },
    #|    {
    #|      "type": 3,
    #|      "metadata": { "duration_seconds": 60 }
    #|    }
    #|  ],
    #|  "trigger_metadata": {
    #|    "keyword_filter": ["cat*", "*dog", "*ana*", "i like c++"],
    #|    "regex_patterns": ["(b|c)at", "^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$"]
    #|  },
    #|  "enabled": true,
    #|  "exempt_roles": ["323456789123456789", "423456789123456789"],
    #|  "exempt_channels": ["523456789123456789"]
    #|}
  let first : @model.AutoModerationRule = @json.from_json(@json.parse(fixture))
  let second : @model.AutoModerationRule = @json.from_json(first.to_json())
  assert_eq("\{Repr(first)}", "\{Repr(second)}")
  inspect(first.id.to_string(), content="969707018069872670")
  inspect(first.actions.length(), content="3")
}
