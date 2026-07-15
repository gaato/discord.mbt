///|
test "user decodes a full fixture" {
  let fixture =
    #|{
    #|  "id": "80351110224678912",
    #|  "username": "Nelly",
    #|  "discriminator": "1337",
    #|  "global_name": null,
    #|  "avatar": "8342729096ea3675442027381ff50dfe",
    #|  "bot": false,
    #|  "system": false,
    #|  "mfa_enabled": true,
    #|  "banner": null,
    #|  "accent_color": null,
    #|  "locale": "en-US",
    #|  "verified": true,
    #|  "email": null,
    #|  "flags": 131072,
    #|  "premium_type": 2,
    #|  "public_flags": 131072,
    #|  "avatar_decoration": null,
    #|  "avatar_decoration_data": {
    #|    "asset": "a_1269e74af4df7417b13759eae50c83dc",
    #|    "sku_id": "1144058844004233369"
    #|  },
    #|  "brand_new_field_from_discord": true
    #|}
  let user : @model.User = @json.from_json(@json.parse(fixture))
  debug_inspect(
    user,
    content=(
      #|{
      #|  id: 80351110224678912,
      #|  username: "Nelly",
      #|  discriminator: "1337",
      #|  global_name: Some(Null),
      #|  avatar: Value("8342729096ea3675442027381ff50dfe"),
      #|  bot: Some(false),
      #|  system: Some(false),
      #|  mfa_enabled: Some(true),
      #|  banner: Some(Null),
      #|  accent_color: Some(Null),
      #|  locale: Some("en-US"),
      #|  verified: Some(true),
      #|  email: Some(Null),
      #|  flags: Some(131072),
      #|  premium_type: Some(Nitro),
      #|  public_flags: Some(131072),
      #|  avatar_decoration: Some(Null),
      #|  avatar_decoration_data: Some(
      #|    Value(
      #|      {
      #|        asset: "a_1269e74af4df7417b13759eae50c83dc",
      #|        sku_id: 1144058844004233369,
      #|      },
      #|    ),
      #|  ),
      #|  collectibles: None,
      #|  primary_guild: None,
      #|}
    ),
  )
}

///|
test "user decodes required fields only" {
  let fixture =
    #|{
    #|  "id": "80351110224678912",
    #|  "username": "Nelly",
    #|  "discriminator": "0",
    #|  "global_name": "Nelly",
    #|  "avatar": null
    #|}
  let user : @model.User = @json.from_json(@json.parse(fixture))
  debug_inspect(
    user,
    content=(
      #|{
      #|  id: 80351110224678912,
      #|  username: "Nelly",
      #|  discriminator: "0",
      #|  global_name: Some(Value("Nelly")),
      #|  avatar: Null,
      #|  bot: None,
      #|  system: None,
      #|  mfa_enabled: None,
      #|  banner: None,
      #|  accent_color: None,
      #|  locale: None,
      #|  verified: None,
      #|  email: None,
      #|  flags: None,
      #|  premium_type: None,
      #|  public_flags: None,
      #|  avatar_decoration: None,
      #|  avatar_decoration_data: None,
      #|  collectibles: None,
      #|  primary_guild: None,
      #|}
    ),
  )
}

///|
test "user encode omits absent optional fields" {
  let user : @model.User = {
    id: Id(1UL),
    username: "neko",
    discriminator: "0",
    global_name: Some(Value("Neko")),
    avatar: Null,
    bot: None,
    system: None,
    mfa_enabled: None,
    banner: None,
    accent_color: None,
    locale: None,
    verified: None,
    email: None,
    flags: None,
    premium_type: None,
    public_flags: None,
    avatar_decoration: None,
    avatar_decoration_data: None,
    collectibles: None,
    primary_guild: None,
  }
  inspect(
    user.to_json().stringify(),
    content=(
      #|{"id":"1","username":"neko","discriminator":"0","global_name":"Neko","avatar":null}
    ),
  )
}

///|
test "user flags combine and preserve unknown bits as a JSON number" {
  let flags = @model.UserFlags::staff() | @model.UserFlags::bug_hunter_level_2()
  inspect(
    flags.bits(),
    content=(
      #|16385
    ),
  )
  assert_true(flags.contains(@model.UserFlags::staff()))
  assert_false(flags.contains(@model.UserFlags::partner()))
  let encoded = flags.to_json().stringify()
  inspect(
    encoded,
    content=(
      #|16385
    ),
  )
  let decoded : @model.UserFlags = @json.from_json(@json.parse(encoded))
  assert_true(decoded == flags)
  let unknown_bits = (1UL << 60) | 1UL
  let unknown = @model.UserFlags::from_bits(unknown_bits)
  let unknown_json = unknown.to_json().stringify()
  inspect(
    unknown_json,
    content=(
      #|1152921504606846977
    ),
  )
  let unknown_round_trip : @model.UserFlags = @json.from_json(
    @json.parse(unknown_json),
  )
  assert_true(unknown_round_trip.bits() == unknown_bits)
}

///|
test "premium type round-trips known and unknown values" {
  let known : @model.PremiumType = @json.from_json(@json.parse("2"))
  debug_inspect(
    known,
    content=(
      #|Nitro
    ),
  )
  let unknown : @model.PremiumType = @json.from_json(@json.parse("99"))
  debug_inspect(
    unknown,
    content=(
      #|Unknown(99)
    ),
  )
  inspect(
    unknown.to_json().stringify(),
    content=(
      #|99
    ),
  )
  let round_trip : @model.PremiumType = @json.from_json(unknown.to_json())
  assert_true(round_trip == unknown)
}
