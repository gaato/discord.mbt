///|
/// A guild id bound to the REST client that operates on it.
pub struct GuildRef {
  priv client : Client
  priv guild_id : @model.GuildId
}

///|
/// A role id and its guild id bound to the REST client that operates on it.
pub struct RoleRef {
  priv client : Client
  priv guild_id : @model.GuildId
  priv role_id : @model.RoleId
}

///|
/// Bind a guild id to this client.
pub fn Client::guild_ref(self : Client, guild_id : @model.GuildId) -> GuildRef {
  { client: self, guild_id, }
}

///|
/// Bind a guild/role id pair to this client.
pub fn Client::role_ref(
  self : Client,
  guild_id : @model.GuildId,
  role_id : @model.RoleId,
) -> RoleRef {
  { client: self, guild_id, role_id, }
}

///|
/// Fetch this guild.
pub async fn GuildRef::fetch(
  self : GuildRef,
  with_counts? : Bool,
) -> @model.Guild raise DiscordHttpError {
  self.client.get_guild(self.guild_id, with_counts?)
}

///|
/// Edit this guild.
pub async fn GuildRef::edit(
  self : GuildRef,
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
  reason? : String,
) -> @model.Guild raise DiscordHttpError {
  self.client.modify_guild(
    self.guild_id,
    name?,
    verification_level?,
    default_message_notifications?,
    explicit_content_filter?,
    afk_channel_id?,
    clear_afk_channel_id~,
    afk_timeout?,
    icon?,
    clear_icon~,
    owner_id?,
    splash?,
    clear_splash~,
    discovery_splash?,
    clear_discovery_splash~,
    banner?,
    clear_banner~,
    system_channel_id?,
    clear_system_channel_id~,
    system_channel_flags?,
    rules_channel_id?,
    clear_rules_channel_id~,
    public_updates_channel_id?,
    clear_public_updates_channel_id~,
    preferred_locale?,
    features?,
    description?,
    clear_description~,
    premium_progress_bar_enabled?,
    safety_alerts_channel_id?,
    clear_safety_alerts_channel_id~,
    audit_reason?=reason,
  )
}

///|
/// Fetch this guild's public preview.
pub async fn GuildRef::preview(
  self : GuildRef,
) -> @model.GuildPreview raise DiscordHttpError {
  self.client.get_guild_preview(self.guild_id)
}

///|
/// Paginate this guild's audit-log entries.
pub fn GuildRef::audit_log(
  self : GuildRef,
  user_id? : @model.UserId,
  action_type? : @model.AuditLogEvent,
  before? : @model.AuditLogEntryId,
  page_size? : Int = 100,
) -> Paginator[@model.AuditLogEntry] raise DiscordHttpError {
  self.client.paginate_guild_audit_log(
    self.guild_id,
    user_id?,
    action_type?,
    before?,
    page_size~,
  )
}

///|
/// Paginate bans in this guild.
pub fn GuildRef::bans(
  self : GuildRef,
  before? : @model.UserId,
  after? : @model.UserId,
  page_size? : Int = 1000,
) -> Paginator[@model.GuildBan] raise DiscordHttpError {
  self.client.paginate_guild_bans(self.guild_id, before?, after?, page_size~)
}

///|
/// Fetch ban information for a user; use `MemberRef::ban` to perform a ban.
pub async fn GuildRef::fetch_ban(
  self : GuildRef,
  user_id : @model.UserId,
) -> @model.GuildBan raise DiscordHttpError {
  self.client.get_guild_ban(self.guild_id, user_id)
}

///|
/// Ban up to 200 users from this guild.
pub async fn GuildRef::bulk_ban(
  self : GuildRef,
  user_ids : Array[@model.UserId],
  delete_message_seconds? : Int,
  reason? : String,
) -> @model.BulkBanResponse raise DiscordHttpError {
  self.client.bulk_guild_ban(
    self.guild_id,
    user_ids,
    delete_message_seconds?,
    audit_reason?=reason,
  )
}

///|
/// List channels in this guild.
pub async fn GuildRef::channels(
  self : GuildRef,
) -> Array[@model.Channel] raise DiscordHttpError {
  self.client.get_guild_channels(self.guild_id)
}

///|
/// Create a channel in this guild.
pub async fn GuildRef::create_channel(
  self : GuildRef,
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
  rtc_region? : String,
  video_quality_mode? : @model.VideoQualityMode,
  default_auto_archive_duration? : @model.ThreadAutoArchiveDuration,
  available_tags? : Array[@model.ForumTagRequest],
  default_reaction_emoji? : @model.DefaultReaction,
  default_thread_rate_limit_per_user? : Int,
  default_sort_order? : @model.SortOrderType,
  default_forum_layout? : @model.ForumLayoutType,
  reason? : String,
) -> @model.Channel raise DiscordHttpError {
  self.client.create_guild_channel(
    self.guild_id,
    name,
    typ?,
    topic?,
    parent_id?,
    position?,
    permission_overwrites?,
    nsfw?,
    bitrate?,
    user_limit?,
    rate_limit_per_user?,
    rtc_region?,
    video_quality_mode?,
    default_auto_archive_duration?,
    available_tags?,
    default_reaction_emoji?,
    default_thread_rate_limit_per_user?,
    default_sort_order?,
    default_forum_layout?,
    audit_reason?=reason,
  )
}

