///|
/// Fetch a guild, optionally including approximate member counts.
pub async fn Client::get_guild(
  self : Client,
  guild_id : @model.GuildId,
  with_counts? : Bool,
) -> @model.Guild raise DiscordHttpError {
  let route = match with_counts {
    None => Route::GetGuild(guild_id~)
    Some(value) => GetGuildWithCounts(guild_id~, query="?with_counts=\{value}")
  }
  decode(self.request(route))
}

///|
/// Modify guild settings. Nullable fields use a matching `clear_*` flag so
/// omission remains distinct from sending JSON null.
pub async fn Client::modify_guild(
  self : Client,
  guild_id : @model.GuildId,
  name? : String,
  verification_level? : @model.VerificationLevel,
  default_message_notifications? : @model.DefaultMessageNotifications,
  explicit_content_filter? : @model.ExplicitContentFilter,
  afk_channel_id? : @model.ChannelId,
  clear_afk_channel_id? : Bool = false,
  afk_timeout? : Int,
  icon? : String,
  clear_icon? : Bool = false,
  owner_id? : @model.UserId,
  splash? : String,
  clear_splash? : Bool = false,
  discovery_splash? : String,
  clear_discovery_splash? : Bool = false,
  banner? : String,
  clear_banner? : Bool = false,
  system_channel_id? : @model.ChannelId,
  clear_system_channel_id? : Bool = false,
  system_channel_flags? : @model.SystemChannelFlags,
  rules_channel_id? : @model.ChannelId,
  clear_rules_channel_id? : Bool = false,
  public_updates_channel_id? : @model.ChannelId,
  clear_public_updates_channel_id? : Bool = false,
  preferred_locale? : String,
  features? : Array[@model.GuildFeature],
  description? : String,
  clear_description? : Bool = false,
  premium_progress_bar_enabled? : Bool,
  safety_alerts_channel_id? : @model.ChannelId,
  clear_safety_alerts_channel_id? : Bool = false,
  audit_reason? : String,
) -> @model.Guild raise DiscordHttpError {
  if name is Some(value) && (value.length() < 2 || value.length() > 100) {
    raise Validation(message="guild name must be between 2 and 100 characters")
  }
  if description is Some(value) && value.length() > 120 {
    raise Validation(message="guild description exceeds 120 characters")
  }
  let body = @model.ObjBuilder()
    .opt("name", name)
    .opt("verification_level", verification_level)
    .opt("default_message_notifications", default_message_notifications)
    .opt("explicit_content_filter", explicit_content_filter)
    .und(
      "afk_channel_id",
      patch_nullable("afk_channel_id", afk_channel_id, clear_afk_channel_id),
    )
    .opt("afk_timeout", afk_timeout)
    .und("icon", patch_nullable("icon", icon, clear_icon))
    .opt("owner_id", owner_id)
    .und("splash", patch_nullable("splash", splash, clear_splash))
    .und(
      "discovery_splash",
      patch_nullable(
        "discovery_splash", discovery_splash, clear_discovery_splash,
      ),
    )
    .und("banner", patch_nullable("banner", banner, clear_banner))
    .und(
      "system_channel_id",
      patch_nullable(
        "system_channel_id", system_channel_id, clear_system_channel_id,
      ),
    )
    .opt("system_channel_flags", system_channel_flags)
    .und(
      "rules_channel_id",
      patch_nullable(
        "rules_channel_id", rules_channel_id, clear_rules_channel_id,
      ),
    )
    .und(
      "public_updates_channel_id",
      patch_nullable(
        "public_updates_channel_id", public_updates_channel_id, clear_public_updates_channel_id,
      ),
    )
    .opt("preferred_locale", preferred_locale)
    .opt("features", features)
    .und(
      "description",
      patch_nullable("description", description, clear_description),
    )
    .opt("premium_progress_bar_enabled", premium_progress_bar_enabled)
    .und(
      "safety_alerts_channel_id",
      patch_nullable(
        "safety_alerts_channel_id", safety_alerts_channel_id, clear_safety_alerts_channel_id,
      ),
    )
    .build()
  decode(self.request(ModifyGuild(guild_id~), body~, audit_reason?))
}

///|
/// Fetch a guild audit log with optional actor, action, and snowflake filters.
pub async fn Client::get_guild_audit_log(
  self : Client,
  guild_id : @model.GuildId,
  user_id? : @model.UserId,
  action_type? : @model.AuditLogEvent,
  before? : @model.AuditLogEntryId,
  after? : @model.AuditLogEntryId,
  limit? : Int,
) -> @model.AuditLog raise DiscordHttpError {
  validate_cursor_pair("audit log", before, after)
  if limit is Some(value) && (value < 1 || value > 100) {
    raise Validation(message="audit log limit must be 1 through 100")
  }
  let params : Array[String] = []
  if user_id is Some(value) {
    params.push("user_id=\{value}")
  }
  if action_type is Some(value) {
    params.push("action_type=\{value.to_int()}")
  }
  if before is Some(value) {
    params.push("before=\{value}")
  }
  if after is Some(value) {
    params.push("after=\{value}")
  }
  if limit is Some(value) {
    params.push("limit=\{value}")
  }
  let query = if params.length() == 0 { "" } else { "?" + params.join("&") }
  decode(self.request(GetGuildAuditLog(guild_id~, query~)))
}

