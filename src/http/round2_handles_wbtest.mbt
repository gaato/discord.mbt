///|
async fn expect_round2_deserialize(call : async () -> Unit) -> Unit {
  try call() catch {
    Deserialize(_) => ()
    error => fail("unexpected fake-response error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the null fake response to fail decoding")
  }
}

///|
async test "application handles delegate remaining fetch and mutation methods" {
  let client = Client("test-token")
  defer client.close()
  let calls : Array[String] = []
  client.perform_override_.val = Some((route, path, _headers, _body, _files) => {
    calls.push("\{@debug.to_string(route.method_())} \{path}")
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let application_id : @model.ApplicationId = Id(100UL)
  let guild_id : @model.GuildId = Id(101UL)
  let emoji_id : @model.EmojiId = Id(102UL)
  let command_id : @model.CommandId = Id(103UL)
  let entitlement_id : @model.EntitlementId = Id(104UL)
  let sku_id : @model.SkuId = Id(105UL)
  let subscription_id : @model.SubscriptionId = Id(106UL)
  let app = client.application_ref(application_id)
  expect_round2_deserialize(() => app.activity_instance("instance-a") |> ignore)
  expect_round2_deserialize(() => app.role_connection_metadata() |> ignore)
  expect_round2_deserialize(() => {
    app.update_role_connection_metadata([]) |> ignore
  })
  expect_round2_deserialize(() => app.emojis() |> ignore)
  expect_round2_deserialize(() => {
    app.create_emoji("wave", "data:image/png;base64,AAAA") |> ignore
  })
  expect_round2_deserialize(() => {
    app.global_commands(with_localizations=true) |> ignore
  })
  expect_round2_deserialize(() => {
    app.bulk_overwrite_global_commands([]) |> ignore
  })
  expect_round2_deserialize(() => {
    app.create_guild_command(guild_id, "ping", description="Ping") |> ignore
  })
  expect_round2_deserialize(() => {
    app.bulk_overwrite_guild_commands(guild_id, []) |> ignore
  })
  expect_round2_deserialize(() => {
    app.guild_command_permissions(guild_id) |> ignore
  })
  expect_round2_deserialize(() => app.entitlements(limit=1) |> ignore)
  expect_round2_deserialize(() => app.skus() |> ignore)
  let app_emoji = app.emoji_ref(emoji_id)
  expect_round2_deserialize(() => app_emoji.fetch() |> ignore)
  expect_round2_deserialize(() => app_emoji.edit("renamed") |> ignore)
  let global_command = app.global_command_ref(command_id)
  expect_round2_deserialize(() => global_command.fetch() |> ignore)
  expect_round2_deserialize(() => {
    global_command.edit(name="renamed", description="Updated") |> ignore
  })
  let guild_command = app.guild_command_ref(guild_id, command_id)
  expect_round2_deserialize(() => guild_command.fetch() |> ignore)
  expect_round2_deserialize(() => {
    guild_command.edit(name="renamed", description="Updated") |> ignore
  })
  expect_round2_deserialize(() => guild_command.permissions() |> ignore)
  expect_round2_deserialize(() => {
    app.entitlement_ref(entitlement_id).fetch() |> ignore
  })
  expect_round2_deserialize(() => {
    app.sku_ref(sku_id).subscription(subscription_id) |> ignore
  })
  assert_eq(calls, [
    "Get /api/v10/applications/100/activity-instances/instance-a", "Get /api/v10/applications/100/role-connections/metadata",
    "Put /api/v10/applications/100/role-connections/metadata", "Get /api/v10/applications/100/emojis",
    "Post /api/v10/applications/100/emojis", "Get /api/v10/applications/100/commands?with_localizations=true",
    "Put /api/v10/applications/100/commands", "Post /api/v10/applications/100/guilds/101/commands",
    "Put /api/v10/applications/100/guilds/101/commands", "Get /api/v10/applications/100/guilds/101/commands/permissions",
    "Get /api/v10/applications/100/entitlements?limit=1", "Get /api/v10/applications/100/skus",
    "Get /api/v10/applications/100/emojis/102", "Patch /api/v10/applications/100/emojis/102",
    "Get /api/v10/applications/100/commands/103", "Patch /api/v10/applications/100/commands/103",
    "Get /api/v10/applications/100/guilds/101/commands/103", "Patch /api/v10/applications/100/guilds/101/commands/103",
    "Get /api/v10/applications/100/guilds/101/commands/103/permissions", "Get /api/v10/applications/100/entitlements/104",
    "Get /api/v10/skus/105/subscriptions/106",
  ])
}

///|
async test "guild asset handles delegate remaining collections and item methods" {
  let client = Client("test-token")
  defer client.close()
  let calls : Array[String] = []
  client.perform_override_.val = Some((route, path, _headers, _body, _files) => {
    calls.push("\{@debug.to_string(route.method_())} \{path}")
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let guild_id : @model.GuildId = Id(200UL)
  let emoji_id : @model.EmojiId = Id(201UL)
  let sticker_id : @model.StickerId = Id(202UL)
  let sound_id : @model.SoundboardSoundId = Id(203UL)
  let event_id : @model.ScheduledEventId = Id(204UL)
  let rule_id : @model.AutoModerationRuleId = Id(205UL)
  let guild = client.guild_ref(guild_id)
  expect_round2_deserialize(() => guild.emojis() |> ignore)
  expect_round2_deserialize(() => {
    guild.create_emoji("wave", "data:image/png;base64,AAAA") |> ignore
  })
  expect_round2_deserialize(() => guild.stickers() |> ignore)
  expect_round2_deserialize(() => {
    guild.create_sticker(
      FileUpload("wave.png", b"PNG", content_type="image/png"),
      "wave",
      "friendly wave",
      "wave",
    )
    |> ignore
  })
  expect_round2_deserialize(() => guild.soundboard_sounds() |> ignore)
  expect_round2_deserialize(() => {
    guild.create_soundboard_sound("ding", "data:audio/ogg;base64,AAAA")
    |> ignore
  })
  expect_round2_deserialize(() => {
    guild.scheduled_events(with_user_count=true) |> ignore
  })
  expect_round2_deserialize(() => {
    guild.create_scheduled_event(
      "Meetup",
      GuildOnly,
      Timestamp("2026-08-01T10:00:00Z"),
      External,
      entity_metadata={ location: Some("Hall"), },
      scheduled_end_time=Timestamp("2026-08-01T12:00:00Z"),
    )
    |> ignore
  })
  expect_round2_deserialize(() => guild.auto_moderation_rules() |> ignore)
  expect_round2_deserialize(() => {
    guild.create_auto_moderation_rule("block", MessageSend, Keyword, [
      { typ: BlockMessage, metadata: None, },
    ])
    |> ignore
  })
  expect_round2_deserialize(() => guild.templates() |> ignore)
  expect_round2_deserialize(() => {
    guild.create_template("starter", description="Starter guild") |> ignore
  })
  let emoji = guild.emoji_ref(emoji_id)
  expect_round2_deserialize(() => emoji.fetch() |> ignore)
  expect_round2_deserialize(() => emoji.edit(name="renamed") |> ignore)
  let sticker = guild.sticker_ref(sticker_id)
  expect_round2_deserialize(() => sticker.fetch() |> ignore)
  expect_round2_deserialize(() => sticker.edit(name="renamed") |> ignore)
  let sound = guild.soundboard_sound_ref(sound_id)
  expect_round2_deserialize(() => sound.fetch() |> ignore)
  let event = guild.scheduled_event_ref(event_id)
  expect_round2_deserialize(() => event.fetch(with_user_count=true) |> ignore)
  expect_round2_deserialize(() => event.edit(name="Renamed meetup") |> ignore)
  let rule = guild.auto_moderation_rule_ref(rule_id)
  expect_round2_deserialize(() => rule.fetch() |> ignore)
  expect_round2_deserialize(() => rule.edit(name="renamed") |> ignore)
  let template = guild.template_ref("starter")
  expect_round2_deserialize(() => {
    template.create_guild("Created guild", icon="data:image/png;base64,AAAA")
    |> ignore
  })
  expect_round2_deserialize(() => {
    template.edit(name="renamed", description="Updated") |> ignore
  })
  expect_round2_deserialize(() => template.delete() |> ignore)
  assert_eq(calls, [
    "Get /api/v10/guilds/200/emojis", "Post /api/v10/guilds/200/emojis", "Get /api/v10/guilds/200/stickers",
    "Post /api/v10/guilds/200/stickers", "Get /api/v10/guilds/200/soundboard-sounds",
    "Post /api/v10/guilds/200/soundboard-sounds", "Get /api/v10/guilds/200/scheduled-events?with_user_count=true",
    "Post /api/v10/guilds/200/scheduled-events", "Get /api/v10/guilds/200/auto-moderation/rules",
    "Post /api/v10/guilds/200/auto-moderation/rules", "Get /api/v10/guilds/200/templates",
    "Post /api/v10/guilds/200/templates", "Get /api/v10/guilds/200/emojis/201", "Patch /api/v10/guilds/200/emojis/201",
    "Get /api/v10/guilds/200/stickers/202", "Patch /api/v10/guilds/200/stickers/202",
    "Get /api/v10/guilds/200/soundboard-sounds/203", "Get /api/v10/guilds/200/scheduled-events/204?with_user_count=true",
    "Patch /api/v10/guilds/200/scheduled-events/204", "Get /api/v10/guilds/200/auto-moderation/rules/205",
    "Patch /api/v10/guilds/200/auto-moderation/rules/205", "Post /api/v10/guilds/templates/starter",
    "Patch /api/v10/guilds/200/templates/starter", "Delete /api/v10/guilds/200/templates/starter",
  ])
}

///|
async test "channel handles exercise remaining channel API routes and builders" {
  let client = Client("test-token")
  defer client.close()
  let calls : Array[String] = []
  let bodies : Array[Json] = []
  client.perform_override_.val = Some((route, path, _headers, body, _files) => {
    calls.push("\{@debug.to_string(route.method_())} \{path}")
    bodies.push(body.unwrap_or(Json::null()))
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let channel_id : @model.ChannelId = Id(300UL)
  let user_id : @model.UserId = Id(301UL)
  let overwrite_id : @model.GenericId = Id(302UL)
  let sound_id : @model.SoundboardSoundId = Id(303UL)
  let first_message : @model.MessageId = Id(304UL)
  let second_message : @model.MessageId = Id(305UL)
  let channel = client.channel_ref(channel_id)
  expect_round2_deserialize(() => channel.delete(reason="cleanup") |> ignore)
  expect_round2_deserialize(() => channel.pins() |> ignore)
  expect_round2_deserialize(() => channel.invites() |> ignore)
  expect_round2_deserialize(() => {
    channel.create_webhook("updates", reason="coverage") |> ignore
  })
  expect_round2_deserialize(() => channel.webhooks() |> ignore)
  expect_round2_deserialize(() => {
    channel.create_invite(max_age=60, max_uses=1) |> ignore
  })
  channel.delete_permission(overwrite_id, reason="cleanup")
  channel.set_voice_status(status="Pairing", reason="coverage")
  expect_round2_deserialize(() => {
    channel.thread_member(user_id, with_member=true) |> ignore
  })
  expect_round2_deserialize(() => {
    channel.thread_members(with_member=true, after=user_id, limit=2) |> ignore
  })
  expect_round2_deserialize(() => {
    channel.public_archived_threads(
      before=Timestamp("2026-07-18T00:00:00Z"),
      limit=2,
    )
    |> ignore
  })
  expect_round2_deserialize(() => {
    channel.private_archived_threads(
      before=Timestamp("2026-07-18T00:00:00Z"),
      limit=2,
    )
    |> ignore
  })
  expect_round2_deserialize(() => {
    channel.joined_private_archived_threads(before=channel_id, limit=2)
    |> ignore
  })
  expect_round2_deserialize(() => {
    channel.start_thread(
      "discussion",
      typ=PrivateThread,
      auto_archive_duration=OneDay,
      invitable=true,
      rate_limit_per_user=5,
    )
    |> ignore
  })
  expect_round2_deserialize(() => {
    channel.start_forum_thread(
      "release",
      content="Release notes",
      files=[FileUpload("notes.txt", b"notes", content_type="text/plain")],
      auto_archive_duration=OneDay,
      rate_limit_per_user=5,
      applied_tags=[overwrite_id],
    )
    |> ignore
  })
  channel.bulk_delete([first_message, second_message], reason="cleanup")
  channel.send_soundboard_sound(sound_id)
  expect_round2_deserialize(() => channel.stage_instance() |> ignore)
  expect_round2_deserialize(() => {
    channel.edit_stage_instance(topic="Updated topic", privacy_level=GuildOnly)
    |> ignore
  })
  assert_eq(calls.length(), 19)
  assert_eq(calls[0], "Delete /api/v10/channels/300")
  assert_eq(
    calls[8],
    "Get /api/v10/channels/300/thread-members/301?with_member=true",
  )
  assert_eq(calls[13], "Post /api/v10/channels/300/threads")
  assert_eq(calls[14], "Post /api/v10/channels/300/threads")
  assert_eq(calls[18], "Patch /api/v10/stage-instances/300")
  json_inspect(bodies[13], content={
    "name": "discussion",
    "type": 12,
    "auto_archive_duration": 1440,
    "invitable": true,
    "rate_limit_per_user": 5,
  })
  json_inspect(bodies[14], content={
    "name": "release",
    "auto_archive_duration": 1440,
    "rate_limit_per_user": 5,
    "applied_tags": ["302"],
    "message": {
      "content": "Release notes",
      "allowed_mentions": { "parse": ["users", "roles"] },
      "attachments": [{ "id": 0, "filename": "notes.txt" }],
    },
  })
}

///|
async test "guild handles exercise remaining guild API routes" {
  let client = Client("test-token")
  defer client.close()
  let calls : Array[String] = []
  client.perform_override_.val = Some((route, path, _headers, _body, _files) => {
    let verb = @debug.to_string(route.method_())
    calls.push("\{verb} \{path}")
    let body = if verb == "Put" && path == "/api/v10/guilds/400/members/401" {
      @json.parse("{\"roles\":[],\"joined_at\":null,\"flags\":0}")
    } else {
      Json::null()
    }
    { status: 200, headers: Map([]), body, }
  })
  let guild_id : @model.GuildId = Id(400UL)
  let user_id : @model.UserId = Id(401UL)
  let channel_id : @model.ChannelId = Id(402UL)
  let role_id : @model.RoleId = Id(403UL)
  let guild = client.guild_ref(guild_id)
  expect_round2_deserialize(() => guild.preview() |> ignore)
  expect_round2_deserialize(() => {
    guild.audit_log(page_size=2).next_page() |> ignore
  })
  expect_round2_deserialize(() => {
    guild.bans(after=user_id, page_size=2).next_page() |> ignore
  })
  expect_round2_deserialize(() => guild.fetch_ban(user_id) |> ignore)
  expect_round2_deserialize(() => {
    guild.bulk_ban([user_id], delete_message_seconds=60) |> ignore
  })
  expect_round2_deserialize(() => guild.channels() |> ignore)
  expect_round2_deserialize(() => {
    guild.create_channel("general", typ=GuildText) |> ignore
  })
  guild.edit_channel_positions([GuildChannelPosition(channel_id, position=1)])
  expect_round2_deserialize(() => {
    guild.search_members("Nelly Example", limit=2) |> ignore
  })
  let added = guild.add_member(user_id, "oauth-token", nick="Nelly")
  assert_true(added is Some({ user: None, .. }))
  expect_round2_deserialize(() => {
    guild.edit_current_member(nick="Bot", bio="helper") |> ignore
  })
  expect_round2_deserialize(() => guild.roles() |> ignore)
  expect_round2_deserialize(() => guild.create_role(name="moderator") |> ignore)
  expect_round2_deserialize(() => {
    guild.edit_role_positions([(role_id, Some(2))]) |> ignore
  })
  expect_round2_deserialize(() => {
    guild.prune_count(days=7, include_roles=[role_id]) |> ignore
  })
  expect_round2_deserialize(() => {
    guild.begin_prune(days=7, compute_prune_count=true) |> ignore
  })
  expect_round2_deserialize(() => guild.voice_regions() |> ignore)
  expect_round2_deserialize(() => guild.invites() |> ignore)
  expect_round2_deserialize(() => guild.integrations() |> ignore)
  expect_round2_deserialize(() => guild.webhooks() |> ignore)
  expect_round2_deserialize(() => guild.vanity_url() |> ignore)
  expect_round2_deserialize(() => guild.widget_settings() |> ignore)
  expect_round2_deserialize(() => {
    guild.edit_widget(enabled=true, channel_id~) |> ignore
  })
  expect_round2_deserialize(() => guild.widget() |> ignore)
  assert_eq(
    guild.widget_image_url(style="shield"),
    "https://discord.com/api/v10/guilds/400/widget.png?style=shield",
  )
  expect_round2_deserialize(() => guild.welcome_screen() |> ignore)
  expect_round2_deserialize(() => {
    guild.edit_welcome_screen(enabled=true, description="Welcome") |> ignore
  })
  expect_round2_deserialize(() => guild.onboarding() |> ignore)
  expect_round2_deserialize(() => {
    guild.edit_onboarding([], [channel_id], true, Default) |> ignore
  })
  expect_round2_deserialize(() => {
    guild.edit_incident_actions(
      invites_disabled_until=Timestamp("2026-07-18T01:00:00Z"),
    )
    |> ignore
  })
  expect_round2_deserialize(() => guild.active_threads() |> ignore)
  expect_round2_deserialize(() => guild.my_voice_state() |> ignore)
  guild.edit_my_voice_state(channel_id~, suppress=true)
  expect_round2_deserialize(() => guild.role_ref(role_id).fetch() |> ignore)
  assert_eq(calls.length(), 33)
  assert_eq(calls[0], "Get /api/v10/guilds/400/preview")
  assert_eq(calls[1], "Get /api/v10/guilds/400/audit-logs?limit=2")
  assert_eq(
    calls[8],
    "Get /api/v10/guilds/400/members/search?query=Nelly%20Example&limit=2",
  )
  assert_eq(calls[22], "Patch /api/v10/guilds/400/widget")
  assert_eq(calls[29], "Get /api/v10/guilds/400/threads/active")
  assert_eq(calls[32], "Get /api/v10/guilds/400/roles/403")
}

///|
async test "user command webhook invite and gateway long-tail routes are pinned" {
  let client = Client("test-token")
  defer client.close()
  let calls : Array[String] = []
  let authorizations : Array[String] = []
  let bodies : Array[Json] = []
  let gateway_calls = Ref(0)
  client.perform_override_.val = Some((route, path, headers, body, _files) => {
    let verb = @debug.to_string(route.method_())
    calls.push("\{verb} \{path}")
    authorizations.push(headers.get_or_default("authorization", ""))
    bodies.push(body.unwrap_or(Json::null()))
    let response : Json = if path == "/api/v10/gateway" {
      gateway_calls.val += 1
      if gateway_calls.val == 1 {
        { "url": "wss://gateway.example" }
      } else {
        Json::null()
      }
    } else {
      Json::null()
    }
    { status: 200, headers: Map([]), body: response, }
  })
  let user_id : @model.UserId = Id(500UL)
  let guild_id : @model.GuildId = Id(501UL)
  let application_id : @model.ApplicationId = Id(502UL)
  let command_id : @model.CommandId = Id(503UL)
  let webhook_id : @model.WebhookId = Id(504UL)
  let message_id : @model.MessageId = Id(505UL)
  expect_round2_deserialize(() => client.get_current_user() |> ignore)
  expect_round2_deserialize(() => client.create_dm(user_id) |> ignore)
  expect_round2_deserialize(() => {
    client.get_current_user_connections(bearer_token="bearer-a") |> ignore
  })
  expect_round2_deserialize(() => {
    client.get_current_user_guild_member(guild_id, bearer_token="bearer-b")
    |> ignore
  })
  expect_round2_deserialize(() => {
    client.get_current_user_application_role_connection(
      application_id,
      bearer_token="bearer-c",
    )
    |> ignore
  })
  expect_round2_deserialize(() => {
    client.update_current_user_application_role_connection(
      application_id,
      platform_name="MoonBit",
      platform_username="nelly",
      metadata={ "level": "42" },
      bearer_token="bearer-d",
    )
    |> ignore
  })
  client.delete_current_user_application_role_connection(
    application_id,
    bearer_token="bearer-e",
  )
  client.guild_command_ref(application_id, guild_id, command_id).delete()
  try
    client.bulk_overwrite_global_commands(application_id, Json::empty_object())
    |> ignore
  catch {
    Validation(message~) =>
      assert_eq(message, "bulk command payload must be a JSON array")
    error => fail("unexpected bulk command error: \{Repr(error)}")
  } noraise {
    _ => fail("expected object bulk command payload to be rejected")
  }
  let webhook = client.webhook_ref(webhook_id)
  expect_round2_deserialize(() => webhook.fetch() |> ignore)
  let token_webhook = webhook.with_token("tok")
  expect_round2_deserialize(() => token_webhook.fetch() |> ignore)
  expect_round2_deserialize(() => {
    token_webhook.edit(name="renamed", clear_avatar=true) |> ignore
  })
  expect_round2_deserialize(() => {
    token_webhook.message_ref(message_id).fetch() |> ignore
  })
  let invite = client.invite_ref("invite-code")
  expect_round2_deserialize(() => invite.fetch(with_counts=true) |> ignore)
  expect_round2_deserialize(() => invite.delete(reason="cleanup") |> ignore)
  expect_round2_deserialize(() => invite.target_users_job_status() |> ignore)
  assert_eq(client.get_gateway(), "wss://gateway.example")
  try client.get_gateway() |> ignore catch {
    Deserialize(message~) =>
      assert_eq(message, "expected gateway url, got null")
    error => fail("unexpected gateway error: \{Repr(error)}")
  } noraise {
    _ => fail("expected gateway response without url to fail")
  }
  expect_round2_deserialize(() => client.get_gateway_bot() |> ignore)
  assert_eq(calls.length(), 18)
  assert_eq(calls[1], "Post /api/v10/users/@me/channels")
  json_inspect(bodies[1], content={ "recipient_id": "500" })
  assert_eq(authorizations[2], "Bearer bearer-a")
  assert_eq(authorizations[6], "Bearer bearer-e")
  assert_eq(
    calls[7],
    "Delete /api/v10/applications/502/guilds/501/commands/503",
  )
  assert_eq(calls[12], "Get /api/v10/invites/invite-code?with_counts=true")
  assert_eq(calls[15], "Get /api/v10/gateway")
  assert_eq(calls[16], "Get /api/v10/gateway")
  assert_eq(calls[17], "Get /api/v10/gateway/bot")
}
