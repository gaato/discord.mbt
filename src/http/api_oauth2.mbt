///|
fn bearer_headers(bearer_token : String) -> Map[String, String] {
  { "authorization": "Bearer \{bearer_token}" }
}

///|
/// Fetch information about the authorization represented by a bearer token.
///
/// Requires a valid OAuth2 bearer token; this endpoint has no additional scope
/// requirement. The token's granted scopes are returned in the response, and
/// the `user` field is present only when the token has the `identify` scope.
///
/// https://discord.com/developers/docs/topics/oauth2#get-current-authorization-information
pub async fn Client::get_current_authorization_information(
  self : Client,
  bearer_token~ : String,
) -> @model.AuthorizationInformation raise DiscordHttpError {
  decode(
    self.request(
      GetCurrentAuthorizationInformation,
      headers=bearer_headers(bearer_token),
    ),
  )
}

///|
/// Fetch the current bot application's information.
///
/// https://discord.com/developers/docs/topics/oauth2#get-current-bot-application-information
pub async fn Client::get_current_bot_application_information(
  self : Client,
) -> @model.Application raise DiscordHttpError {
  decode(self.request(GetCurrentBotApplicationInformation))
}
