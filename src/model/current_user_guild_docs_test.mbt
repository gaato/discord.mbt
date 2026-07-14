///|
test "current user guild docs fixture" {
  let fixture =
    #|{
    #|  "id": "80351110224678912",
    #|  "name": "Discord Developers",
    #|  "icon": "abc123",
    #|  "banner": null,
    #|  "owner": true,
    #|  "permissions": "104324673",
    #|  "features": ["COMMUNITY", "FUTURE_FEATURE"],
    #|  "approximate_member_count": 42,
    #|  "approximate_presence_count": 7
    #|}
  let guild : @model.CurrentUserGuild = @json.from_json(@json.parse(fixture))
  inspect(guild.id.to_string(), content="80351110224678912")
  inspect(guild.name, content="Discord Developers")
  assert_true(guild.owner)
  inspect(guild.permissions.bits().to_string(), content="104324673")
  inspect(guild.approximate_member_count.unwrap(), content="42")
}
