// Source: discord/discord-api-docs @ 845fcaa38e1653d19420311a8e42635eca8de7e5
// Documentation excerpts are attributed under CC-BY-SA 4.0.
// Pages: developers/resources/{audit-log,message,guild,invite}.mdx,
// developers/interactions/{application-commands,receiving-and-responding}.mdx,
// and developers/events/gateway-events.mdx.

///|
test "discord docs: partial audit-log integration (line 37)" {
  let fixture =
    #|{
    #|  "id": "33590653072239123",
    #|  "name": "A Name",
    #|  "type": "twitch",
    #|  "account": {"name": "twitchusername", "id": "1234567"},
    #|  "application_id": "94651234501213162"
    #|}
  let value : @model.Integration = @json.from_json(@json.parse(fixture))
  inspect(value.id.unwrap().to_string(), content="33590653072239123")
  assert_eq(value.account.unwrap().name, "twitchusername")
}

///|
test "discord docs: attachment placeholder and Clips fields" {
  let fixture =
    #|{
    #|  "id":"110000000000000001","filename":"clip.mp4","size":42,
    #|  "url":"https://cdn.discordapp.com/clip.mp4",
    #|  "proxy_url":"https://media.discordapp.net/clip.mp4",
    #|  "placeholder":"AQAFAAoPEA==","placeholder_version":1,
    #|  "clip_created_at":"2026-07-01T00:00:00Z",
    #|  "clip_participants":[{
    #|    "id":"120000000000000001","username":"Nelly",
    #|    "discriminator":"0","avatar":null
    #|  }],
    #|  "application":null
    #|}
  let value : @model.Attachment = @json.from_json(@json.parse(fixture))
  assert_eq(value.placeholder.unwrap(), "AQAFAAoPEA==")
  assert_true(value.placeholder_version == Some(1))
  inspect(
    value.clip_participants.unwrap()[0].id.to_string(),
    content="120000000000000001",
  )
}

///|
test "discord docs: entry-point command handler and localized response fields" {
  let fixture =
    #|{
    #|  "id":"107000000000000001","type":4,
    #|  "application_id":"172150183260323840","name":"launch",
    #|  "name_localizations":{"zh-CN":"启动"},"name_localized":"启动",
    #|  "description":"","description_localizations":null,
    #|  "description_localized":"","default_member_permissions":null,
    #|  "version":"107000000000000002","handler":2
    #|}
  let value : @model.ApplicationCommand = @json.from_json(@json.parse(fixture))
  assert_true(
    value.handler ==
    Some(@model.EntryPointCommandHandlerType::DiscordLaunchActivity),
  )
  assert_true(value.name_localized == Some("启动"))
}

///|
test "discord docs: invite application, event, roles, and flags" {
  let fixture =
    #|{
    #|  "type":0,"code":"event-code","flags":1,
    #|  "target_application":{
    #|    "id":"172150183260323840","name":"Activity","icon":null,
    #|    "description":"Embedded activity"
    #|  },
    #|  "roles":[{
    #|    "id":"130000000000000001","name":"guest","position":1,
    #|    "color":0,"colors":{"primary_color":0,"secondary_color":null,
    #|    "tertiary_color":null},"icon":null,"unicode_emoji":null
    #|  }],
    #|  "guild_scheduled_event":{
    #|    "id":"140000000000000001","guild_id":"150000000000000001",
    #|    "channel_id":null,"name":"Town hall","description":null,
    #|    "scheduled_start_time":"2026-08-01T00:00:00Z",
    #|    "scheduled_end_time":"2026-08-01T01:00:00Z",
    #|    "privacy_level":2,"status":1,"entity_type":3,"entity_id":null,
    #|    "entity_metadata":{"location":"Online"},"recurrence_rule":null
    #|  }
    #|}
  let value : @model.Invite = @json.from_json(@json.parse(fixture))
  assert_true(value.flags.unwrap().bits() == 1UL)
  assert_eq(value.target_application.unwrap().name, "Activity")
  assert_eq(value.roles.unwrap()[0].name, "guest")
}

