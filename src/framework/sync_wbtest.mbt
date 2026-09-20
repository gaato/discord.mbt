///|
fn sync_unchanged(
  declared : Array[@interaction.CommandSpec],
  fetched : Array[Json],
) -> Bool {
  !plan_command_sync(declared, fetched, unowned=Delete).1.overwritten
}

///|
fn sync_fetched_command(fixture : String) -> Json raise {
  @json.parse(fixture)
}

///|
test "localized command specs compare localization dictionaries" {
  let declared = @interaction.CommandSpec::slash(
    "ping",
    "Check latency",
    name_localizations={ "ja": "ピング" },
    description_localizations={ "ja": "レイテンシを確認" },
  )
  let matching = sync_fetched_command(
    (
      #|{"id":"900000000000000001","application_id":"400000000000000001","type":1,"name":"ping","name_localizations":{"ja":"ピング"},"description":"Check latency","description_localizations":{"ja":"レイテンシを確認"},"default_member_permissions":null,"version":"900000000000000002"}
    ),
  )
  let missing = sync_fetched_command(
    (
      #|{"id":"900000000000000001","application_id":"400000000000000001","type":1,"name":"ping","description":"Check latency","default_member_permissions":null,"version":"900000000000000002"}
    ),
  )
  let different = sync_fetched_command(
    (
      #|{"id":"900000000000000001","application_id":"400000000000000001","type":1,"name":"ping","name_localizations":{"ja":"ピン"},"description":"Check latency","description_localizations":{"ja":"レイテンシを確認"},"default_member_permissions":null,"version":"900000000000000002"}
    ),
  )
  debug_inspect(
    [
      sync_unchanged([declared], [matching]),
      sync_unchanged([declared], [missing]),
      sync_unchanged([declared], [different]),
    ],
    content="[true, false, false]",
  )
}

///|
test "non-localized specs accept null localization echoes" {
  let declared = @interaction.CommandSpec::slash("ping", "Check latency")
  let fetched = sync_fetched_command(
    (
      #|{"id":"900000000000000001","application_id":"400000000000000001","type":1,"name":"ping","name_localizations":null,"description":"Check latency","description_localizations":null,"default_member_permissions":null,"version":"900000000000000002"}
    ),
  )
  assert_true(sync_unchanged([declared], [fetched]))
}

///|
test "set-valued command fields match in any order" {
  let declared = @interaction.CommandSpec::slash("upload", "Upload", options=[
    @interaction.attachment_option("file", "File", file_types=[
      Image,
      Extension(".pdf"),
    ]),
    @interaction.channel_option("where", "Where", channel_types=[
      GuildText,
      GuildForum,
    ]),
  ])
  // Discord echoed `file_types` reordered in a live run (2026-09-20).
  let reordered = sync_fetched_command(
    (
      #|{"id":"900000000000000001","application_id":"400000000000000001","type":1,"name":"upload","description":"Upload","options":[{"type":11,"name":"file","description":"File","file_types":[".pdf","image"]},{"type":7,"name":"where","description":"Where","channel_types":[15,0]}],"default_member_permissions":null,"version":"900000000000000002"}
    ),
  )
  assert_true(sync_unchanged([declared], [reordered]))
  let different = sync_fetched_command(
    (
      #|{"id":"900000000000000001","application_id":"400000000000000001","type":1,"name":"upload","description":"Upload","options":[{"type":11,"name":"file","description":"File","file_types":[".pdf","video"]},{"type":7,"name":"where","description":"Where","channel_types":[15,0]}],"default_member_permissions":null,"version":"900000000000000002"}
    ),
  )
  assert_false(sync_unchanged([declared], [different]))
  // Option order is user-visible and still compared in order.
  let swapped_options = sync_fetched_command(
    (
      #|{"id":"900000000000000001","application_id":"400000000000000001","type":1,"name":"upload","description":"Upload","options":[{"type":7,"name":"where","description":"Where","channel_types":[0,15]},{"type":11,"name":"file","description":"File","file_types":["image",".pdf"]}],"default_member_permissions":null,"version":"900000000000000002"}
    ),
  )
  assert_false(sync_unchanged([declared], [swapped_options]))
}

///|
fn fetched_command(fixture : String) -> Json raise {
  @json.parse(fixture)
}

///|
fn fetched_ping(
  name? : String = "ping",
  description? : String = "Check latency",
) -> Json raise {
  fetched_command(
    (
      #|{
      #|  "id": "900000000000000001",
      #|  "application_id": "400000000000000001",
      #|  "type": 1,
      #|  "name": "NAME_PLACEHOLDER",
      #|  "description": "DESCRIPTION_PLACEHOLDER",
      #|  "default_member_permissions": null,
      #|  "version": "900000000000000002",
      #|  "dm_permission": true
      #|}
    )
    .replace(old="NAME_PLACEHOLDER", new=name)
    .replace(old="DESCRIPTION_PLACEHOLDER", new=description),
  )
}

