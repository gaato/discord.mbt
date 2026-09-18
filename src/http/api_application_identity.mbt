///|
fn validate_application_identity_profile_data(
  data : @model.ApplicationIdentityProfileData,
) -> Unit raise DiscordHttpError {
  if data.primary is Some(primary) {
    validate_length("profile primary season", primary.season, max=100)
    validate_length("profile primary rank_name", primary.rank_name, max=100)
    validate_length(
      "profile primary highest_rank",
      primary.highest_rank,
      max=100,
    )
    validate_length(
      "profile primary featured_played_character",
      primary.featured_played_character,
      max=100,
    )
  }
  if data.dynamic is Some(fields) {
    if fields.length() > 30 {
      raise Validation(message="profile dynamic fields exceed 30 entries")
    }
    for field in fields {
      let name = match field {
        StringField(value) => Some(value.name)
        NumberField(value) => Some(value.name)
        MediaField(value) => Some(value.name)
        Unknown(_) => None
      }
      validate_length("profile dynamic field name", name, max=100)
    }
  }
}

///|
/// Update the profile attached to an application identity.
///
/// Supplying `data` fully replaces the previous profile data. Omitting it
/// leaves the existing data untouched. Discord responds with either 201 on
/// the first write or 204 on later writes, so this wrapper intentionally
/// returns `Unit` without attempting to decode a response body.
pub async fn Client::update_application_identity_profile(
  self : Client,
  application_id~ : @model.ApplicationId,
  user_id~ : @model.UserId,
  provider_issued_user_id~ : String,
  username? : String,
  data? : @model.ApplicationIdentityProfileData,
) -> Unit raise DiscordHttpError {
  validate_length("application identity username", username, max=1024)
  if data is Some(value) {
    validate_application_identity_profile_data(value)
  }
  let body = @model.ObjBuilder()
    .opt("username", username)
    .opt("data", data)
    .build()
  self.request(
    UpdateApplicationIdentityProfile(
      application_id~,
      user_id~,
      provider_issued_user_id~,
    ),
    body~,
  )
  |> ignore
}

///|
/// Fetch the profile attached to an application identity.
pub async fn Client::get_application_identity_profile(
  self : Client,
  application_id~ : @model.ApplicationId,
  user_id~ : @model.UserId,
  provider_issued_user_id~ : String,
) -> @model.ApplicationIdentityProfile raise DiscordHttpError {
  decode(
    self.request(
      GetApplicationIdentityProfile(
        application_id~,
        user_id~,
        provider_issued_user_id~,
      ),
    ),
  )
}

///|
priv struct ApplicationIdentities {
  identities : Array[@model.ApplicationIdentity]
} derive(FromJson)

///|
/// List a user's external identities for an application (unwrapped from
/// Discord's `identities` envelope).
pub async fn Client::get_application_identities_by_user_id(
  self : Client,
  user_id~ : @model.UserId,
  application_id~ : @model.ApplicationId,
) -> Array[@model.ApplicationIdentity] raise DiscordHttpError {
  let envelope : ApplicationIdentities = decode(
    self.request(GetApplicationIdentitiesByUserId(user_id~, application_id~)),
  )
  envelope.identities
}

///|
/// Resolve application identities from an external provider identity. An
/// unmatched external id yields an empty array.
pub async fn Client::get_application_identities_by_external_id(
  self : Client,
  application_id~ : @model.ApplicationId,
  provider_type~ : String,
  provider_issued_user_id~ : String,
  provider_id? : String,
) -> Array[@model.ApplicationIdentity] raise DiscordHttpError {
  let query = match provider_id {
    Some(value) => "?provider_id=\{percent_encode(value)}"
    None => ""
  }
  let envelope : ApplicationIdentities = decode(
    self.request(
      GetApplicationIdentitiesByExternalId(
        application_id~,
        provider_type~,
        provider_issued_user_id~,
        query~,
      ),
    ),
  )
  envelope.identities
}

///|
/// Delete an application identity and its associated profile.
pub async fn Client::delete_application_identity(
  self : Client,
  user_id~ : @model.UserId,
  application_id~ : @model.ApplicationId,
  provider_type~ : String,
  provider_issued_user_id~ : String,
  provider_id? : String,
) -> Unit raise DiscordHttpError {
  let route = DeleteApplicationIdentity(
    user_id~,
    application_id~,
    provider_type~,
    provider_issued_user_id~,
  )
  match provider_id {
    Some(value) => self.request(route, body={ "provider_id": value }) |> ignore
    None => self.request(route) |> ignore
  }
}
