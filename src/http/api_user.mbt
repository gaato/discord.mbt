///|
/// Fetch the bot user's account.
pub async fn Client::get_current_user(
  self : Client,
) -> @model.User raise DiscordHttpError {
  decode(self.request(Route::GetCurrentUser))
}

///|
/// List guilds available to the current user.
pub async fn Client::get_current_user_guilds(
  self : Client,
  limit? : Int,
  before? : @model.GuildId,
  after? : @model.GuildId,
  with_counts? : Bool,
) -> Array[@model.CurrentUserGuild] raise DiscordHttpError {
  validate_page_limit("current user guild", limit, 200)
  validate_cursor_pair("current user guild", before, after)
  let params : Array[String] = []
  if limit is Some(value) {
    params.push("limit=\{value}")
  }
  if before is Some(value) {
    params.push("before=\{value}")
  }
  if after is Some(value) {
    params.push("after=\{value}")
  }
  if with_counts is Some(value) {
    params.push("with_counts=\{value}")
  }
  let query = if params.length() == 0 { "" } else { "?" + params.join("&") }
  decode(self.request(Route::GetCurrentUserGuilds(query~)))
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
  avatar? : String,
  clear_avatar? : Bool = false,
) -> @model.User raise DiscordHttpError {
  if username is Some(value) && (value.length() < 2 || value.length() > 32) {
    raise DiscordHttpError::Validation(
      message="username must be between 2 and 32 characters",
    )
  }
  let body = @model.ObjBuilder::new()
    .opt("username", username)
    .und("avatar", patch_nullable("avatar", avatar, clear_avatar))
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
