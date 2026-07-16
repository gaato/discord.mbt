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

///|
/// Fetch the public preview for a discoverable guild.
pub async fn Client::get_guild_preview(
  self : Client,
  guild_id : @model.GuildId,
) -> @model.GuildPreview raise DiscordHttpError {
  decode(self.request(GetGuildPreview(guild_id~)))
}

///|
/// Fetch one guild ban.
pub async fn Client::get_guild_ban(
  self : Client,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
) -> @model.GuildBan raise DiscordHttpError {
  decode(self.request(GetGuildBan(guild_id~, user_id~)))
}

///|
fn bulk_guild_ban_body(
  user_ids : Array[@model.UserId],
  delete_message_seconds : Int?,
) -> Json raise DiscordHttpError {
  if user_ids.length() > 200 {
    raise Validation(message="bulk guild ban exceeds 200 users")
  }
  if delete_message_seconds is Some(value) && (value < 0 || value > 604800) {
    raise Validation(
      message="delete_message_seconds must be between 0 and 604800",
    )
  }
  @model.ObjBuilder()
  .field("user_ids", user_ids)
  .opt("delete_message_seconds", delete_message_seconds)
  .build()
}

///|
/// Ban up to 200 users from a guild in one request.
pub async fn Client::bulk_guild_ban(
  self : Client,
  guild_id : @model.GuildId,
  user_ids : Array[@model.UserId],
  delete_message_seconds? : Int,
  audit_reason? : String,
) -> @model.BulkBanResponse raise DiscordHttpError {
  let body = bulk_guild_ban_body(user_ids, delete_message_seconds)
  decode(self.request(BulkGuildBan(guild_id~), body~, audit_reason?))
}

///|
fn guild_prune_query(
  days : Int?,
  include_roles : Array[@model.RoleId]?,
) -> String raise DiscordHttpError {
  if days is Some(value) && (value < 1 || value > 30) {
    raise Validation(message="prune days must be between 1 and 30")
  }
  let params : Array[String] = []
  if days is Some(value) {
    params.push("days=\{value}")
  }
  if include_roles is Some(value) {
    params.push(
      "include_roles=\{[for role_id in value => "\{role_id}"].join(",")}",
    )
  }
  if params.length() == 0 {
    ""
  } else {
    "?" + params.join("&")
  }
}

///|
/// Return the number of members that would be removed by a guild prune.
pub async fn Client::get_guild_prune_count(
  self : Client,
  guild_id : @model.GuildId,
  days? : Int,
  include_roles? : Array[@model.RoleId],
) -> @model.GuildPruneResult raise DiscordHttpError {
  let query = guild_prune_query(days, include_roles)
  decode(self.request(GetGuildPruneCount(guild_id~, query~)))
}

///|
fn begin_guild_prune_body(
  days : Int?,
  compute_prune_count : Bool?,
  include_roles : Array[@model.RoleId]?,
) -> Json raise DiscordHttpError {
  if days is Some(value) && (value < 1 || value > 30) {
    raise Validation(message="prune days must be between 1 and 30")
  }
  @model.ObjBuilder()
  .opt("days", days)
  .opt("compute_prune_count", compute_prune_count)
  .opt("include_roles", include_roles)
  .build()
}

///|
/// Begin pruning inactive members from a guild.
pub async fn Client::begin_guild_prune(
  self : Client,
  guild_id : @model.GuildId,
  days? : Int,
  compute_prune_count? : Bool,
  include_roles? : Array[@model.RoleId],
  audit_reason? : String,
) -> @model.GuildPruneResult raise DiscordHttpError {
  let body = begin_guild_prune_body(days, compute_prune_count, include_roles)
  decode(self.request(BeginGuildPrune(guild_id~), body~, audit_reason?))
}

///|
/// List the voice regions available to a guild.
pub async fn Client::get_guild_voice_regions(
  self : Client,
  guild_id : @model.GuildId,
) -> Array[@model.VoiceRegion] raise DiscordHttpError {
  decode(self.request(GetGuildVoiceRegions(guild_id~)))
}

///|
/// List the invites for a guild.
pub async fn Client::get_guild_invites(
  self : Client,
  guild_id : @model.GuildId,
) -> Array[@model.Invite] raise DiscordHttpError {
  decode(self.request(GetGuildInvites(guild_id~)))
}

///|
/// List the integrations configured for a guild.
pub async fn Client::get_guild_integrations(
  self : Client,
  guild_id : @model.GuildId,
) -> Array[@model.Integration] raise DiscordHttpError {
  decode(self.request(GetGuildIntegrations(guild_id~)))
}

