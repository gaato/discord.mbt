///|
test "role decodes a full fixture" {
  let fixture =
    #|{
    #|  "id": "41771983423143936",
    #|  "name": "WE DEM BOYZZ!!!!!!",
    #|  "color": 3447003,
    #|  "colors": {
    #|    "primary_color": 3447003,
    #|    "secondary_color": null,
    #|    "tertiary_color": null
    #|  },
    #|  "hoist": true,
    #|  "icon": "a_1269e74af4df7417b13759eae50c83dc",
    #|  "unicode_emoji": null,
    #|  "position": 1,
    #|  "permissions": "66321471",
    #|  "managed": false,
    #|  "mentionable": false,
    #|  "tags": {
    #|    "bot_id": "80351110224678912",
    #|    "premium_subscriber": null,
    #|    "integration_id": "81384788765712384",
    #|    "subscription_listing_id": "1144058844004233369",
    #|    "available_for_purchase": null,
    #|    "guild_connections": null
    #|  },
    #|  "flags": 1,
    #|  "brand_new_field_from_discord": true
    #|}
  let role : @model.Role = @json.from_json(@json.parse(fixture))
  debug_inspect(
    role,
    content=(
      #|{
      #|  id: 41771983423143936,
      #|  name: "WE DEM BOYZZ!!!!!!",
      #|  color: 3447003,
      #|  colors: Some(
      #|    {
      #|      primary_color: 3447003,
      #|      secondary_color: Null,
      #|      tertiary_color: Null,
      #|    },
      #|  ),
      #|  hoist: true,
      #|  icon: Some(Value("a_1269e74af4df7417b13759eae50c83dc")),
      #|  unicode_emoji: Some(Null),
      #|  position: 1,
      #|  permissions: 66321471,
      #|  managed: false,
      #|  mentionable: false,
      #|  tags: Some(
      #|    {
      #|      bot_id: Some(80351110224678912),
      #|      premium_subscriber: true,
      #|      integration_id: Some(81384788765712384),
      #|      subscription_listing_id: Some(1144058844004233369),
      #|      available_for_purchase: true,
      #|      guild_connections: true,
      #|    },
      #|  ),
      #|  flags: Some(1),
      #|}
    ),
  )
}

///|
test "role decodes required fields only" {
  let fixture =
    #|{
    #|  "id": "41771983423143936",
    #|  "name": "members",
    #|  "color": 0,
    #|  "hoist": false,
    #|  "position": 0,
    #|  "permissions": "0",
    #|  "managed": false,
    #|  "mentionable": false,
    #|  "flags": 0
    #|}
  let role : @model.Role = @json.from_json(@json.parse(fixture))
  debug_inspect(
    role,
    content=(
      #|{
      #|  id: 41771983423143936,
      #|  name: "members",
      #|  color: 0,
      #|  colors: None,
      #|  hoist: false,
      #|  icon: None,
      #|  unicode_emoji: None,
      #|  position: 0,
      #|  permissions: 0,
      #|  managed: false,
      #|  mentionable: false,
      #|  tags: None,
      #|  flags: Some(0),
      #|}
    ),
  )
}

///|
test "role encode omits absent optional fields" {
  let role = @model.Role::{
    id: Id(1UL),
    name: "members",
    color: 0,
    colors: None,
    hoist: false,
    icon: None,
    unicode_emoji: None,
    position: 0,
    permissions: @model.Permissions::none(),
    managed: false,
    mentionable: false,
    tags: None,
    flags: Some(@model.RoleFlags::none()),
  }
  inspect(
    role.to_json().stringify(),
    content=(
      #|{"id":"1","name":"members","color":0,"hoist":false,"position":0,"permissions":"0","managed":false,"mentionable":false,"flags":0}
    ),
  )
}

///|
test "role tags presence markers map null to true and absence to false" {
  let present : @model.RoleTags = @json.from_json(
    @json.parse(
      (
        #|{
        #|  "bot_id": "80351110224678912",
        #|  "premium_subscriber": null,
        #|  "integration_id": "81384788765712384",
        #|  "subscription_listing_id": "1144058844004233369",
        #|  "available_for_purchase": null,
        #|  "guild_connections": null
        #|}
      ),
    ),
  )
  debug_inspect(
    present,
    content=(
      #|{
      #|  bot_id: Some(80351110224678912),
      #|  premium_subscriber: true,
      #|  integration_id: Some(81384788765712384),
      #|  subscription_listing_id: Some(1144058844004233369),
      #|  available_for_purchase: true,
      #|  guild_connections: true,
      #|}
    ),
  )
  inspect(
    present.to_json().stringify(),
    content=(
      #|{"bot_id":"80351110224678912","premium_subscriber":null,"integration_id":"81384788765712384","subscription_listing_id":"1144058844004233369","available_for_purchase":null,"guild_connections":null}
    ),
  )
  let round_trip : @model.RoleTags = @json.from_json(present.to_json())
  assert_true(round_trip == present)
  let absent : @model.RoleTags = @json.from_json(@json.parse("{}"))
  debug_inspect(
    absent,
    content=(
      #|{
      #|  bot_id: None,
      #|  premium_subscriber: false,
      #|  integration_id: None,
      #|  subscription_listing_id: None,
      #|  available_for_purchase: false,
      #|  guild_connections: false,
      #|}
    ),
  )
  inspect(
    absent.to_json().stringify(),
    content=(
      #|{}
    ),
  )
}

///|
test "role flags serialize as a number and preserve unknown bits" {
  let flags = @model.RoleFlags::in_prompt()
  assert_true(flags.contains(@model.RoleFlags::in_prompt()))
  inspect(
    flags.to_json().stringify(),
    content=(
      #|1
    ),
  )
  let unknown_bits = (1UL << 60) | 1UL
  let unknown = @model.RoleFlags::from_bits(unknown_bits)
  let encoded = unknown.to_json().stringify()
  inspect(
    encoded,
    content=(
      #|1152921504606846977
    ),
  )
  let decoded : @model.RoleFlags = @json.from_json(@json.parse(encoded))
  assert_true(decoded.bits() == unknown_bits)
}