///|
test "sync_unchanged compares declarations and ignores server fields" {
  let ping = @interaction.CommandSpec::slash("ping", "Check latency")
  let echo_arg = @interaction.arg_string(
    name="text",
    description="Text to echo",
  )
  let echo = @interaction.CommandSpec::slash(
    "echo",
    "Echo text",
    options=@interaction.Args::of(echo_arg).definitions(),
  )
  let echo_matching = fetched_command(
    (
      #|{
      #|  "id": "900000000000000003",
      #|  "application_id": "400000000000000001",
      #|  "type": 1,
      #|  "name": "echo",
      #|  "description": "Echo text",
      #|  "options": [
      #|    {
      #|      "type": 3,
      #|      "name": "text",
      #|      "description": "Text to echo",
      #|      "required": true
      #|    }
      #|  ],
      #|  "default_member_permissions": null,
      #|  "version": "900000000000000004"
      #|}
    ),
  )
  let echo_wrong_required = fetched_command(
    (
      #|{
      #|  "id": "900000000000000003",
      #|  "application_id": "400000000000000001",
      #|  "type": 1,
      #|  "name": "echo",
      #|  "description": "Echo text",
      #|  "options": [
      #|    {
      #|      "type": 3,
      #|      "name": "text",
      #|      "description": "Text to echo",
      #|      "required": false
      #|    }
      #|  ],
      #|  "default_member_permissions": null,
      #|  "version": "900000000000000004"
      #|}
    ),
  )
  let ping_with_option = fetched_command(
    (
      #|{
      #|  "id": "900000000000000001",
      #|  "application_id": "400000000000000001",
      #|  "type": 1,
      #|  "name": "ping",
      #|  "description": "Check latency",
      #|  "options": [
      #|    {"type":3,"name":"extra","description":"Extra","required":false}
      #|  ],
      #|  "default_member_permissions": null,
      #|  "version": "900000000000000002"
      #|}
    ),
  )
  debug_inspect(
    [
      sync_unchanged([ping], [fetched_ping()]),
      sync_unchanged([ping], [fetched_ping(description="Changed")]),
      sync_unchanged([ping], [ping_with_option]),
      sync_unchanged([echo], [echo_wrong_required]),
      sync_unchanged([ping], [fetched_ping(name="other")]),
      sync_unchanged([echo], [echo_matching]),
    ],
    content="[true, false, false, false, false, true]",
  )
}

///|
test "sync_unchanged normalizes command defaults and uses type plus name" {
  let slash = @interaction.CommandSpec::slash("inspect", "Inspect a target")
  assert_false(slash.to_json().stringify().contains("\"type\""))
  let response = fetched_command(
    (
      #|{
      #|  "id": "900000000000000010",
      #|  "application_id": "400000000000000001",
      #|  "type": 1,
      #|  "name": "inspect",
      #|  "description": "Inspect a target",
      #|  "default_member_permissions": null,
      #|  "dm_permission": true,
      #|  "nsfw": false,
      #|  "integration_types": [0],
      #|  "contexts": null,
      #|  "version": "900000000000000011"
      #|}
    ),
  )
  let wrong_nsfw = fetched_command(
    response.stringify().replace(old="\"nsfw\":false", new="\"nsfw\":true"),
  )
  let wrong_integration = fetched_command(
    response
    .stringify()
    .replace(old="\"integration_types\":[0]", new="\"integration_types\":[1]"),
  )
  let wrong_contexts = fetched_command(
    response
    .stringify()
    .replace(old="\"contexts\":null", new="\"contexts\":[0]"),
  )
  let wrong_dm_permission = fetched_command(
    response
    .stringify()
    .replace(old="\"dm_permission\":true", new="\"dm_permission\":false"),
  )
  let wrong_permissions = fetched_command(
    response
    .stringify()
    .replace(
      old="\"default_member_permissions\":null",
      new="\"default_member_permissions\":\"8\"",
    ),
  )
  let wrong_type = fetched_command(
    response.stringify().replace(old="\"type\":1", new="\"type\":2"),
  )
  debug_inspect(
    [
      sync_unchanged([slash], [response]),
      sync_unchanged([slash], [wrong_nsfw]),
      sync_unchanged([slash], [wrong_integration]),
      sync_unchanged([slash], [wrong_contexts]),
      sync_unchanged([slash], [wrong_dm_permission]),
      sync_unchanged([slash], [wrong_permissions]),
      sync_unchanged([slash], [wrong_type]),
    ],
    content="[true, false, false, false, false, false, false]",
  )
  let explicit_defaults = @interaction.CommandSpec::slash(
    "inspect",
    "Inspect a target",
    nsfw=false,
    integration_types=[GuildInstall],
  )
  let omitted_defaults = fetched_command(
    (
      #|{
      #|  "id": "900000000000000014",
      #|  "application_id": "400000000000000001",
      #|  "name": "inspect",
      #|  "description": "Inspect a target",
      #|  "default_member_permissions": null,
      #|  "version": "900000000000000015"
      #|}
    ),
  )
  assert_true(sync_unchanged([explicit_defaults], [omitted_defaults]))
  let user = @interaction.CommandSpec::user("inspect")
  let user_response = fetched_command(
    (
      #|{
      #|  "id": "900000000000000012",
      #|  "application_id": "400000000000000001",
      #|  "type": 2,
      #|  "name": "inspect",
      #|  "description": "",
      #|  "default_member_permissions": null,
      #|  "dm_permission": true,
      #|  "nsfw": false,
      #|  "integration_types": [0],
      #|  "contexts": null,
      #|  "version": "900000000000000013"
      #|}
    ),
  )
  assert_true(sync_unchanged([slash, user], [response, user_response]))
}
