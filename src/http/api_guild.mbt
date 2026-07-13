///|
/// Fetch a guild, optionally including approximate member counts.
pub async fn Client::get_guild(
  self : Client,
  guild_id : @model.GuildId,
  with_counts? : Bool,
) -> @model.Guild raise DiscordHttpError {
  let route = match with_counts {
    None => Route::GetGuild(guild_id~)
    Some(value) =>
      Route::GetGuildWithCounts(guild_id~, query="?with_counts=\{value}")
  }
  decode(self.request(route))
}

///|
/// List the channels in a guild.
pub async fn Client::get_guild_channels(
  self : Client,
  guild_id : @model.GuildId,
) -> Array[@model.Channel] raise DiscordHttpError {
  decode(self.request(Route::GetGuildChannels(guild_id~)))
}

///|
/// Create a channel in a guild.
pub async fn Client::create_guild_channel(
  self : Client,
  guild_id : @model.GuildId,
  name : String,
  typ? : @model.ChannelType,
  topic? : String,
  parent_id? : @model.ChannelId,
  position? : Int,
  permission_overwrites? : Array[@model.Overwrite],
  nsfw? : Bool,
  bitrate? : Int,
  user_limit? : Int,
  rate_limit_per_user? : Int,
  audit_reason? : String,
) -> @model.Channel raise DiscordHttpError {
  if name.length() < 1 || name.length() > 100 {
    raise DiscordHttpError::Validation(
      message="channel name must be between 1 and 100 characters",
    )
  }
  if topic is Some(value) && value.length() > 4096 {
    raise DiscordHttpError::Validation(
      message="channel topic exceeds 4096 characters",
    )
  }
  if rate_limit_per_user is Some(value) && (value < 0 || value > 21600) {
    raise DiscordHttpError::Validation(
      message="rate_limit_per_user must be between 0 and 21600",
    )
  }
  let body = @model.ObjBuilder::new()
    .field("name", name)
    .opt("type", typ)
    .opt("topic", topic)
    .opt("parent_id", parent_id)
    .opt("position", position)
    .opt("permission_overwrites", permission_overwrites)
    .opt("nsfw", nsfw)
    .opt("bitrate", bitrate)
    .opt("user_limit", user_limit)
    .opt("rate_limit_per_user", rate_limit_per_user)
    .build()
  decode(
    self.request(Route::CreateGuildChannel(guild_id~), body~, audit_reason?),
  )
}

///|
/// Fetch one guild member.
pub async fn Client::get_guild_member(
  self : Client,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
) -> @model.GuildMember raise DiscordHttpError {
  decode(self.request(Route::GetGuildMember(guild_id~, user_id~)))
}

///|
/// List guild members after an optional user snowflake.
pub async fn Client::list_guild_members(
  self : Client,
  guild_id : @model.GuildId,
  limit? : Int,
  after? : @model.UserId,
) -> Array[@model.GuildMember] raise DiscordHttpError {
  if limit is Some(value) && (value < 1 || value > 1000) {
    raise DiscordHttpError::Validation(
      message="member limit must be 1 through 1000",
    )
  }
  let params : Array[String] = []
  if limit is Some(value) {
    params.push("limit=\{value}")
  }
  if after is Some(value) {
    params.push("after=\{value}")
  }
  let query = if params.length() == 0 { "" } else { "?" + params.join("&") }
  decode(self.request(Route::ListGuildMembers(guild_id~, query~)))
}

///|
/// Search guild members. The query string must already be URL-encoded.
pub async fn Client::search_guild_members(
  self : Client,
  guild_id : @model.GuildId,
  query : String,
  limit? : Int,
) -> Array[@model.GuildMember] raise DiscordHttpError {
  if query.length() == 0 {
    raise DiscordHttpError::Validation(message="member query must not be empty")
  }
  if limit is Some(value) && (value < 1 || value > 1000) {
    raise DiscordHttpError::Validation(
      message="member limit must be 1 through 1000",
    )
  }
  let suffix = match limit {
    None => "?query=\{query}"
    Some(value) => "?query=\{query}&limit=\{value}"
  }
  decode(self.request(Route::SearchGuildMembers(guild_id~, query=suffix)))
}

///|
/// Modify a guild member, preserving omit-versus-null PATCH semantics.
pub async fn Client::modify_guild_member(
  self : Client,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
  nick? : @model.Undefinable[String] = Missing,
  roles? : @model.Undefinable[Array[@model.RoleId]] = Missing,
  mute? : @model.Undefinable[Bool] = Missing,
  deaf? : @model.Undefinable[Bool] = Missing,
  channel_id? : @model.Undefinable[@model.ChannelId] = Missing,
  communication_disabled_until? : @model.Undefinable[@model.Timestamp] = Missing,
  audit_reason? : String,
) -> @model.GuildMember raise DiscordHttpError {
  let body = @model.ObjBuilder::new()
    .und("nick", nick)
    .und("roles", roles)
    .und("mute", mute)
    .und("deaf", deaf)
    .und("channel_id", channel_id)
    .und("communication_disabled_until", communication_disabled_until)
    .build()
  decode(
    self.request(
      Route::ModifyGuildMember(guild_id~, user_id~),
      body~,
      audit_reason?,
    ),
  )
}

