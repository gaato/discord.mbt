///|
test "guild member decodes a full fixture" {
  let fixture =
    #|{
    #|  "user": {
    #|    "id": "80351110224678912",
    #|    "username": "Nelly",
    #|    "discriminator": "0",
    #|    "global_name": "Nelly",
    #|    "avatar": null
    #|  },
    #|  "nick": "Nel",
    #|  "avatar": null,
    #|  "banner": "a_1269e74af4df7417b13759eae50c83dc",
    #|  "roles": ["41771983423143936"],
    #|  "joined_at": null,
    #|  "premium_since": "2024-01-02T03:04:05.000000+00:00",
    #|  "deaf": false,
    #|  "mute": true,
    #|  "flags": 3,
    #|  "pending": false,
    #|  "permissions": "1024",
    #|  "communication_disabled_until": null,
    #|  "avatar_decoration_data": {
    #|    "asset": "a_1269e74af4df7417b13759eae50c83dc",
    #|    "sku_id": "1144058844004233369"
    #|  },
    #|  "collectibles": {"future": true},
    #|  "brand_new_field_from_discord": true
    #|}
  let guild_member : @model.GuildMember = @json.from_json(@json.parse(fixture))
  debug_inspect(
    guild_member,
    content=(
      #|{
      #|  user: Some(
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
      #|  ),
      #|  nick: Some(Value("Nel")),
      #|  avatar: Some(Null),
      #|  banner: Some(Value("a_1269e74af4df7417b13759eae50c83dc")),
      #|  roles: [41771983423143936],
      #|  joined_at: Null,
      #|  premium_since: Some(Value("2024-01-02T03:04:05.000000+00:00")),
      #|  deaf: false,
      #|  mute: true,
      #|  flags: 3,
      #|  pending: Some(false),
      #|  permissions: Some(1024),
      #|  communication_disabled_until: Some(Null),
      #|  avatar_decoration_data: Some(
      #|    Value(
      #|      {
      #|        asset: "a_1269e74af4df7417b13759eae50c83dc",
      #|        sku_id: 1144058844004233369,
      #|      },
      #|    ),
      #|  ),
      #|}
    ),
  )
}

///|
test "guild member decodes required fields only" {
  let fixture =
    #|{
    #|  "roles": [],
    #|  "joined_at": null,
    #|  "deaf": false,
    #|  "mute": false,
    #|  "flags": 0
    #|}
  let guild_member : @model.GuildMember = @json.from_json(@json.parse(fixture))
  debug_inspect(
    guild_member,
    content=(
      #|{
      #|  user: None,
      #|  nick: None,
      #|  avatar: None,
      #|  banner: None,
      #|  roles: [],
      #|  joined_at: Null,
      #|  premium_since: None,
      #|  deaf: false,
      #|  mute: false,
      #|  flags: 0,
      #|  pending: None,
      #|  permissions: None,
      #|  communication_disabled_until: None,
      #|  avatar_decoration_data: None,
      #|}
    ),
  )
}

///|
test "guild member encode omits absent optional fields" {
  let guild_member : @model.GuildMember = {
    user: None,
    nick: None,
    avatar: None,
    banner: None,
    roles: [],
    joined_at: @model.Nullable::Null,
    premium_since: None,
    deaf: false,
    mute: false,
    flags: @model.GuildMemberFlags::none(),
    pending: None,
    permissions: None,
    communication_disabled_until: None,
    avatar_decoration_data: None,
  }
  inspect(
    guild_member.to_json().stringify(),
    content=(
      #|{"roles":[],"joined_at":null,"deaf":false,"mute":false,"flags":0}
    ),
  )
}

///|
test "guild member flags combine and preserve unknown bits" {
  let flags = @model.GuildMemberFlags::did_rejoin() |
    @model.GuildMemberFlags::completed_onboarding()
  inspect(
    flags.bits(),
    content=(
      #|3
    ),
  )
  assert_true(flags.contains(@model.GuildMemberFlags::did_rejoin()))
  let unknown_bits = (1UL << 60) | flags.bits()
  let unknown = @model.GuildMemberFlags::from_bits(unknown_bits)
  let encoded = unknown.to_json().stringify()
  inspect(
    encoded,
    content=(
      #|1152921504606846979
    ),
  )
  let decoded : @model.GuildMemberFlags = @json.from_json(@json.parse(encoded))
  assert_true(decoded.bits() == unknown_bits)
}