///|
/// Edit channel positions in this guild.
pub async fn GuildRef::edit_channel_positions(
  self : GuildRef,
  positions : Array[GuildChannelPosition],
  reason? : String,
) -> Unit raise DiscordHttpError {
  self.client.modify_guild_channel_positions(
    self.guild_id,
    positions,
    audit_reason?=reason,
  )
}

///|
/// Paginate members in this guild.
pub fn GuildRef::members(
  self : GuildRef,
  after? : @model.UserId,
  page_size? : Int = 1000,
) -> Paginator[@model.GuildMember] raise DiscordHttpError {
  self.client.paginate_guild_members(self.guild_id, after?, page_size~)
}

///|
/// Search members in this guild.
pub async fn GuildRef::search_members(
  self : GuildRef,
  query : String,
  limit? : Int,
) -> Array[@model.GuildMember] raise DiscordHttpError {
  self.client.search_guild_members(self.guild_id, query, limit?)
}

///|
/// Add a user to this guild.
pub async fn GuildRef::add_member(
  self : GuildRef,
  user_id : @model.UserId,
  access_token : String,
  nick? : String,
  roles? : Array[@model.RoleId],
  mute? : Bool,
  deaf? : Bool,
) -> @model.GuildMember? raise DiscordHttpError {
  self.client.add_guild_member(
    self.guild_id,
    user_id,
    access_token,
    nick?,
    roles?,
    mute?,
    deaf?,
  )
}

///|
/// Edit the current user's member record in this guild.
pub async fn GuildRef::edit_current_member(
  self : GuildRef,
  nick? : String,
  clear_nick? : Bool = false,
  avatar? : String,
  clear_avatar? : Bool = false,
  banner? : String,
  clear_banner? : Bool = false,
  bio? : String,
  clear_bio? : Bool = false,
  reason? : String,
) -> @model.GuildMember raise DiscordHttpError {
  self.client.modify_current_member(
    self.guild_id,
    nick?,
    clear_nick~,
    avatar?,
    clear_avatar~,
    banner?,
    clear_banner~,
    bio?,
    clear_bio~,
    audit_reason?=reason,
  )
}

///|
/// List roles in this guild.
pub async fn GuildRef::roles(
  self : GuildRef,
) -> Array[@model.Role] raise DiscordHttpError {
  self.client.get_guild_roles(self.guild_id)
}

///|
/// Create a role in this guild.
pub async fn GuildRef::create_role(
  self : GuildRef,
  name? : String,
  permissions? : @model.Permissions,
  color? : Int,
  colors? : @model.RoleColors,
  hoist? : Bool,
  icon? : String,
  unicode_emoji? : String,
  mentionable? : Bool,
  reason? : String,
) -> @model.Role raise DiscordHttpError {
  self.client.create_guild_role(
    self.guild_id,
    name?,
    permissions?,
    color?,
    colors?,
    hoist?,
    icon?,
    unicode_emoji?,
    mentionable?,
    audit_reason?=reason,
  )
}

///|
/// Edit role positions in this guild.
pub async fn GuildRef::edit_role_positions(
  self : GuildRef,
  positions : Array[(@model.RoleId, Int?)],
  reason? : String,
) -> Array[@model.Role] raise DiscordHttpError {
  self.client.modify_guild_role_positions(
    self.guild_id,
    positions,
    audit_reason?=reason,
  )
}

///|
/// Count members that a prune would remove from this guild.
pub async fn GuildRef::prune_count(
  self : GuildRef,
  days? : Int,
  include_roles? : Array[@model.RoleId],
) -> @model.GuildPruneResult raise DiscordHttpError {
  self.client.get_guild_prune_count(self.guild_id, days?, include_roles?)
}

///|
/// Begin pruning inactive members from this guild.
pub async fn GuildRef::begin_prune(
  self : GuildRef,
  days? : Int,
  compute_prune_count? : Bool,
  include_roles? : Array[@model.RoleId],
  reason? : String,
) -> @model.GuildPruneResult raise DiscordHttpError {
  self.client.begin_guild_prune(
    self.guild_id,
    days?,
    compute_prune_count?,
    include_roles?,
    audit_reason?=reason,
  )
}