///|
/// Add a role to a guild member.
pub async fn Client::add_member_role(
  self : Client,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
  role_id : @model.RoleId,
  audit_reason? : String,
) -> Unit raise DiscordHttpError {
  self.request(
    Route::AddGuildMemberRole(guild_id~, user_id~, role_id~),
    audit_reason?,
  )
  |> ignore
}

///|
/// Remove a role from a guild member.
pub async fn Client::remove_member_role(
  self : Client,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
  role_id : @model.RoleId,
  audit_reason? : String,
) -> Unit raise DiscordHttpError {
  self.request(
    Route::RemoveGuildMemberRole(guild_id~, user_id~, role_id~),
    audit_reason?,
  )
  |> ignore
}

///|
/// Remove a member from a guild.
pub async fn Client::remove_guild_member(
  self : Client,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
  audit_reason? : String,
) -> Unit raise DiscordHttpError {
  self.request(Route::RemoveGuildMember(guild_id~, user_id~), audit_reason?)
  |> ignore
}

///|
/// Ban a user from a guild.
pub async fn Client::create_guild_ban(
  self : Client,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
  delete_message_seconds? : Int,
  audit_reason? : String,
) -> Unit raise DiscordHttpError {
  if delete_message_seconds is Some(value) && (value < 0 || value > 604800) {
    raise DiscordHttpError::Validation(
      message="delete_message_seconds must be between 0 and 604800",
    )
  }
  let body = @model.ObjBuilder::new()
    .opt("delete_message_seconds", delete_message_seconds)
    .build()
  self.request(Route::CreateGuildBan(guild_id~, user_id~), body~, audit_reason?)
  |> ignore
}

///|
/// Remove a guild ban.
pub async fn Client::remove_guild_ban(
  self : Client,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
  audit_reason? : String,
) -> Unit raise DiscordHttpError {
  self.request(Route::RemoveGuildBan(guild_id~, user_id~), audit_reason?)
  |> ignore
}

///|
/// List the roles in a guild.
pub async fn Client::get_guild_roles(
  self : Client,
  guild_id : @model.GuildId,
) -> Array[@model.Role] raise DiscordHttpError {
  decode(self.request(Route::GetGuildRoles(guild_id~)))
}

///|
/// Create a guild role.
pub async fn Client::create_guild_role(
  self : Client,
  guild_id : @model.GuildId,
  name? : String,
  permissions? : @model.Permissions,
  color? : Int,
  hoist? : Bool,
  mentionable? : Bool,
  audit_reason? : String,
) -> @model.Role raise DiscordHttpError {
  if name is Some(value) && (value.length() < 1 || value.length() > 100) {
    raise DiscordHttpError::Validation(
      message="role name must be between 1 and 100 characters",
    )
  }
  let body = @model.ObjBuilder::new()
    .opt("name", name)
    .opt("permissions", permissions)
    .opt("color", color)
    .opt("hoist", hoist)
    .opt("mentionable", mentionable)
    .build()
  decode(self.request(Route::CreateGuildRole(guild_id~), body~, audit_reason?))
}

///|
/// Modify a guild role, preserving omit-versus-null PATCH semantics.
pub async fn Client::modify_guild_role(
  self : Client,
  guild_id : @model.GuildId,
  role_id : @model.RoleId,
  name? : @model.Undefinable[String] = Missing,
  permissions? : @model.Undefinable[@model.Permissions] = Missing,
  color? : @model.Undefinable[Int] = Missing,
  hoist? : @model.Undefinable[Bool] = Missing,
  mentionable? : @model.Undefinable[Bool] = Missing,
  audit_reason? : String,
) -> @model.Role raise DiscordHttpError {
  if name is Value(value) && (value.length() < 1 || value.length() > 100) {
    raise DiscordHttpError::Validation(
      message="role name must be between 1 and 100 characters",
    )
  }
  let body = @model.ObjBuilder::new()
    .und("name", name)
    .und("permissions", permissions)
    .und("color", color)
    .und("hoist", hoist)
    .und("mentionable", mentionable)
    .build()
  decode(
    self.request(
      Route::ModifyGuildRole(guild_id~, role_id~),
      body~,
      audit_reason?,
    ),
  )
}

///|
/// Delete a guild role.
pub async fn Client::delete_guild_role(
  self : Client,
  guild_id : @model.GuildId,
  role_id : @model.RoleId,
  audit_reason? : String,
) -> Unit raise DiscordHttpError {
  self.request(Route::DeleteGuildRole(guild_id~, role_id~), audit_reason?)
  |> ignore
}
