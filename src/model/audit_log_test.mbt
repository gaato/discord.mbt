///|
test "audit log decodes referenced objects and raw integrations" {
  let fixture =
    #|{
    #|  "audit_log_entries": [{
    #|    "target_id": "41771983423143937",
    #|    "changes": [{
    #|      "key": "name",
    #|      "old_value": "general",
    #|      "new_value": "announcements"
    #|    }],
    #|    "user_id": "80351110224678912",
    #|    "id": "119000000000000001",
    #|    "action_type": 11,
    #|    "options": {"channel_id": "41771983423143937"},
    #|    "reason": "Clarify purpose",
    #|    "future": true
    #|  }],
    #|  "users": [{
    #|    "id": "80351110224678912", "username": "Nelly",
    #|    "discriminator": "0", "global_name": "Nelly", "avatar": null
    #|  }],
    #|  "webhooks": [],
    #|  "integrations": [{"id":"raw-integration","type":"future"}],
    #|  "application_commands": [],
    #|  "auto_moderation_rules": [],
    #|  "threads": [],
    #|  "guild_scheduled_events": [],
    #|  "brand_new_field_from_discord": true
    #|}
  let audit_log : @model.AuditLog = @json.from_json(@json.parse(fixture))
  debug_inspect(
    audit_log,
    content=(
      #|{
      #|  audit_log_entries: [
      #|    {
      #|      target_id: Value("41771983423143937"),
      #|      changes: Some(
      #|        [
      #|          {
      #|            key: "name",
      #|            new_value: Some(String("announcements")),
      #|            old_value: Some(String("general")),
      #|          },
      #|        ],
      #|      ),
      #|      user_id: Value(80351110224678912),
      #|      id: 119000000000000001,
      #|      action_type: ChannelUpdate,
      #|      options: Some(Object({ "channel_id": String("41771983423143937") })),
      #|      reason: Some("Clarify purpose"),
      #|    },
      #|  ],
      #|  users: [
      #|    {
      #|      id: 80351110224678912,
      #|      username: "Nelly",
      #|      discriminator: "0",
      #|      global_name: Value("Nelly"),
      #|      avatar: Null,
      #|      bot: None,
      #|      system: None,
      #|      mfa_enabled: None,
      #|      banner: None,
      #|      accent_color: None,
      #|      locale: None,
      #|      verified: None,
      #|      email: None,
      #|      flags: None,
      #|      premium_type: None,
      #|      public_flags: None,
      #|      avatar_decoration: None,
      #|      avatar_decoration_data: None,
      #|    },
      #|  ],
      #|  webhooks: [],
      #|  integrations: [Object({ "id": String("raw-integration"), "type": String("future") })],
      #|  application_commands: [],
      #|  auto_moderation_rules: [],
      #|  threads: [],
      #|  guild_scheduled_events: [],
      #|}
    ),
  )
}

///|
test "audit log event preserves an unknown value" {
  let event : @model.AuditLogEvent = @json.from_json(@json.parse("999"))
  debug_inspect(
    event,
    content=(
      #|Unknown(999)
    ),
  )
  inspect(
    event.to_json().stringify(),
    content=(
      #|999
    ),
  )
}
