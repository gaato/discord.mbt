///|
test "entitlement and SKU decode realistic fixtures" {
  let entitlement_fixture =
    #|{
    #|  "id":"125000000000000001","sku_id":"125000000000000002",
    #|  "application_id":"172150183260323840","user_id":"80351110224678912",
    #|  "type":8,"deleted":false,
    #|  "starts_at":"2026-07-01T00:00:00Z","ends_at":null,
    #|  "guild_id":"81384788765712384","consumed":false,"future":true
    #|}
  let entitlement : @model.Entitlement = @json.from_json(
    @json.parse(entitlement_fixture),
  )
  debug_inspect(
    entitlement,
    content=(
      #|{
      #|  id: 125000000000000001,
      #|  sku_id: 125000000000000002,
      #|  application_id: 172150183260323840,
      #|  user_id: Some(80351110224678912),
      #|  typ: ApplicationSubscription,
      #|  deleted: false,
      #|  starts_at: Some(Value("2026-07-01T00:00:00Z")),
      #|  ends_at: Some(Null),
      #|  guild_id: Some(81384788765712384),
      #|  consumed: Some(false),
      #|}
    ),
  )
  let sku_fixture =
    #|{"id":"125000000000000002","type":5,"application_id":"172150183260323840","name":"Pro","slug":"pro","flags":388}
  let sku : @model.Sku = @json.from_json(@json.parse(sku_fixture))
  debug_inspect(
    sku,
    content=(
      #|{
      #|  id: 125000000000000002,
      #|  typ: Subscription,
      #|  application_id: 172150183260323840,
      #|  name: "Pro",
      #|  slug: "pro",
      #|  flags: 388,
      #|}
    ),
  )
}

///|
test "interaction decodes typed entitlements" {
  let fixture =
    #|{
    #|  "id":"125000000000000003","application_id":"172150183260323840",
    #|  "type":1,"token":"ping-token","version":1,
    #|  "entitlements":[{
    #|    "id":"125000000000000001","sku_id":"125000000000000002",
    #|    "application_id":"172150183260323840","type":1,"deleted":false,
    #|    "starts_at":null,"ends_at":null
    #|  }]
    #|}
  let interaction : @model.Interaction = @json.from_json(@json.parse(fixture))
  debug_inspect(
    interaction,
    content=(
      #|{
      #|  id: 125000000000000003,
      #|  application_id: 172150183260323840,
      #|  typ: Ping,
      #|  data: None,
      #|  guild: None,
      #|  guild_id: None,
      #|  channel: None,
      #|  channel_id: None,
      #|  guild_member: None,
      #|  user: None,
      #|  token: "ping-token",
      #|  version: 1,
      #|  message: None,
      #|  app_permissions: None,
      #|  locale: None,
      #|  guild_locale: None,
      #|  entitlements: Some(
      #|    [
      #|      {
      #|        id: 125000000000000001,
      #|        sku_id: 125000000000000002,
      #|        application_id: 172150183260323840,
      #|        user_id: None,
      #|        typ: Purchase,
      #|        deleted: false,
      #|        starts_at: Some(Null),
      #|        ends_at: Some(Null),
      #|        guild_id: None,
      #|        consumed: None,
      #|      },
      #|    ],
      #|  ),
      #|  authorizing_integration_owners: None,
      #|  context: None,
      #|  attachment_size_limit: None,
      #|}
    ),
  )
  assert_true(interaction.entitlements is Some(values) && values.length() == 1)
}

///|
test "monetization enums and flags preserve unknown values" {
  let entitlement_type : @model.EntitlementType = @json.from_json(
    @json.parse("99"),
  )
  let sku_type : @model.SkuType = @json.from_json(@json.parse("98"))
  let bits = (1UL << 60) | @model.SkuFlags::available().bits()
  let encoded_flags = @model.SkuFlags::from_bits(bits).to_json().stringify()
  inspect(
    [entitlement_type.to_json(), sku_type.to_json()].to_json().stringify(),
    content=(
      #|[99,98]
    ),
  )
  inspect(
    encoded_flags,
    content=(
      #|1152921504606846980
    ),
  )
  let decoded : @model.SkuFlags = @json.from_json(@json.parse(encoded_flags))
  assert_true(decoded.bits() == bits)
}
