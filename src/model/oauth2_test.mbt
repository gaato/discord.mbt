///|
test "external connection decodes a realistic fixture" {
  let fixture =
    #|{
    #|  "id":"nelly","name":"Nelly","type":"github","revoked":false,
    #|  "integrations":[{"id":"raw","future":true}],
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
      #|  integrations: Some(Array([Object({ "id": String("raw"), "future": True })])),
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