///|
/// List voice regions available to this guild.
pub async fn GuildRef::voice_regions(
  self : GuildRef,
) -> Array[@model.VoiceRegion] raise DiscordHttpError {
  self.client.get_guild_voice_regions(self.guild_id)
}

///|
/// List invites for this guild.
pub async fn GuildRef::invites(
  self : GuildRef,
) -> Array[@model.Invite] raise DiscordHttpError {
  self.client.get_guild_invites(self.guild_id)
}

///|
/// List integrations configured for this guild.
pub async fn GuildRef::integrations(
  self : GuildRef,
) -> Array[@model.Integration] raise DiscordHttpError {
  self.client.get_guild_integrations(self.guild_id)
}

///|
/// List webhooks belonging to this guild.
pub async fn GuildRef::webhooks(
  self : GuildRef,
) -> Array[@model.Webhook] raise DiscordHttpError {
  self.client.get_guild_webhooks(self.guild_id)
}

///|
/// Delete an integration from this guild.
pub async fn GuildRef::delete_integration(
  self : GuildRef,
  integration_id : @model.IntegrationId,
  reason? : String,
) -> Unit raise DiscordHttpError {
  self.client.delete_guild_integration(
    self.guild_id,
    integration_id,
    audit_reason?=reason,
  )
}

///|
/// Fetch this guild's vanity invite information.
pub async fn GuildRef::vanity_url(
  self : GuildRef,
) -> @model.GuildVanityUrl raise DiscordHttpError {
  self.client.get_guild_vanity_url(self.guild_id)
}

///|
/// Fetch this guild's widget settings.
pub async fn GuildRef::widget_settings(
  self : GuildRef,
) -> @model.GuildWidgetSettings raise DiscordHttpError {
  self.client.get_guild_widget_settings(self.guild_id)
}

///|
/// Edit this guild's widget settings.
pub async fn GuildRef::edit_widget(
  self : GuildRef,
  enabled? : Bool,
  channel_id? : @model.ChannelId,
  clear_channel_id? : Bool = false,
  reason? : String,
) -> @model.GuildWidgetSettings raise DiscordHttpError {
  self.client.modify_guild_widget(
    self.guild_id,
    enabled?,
    channel_id?,
    clear_channel_id~,
    audit_reason?=reason,
  )
}

///|
/// Fetch this guild's public widget representation.
pub async fn GuildRef::widget(
  self : GuildRef,
) -> @model.GuildWidget raise DiscordHttpError {
  self.client.get_guild_widget(self.guild_id)
}

///|
/// Build this guild's widget image URL.
pub fn GuildRef::widget_image_url(self : GuildRef, style? : String) -> String {
  self.client.guild_widget_image_url(self.guild_id, style?)
}

///|
/// Fetch this guild's welcome screen.
pub async fn GuildRef::welcome_screen(
  self : GuildRef,
) -> @model.WelcomeScreen raise DiscordHttpError {
  self.client.get_guild_welcome_screen(self.guild_id)
}

///|
/// Edit this guild's welcome screen.
pub async fn GuildRef::edit_welcome_screen(
  self : GuildRef,
  enabled? : Bool,
  clear_enabled? : Bool = false,
  welcome_channels? : Array[@model.WelcomeScreenChannel],
  clear_welcome_channels? : Bool = false,
  description? : String,
  clear_description? : Bool = false,
  reason? : String,
) -> @model.WelcomeScreen raise DiscordHttpError {
  self.client.modify_guild_welcome_screen(
    self.guild_id,
    enabled?,
    clear_enabled~,
    welcome_channels?,
    clear_welcome_channels~,
    description?,
    clear_description~,
    audit_reason?=reason,
  )
}

///|
/// Fetch this guild's onboarding configuration.
pub async fn GuildRef::onboarding(
  self : GuildRef,
) -> @model.GuildOnboarding raise DiscordHttpError {
  self.client.get_guild_onboarding(self.guild_id)
}

///|
/// Replace this guild's onboarding configuration.
pub async fn GuildRef::edit_onboarding(
  self : GuildRef,
  prompts : Array[@model.OnboardingPrompt],
  default_channel_ids : Array[@model.ChannelId],
  enabled : Bool,
  mode : @model.OnboardingMode,
  reason? : String,
) -> @model.GuildOnboarding raise DiscordHttpError {
  self.client.modify_guild_onboarding(
    self.guild_id,
    prompts,
    default_channel_ids,
    enabled,
    mode,
    audit_reason?=reason,
  )
}

///|
/// Edit incident actions for this guild.
pub async fn GuildRef::edit_incident_actions(
  self : GuildRef,
  invites_disabled_until? : @model.Timestamp,
  clear_invites_disabled_until? : Bool = false,
  dms_disabled_until? : @model.Timestamp,
  clear_dms_disabled_until? : Bool = false,
) -> @model.IncidentsData raise DiscordHttpError {
  self.client.modify_guild_incident_actions(
    self.guild_id,
    invites_disabled_until?,
    clear_invites_disabled_until~,
    dms_disabled_until?,
    clear_dms_disabled_until~,
  )
}

