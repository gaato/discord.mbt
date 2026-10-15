///|
test "external connection decodes a realistic fixture" {
  let fixture =
    #|{
    #|  "id":"nelly","name":"Nelly","type":"github","revoked":false,
    #|  "integrations":[{"id":"33590653072239123","future":true}],
    #|  "verified":true,"friend_sync":false,"show_activity":true,
    #|  "two_way_link":false,"visibility":1,
    #|  "brand_new_field_from_discord":true
    #|}
  let connection : @model.Connection = @json.from_json(@json.parse(fixture))
  debug_inspect(
    connection,
    content=(
      #|{
      #|  id: "nelly",
      #|  name: "Nelly",
      #|  typ: Github,
      #|  revoked: Some(false),
      #|  integrations: Some(
      #|    [
      #|      {
      #|        id: Some(33590653072239123),
      #|        name: None,
      #|        typ: None,
      #|        enabled: None,
      #|        syncing: None,
      #|        role_id: None,
      #|        enable_emoticons: None,
      #|        expire_behavior: None,
      #|        expire_grace_period: None,
      #|        user: None,
      #|        account: None,
      #|        synced_at: None,
      #|        subscriber_count: None,
      #|        revoked: None,
      #|        application: None,
      #|        application_id: None,
      #|        scopes: None,
      #|      },
      #|    ],
      #|  ),
      #|  verified: true,
      #|  friend_sync: false,
      #|  show_activity: true,
      #|  two_way_link: false,
      #|  visibility: 1,
      #|}
    ),
  )
}

///|
test "connection service and role metadata preserve unknown values" {
  let service : @model.ConnectionService = @json.from_json(
    @json.parse("\"future-service\""),
  )
  debug_inspect(
    service,
    content=(
      #|Unknown("future-service")
    ),
  )
  inspect(
    service.to_json().stringify(),
    content=(
      #|"future-service"
    ),
  )
  let role_fixture =
    #|{"platform_name":null,"platform_username":"nelly","metadata":{"level":"42","score":9001,"future":true}}
  let role_connection : @model.ApplicationRoleConnection = @json.from_json(
    @json.parse(role_fixture),
  )
  debug_inspect(
    role_connection,
    content=(
      #|{
      #|  platform_name: Null,
      #|  platform_username: Value("nelly"),
      #|  metadata: Object({ "level": String("42"), "score": Number(9001), "future": True }),
      #|}
    ),
  )
  inspect(
    role_connection.to_json().stringify(),
    content=(
      #|{"platform_name":null,"platform_username":"nelly","metadata":{"level":"42","score":9001,"future":true}}
    ),
  )
}

///|
test "authorization information round-trips the documented response shape" {
  let fixture =
    #|{"application":{"id":"172150183260323840","name":"Example App","icon":null,"description":"An example OAuth2 application"},"scopes":["identify","applications.commands"],"expires":"2021-01-01T00:00:00.000000+00:00","user":{"id":"80351110224678912","username":"Nelly","discriminator":"1337","global_name":"Nelly","avatar":"8342729096ea3675442027381ff50dfe","public_flags":131072}}
  let first : @model.AuthorizationInformation = @json.from_json(
    @json.parse(fixture),
  )
  json_inspect(first.to_json(), content={
    "application": {
      "id": "172150183260323840",
      "name": "Example App",
      "icon": Json::null(),
      "description": "An example OAuth2 application",
    },
    "scopes": ["identify", "applications.commands"],
    "expires": "2021-01-01T00:00:00.000000+00:00",
    "user": {
      "id": "80351110224678912",
      "username": "Nelly",
      "discriminator": "1337",
      "global_name": "Nelly",
      "avatar": "8342729096ea3675442027381ff50dfe",
      "public_flags": 131072,
    },
  })
  let second : @model.AuthorizationInformation = @json.from_json(
    first.to_json(),
  )
  assert_eq(second.to_json().stringify(), first.to_json().stringify())
}
