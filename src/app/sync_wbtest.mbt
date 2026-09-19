///|
fn sync_fetched_command(fixture : String) -> @model.ApplicationCommand raise {
  @json.from_json(@json.parse(fixture))
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
      commands_in_sync([declared], [matching]),
      commands_in_sync([declared], [missing]),
      commands_in_sync([declared], [different]),
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
  assert_true(commands_in_sync([declared], [fetched]))
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
  assert_true(commands_in_sync([declared], [reordered]))
  let different = sync_fetched_command(
    (
      #|{"id":"900000000000000001","application_id":"400000000000000001","type":1,"name":"upload","description":"Upload","options":[{"type":11,"name":"file","description":"File","file_types":[".pdf","video"]},{"type":7,"name":"where","description":"Where","channel_types":[15,0]}],"default_member_permissions":null,"version":"900000000000000002"}
    ),
  )
  assert_false(commands_in_sync([declared], [different]))
  // Option order is user-visible and still compared in order.
  let swapped_options = sync_fetched_command(
    (
      #|{"id":"900000000000000001","application_id":"400000000000000001","type":1,"name":"upload","description":"Upload","options":[{"type":7,"name":"where","description":"Where","channel_types":[0,15]},{"type":11,"name":"file","description":"File","file_types":["image",".pdf"]}],"default_member_permissions":null,"version":"900000000000000002"}
    ),
  )
  assert_false(commands_in_sync([declared], [swapped_options]))
}
