///|
/// Fetch the bot user's account.
pub async fn Client::get_current_user(
  self : Client,
) -> @model.User raise DiscordHttpError {
  decode(self.request(Route::GetCurrentUser))
}

///|
/// Fetch a user by snowflake.
pub async fn Client::get_user(
  self : Client,
  user_id : @model.UserId,
) -> @model.User raise DiscordHttpError {
  decode(self.request(Route::GetUser(user_id~)))
}

///|
/// Modify the bot user's username or avatar data URI.
pub async fn Client::modify_current_user(
  self : Client,
  username? : String,
  avatar? : @model.Undefinable[String] = Missing,
) -> @model.User raise DiscordHttpError {
  if username is Some(value) && (value.length() < 2 || value.length() > 32) {
    raise DiscordHttpError::Validation(
      message="username must be between 2 and 32 characters",
    )
  }
  let body = @model.ObjBuilder::new()
    .opt("username", username)
    .und("avatar", avatar)
    .build()
  decode(self.request(Route::ModifyCurrentUser, body~))
}

///|
/// Create or reuse a direct-message channel with one recipient.
pub async fn Client::create_dm(
  self : Client,
  recipient_id : @model.UserId,
) -> @model.Channel raise DiscordHttpError {
  let body = @model.ObjBuilder::new()
    .field("recipient_id", recipient_id)
    .build()
  decode(self.request(Route::CreateDm, body~))
}
