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
    #|  "brand_new_field_from_discord": true
    #|}
  let invite : @model.Invite = @json.from_json(@json.parse(fixture))
  debug_inspect(
    invite,
    content=(
      #|{
      #|  typ: Some(Guild),
      #|  code: "abc123",
      #|  guild: Some(
      #|    {
      #|      id: 81384788765712384,
      #|      name: Some("ignored"),
      #|      icon: None,
      #|      splash: None,
      #|      banner: None,
      #|      description: None,
      #|      features: None,
      #|      verification_level: None,
      #|      vanity_url_code: None,
      #|      nsfw_level: None,
      #|      premium_subscription_count: None,
      #|      locale: None,
      #|    },
      #|  ),
      #|  channel: Some(
      #|    Value(
      #|      {
      #|        id: 41771983423143937,
      #|        typ: Some(GuildText),
      #|        name: Some(Value("general")),
      #|        icon: None,
      #|        permissions: None,
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
      #|      collectibles: None,
      #|      primary_guild: None,
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
      #|      collectibles: None,
      #|      primary_guild: None,
      #|    },
      #|  ),
      #|  target_application: None,
      #|  approximate_presence_count: Some(12),
      #|  approximate_member_count: Some(42),
      #|  expires_at: Some(Null),
      #|  guild_scheduled_event: None,
      #|  flags: None,
      #|  roles: None,
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
      #|  guild: None,
      #|  channel: None,
      #|  inviter: None,
      #|  target_type: None,
      #|  target_user: None,
      #|  target_application: None,
      #|  approximate_presence_count: None,
      #|  approximate_member_count: None,
      #|  expires_at: None,
      #|  guild_scheduled_event: None,
      #|  flags: None,
      #|  roles: None,
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
    guild: None,
    channel: None,
    inviter: None,
    target_type: None,
    target_user: None,
    target_application: None,
    approximate_presence_count: None,
    approximate_member_count: None,
    expires_at: None,
    guild_scheduled_event: None,
    flags: None,
    roles: None,
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
