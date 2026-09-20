///|
async test "application identity ref binds all identifiers and delegates profile updates" {
  let client = Client("test-token")
  defer client.close()
  let paths : Array[String] = []
  client.middleware((request, _next) => {
    paths.push(request.route.path())
    match request.route {
      UpdateApplicationIdentityProfile(..) => {
        assert_eq(@debug.to_string(request.route.method_()), "Patch")
        assert_eq(request.body, Some({ "username": "player" }))
      }
      DeleteApplicationIdentity(..) => {
        assert_eq(@debug.to_string(request.route.method_()), "Post")
        assert_eq(request.body, Some({ "provider_id": "realm" }))
      }
      _ => fail("unexpected route")
    }
    { status: 204, headers: Map([]), body: Json::null(), }
  })
  let identity = client
    .application_ref(Id(10UL))
    .identity_ref(
      user_id=Id(20UL),
      provider_type="game/net",
      provider_issued_user_id="a/b c",
    )
  identity.update_profile(username="player")
  identity.delete(provider_id="realm")
  assert_eq(paths, [
    "/applications/10/users/20/identities/a%2Fb%20c/profile", "/users/20/application-identities/10/game%2Fnet/a%2Fb%20c/delete",
  ])
}

///|
async test "application identity refs delegate collection and item verbs" {
  let client = Client("test-token")
  defer client.close()
  let paths : Array[String] = []
  client.middleware((request, _next) => {
    paths.push(request.route.path())
    match request.route {
      GetApplicationIdentityProfile(..) =>
        {
          status: 200,
          headers: Map([]),
          body: { "username": null, "metadata": null, "data": null },
        }
      GetApplicationIdentitiesByUserId(..)
      | GetApplicationIdentitiesByExternalId(..) =>
        { status: 200, headers: Map([]), body: { "identities": [] }, }
      UpdateApplicationIdentityProfile(..) | DeleteApplicationIdentity(..) =>
        { status: 204, headers: Map([]), body: Json::null(), }
      _ => fail("unexpected route")
    }
  })
  let application_id : @model.ApplicationId = Id(10UL)
  let user_id : @model.UserId = Id(20UL)
  let application = client.application_ref(application_id)
  let user = client.user_ref(user_id)
  application.identities_by_user_id(user_id~) |> ignore
  application.identities_by_external_id(
    provider_type="steam",
    provider_issued_user_id="a/b c",
  )
  |> ignore
  user.application_identities(application_id~) |> ignore
  let identity = user.application_identity_ref(
    application_id~,
    provider_type="steam",
    provider_issued_user_id="a/b c",
  )
  identity.profile() |> ignore
  identity.update_profile(username="player")
  identity.delete(provider_id="pc")
  assert_eq(paths, [
    "/users/20/application-identities/10", "/applications/10/application-identities/steam/a%2Fb%20c",
    "/users/20/application-identities/10", "/applications/10/users/20/identities/a%2Fb%20c/profile",
    "/applications/10/users/20/identities/a%2Fb%20c/profile", "/users/20/application-identities/10/steam/a%2Fb%20c/delete",
  ])
}
