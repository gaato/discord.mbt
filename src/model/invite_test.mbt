///|
test "invite decodes a full fixture" {
  let fixture =
    #|{
    #|  "type": 0, "code": "abc123",
    #|  "guild": {"id":"81384788765712384","name":"ignored"},
    #|  "channel": {"id":"41771983423143937","type":0,"name":"general"},
    #|  "inviter": {
    #|    "id":"80351110224678912","username":"Nelly","discriminator":"0",
    #|    "global_name":"Nelly","avatar":null
    #|  },
    #|  "target_type": 2,
    #|  "target_user": {
    #|    "id":"80351110224678912","username":"Nelly","discriminator":"0",
    #|    "global_name":null,"avatar":null
    #|  },
    #|  "approximate_presence_count": 12,
    #|  "approximate_member_count": 42,
    #|  "expires_at": null,
    #|  "uses": 3, "max_uses": 10, "max_age": 86400,
    #|  "temporary": false,
    #|  "created_at": "2024-01-02T03:04:05.000000+00:00",
    #|  "guild_scheduled_event": {"id":"ignored"},
    #|  "brand_new_field_from_discord": true
    #|}
  let invite : @model.Invite = @json.from_json(@json.parse(fixture))
  debug_inspect(
    invite,
    content=(
      #|{
      #|  typ: Some(Guild),
      #|  code: "abc123",
      #|  channel: Some(
      #|    Value(
      #|      {
      #|        id: 41771983423143937,
      #|        typ: GuildText,
      #|        guild_id: None,
      #|        position: None,
      #|        permission_overwrites: None,
      #|        name: Some(Value("general")),
      #|        topic: None,
      #|        nsfw: None,
      #|        last_message_id: None,
      #|        bitrate: None,
      #|        user_limit: None,
      #|        rate_limit_per_user: None,
      #|        recipients: None,
      #|        icon: None,
      #|        owner_id: None,
      #|        application_id: None,
      #|        managed: None,
      #|        parent_id: None,
      #|        last_pin_timestamp: None,
      #|        rtc_region: None,
      #|        video_quality_mode: None,
      #|        message_count: None,
      #|        member_count: None,
      #|        thread_metadata: None,
      #|        thread_member: None,
      #|        default_auto_archive_duration: None,
      #|        permissions: None,
      #|        flags: None,
      #|        total_message_sent: None,
      #|        available_tags: None,
      #|        applied_tags: None,
      #|        default_reaction_emoji: None,
      #|        default_thread_rate_limit_per_user: None,
      #|        default_sort_order: None,
      #|        default_forum_layout: None,
      #|      },
      #|    ),
      #|  ),
      #|  inviter: Some(
      #|    {
      #|      id: 80351110224678912,
      #|      username: "Nelly",
      #|      discriminator: "0",
      #|      global_name: Some(Value("Nelly")),
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
      #|  ),
      #|  target_type: Some(EmbeddedApplication),
      #|  target_user: Some(
      #|    {
      #|      id: 80351110224678912,
      #|      username: "Nelly",
      #|      discriminator: "0",
      #|      global_name: Some(Null),
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
      #|  ),
      #|  approximate_presence_count: Some(12),
      #|  approximate_member_count: Some(42),
      #|  expires_at: Some(Null),
      #|  uses: Some(3),
      #|  max_uses: Some(10),
      #|  max_age: Some(86400),
      #|  temporary: Some(false),
      #|  created_at: Some("2024-01-02T03:04:05.000000+00:00"),
      #|}
    ),
  )
}

///|
test "invite decodes required fields only" {
  let invite : @model.Invite = @json.from_json(
    @json.parse(
      (
        #|{"code":"abc123"}
      ),
    ),
  )
  debug_inspect(
    invite,
    content=(
      #|{
      #|  typ: None,
      #|  code: "abc123",
      #|  channel: None,
      #|  inviter: None,
      #|  target_type: None,
      #|  target_user: None,
      #|  approximate_presence_count: None,
      #|  approximate_member_count: None,
      #|  expires_at: None,
      #|  uses: None,
      #|  max_uses: None,
      #|  max_age: None,
      #|  temporary: None,
      #|  created_at: None,
      #|}
    ),
  )
}

///|
test "invite encode omits absent optional fields" {
  let invite : @model.Invite = {
    typ: None,
    code: "abc123",
    channel: None,
    inviter: None,
    target_type: None,
    target_user: None,
    approximate_presence_count: None,
    approximate_member_count: None,
    expires_at: None,
    uses: None,
    max_uses: None,
    max_age: None,
    temporary: None,
    created_at: None,
  }
  inspect(
    invite.to_json().stringify(),
    content=(
      #|{"code":"abc123"}
    ),
  )
}

///|
test "invite enums preserve unknown values" {
  let invite_type : @model.InviteType = @json.from_json(@json.parse("99"))
  let target_type : @model.InviteTargetType = @json.from_json(@json.parse("98"))
  debug_inspect(
    invite_type,
    content=(
      #|Unknown(99)
    ),
  )
  debug_inspect(
    target_type,
    content=(
      #|Unknown(98)
    ),
  )
  inspect(
    [invite_type.to_json(), target_type.to_json()].to_json().stringify(),
    content=(
      #|[99,98]
    ),
  )
}
