///|
test "application decodes a minimal interaction-ready fixture" {
  let fixture =
    #|{
    #|  "id": "172150183260323840",
    #|  "name": "Example App",
    #|  "icon": null,
    #|  "description": "An example interaction application",
    #|  "bot": {
    #|    "id": "172150183260323841",
    #|    "username": "Example Bot",
    #|    "discriminator": "0",
    #|    "global_name": null,
    #|    "avatar": null
    #|  },
    #|  "owner": {
    #|    "id": "80351110224678912",
    #|    "username": "Nelly",
    #|    "discriminator": "0",
    #|    "global_name": "Nelly",
    #|    "avatar": null
    #|  },
    #|  "flags": 8388608,
    #|  "approximate_guild_count": 42,
    #|  "approximate_user_install_count": 120,
    #|  "verify_key": "ignored-by-minimal-model",
    #|  "brand_new_field_from_discord": true
    #|}
  let application : @model.Application = @json.from_json(@json.parse(fixture))
  debug_inspect(
    application,
    content=(
      #|{
      #|  id: 172150183260323840,
      #|  name: "Example App",
      #|  icon: Null,
      #|  description: "An example interaction application",
      #|  bot: Some(
      #|    {
      #|      id: 172150183260323841,
      #|      username: "Example Bot",
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
      #|  owner: Some(
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
      #|  flags: Some(8388608),
      #|  flags_new: None,
      #|  approximate_guild_count: Some(42),
      #|  approximate_user_install_count: Some(120),
      #|  rpc_origins: None,
      #|  bot_public: None,
      #|  bot_require_code_grant: None,
      #|  terms_of_service_url: None,
      #|  privacy_policy_url: None,
      #|  verify_key: Some("ignored-by-minimal-model"),
      #|  team: None,
      #|  guild_id: None,
      #|  guild: None,
      #|  primary_sku_id: None,
      #|  slug: None,
      #|  cover_image: None,
      #|  approximate_user_authorization_count: None,
      #|  redirect_uris: None,
      #|  interactions_endpoint_url: None,
      #|  role_connections_verification_url: None,
      #|  event_webhooks_url: None,
      #|  event_webhooks_status: None,
      #|  event_webhooks_types: None,
      #|  tags: None,
      #|  install_params: None,
      #|  integration_types_config: None,
      #|  custom_install_url: None,
      #|}
    ),
  )
}

///|
test "application flags combine and preserve unknown bits" {
  let flags = @model.ApplicationFlags::gateway_presence() |
    @model.ApplicationFlags::application_command_badge()
  assert_true(flags.bits() == ((1UL << 12) | (1UL << 23)))
  assert_true(flags.contains(@model.ApplicationFlags::gateway_presence()))
  let bits = flags.bits() | (1UL << 60)
  let encoded = @model.ApplicationFlags::from_bits(bits).to_json().stringify()
  inspect(
    encoded,
    content=(
      #|1152921504615239680
    ),
  )
  let decoded : @model.ApplicationFlags = @json.from_json(@json.parse(encoded))
  assert_true(decoded.bits() == bits)
}

///|
test "application flags_new preserves bits above the legacy numeric field" {
  let application : @model.Application = @json.from_json(
    @json.parse(
      (
        #|{"id":"1","name":"flags","icon":null,"description":"","flags":1,"flags_new":"2147483649"}
      ),
    ),
  )
  assert_eq(application.flags.unwrap().bits(), 1UL)
  assert_eq(application.flags_new.unwrap().bits(), 2147483649UL)
  assert_eq(application.effective_flags().unwrap().bits(), 2147483649UL)
}