///|
/// List bans in a guild using before/after snowflake pagination.
pub async fn Client::get_guild_bans(
  self : Client,
  guild_id : @model.GuildId,
  limit? : Int,
  before? : @model.UserId,
  after? : @model.UserId,
) -> Array[@model.GuildBan] raise DiscordHttpError {
  if limit is Some(value) && (value < 1 || value > 1000) {
    raise Validation(message="guild ban limit must be 1 through 1000")
  }
  validate_cursor_pair("guild ban", before, after)
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
  let query = if params.length() == 0 { "" } else { "?" + params.join("&") }
  decode(self.request(GetGuildBans(guild_id~, query~)))
}

///|
/// List the channels in a guild.
pub async fn Client::get_guild_channels(
  self : Client,
  guild_id : @model.GuildId,
) -> Array[@model.Channel] raise DiscordHttpError {
  decode(self.request(GetGuildChannels(guild_id~)))
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
    raise Validation(
      message="channel name must be between 1 and 100 characters",
    )
  }
  if topic is Some(value) && value.length() > 4096 {
    raise Validation(message="channel topic exceeds 4096 characters")
  }
  if rate_limit_per_user is Some(value) && (value < 0 || value > 21600) {
    raise Validation(message="rate_limit_per_user must be between 0 and 21600")
  }
  let body = @model.ObjBuilder()
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
  decode(self.request(CreateGuildChannel(guild_id~), body~, audit_reason?))
}

///|
/// Fetch one guild member.
pub async fn Client::get_guild_member(
  self : Client,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
) -> @model.GuildMember raise DiscordHttpError {
  decode(self.request(GetGuildMember(guild_id~, user_id~)))
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
    raise Validation(message="member limit must be 1 through 1000")
  }
  let params : Array[String] = []
  if limit is Some(value) {
    params.push("limit=\{value}")
  }
  if after is Some(value) {
    params.push("after=\{value}")
  }
  let query = if params.length() == 0 { "" } else { "?" + params.join("&") }
  decode(self.request(ListGuildMembers(guild_id~, query~)))
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
    raise Validation(message="member query must not be empty")
  }
  if limit is Some(value) && (value < 1 || value > 1000) {
    raise Validation(message="member limit must be 1 through 1000")
  }
  let suffix = match limit {
    None => "?query=\{query}"
    Some(value) => "?query=\{query}&limit=\{value}"
  }
  decode(self.request(SearchGuildMembers(guild_id~, query=suffix)))
}

///|
/// Modify a guild member.
pub async fn Client::modify_guild_member(
  self : Client,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
  nick? : String,
  clear_nick? : Bool = false,
  roles? : Array[@model.RoleId],
  mute? : Bool,
  deaf? : Bool,
  channel_id? : @model.ChannelId,
  clear_channel_id? : Bool = false,
  communication_disabled_until? : @model.Timestamp,
  clear_communication_disabled_until? : Bool = false,
  audit_reason? : String,
) -> @model.GuildMember raise DiscordHttpError {
  let body = @model.ObjBuilder()
    .und("nick", patch_nullable("nick", nick, clear_nick))
    .und("roles", patch_value(roles))
    .opt("mute", mute)
    .opt("deaf", deaf)
    .und(
      "channel_id",
      patch_nullable("channel_id", channel_id, clear_channel_id),
    )
    .und(
      "communication_disabled_until",
      patch_nullable(
        "communication_disabled_until", communication_disabled_until, clear_communication_disabled_until,
      ),
    )
    .build()
  decode(
    self.request(ModifyGuildMember(guild_id~, user_id~), body~, audit_reason?),
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
  self.request(AddGuildMemberRole(guild_id~, user_id~, role_id~), audit_reason?)
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
    RemoveGuildMemberRole(guild_id~, user_id~, role_id~),
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
  self.request(RemoveGuildMember(guild_id~, user_id~), audit_reason?) |> ignore
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
    raise Validation(
      message="delete_message_seconds must be between 0 and 604800",
    )
  }
  let body = @model.ObjBuilder()
    .opt("delete_message_seconds", delete_message_seconds)
    .build()
  self.request(CreateGuildBan(guild_id~, user_id~), body~, audit_reason?)
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
  self.request(RemoveGuildBan(guild_id~, user_id~), audit_reason?) |> ignore
}

///|
/// List the roles in a guild.
pub async fn Client::get_guild_roles(
  self : Client,
  guild_id : @model.GuildId,
) -> Array[@model.Role] raise DiscordHttpError {
  decode(self.request(GetGuildRoles(guild_id~)))
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
    raise Validation(message="role name must be between 1 and 100 characters")
  }
  let body = @model.ObjBuilder()
    .opt("name", name)
    .opt("permissions", permissions)
    .opt("color", color)
    .opt("hoist", hoist)
    .opt("mentionable", mentionable)
    .build()
  decode(self.request(CreateGuildRole(guild_id~), body~, audit_reason?))
}

///|
/// Modify a guild role.
pub async fn Client::modify_guild_role(
  self : Client,
  guild_id : @model.GuildId,
  role_id : @model.RoleId,
  name? : String,
  permissions? : @model.Permissions,
  color? : Int,
  hoist? : Bool,
  mentionable? : Bool,
  audit_reason? : String,
) -> @model.Role raise DiscordHttpError {
  if name is Some(value) && (value.length() < 1 || value.length() > 100) {
    raise Validation(message="role name must be between 1 and 100 characters")
  }
  let body = @model.ObjBuilder()
    .opt("name", name)
    .opt("permissions", permissions)
    .opt("color", color)
    .opt("hoist", hoist)
    .opt("mentionable", mentionable)
    .build()
  decode(
    self.request(ModifyGuildRole(guild_id~, role_id~), body~, audit_reason?),
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
  self.request(DeleteGuildRole(guild_id~, role_id~), audit_reason?) |> ignore
}