///|
/// Delete an integration from a guild.
pub async fn Client::delete_guild_integration(
  self : Client,
  guild_id : @model.GuildId,
  integration_id : @model.IntegrationId,
  audit_reason? : String,
) -> Unit raise DiscordHttpError {
  self.request(
    DeleteGuildIntegration(guild_id~, integration_id~),
    audit_reason?,
  )
  |> ignore
}

///|
/// Fetch a guild's vanity invite code and use count.
pub async fn Client::get_guild_vanity_url(
  self : Client,
  guild_id : @model.GuildId,
) -> @model.GuildVanityUrl raise DiscordHttpError {
  decode(self.request(GetGuildVanityUrl(guild_id~)))
}

///|
/// Fetch a guild's widget settings.
pub async fn Client::get_guild_widget_settings(
  self : Client,
  guild_id : @model.GuildId,
) -> @model.GuildWidgetSettings raise DiscordHttpError {
  decode(self.request(GetGuildWidgetSettings(guild_id~)))
}

///|
fn modify_guild_widget_body(
  enabled : Bool?,
  channel_id : @model.ChannelId?,
  clear_channel_id : Bool,
) -> Json raise DiscordHttpError {
  @model.ObjBuilder()
  .opt("enabled", enabled)
  .und("channel_id", patch_nullable("channel_id", channel_id, clear_channel_id))
  .build()
}

///|
/// Modify a guild's widget settings.
pub async fn Client::modify_guild_widget(
  self : Client,
  guild_id : @model.GuildId,
  enabled? : Bool,
  channel_id? : @model.ChannelId,
  clear_channel_id? : Bool = false,
  audit_reason? : String,
) -> @model.GuildWidgetSettings raise DiscordHttpError {
  let body = modify_guild_widget_body(enabled, channel_id, clear_channel_id)
  decode(self.request(ModifyGuildWidget(guild_id~), body~, audit_reason?))
}

///|
/// Fetch the public JSON representation of a guild widget.
pub async fn Client::get_guild_widget(
  self : Client,
  guild_id : @model.GuildId,
) -> @model.GuildWidget raise DiscordHttpError {
  decode(self.request(GetGuildWidget(guild_id~)))
}

///|
/// Build the guild widget PNG URL using this client's configured API base.
/// Discord documents the styles `shield`, `banner1`, `banner2`, `banner3`,
/// and `banner4`; the style is passed through without validation.
pub fn Client::guild_widget_image_url(
  self : Client,
  guild_id : @model.GuildId,
  style? : String,
) -> String {
  let url = "\{self.base_url}\{self.base_path}/guilds/\{guild_id}/widget.png"
  match style {
    None => url
    Some(value) => "\{url}?style=\{value}"
  }
}

///|
/// Fetch a guild's welcome screen.
pub async fn Client::get_guild_welcome_screen(
  self : Client,
  guild_id : @model.GuildId,
) -> @model.WelcomeScreen raise DiscordHttpError {
  decode(self.request(GetGuildWelcomeScreen(guild_id~)))
}

///|
fn modify_guild_welcome_screen_body(
  enabled : Bool?,
  clear_enabled : Bool,
  welcome_channels : Array[@model.WelcomeScreenChannel]?,
  clear_welcome_channels : Bool,
  description : String?,
  clear_description : Bool,
) -> Json raise DiscordHttpError {
  @model.ObjBuilder()
  .und("enabled", patch_nullable("enabled", enabled, clear_enabled))
  .und(
    "welcome_channels",
    patch_nullable("welcome_channels", welcome_channels, clear_welcome_channels),
  )
  .und(
    "description",
    patch_nullable("description", description, clear_description),
  )
  .build()
}

///|
/// Modify a guild's welcome screen. Each nullable field has a matching clear
/// flag so omission remains distinct from JSON null.
pub async fn Client::modify_guild_welcome_screen(
  self : Client,
  guild_id : @model.GuildId,
  enabled? : Bool,
  clear_enabled? : Bool = false,
  welcome_channels? : Array[@model.WelcomeScreenChannel],
  clear_welcome_channels? : Bool = false,
  description? : String,
  clear_description? : Bool = false,
  audit_reason? : String,
) -> @model.WelcomeScreen raise DiscordHttpError {
  let body = modify_guild_welcome_screen_body(
    enabled, clear_enabled, welcome_channels, clear_welcome_channels, description,
    clear_description,
  )
  decode(
    self.request(ModifyGuildWelcomeScreen(guild_id~), body~, audit_reason?),
  )
}

///|
/// Fetch a guild's onboarding configuration.
pub async fn Client::get_guild_onboarding(
  self : Client,
  guild_id : @model.GuildId,
) -> @model.GuildOnboarding raise DiscordHttpError {
  decode(self.request(GetGuildOnboarding(guild_id~)))
}

