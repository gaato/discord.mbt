///|
/// Application commands (global + guild), command permissions, role
/// connections, and interaction-endpoint wiring probes.
async fn sec_commands(p : P) -> Unit {
  let c = p.client
  let g = p.guild_id
  let a = p.app_id
  let ar = c.application_ref(a)

  // Preserve whatever command sets already exist (kitchen_sink et al).
  let original_global = c.get_global_commands(a) catch { _ => [] }
  let original_guild = c.get_guild_commands(a, g) catch { _ => [] }

  // Global commands
  let mut global_cmd : @model.CommandId? = None
  p.probe("create_global_command", () => {
    let option = @model.CommandOption::{
      typ: String,
      name: "text",
      name_localizations: None,
      description: "some text",
      description_localizations: None,
      required: Some(true),
      choices: None,
      options: None,
      channel_types: None,
      min_value: None,
      max_value: None,
      min_length: None,
      max_length: None,
      autocomplete: None,
    }
    let cmd = c.create_global_command(
      a,
      "live-probe-global",
      description="created by live probe",
      options=[option],
      name_localizations={ "ja": "らいぶぷろーぶ" },
      description_localizations={ "ja": "ライブプローブ製" },
      integration_types=[GuildInstall],
      contexts=[Guild, BotDm],
    )
    global_cmd = Some(cmd.id)
    "id=\{cmd.id} contexts=\{cmd.contexts is Some(Value(_))}"
  })
  p.probe("create_global_command (USER type, no description)", () => {
    let cmd = c.create_global_command(a, "live-probe-user-cmd", typ=User)
    c.delete_global_command(a, cmd.id)
    "type=\{cmd.typ.map_or(-1, t => t.to_int())}"
  })
  guard global_cmd is Some(gc) else { return }
  p.probe("get_global_commands (+with_localizations)", () => {
    let cmds = c.get_global_commands(a)
    let localized = ar.global_commands(with_localizations=true)
    let has_localization = localized
      .iter()
      .any(cmd => cmd.name_localizations is Some(Value(_)))
    "count=\{cmds.length()} localized=\{has_localization}"
  })
  p.probe("edit_global_command (clear localizations)", () => {
    let cmd = c.edit_global_command(
      a,
      gc,
      clear_name_localizations=true,
      clear_description_localizations=true,
    )
    "name_loc=\{cmd.name_localizations is Some(Value(_))}"
  })
  p.probe("get_global_command + GlobalCommandRef::fetch", () => {
    let cmd = c.get_global_command(a, gc)
    ignore(c.global_command_ref(a, gc).fetch())
    "name=\{cmd.name}"
  })
  p.probe("edit_global_command + GlobalCommandRef::edit", () => {
    let edited = c.edit_global_command(a, gc, description="edited by probe")
    ignore(edited)
    let back = c
      .global_command_ref(a, gc)
      .edit(description="created by live probe")
    "desc=\{back.description}"
  })
  p.probe("delete_global_command", () => {
    c.delete_global_command(a, gc)
    "ok"
  })
  p.probe("bulk_overwrite_global_commands (restore original)", () => {
    let restored = c.bulk_overwrite_global_commands(
      a,
      original_global.map(cmd => cmd.to_json()).to_json(),
    )
    "count=\{restored.length()}"
  })

  // Guild commands
  let mut guild_cmd : @model.CommandId? = None
  p.probe("create_guild_command", () => {
    let cmd = c.create_guild_command(
      a,
      g,
      "live-probe-guild",
      description="guild command by live probe",
    )
    guild_cmd = Some(cmd.id)
    "id=\{cmd.id}"
  })
  guard guild_cmd is Some(gcm) else { return }
  p.probe("get_guild_commands + ApplicationRef::guild_commands", () => {
    let cmds = c.get_guild_commands(a, g)
    ignore(ar.guild_commands(g))
    "count=\{cmds.length()}"
  })
  p.probe("get_guild_command + GuildCommandRef::fetch", () => {
    let cmd = c.get_guild_command(a, g, gcm)
    ignore(c.guild_command_ref(a, g, gcm).fetch())
    "name=\{cmd.name}"
  })
  p.probe("edit_guild_command + GuildCommandRef::edit", () => {
    let edited = c.edit_guild_command(a, g, gcm, description="edited")
    ignore(edited)
    let back = c
      .guild_command_ref(a, g, gcm)
      .edit(description="guild command by live probe")
    "desc=\{back.description}"
  })
  p.probe("get_guild_application_command_permissions", () => {
    let perms = c.get_guild_application_command_permissions(a, g)
    "count=\{perms.length()}"
  })
  p.probe_err("get_application_command_permissions (none set)", expect=[404], () => {
    c.get_application_command_permissions(a, g, gcm) |> ignore
  })
  p.probe_err(
    "edit_application_command_permissions (bogus bearer)",
    expect=[401],
    () => {
      c.edit_application_command_permissions(
        a,
        g,
        gcm,
        [],
        bearer_token="bogus",
      )
      |> ignore
    },
  )
  p.probe_err("GuildCommandRef::permissions (none set)", expect=[404], () => {
    c.guild_command_ref(a, g, gcm).permissions() |> ignore
  })
  p.probe("delete_guild_command", () => {
    c.delete_guild_command(a, g, gcm)
    "ok"
  })
  p.probe("bulk_overwrite_guild_commands (restore original)", () => {
    let restored = c.bulk_overwrite_guild_commands(
      a,
      g,
      original_guild.map(cmd => cmd.to_json()).to_json(),
    )
    "count=\{restored.length()}"
  })

  // Role connection metadata (app-scoped, restored to its original value).
  let mut original_metadata : Array[@model.ApplicationRoleConnectionMetadata] = []
  p.probe("get_application_role_connection_metadata_records", () => {
    let records = c.get_application_role_connection_metadata_records(a)
    original_metadata = records
    "count=\{records.length()}"
  })
  p.probe("update_application_role_connection_metadata_records", () => {
    let record = @model.ApplicationRoleConnectionMetadata::{
      typ: IntegerGreaterThanOrEqual,
      key: "probe_score",
      name: "Probe Score",
      name_localizations: None,
      description: "live probe metadata",
      description_localizations: None,
    }
    let updated = c.update_application_role_connection_metadata_records(a, [
      record,
    ])
    let restored = c.update_application_role_connection_metadata_records(
      a, original_metadata,
    )
    "updated=\{updated.length()} restored=\{restored.length()}"
  })
  p.probe_err(
    "get_current_user_application_role_connection (bogus bearer)",
    expect=[401],
    () => {
      c.get_current_user_application_role_connection(a, bearer_token="bogus")
      |> ignore
    },
  )
  p.probe_err(
    "update_current_user_application_role_connection (bogus bearer)",
    expect=[401],
    () => {
      c.update_current_user_application_role_connection(
        a,
        platform_name="probe",
        bearer_token="bogus",
      )
      |> ignore
    },
  )
  p.probe_err(
    "delete_current_user_application_role_connection (bogus bearer)",
    expect=[401],
    () => {
      c.delete_current_user_application_role_connection(a, bearer_token="bogus")
    },
  )

  // Interaction endpoints need a live interaction token; bogus targets verify
  // wiring (they were exercised for real via kitchen_sink previously).
  p.probe_err("create_interaction_response (bogus)", expect=[404], () => {
    c.create_interaction_response(Id(1234567890123456789UL), "bogus-token", {
      typ: Pong,
      data: None,
    })
  })
  p.probe_err("get_original_response (bogus token)", expect=[404, 401], () => {
    c.get_original_response(a, "bogus-token") |> ignore
  })
  p.probe_err("edit_original_response (bogus token)", expect=[404, 401], () => {
    c.edit_original_response(a, "bogus-token", content="x") |> ignore
  })
  p.probe_err("delete_original_response (bogus token)", expect=[404, 401], () => {
    c.delete_original_response(a, "bogus-token")
  })
  p.probe_err("create_followup (bogus token)", expect=[404, 401], () => {
    c.create_followup(a, "bogus-token", content="x") |> ignore
  })
  p.probe_err("get_followup (bogus token)", expect=[404, 401], () => {
    c.get_followup(a, "bogus-token", Id(1234567890123456789UL)) |> ignore
  })
  p.probe_err("edit_followup (bogus token)", expect=[404, 401], () => {
    c.edit_followup(a, "bogus-token", Id(1234567890123456789UL), content="x")
    |> ignore
  })
  p.probe_err("delete_followup (bogus token)", expect=[404, 401], () => {
    c.delete_followup(a, "bogus-token", Id(1234567890123456789UL))
  })
  p.probe_err("get_application_activity_instance (bogus)", expect=[400, 404], () => {
    c.get_application_activity_instance(a, "i-bogus") |> ignore
  })
}

