// Source: discord/discord-api-docs @ 845fcaa38e1653d19420311a8e42635eca8de7e5
// Documentation excerpts are attributed under CC-BY-SA 4.0.
// Page: developers/resources/webhook.mdx
// Skipped blocks from this page: none.

///|
test "discord docs: example incoming webhook (line 55)" {
  let fixture =
    #|{
    #|  "name": "test webhook",
    #|  "type": 1,
    #|  "channel_id": "199737254929760256",
    #|  "token": "3d89bb7572e0fb30d8128367b3b1b44fecd1726de135cbe28a41f8b2f777c372ba2939e72279b94526ff5d1bd4358d65cf11",
    #|  "avatar": null,
    #|  "guild_id": "199737254929760256",
    #|  "id": "223704706495545344",
    #|  "application_id": null,
    #|  "user": {
    #|    "username": "test",
    #|    "discriminator": "7479",
    #|    "id": "190320984123768832",
    #|    "avatar": "b004ec1740a63ca06ae2e14c5cee11f3",
    #|    "public_flags": 131328
    #|  }
    #|}
  let first : @model.Webhook = @json.from_json(@json.parse(fixture))
  let second : @model.Webhook = @json.from_json(first.to_json())
  assert_eq("\{to_repr(first)}", "\{to_repr(second)}")
  inspect(first.id.to_string(), content="223704706495545344")
  inspect(first.typ.to_int(), content="1")
}

///|
test "discord docs: example channel follower webhook (line 78)" {
  let fixture =
    #|{
    #|  "type": 2,
    #|  "id": "752831914402115456",
    #|  "name": "Guildy name",
    #|  "avatar": "bb71f469c158984e265093a81b3397fb",
    #|  "channel_id": "561885260615255432",
    #|  "guild_id": "56188498421443265",
    #|  "application_id": null,
    #|  "source_guild": {
    #|    "id": "56188498421476534",
    #|    "name": "Guildy name",
    #|    "icon": "bb71f469c158984e265093a81b3397fb"
    #|  },
    #|  "source_channel": {
    #|    "id": "5618852344134324",
    #|    "name": "announcements"
    #|  },
    #|  "user": {
    #|    "username": "test",
    #|    "discriminator": "7479",
    #|    "id": "190320984123768832",
    #|    "avatar": "b004ec1740a63ca06ae2e14c5cee11f3",
    #|    "public_flags": 131328
    #|  }
    #|}
  let first : @model.Webhook = @json.from_json(@json.parse(fixture))
  let second : @model.Webhook = @json.from_json(first.to_json())
  assert_eq("\{to_repr(first)}", "\{to_repr(second)}")
  inspect(first.id.to_string(), content="752831914402115456")
  inspect(first.typ.to_int(), content="2")
}

///|
test "discord docs: example application webhook (line 109)" {
  let fixture =
    #|{
    #|  "type": 3,
    #|  "id": "658822586720976555",
    #|  "name": "Clyde",
    #|  "avatar": "689161dc90ac261d00f1608694ac6bfd",
    #|  "channel_id": null,
    #|  "guild_id": null,
    #|  "application_id": "658822586720976555"
    #|}
  let first : @model.Webhook = @json.from_json(@json.parse(fixture))
  let second : @model.Webhook = @json.from_json(first.to_json())
  assert_eq("\{to_repr(first)}", "\{to_repr(second)}")
  inspect(first.id.to_string(), content="658822586720976555")
  inspect(first.typ.to_int(), content="3")
}
