///|
fn application_identity_route_signature(route : Route) -> String {
  "\{@debug.to_string(route.method_())} \{route.path()} | \{route.bucket()}"
}

///|
test "application identity routes pin methods encoded paths queries and buckets" {
  let application_id : @model.ApplicationId = Id(10UL)
  let user_id : @model.UserId = Id(20UL)
  let provider_type = "game/net work"
  let provider_user_id = "a/b c"
  let query = "?provider_id=realm%2Fone%20two"
  inspect(
    application_identity_route_signature(
      UpdateApplicationIdentityProfile(
        application_id~,
        user_id~,
        provider_issued_user_id=provider_user_id,
      ),
    ),
    content="Patch /applications/10/users/20/identities/a%2Fb%20c/profile | PATCH:/applications/10/users/{}/identities/{}/profile",
  )
  inspect(
    application_identity_route_signature(
      GetApplicationIdentityProfile(
        application_id~,
        user_id~,
        provider_issued_user_id=provider_user_id,
      ),
    ),
    content="Get /applications/10/users/20/identities/a%2Fb%20c/profile | GET:/applications/10/users/{}/identities/{}/profile",
  )
  inspect(
    application_identity_route_signature(
      GetApplicationIdentitiesByUserId(user_id~, application_id~),
    ),
    content="Get /users/20/application-identities/10 | GET:/users/{}/application-identities/10",
  )
  inspect(
    application_identity_route_signature(
      GetApplicationIdentitiesByExternalId(
        application_id~,
        provider_type~,
        provider_issued_user_id=provider_user_id,
        query~,
      ),
    ),
    content="Get /applications/10/application-identities/game%2Fnet%20work/a%2Fb%20c?provider_id=realm%2Fone%20two | GET:/applications/10/application-identities/{}/{}",
  )
  inspect(
    application_identity_route_signature(
      DeleteApplicationIdentity(
        user_id~,
        application_id~,
        provider_type~,
        provider_issued_user_id=provider_user_id,
      ),
    ),
    content="Post /users/20/application-identities/10/game%2Fnet%20work/a%2Fb%20c/delete | POST:/users/{}/application-identities/10/{}/{}/delete",
  )
}