///|
test "discord docs: incidents data example (line 739)" {
  let fixture =
    #|{
    #|  "invites_disabled_until":"2023-09-01T14:48:02.222000+00:00",
    #|  "dms_disabled_until":null
    #|}
  let value : @model.IncidentsData = @json.from_json(@json.parse(fixture))
  assert_true(value.invites_disabled_until is Some(@model.Nullable::Value(_)))
  assert_true(value.dms_disabled_until == Some(@model.Nullable::Null))
}

///|
test "discord docs: rich presence activity example (line 1436)" {
  // The docs example omits required created_at; add it without changing the
  // documented rich-presence fields under test.
  let fixture =
    #|{
    #|  "name":"Rocket League","type":0,"created_at":15112000660000,
    #|  "application_id":"379286085710381999","state":"In a Match",
    #|  "details":"Ranked Duos: 2-1","timestamps":{"start":15112000660000},
    #|  "party":{"id":"9dd6594e-81b3-49f6-a6b5-a679e6a060d3","size":[2,2]},
    #|  "assets":{"large_image":"351371005538729000","large_text":"DFH Stadium",
    #|    "small_image":"351371005538729111","small_text":"Silver III"},
    #|  "secrets":{"join":"join-secret","spectate":"spectate-secret",
    #|    "match":"match-secret"},"flags":3,
    #|  "buttons":[{"label":"Join","url":"https://example.com/join"}]
    #|}
  let value : @model.Activity = @json.from_json(@json.parse(fixture))
  assert_true(value.party.unwrap().size.unwrap() == [2, 2])
  assert_eq(value.secrets.unwrap().match_.unwrap(), "match-secret")
  assert_true(value.flags.unwrap().bits() == 3UL)
}

///|
test "discord docs: interaction guild and authorization metadata" {
  let fixture =
    #|{
    #|  "id":"108000000000000001","application_id":"172150183260323840",
    #|  "type":1,"guild":{"id":"150000000000000001","name":"Guild"},
    #|  "guild_id":"150000000000000001","token":"token","version":1,
    #|  "authorizing_integration_owners":{"0":"150000000000000001"},
    #|  "attachment_size_limit":10485760
    #|}
  let value : @model.Interaction = @json.from_json(@json.parse(fixture))
  assert_eq(value.guild.unwrap().name.unwrap(), "Guild")
  assert_true(value.attachment_size_limit == Some(10485760))
}

///|
test "discord docs: message interaction metadata and forwarded snapshot" {
  let metadata_fixture =
    #|{
    #|  "id":"108000000000000002","type":2,
    #|  "user":{"id":"120000000000000001","username":"Nelly",
    #|    "discriminator":"0","avatar":null},
    #|  "authorizing_integration_owners":{"0":"150000000000000001"},
    #|  "target_user":{"id":"120000000000000002","username":"Ada",
    #|    "discriminator":"0","avatar":null}
    #|}
  let metadata : @model.MessageInteractionMetadata = @json.from_json(
    @json.parse(metadata_fixture),
  )
  assert_eq(metadata.target_user.unwrap().username, "Ada")
  let snapshot_fixture =
    #|{"message":{"type":0,"content":"forwarded","embeds":[],
    #|"attachments":[],"timestamp":"2026-07-01T00:00:00Z","flags":0,
    #|"mentions":[],"mention_roles":[],"sticker_items":[],"components":[]}}
  let snapshot : @model.MessageSnapshot = @json.from_json(
    @json.parse(snapshot_fixture),
  )
  assert_true(snapshot.message.content == Some("forwarded"))
}

///|
test "discord docs: shared client theme example (line 882)" {
  let fixture =
    #|{"colors":["5865F2","7258F2","9858F2","BE58F2","E558F2"],
    #|"gradient_angle":0,"base_mix":58,"base_theme":1}
  let value : @model.SharedClientTheme = @json.from_json(@json.parse(fixture))
  assert_true(
    value.base_theme == Some(@model.Nullable::Value(@model.BaseTheme::Dark)),
  )
  inspect(value.colors.length(), content="5")
}

///|
test "discord docs: embed flags" {
  let fixture =
    #|{"flags":32}
  let value : @model.Embed = @json.from_json(@json.parse(fixture))
  assert_true(
    value.flags.unwrap().bits() ==
    @model.EmbedFlags::is_content_inventory_entry().bits(),
  )
}