///|
/// Monetization + misc catalog endpoints. The test app has no SKUs, so list
/// endpoints assert empty success and item endpoints assert clean 404s.
async fn sec_monetization(p : P) -> Unit {
  let c = p.client
  let a = p.app_id
  let bogus_sku : @model.SkuId = Id(1234567890123456789UL)
  let bogus_ent : @model.EntitlementId = Id(1234567890123456789UL)
  let bogus_sub : @model.SubscriptionId = Id(1234567890123456789UL)
  p.probe("list_skus + ApplicationRef::skus", () => {
    let skus = c.list_skus(a)
    ignore(c.application_ref(a).skus())
    "count=\{skus.length()}"
  })
  p.probe("list_entitlements + ApplicationRef::entitlements", () => {
    let entitlements = c.list_entitlements(a, limit=10)
    ignore(c.application_ref(a).entitlements(limit=5))
    "count=\{entitlements.length()}"
  })
  p.probe_err("get_entitlement (bogus)", expect=[404], () => {
    c.get_entitlement(a, bogus_ent) |> ignore
  })
  p.probe_err("consume_entitlement (bogus)", expect=[404], () => {
    c.consume_entitlement(a, bogus_ent)
  })
  p.probe_err("create_test_entitlement (bogus sku)", expect=[400, 404], () => {
    c.create_test_entitlement(a, bogus_sku, Id(p.guild_id.value()), Guild)
    |> ignore
  })
  p.probe_err("delete_test_entitlement (bogus)", expect=[404], () => {
    c.delete_test_entitlement(a, bogus_ent)
  })
  p.probe_err("EntitlementRef::fetch (bogus)", expect=[404], () => {
    c.entitlement_ref(a, bogus_ent).fetch() |> ignore
  })
  p.probe_err("list_sku_subscriptions (bogus sku)", expect=[400, 404], () => {
    c.list_sku_subscriptions(bogus_sku, limit=5) |> ignore
  })
  p.probe_err("get_sku_subscription (bogus)", expect=[400, 404], () => {
    c.get_sku_subscription(bogus_sku, bogus_sub) |> ignore
  })
  p.probe_err("SkuRef::subscriptions (bogus)", expect=[400, 404], () => {
    c.sku_ref(bogus_sku).subscriptions(limit=5) |> ignore
  })
  // Invite target-users job endpoints (provisional invites feature).
  p.probe_err(
    "update_invite_target_users (bogus code)",
    expect=[400, 403, 404],
    () => {
      let file = @dhttp.FileUpload(
        "users.csv",
        b"user_id\n1\n",
        content_type="text/csv",
      )
      c.update_invite_target_users("boguscode", file)
    },
  )
  p.probe_err(
    "get_invite_target_users_job_status (bogus code)",
    expect=[400, 403, 404],
    () => c.get_invite_target_users_job_status("boguscode") |> ignore,
  )
  p.probe_err(
    "InviteRef::target_users_job_status (bogus)",
    expect=[400, 403, 404],
    () => c.invite_ref("boguscode").target_users_job_status() |> ignore,
  )
}
