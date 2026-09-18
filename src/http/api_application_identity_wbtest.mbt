///|
async test "application identity clients pin routes query bodies and Unit responses" {
  let client = Client("test-token")
  defer client.close()
  let methods : Array[String] = []
  let paths : Array[String] = []
  let buckets : Array[String] = []
  let bodies : Array[Json] = []
  client.middleware((request, _next) => {
    methods.push(@debug.to_string(request.route.method_()))
    paths.push(request.route.path())
    buckets.push(request.route.bucket())
    bodies.push(request.body.unwrap_or(Json::null()))
    match request.route {
      UpdateApplicationIdentityProfile(..) =>
        { status: 201, headers: Map([]), body: Json::null(), }
      GetApplicationIdentityProfile(..) =>
        {
          status: 200,
          headers: Map([]),
          body: { "username": "player", "metadata": null, "data": null },
        }
      GetApplicationIdentitiesByUserId(..)
      | GetApplicationIdentitiesByExternalId(..) =>
        {
          status: 200,
          headers: Map([]),
          body: {
            "identities": [
              {
                "user_id": "20",
                "provider_type": "game/net work",
                "provider_issued_user_id": "a/b c",
              },
            ],
          },
        }
      DeleteApplicationIdentity(..) =>
        { status: 204, headers: Map([]), body: Json::null(), }
      _ => fail("unexpected route")
    }
  })
  let application_id : @model.ApplicationId = Id(10UL)
  let user_id : @model.UserId = Id(20UL)
  let data : @model.ApplicationIdentityProfileData = @json.from_json({
    "primary": { "rank_name": "Silver" },
    "dynamic": [{ "type": 1, "name": "mode", "value": "ranked" }],
  })
  client.update_application_identity_profile(
    application_id~,
    user_id~,
    provider_issued_user_id="a/b c",
    username="player",
    data~,
  )
  let profile = client.get_application_identity_profile(
    application_id~,
    user_id~,
    provider_issued_user_id="a/b c",
  )
  assert_true(profile.username == Value("player"))
  let by_user = client.get_application_identities_by_user_id(
    user_id~,
    application_id~,
  )
  assert_eq(by_user.length(), 1)
  let by_external = client.get_application_identities_by_external_id(
    application_id~,
    provider_type="game/net work",
    provider_issued_user_id="a/b c",
    provider_id="realm/one two",
  )
  assert_eq(by_external.length(), 1)
  client.delete_application_identity(
    user_id~,
    application_id~,
    provider_type="game/net work",
    provider_issued_user_id="a/b c",
    provider_id="realm/one two",
  )
  assert_eq(methods, ["Patch", "Get", "Get", "Get", "Post"])
  assert_eq(paths, [
    "/applications/10/users/20/identities/a%2Fb%20c/profile", "/applications/10/users/20/identities/a%2Fb%20c/profile",
    "/users/20/application-identities/10", "/applications/10/application-identities/game%2Fnet%20work/a%2Fb%20c?provider_id=realm%2Fone%20two",
    "/users/20/application-identities/10/game%2Fnet%20work/a%2Fb%20c/delete",
  ])
  assert_eq(buckets, [
    "PATCH:/applications/10/users/{}/identities/{}/profile", "GET:/applications/10/users/{}/identities/{}/profile",
    "GET:/users/{}/application-identities/10", "GET:/applications/10/application-identities/{}/{}",
    "POST:/users/{}/application-identities/10/{}/{}/delete",
  ])
  json_inspect(bodies[0], content={
    "username": "player",
    "data": {
      "primary": { "rank_name": "Silver" },
      "dynamic": [{ "name": "mode", "value": "ranked", "type": 1 }],
    },
  })
  assert_true(bodies[1] is Null)
  assert_true(bodies[2] is Null)
  assert_true(bodies[3] is Null)
  json_inspect(bodies[4], content={ "provider_id": "realm/one two" })
}

///|
async test "application identity optional PATCH and DELETE bodies are omitted" {
  let client = Client("test-token")
  defer client.close()
  let bodies : Array[Json?] = []
  client.middleware((request, _next) => {
    bodies.push(request.body)
    { status: 204, headers: Map([]), body: Json::null(), }
  })
  let application_id : @model.ApplicationId = Id(10UL)
  let user_id : @model.UserId = Id(20UL)
  client.update_application_identity_profile(
    application_id~,
    user_id~,
    provider_issued_user_id="external",
  )
  client.delete_application_identity(
    user_id~,
    application_id~,
    provider_type="NONE",
    provider_issued_user_id="external",
  )
  assert_eq(bodies.length(), 2)
  guard bodies[0] is Some(update_body) else { fail("expected PATCH body") }
  inspect(update_body.stringify(), content="{}")
  assert_true(bodies[1] is None)
}

///|
async test "application identity profile validates documented client-side limits" {
  let client = Client("test-token")
  defer client.close()
  let application_id : @model.ApplicationId = Id(10UL)
  let user_id : @model.UserId = Id(20UL)
  let too_many : Array[@model.ApplicationIdentityDynamicField] = []
  for i in 0..<31 {
    too_many.push(StringField({ name: "field-\{i}", value: "value", }))
  }
  try
    client.update_application_identity_profile(
      application_id~,
      user_id~,
      provider_issued_user_id="external",
      data={ primary: None, dynamic: Some(too_many), },
    )
  catch {
    Validation(message~) =>
      inspect(message, content="profile dynamic fields exceed 30 entries")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected dynamic field count validation")
  }
  try
    client.update_application_identity_profile(
      application_id~,
      user_id~,
      provider_issued_user_id="external",
      username=String::make(1025, 'x'),
    )
  catch {
    Validation(message~) =>
      inspect(
        message,
        content="application identity username exceeds 1024 characters",
      )
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected username validation")
  }
  let long_primary : @model.ApplicationIdentityProfileData = @json.from_json({
    "primary": { "rank_name": String::make(101, 'x') },
  })
  try validate_application_identity_profile_data(long_primary) catch {
    Validation(message~) =>
      inspect(
        message,
        content="profile primary rank_name exceeds 100 characters",
      )
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected primary string validation")
  }
  let long_name : @model.ApplicationIdentityProfileData = @json.from_json({
    "dynamic": [
      { "type": 1, "name": String::make(101, 'x'), "value": "unbounded" },
    ],
  })
  try validate_application_identity_profile_data(long_name) catch {
    Validation(message~) =>
      inspect(
        message,
        content="profile dynamic field name exceeds 100 characters",
      )
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected dynamic name validation")
  }
}
