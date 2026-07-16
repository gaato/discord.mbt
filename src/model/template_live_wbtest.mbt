///|
/// Live-API shapes observed 2026-07-16: role permissions inside
/// serialized_source_guild arrive as a decimal string, and colors is null.
test "template snapshot role decodes live wire shape" {
  let raw =
    #|{
    #|  "id": 0,
    #|  "name": "@everyone",
    #|  "permissions": "2248473465835073",
    #|  "color": 0,
    #|  "colors": null,
    #|  "hoist": false,
    #|  "mentionable": false,
    #|  "icon": null,
    #|  "unicode_emoji": null
    #|}
  let json = @json.parse(raw)
  let role : GuildTemplateRole = @json.from_json(json)
  inspect(role.permissions.bits(), content="2248473465835073")
  assert_true(role.colors is Some(Null))
}
