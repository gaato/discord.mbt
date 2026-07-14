// Source: discord/discord-api-docs @ 845fcaa38e1653d19420311a8e42635eca8de7e5
// Documentation excerpts are attributed under CC-BY-SA 4.0.
// Page: developers/resources/guild.mdx
// Skipped blocks from this page: none.
// Page: developers/resources/invite.mdx
// Skipped blocks from this page:
// - line 121, Example Invite Metadata — invite metadata is only a fragment and omits the invite code.
// - line 150, Example Invite Stage Instance — invite stage instances are not modeled.
// - line 211, Example Error Response — error response rather than an invite object.
// - line 228, Example Response — bulk invite-processing responses are not modeled.

///|
test "discord docs: example partial invite object (line 1407)" {
  let fixture =
    #|{
    #|  "code": "abc",
    #|  "uses": 12
    #|}
  let first : @model.Invite = @json.from_json(@json.parse(fixture))
  let second : @model.Invite = @json.from_json(first.to_json())
  assert_eq("\{to_repr(first)}", "\{to_repr(second)}")
  assert_eq(first.code, "abc")
  assert_true(first.uses == Some(12))
}

///|
test "discord docs: example invite object (line 63)" {
  let fixture =
    #|{
    #|  "type": 0,
    #|  "code": "0vCdhLbwjZZTWZLD",
    #|  "guild": {
    #|    "id": "165176875973476352",
    #|    "name": "CS:GO Fraggers Only",
    #|    "splash": null,
    #|    "banner": null,
    #|    "description": "Very good description",
    #|    "icon": null,
    #|    "features": ["NEWS", "DISCOVERABLE"],
    #|    "verification_level": 2,
    #|    "vanity_url_code": null,
    #|    "nsfw_level": 0,
    #|    "premium_subscription_count": 5
    #|  },
    #|  "channel": {
    #|    "id": "165176875973476352",
    #|    "name": "illuminati",
    #|    "type": 0
    #|  },
    #|  "inviter": {
    #|    "id": "115590097100865541",
    #|    "username": "speed",
    #|    "avatar": "deadbeef",
    #|    "discriminator": "7653",
    #|    "public_flags": 131328
    #|  },
    #|  "target_type": 1,
    #|  "target_user": {
    #|    "id": "165176875973476352",
    #|    "username": "bob",
    #|    "avatar": "deadbeef",
    #|    "discriminator": "1234",
    #|    "public_flags": 64
    #|  }
    #|}
  let first : @model.Invite = @json.from_json(@json.parse(fixture))
  let second : @model.Invite = @json.from_json(first.to_json())
  assert_eq("\{to_repr(first)}", "\{to_repr(second)}")
  assert_eq(first.code, "0vCdhLbwjZZTWZLD")
  assert_true(first.typ == Some(@model.InviteType::Guild))
  assert_eq(first.guild.unwrap().name.unwrap(), "CS:GO Fraggers Only")
}
