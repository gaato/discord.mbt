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
    Json([Json(entitlement_type), Json(sku_type)]).stringify(),
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

///|
test "entitlement owner type round-trips known and unknown values" {
  for value in [1, 2, 99] {
    let owner_type : @model.EntitlementOwnerType = @json.from_json(
      @json.parse(value.to_string()),
    )
    assert_eq(owner_type.to_int(), value)
    assert_eq(owner_type.to_json().stringify(), value.to_string())
  }
  assert_eq(@model.EntitlementOwnerType::from_int(99), Unknown(99))
}

///|
/// Pins the documented table (ACTIVE=0, INACTIVE=1, ENDING=2); the first
/// transcription had 1 and 2 reversed and no test to catch it.
test "subscription status matches the documented values" {
  let table : Array[(@model.SubscriptionStatus, Int)] = [
    (Active, 0),
    (Inactive, 1),
    (Ending, 2),
  ]
  for pair in table {
    let (status, value) = pair
    assert_eq(status.to_int(), value)
    assert_eq(@model.SubscriptionStatus::from_int(value), status)
  }
  assert_eq(@model.SubscriptionStatus::from_int(9), Unknown(9))
}
