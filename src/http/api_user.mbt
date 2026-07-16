///|
/// Fetch the bot user's account.
pub async fn Client::get_current_user(
  self : Client,
) -> @model.User raise DiscordHttpError {
  decode(self.request(GetCurrentUser))
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
  decode(self.request(GetCurrentUserGuilds(query~)))
}

///|
/// Fetch a user by snowflake.
pub async fn Client::get_user(
  self : Client,
  user_id : @model.UserId,
) -> @model.User raise DiscordHttpError {
  decode(self.request(GetUser(user_id~)))
}

///|
/// Modify the bot user's username, avatar, or banner (both images as base64
/// data URIs).
pub async fn Client::modify_current_user(
  self : Client,
  username? : String,
  avatar? : String,
  clear_avatar? : Bool = false,
  banner? : String,
  clear_banner? : Bool = false,
) -> @model.User raise DiscordHttpError {
  validate_length("username", username, min=2, max=32)
  let body = @model.ObjBuilder()
    .opt("username", username)
    .und("avatar", patch_nullable("avatar", avatar, clear_avatar))
    .und("banner", patch_nullable("banner", banner, clear_banner))
    .build()
  decode(self.request(ModifyCurrentUser, body~))
}

///|
/// Create or reuse a direct-message channel with one recipient.
///
/// `create_dm` is idempotent for an existing one-to-one DM. Sending a message
/// can still fail when the recipient does not accept DMs from the bot.
///
/// # Example
///
/// Send a direct message by creating the DM channel first, then sending
/// through its channel ID:
///
/// ```mbt check
/// test "dm helper compiles" {
///   async fn dm_user(
///     client : @http.Client,
///     user_id : @model.UserId,
///     content : String,
///   ) -> @model.Message {
///     let channel = client.create_dm(user_id)
///     client.create_message(
///       channel.id,
///       content~,
///       allowed_mentions=@model.AllowedMentions::none(),
///     )
///   }
///
///   ignore(dm_user)
/// }
/// ```
pub async fn Client::create_dm(
  self : Client,
  recipient_id : @model.UserId,
) -> @model.Channel raise DiscordHttpError {
  let body = @model.ObjBuilder().field("recipient_id", recipient_id).build()
  decode(self.request(CreateDm, body~))
}

///|
/// List the external service accounts linked to the current user.
///
/// Requires an OAuth2 bearer token with the `connections` scope.
///
/// https://discord.com/developers/docs/resources/user#get-current-user-connections
pub async fn Client::get_current_user_connections(
  self : Client,
  bearer_token~ : String,
) -> Array[@model.Connection] raise DiscordHttpError {
  decode(
    self.request(
      GetCurrentUserConnections,
      headers=bearer_headers(bearer_token),
    ),
  )
}

///|
/// Fetch the current user's member record in a guild.
///
/// Requires an OAuth2 bearer token with the `guilds.members.read` scope.
///
/// https://discord.com/developers/docs/resources/user#get-current-user-guild-member
pub async fn Client::get_current_user_guild_member(
  self : Client,
  guild_id : @model.GuildId,
  bearer_token~ : String,
) -> @model.GuildMember raise DiscordHttpError {
  decode(
    self.request(
      GetCurrentUserGuildMember(guild_id~),
      headers=bearer_headers(bearer_token),
    ),
  )
}

///|
/// Leave a guild as the current user.
///
/// https://discord.com/developers/docs/resources/user#leave-guild
pub async fn Client::leave_guild(
  self : Client,
  guild_id : @model.GuildId,
) -> Unit raise DiscordHttpError {
  self.request(LeaveGuild(guild_id~)) |> ignore
}

///|
fn update_current_user_application_role_connection_body(
  platform_name : String?,
  platform_username : String?,
  metadata : Json?,
) -> Json raise DiscordHttpError {
  validate_length("platform_name", platform_name, max=50)
  validate_length("platform_username", platform_username, max=100)
  @model.ObjBuilder()
  .opt("platform_name", platform_name)
  .opt("platform_username", platform_username)
  .opt("metadata", metadata)
  .build()
}

///|
/// Fetch the current user's role connection for an application.
///
/// Requires an OAuth2 bearer token with the `role_connections.write` scope.
///
/// https://discord.com/developers/docs/resources/user#get-current-user-application-role-connection
pub async fn Client::get_current_user_application_role_connection(
  self : Client,
  application_id : @model.ApplicationId,
  bearer_token~ : String,
) -> @model.ApplicationRoleConnection raise DiscordHttpError {
  decode(
    self.request(
      GetCurrentUserApplicationRoleConnection(application_id~),
      headers=bearer_headers(bearer_token),
    ),
  )
}

///|
/// Update the current user's role connection for an application.
///
/// Requires an OAuth2 bearer token with the `role_connections.write` scope.
///
/// https://discord.com/developers/docs/resources/user#update-current-user-application-role-connection
pub async fn Client::update_current_user_application_role_connection(
  self : Client,
  application_id : @model.ApplicationId,
  platform_name? : String,
  platform_username? : String,
  metadata? : Json,
  bearer_token~ : String,
) -> @model.ApplicationRoleConnection raise DiscordHttpError {
  let body = update_current_user_application_role_connection_body(
    platform_name, platform_username, metadata,
  )
  decode(
    self.request(
      UpdateCurrentUserApplicationRoleConnection(application_id~),
      body~,
      headers=bearer_headers(bearer_token),
    ),
  )
}

///|
/// Delete the current user's role connection for an application.
///
/// Requires an OAuth2 bearer token with the `role_connections.write` scope.
///
/// https://docs.discord.com/developers/resources/user#delete-current-user-application-role-connection
pub async fn Client::delete_current_user_application_role_connection(
  self : Client,
  application_id : @model.ApplicationId,
  bearer_token~ : String,
) -> Unit raise DiscordHttpError {
  self.request(
    DeleteCurrentUserApplicationRoleConnection(application_id~),
    headers=bearer_headers(bearer_token),
  )
  |> ignore
}