///|
fn modify_guild_onboarding_body(
  prompts : Array[@model.OnboardingPrompt],
  default_channel_ids : Array[@model.ChannelId],
  enabled : Bool,
  mode : @model.OnboardingMode,
) -> Json {
  @model.ObjBuilder()
  .field("prompts", prompts)
  .field("default_channel_ids", default_channel_ids)
  .field("enabled", enabled)
  .field("mode", mode)
  .build()
}

///|
/// Replace a guild's onboarding configuration.
pub async fn Client::modify_guild_onboarding(
  self : Client,
  guild_id : @model.GuildId,
  prompts : Array[@model.OnboardingPrompt],
  default_channel_ids : Array[@model.ChannelId],
  enabled : Bool,
  mode : @model.OnboardingMode,
  audit_reason? : String,
) -> @model.GuildOnboarding raise DiscordHttpError {
  let body = modify_guild_onboarding_body(
    prompts, default_channel_ids, enabled, mode,
  )
  decode(self.request(ModifyGuildOnboarding(guild_id~), body~, audit_reason?))
}

///|
fn modify_guild_incident_actions_body(
  invites_disabled_until : @model.Timestamp?,
  clear_invites_disabled_until : Bool,
  dms_disabled_until : @model.Timestamp?,
  clear_dms_disabled_until : Bool,
) -> Json raise DiscordHttpError {
  @model.ObjBuilder()
  .und(
    "invites_disabled_until",
    patch_nullable(
      "invites_disabled_until", invites_disabled_until, clear_invites_disabled_until,
    ),
  )
  .und(
    "dms_disabled_until",
    patch_nullable(
      "dms_disabled_until", dms_disabled_until, clear_dms_disabled_until,
    ),
  )
  .build()
}

///|
/// Modify temporary guild incident restrictions. Discord permits each
/// timestamp to be at most 24 hours in the future.
pub async fn Client::modify_guild_incident_actions(
  self : Client,
  guild_id : @model.GuildId,
  invites_disabled_until? : @model.Timestamp,
  clear_invites_disabled_until? : Bool = false,
  dms_disabled_until? : @model.Timestamp,
  clear_dms_disabled_until? : Bool = false,
) -> @model.IncidentsData raise DiscordHttpError {
  let body = modify_guild_incident_actions_body(
    invites_disabled_until, clear_invites_disabled_until, dms_disabled_until, clear_dms_disabled_until,
  )
  decode(self.request(ModifyGuildIncidentActions(guild_id~), body~))
}

///|
/// Fetch one role from a guild.
pub async fn Client::get_guild_role(
  self : Client,
  guild_id : @model.GuildId,
  role_id : @model.RoleId,
) -> @model.Role raise DiscordHttpError {
  decode(self.request(GetGuildRole(guild_id~, role_id~)))
}

///|
fn modify_guild_role_positions_body(
  positions : Array[(@model.RoleId, Int?)],
) -> Json {
  Json::array(
    positions.map(position => {
      let (id, value) = position
      let builder = @model.ObjBuilder().field("id", id)
      match value {
        Some(position) => builder.field("position", position).build()
        None => builder.field("position", Json::null()).build()
      }
    }),
  )
}

///|
/// Modify guild role positions using Discord's raw JSON array body.
pub async fn Client::modify_guild_role_positions(
  self : Client,
  guild_id : @model.GuildId,
  positions : Array[(@model.RoleId, Int?)],
  audit_reason? : String,
) -> Array[@model.Role] raise DiscordHttpError {
  let body = modify_guild_role_positions_body(positions)
  decode(
    self.request(ModifyGuildRolePositions(guild_id~), body~, audit_reason?),
  )
}

///|
fn add_guild_member_body(
  access_token : String,
  nick : String?,
  roles : Array[@model.RoleId]?,
  mute : Bool?,
  deaf : Bool?,
) -> Json {
  @model.ObjBuilder()
  .field("access_token", access_token)
  .opt("nick", nick)
  .opt("roles", roles)
  .opt("mute", mute)
  .opt("deaf", deaf)
  .build()
}

///|
/// Add a user to a guild with an OAuth2 access token carrying the
/// `guilds.join` scope. A null response means the user was already a member.
pub async fn Client::add_guild_member(
  self : Client,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
  access_token : String,
  nick? : String,
  roles? : Array[@model.RoleId],
  mute? : Bool,
  deaf? : Bool,
) -> @model.GuildMember? raise DiscordHttpError {
  let body = add_guild_member_body(access_token, nick, roles, mute, deaf)
  let json = self.request(AddGuildMember(guild_id~, user_id~), body~)
  match json {
    Null => None
    _ => Some(decode(json))
  }
}
