// Source: discord/discord-api-docs @ 845fcaa38e1653d19420311a8e42635eca8de7e5
// Documentation excerpts are attributed under CC-BY-SA 4.0.
// Page: developers/resources/user.mdx
// Skipped blocks from this page:
// - line 283, Example Partial Guild — partial guild objects are not modeled.

///|
test "discord docs: example user (line 61)" {
  let fixture =
    #|{
    #|  "id": "80351110224678912",
    #|  "username": "Nelly",
    #|  "global_name": null,
    #|  "discriminator": "1337",
    #|  "avatar": "8342729096ea3675442027381ff50dfe",
    #|  "verified": true,
    #|  "email": "nelly@discord.com",
    #|  "flags": 64,
    #|  "banner": "06c16474723fe537c283b8efa61a30c8",
    #|  "accent_color": 16711680,
    #|  "premium_type": 0,
    #|  "public_flags": 64,
    #|  "avatar_decoration_data": {
    #|    "sku_id": "1144058844004233369",
    #|    "asset": "a_fed43ab12698df65902ba06727e20c0e"
    #|  },
    #|  "collectibles": {
    #|    "nameplate": {
    #|      "sku_id": "2247558840304243311",
    #|      "asset": "nameplates/nameplates/twilight/",
    #|      "label": "",
    #|      "palette": "cobalt"
    #|    }
    #|  },
    #|  "primary_guild": {
    #|    "identity_guild_id": "1234647491267808778",
    #|    "identity_enabled": true,
    #|    "tag": "DISC",
    #|    "badge": "7d1734ae5a615e82bc7a4033b98fade8"
    #|  }
    #|}
  let first : @model.User = @json.from_json(@json.parse(fixture))
  let second : @model.User = @json.from_json(first.to_json())
  assert_eq("\{to_repr(first)}", "\{to_repr(second)}")
  inspect(first.id.to_string(), content="80351110224678912")
  assert_eq(first.username, "Nelly")
}
