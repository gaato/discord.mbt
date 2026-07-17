///|
test "every permission constant pins its exact Discord bit" {
  let cases : Array[(String, @model.Permissions, UInt64)] = [
    ("create_instant_invite", @model.Permissions::create_instant_invite(), 1UL),
    ("kick_members", @model.Permissions::kick_members(), 2UL),
    ("ban_members", @model.Permissions::ban_members(), 4UL),
    ("administrator", @model.Permissions::administrator(), 8UL),
    ("manage_channels", @model.Permissions::manage_channels(), 16UL),
    ("manage_guild", @model.Permissions::manage_guild(), 32UL),
    ("add_reactions", @model.Permissions::add_reactions(), 64UL),
    ("view_audit_log", @model.Permissions::view_audit_log(), 128UL),
    ("priority_speaker", @model.Permissions::priority_speaker(), 256UL),
    ("stream", @model.Permissions::stream(), 512UL),
    ("view_channel", @model.Permissions::view_channel(), 1024UL),
    ("send_messages", @model.Permissions::send_messages(), 2048UL),
    ("send_tts_messages", @model.Permissions::send_tts_messages(), 4096UL),
    ("manage_messages", @model.Permissions::manage_messages(), 8192UL),
    ("embed_links", @model.Permissions::embed_links(), 16384UL),
    ("attach_files", @model.Permissions::attach_files(), 32768UL),
    (
      "read_message_history",
      @model.Permissions::read_message_history(),
      65536UL,
    ),
    ("mention_everyone", @model.Permissions::mention_everyone(), 131072UL),
    ("use_external_emojis", @model.Permissions::use_external_emojis(), 262144UL),
    ("view_guild_insights", @model.Permissions::view_guild_insights(), 524288UL),
    ("connect", @model.Permissions::connect(), 1048576UL),
    ("speak", @model.Permissions::speak(), 2097152UL),
    ("mute_members", @model.Permissions::mute_members(), 4194304UL),
    ("deafen_members", @model.Permissions::deafen_members(), 8388608UL),
    ("move_members", @model.Permissions::move_members(), 16777216UL),
    ("use_vad", @model.Permissions::use_vad(), 33554432UL),
    ("change_nickname", @model.Permissions::change_nickname(), 67108864UL),
    ("manage_nicknames", @model.Permissions::manage_nicknames(), 134217728UL),
    ("manage_roles", @model.Permissions::manage_roles(), 268435456UL),
    ("manage_webhooks", @model.Permissions::manage_webhooks(), 536870912UL),
    (
      "manage_guild_expressions",
      @model.Permissions::manage_guild_expressions(),
      1073741824UL,
    ),
    (
      "use_application_commands",
      @model.Permissions::use_application_commands(),
      2147483648UL,
    ),
    ("request_to_speak", @model.Permissions::request_to_speak(), 4294967296UL),
    ("manage_events", @model.Permissions::manage_events(), 8589934592UL),
    ("manage_threads", @model.Permissions::manage_threads(), 17179869184UL),
    (
      "create_public_threads",
      @model.Permissions::create_public_threads(),
      34359738368UL,
    ),
    (
      "create_private_threads",
      @model.Permissions::create_private_threads(),
      68719476736UL,
    ),
    (
      "use_external_stickers",
      @model.Permissions::use_external_stickers(),
      137438953472UL,
    ),
    (
      "send_messages_in_threads",
      @model.Permissions::send_messages_in_threads(),
      274877906944UL,
    ),
    (
      "use_embedded_activities",
      @model.Permissions::use_embedded_activities(),
      549755813888UL,
    ),
    (
      "moderate_members",
      @model.Permissions::moderate_members(),
      1099511627776UL,
    ),
    (
      "view_creator_monetization_analytics",
      @model.Permissions::view_creator_monetization_analytics(),
      2199023255552UL,
    ),
    ("use_soundboard", @model.Permissions::use_soundboard(), 4398046511104UL),
    (
      "create_guild_expressions",
      @model.Permissions::create_guild_expressions(),
      8796093022208UL,
    ),
    ("create_events", @model.Permissions::create_events(), 17592186044416UL),
    (
      "use_external_sounds",
      @model.Permissions::use_external_sounds(),
      35184372088832UL,
    ),
    (
      "send_voice_messages",
      @model.Permissions::send_voice_messages(),
      70368744177664UL,
    ),
    (
      "set_voice_channel_status",
      @model.Permissions::set_voice_channel_status(),
      281474976710656UL,
    ),
    ("send_polls", @model.Permissions::send_polls(), 562949953421312UL),
    (
      "use_external_apps",
      @model.Permissions::use_external_apps(),
      1125899906842624UL,
    ),
    ("pin_messages", @model.Permissions::pin_messages(), 2251799813685248UL),
    (
      "bypass_slowmode",
      @model.Permissions::bypass_slowmode(),
      4503599627370496UL,
    ),
  ]
  for item in cases {
    let (name, permission, expected) = item
    if permission.bits() != expected {
      fail(
        "permission \{name}: expected bit \{expected}, got \{permission.bits()}",
      )
    }
  }
}

///|
test "permissions bit operations pin none, contains, or, and" {
  let send = @model.Permissions::send_messages()
  let embed = @model.Permissions::embed_links()
  let combined = send | embed
  assert_eq(@model.Permissions::none().bits(), 0UL)
  assert_true(combined.contains(send))
  assert_true(combined.contains(embed))
  assert_false(send.contains(embed))
  assert_eq((combined & embed).bits(), 16384UL)
}

///|
test "permissions decode rejects non-string and unparsable string" {
  try (@json.from_json(Json::number(8)) : @model.Permissions) |> ignore catch {
    JsonDecodeError((_, message)) =>
      assert_eq(message, "expected permissions (string)")
  } noraise {
    _ => fail("expected non-string permissions to fail")
  }
  try
    (@json.from_json(Json::string("administrator")) : @model.Permissions)
    |> ignore
  catch {
    JsonDecodeError((_, message)) =>
      assert_eq(
        message, "expected permissions (decimal string), got administrator",
      )
  } noraise {
    _ => fail("expected unparsable permissions to fail")
  }
}