///|
/// Make the bot itself leave this guild.
pub async fn GuildRef::leave(self : GuildRef) -> Unit raise DiscordHttpError {
  self.client.leave_guild(self.guild_id)
}

///|
/// List active threads in this guild.
pub async fn GuildRef::active_threads(
  self : GuildRef,
) -> @model.ActiveGuildThreads raise DiscordHttpError {
  self.client.list_active_guild_threads(self.guild_id)
}

///|
/// Search messages in this guild.
pub async fn GuildRef::search_messages(
  self : GuildRef,
  limit? : Int,
  offset? : Int,
  slop? : Int,
  content? : String,
  mention_everyone? : Bool,
  pinned? : Bool,
  include_nsfw? : Bool,
  sort_by? : String,
  sort_order? : String,
  max_id? : @model.MessageId,
  min_id? : @model.MessageId,
  channel_id? : Array[@model.ChannelId],
  author_type? : Array[String],
  author_id? : Array[@model.UserId],
  mentions? : Array[@model.UserId],
  mentions_role_id? : Array[@model.RoleId],
  replied_to_user_id? : Array[@model.UserId],
  replied_to_message_id? : Array[@model.MessageId],
  has? : Array[String],
  embed_type? : Array[String],
  embed_provider? : Array[String],
  link_hostname? : Array[String],
  attachment_filename? : Array[String],
  attachment_extension? : Array[String],
) -> @model.GuildMessageSearchResults raise DiscordHttpError {
  self.client.search_guild_messages(
    self.guild_id,
    limit?,
    offset?,
    slop?,
    content?,
    mention_everyone?,
    pinned?,
    include_nsfw?,
    sort_by?,
    sort_order?,
    max_id?,
    min_id?,
    channel_id?,
    author_type?,
    author_id?,
    mentions?,
    mentions_role_id?,
    replied_to_user_id?,
    replied_to_message_id?,
    has?,
    embed_type?,
    embed_provider?,
    link_hostname?,
    attachment_filename?,
    attachment_extension?,
  )
}

///|
/// Fetch the current user's voice state in this guild.
pub async fn GuildRef::my_voice_state(
  self : GuildRef,
) -> @model.VoiceState raise DiscordHttpError {
  self.client.get_current_user_voice_state(self.guild_id)
}

///|
/// Edit the current user's voice state in this guild.
pub async fn GuildRef::edit_my_voice_state(
  self : GuildRef,
  channel_id? : @model.ChannelId,
  suppress? : Bool,
  request_to_speak_timestamp? : @model.Timestamp,
  clear_request_to_speak_timestamp? : Bool = false,
) -> Unit raise DiscordHttpError {
  self.client.modify_current_user_voice_state(
    self.guild_id,
    channel_id?,
    suppress?,
    request_to_speak_timestamp?,
    clear_request_to_speak_timestamp~,
  )
}

///|
/// Bind a user id in this guild to the client.
pub fn GuildRef::member_ref(
  self : GuildRef,
  user_id : @model.UserId,
) -> MemberRef {
  { client: self.client, guild_id: self.guild_id, user_id, }
}

///|
/// Bind a role id in this guild to the client.
pub fn GuildRef::role_ref(self : GuildRef, role_id : @model.RoleId) -> RoleRef {
  { client: self.client, guild_id: self.guild_id, role_id, }
}

///|
/// Fetch this role.
pub async fn RoleRef::fetch(
  self : RoleRef,
) -> @model.Role raise DiscordHttpError {
  self.client.get_guild_role(self.guild_id, self.role_id)
}

///|
/// Edit this role.
pub async fn RoleRef::edit(
  self : RoleRef,
  name? : String,
  permissions? : @model.Permissions,
  color? : Int,
  colors? : @model.RoleColors,
  hoist? : Bool,
  icon? : String,
  clear_icon? : Bool = false,
  unicode_emoji? : String,
  clear_unicode_emoji? : Bool = false,
  mentionable? : Bool,
  reason? : String,
) -> @model.Role raise DiscordHttpError {
  self.client.modify_guild_role(
    self.guild_id,
    self.role_id,
    name?,
    permissions?,
    color?,
    colors?,
    hoist?,
    icon?,
    clear_icon~,
    unicode_emoji?,
    clear_unicode_emoji~,
    mentionable?,
    audit_reason?=reason,
  )
}

///|
/// Delete this role.
pub async fn RoleRef::delete(
  self : RoleRef,
  reason? : String,
) -> Unit raise DiscordHttpError {
  self.client.delete_guild_role(
    self.guild_id,
    self.role_id,
    audit_reason?=reason,
  )
}
