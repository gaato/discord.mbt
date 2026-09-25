///|
/// HTTP methods accepted by Discord REST routes.
pub using @ahttp {type RequestMethod}

///|
/// Invalid metadata supplied while constructing a custom REST route.
pub(all) suberror CustomRouteError {
  InvalidPath(path~ : String)
  EmptyBucket
} derive(Debug)

///|
/// One variant per Discord REST endpoint. A route knows its HTTP method, its
/// concrete path (including query string), and its rate-limit bucket key
/// (path template with major parameters kept and minor ones squashed).
/// Free-form string segments (emoji, invite/template codes, external
/// identity ids) are held raw and percent-encoded by `Route::path`.
pub(all) enum Route {
  Custom(
    request_method~ : @ahttp.RequestMethod,
    path~ : String,
    bucket_key~ : String,
    is_interaction~ : Bool,
    supports_reason~ : Bool
  )
  GetGateway
  GetGatewayBot
  GetCurrentApplication
  EditCurrentApplication
  GetApplicationActivityInstance(
    application_id~ : @model.ApplicationId,
    instance_id~ : String
  )
  UpdateApplicationIdentityProfile(
    application_id~ : @model.ApplicationId,
    user_id~ : @model.UserId,
    provider_issued_user_id~ : String
  )
  GetApplicationIdentityProfile(
    application_id~ : @model.ApplicationId,
    user_id~ : @model.UserId,
    provider_issued_user_id~ : String
  )
  GetApplicationIdentitiesByUserId(
    user_id~ : @model.UserId,
    application_id~ : @model.ApplicationId
  )
  GetApplicationIdentitiesByExternalId(
    application_id~ : @model.ApplicationId,
    provider_type~ : String,
    provider_issued_user_id~ : String,
    query~ : String
  )
  DeleteApplicationIdentity(
    user_id~ : @model.UserId,
    application_id~ : @model.ApplicationId,
    provider_type~ : String,
    provider_issued_user_id~ : String
  )
  GetApplicationRoleConnectionMetadataRecords(
    application_id~ : @model.ApplicationId
  )
  UpdateApplicationRoleConnectionMetadataRecords(
    application_id~ : @model.ApplicationId
  )
  ListApplicationEmojis(application_id~ : @model.ApplicationId)
  GetApplicationEmoji(
    application_id~ : @model.ApplicationId,
    emoji_id~ : @model.EmojiId
  )
  CreateApplicationEmoji(application_id~ : @model.ApplicationId)
  ModifyApplicationEmoji(
    application_id~ : @model.ApplicationId,
    emoji_id~ : @model.EmojiId
  )
  DeleteApplicationEmoji(
    application_id~ : @model.ApplicationId,
    emoji_id~ : @model.EmojiId
  )
  ListEntitlements(application_id~ : @model.ApplicationId, query~ : String)
  GetEntitlement(
    application_id~ : @model.ApplicationId,
    entitlement_id~ : @model.EntitlementId
  )
  CreateTestEntitlement(application_id~ : @model.ApplicationId)
  ConsumeEntitlement(
    application_id~ : @model.ApplicationId,
    entitlement_id~ : @model.EntitlementId
  )
  DeleteTestEntitlement(
    application_id~ : @model.ApplicationId,
    entitlement_id~ : @model.EntitlementId
  )
  ListSkus(application_id~ : @model.ApplicationId)
  ListSkuSubscriptions(sku_id~ : @model.SkuId, query~ : String)
  GetSkuSubscription(
    sku_id~ : @model.SkuId,
    subscription_id~ : @model.SubscriptionId
  )
  GetCurrentUser
  GetCurrentUserGuilds(query~ : String)
  GetCurrentUserConnections
  GetCurrentUserGuildMember(guild_id~ : @model.GuildId)
  GetCurrentUserApplicationRoleConnection(
    application_id~ : @model.ApplicationId
  )
  UpdateCurrentUserApplicationRoleConnection(
    application_id~ : @model.ApplicationId
  )
  DeleteCurrentUserApplicationRoleConnection(
    application_id~ : @model.ApplicationId
  )
  LeaveGuild(guild_id~ : @model.GuildId)
  GetUser(user_id~ : @model.UserId)
  ModifyCurrentUser
  CreateDm
  GetCurrentAuthorizationInformation
  GetCurrentBotApplicationInformation
  GetChannel(channel_id~ : @model.ChannelId)
  ModifyChannel(channel_id~ : @model.ChannelId)
  DeleteChannel(channel_id~ : @model.ChannelId)
  GetChannelMessages(channel_id~ : @model.ChannelId, query~ : String)
  GetChannelMessage(
    channel_id~ : @model.ChannelId,
    message_id~ : @model.MessageId
  )
  CreateMessage(channel_id~ : @model.ChannelId)
  EditMessage(channel_id~ : @model.ChannelId, message_id~ : @model.MessageId)
  DeleteMessage(channel_id~ : @model.ChannelId, message_id~ : @model.MessageId)
  BulkDeleteMessages(channel_id~ : @model.ChannelId)
  CreateReaction(
    channel_id~ : @model.ChannelId,
    message_id~ : @model.MessageId,
    emoji~ : String
  )
  DeleteOwnReaction(
    channel_id~ : @model.ChannelId,
    message_id~ : @model.MessageId,
    emoji~ : String
  )
  DeleteUserReaction(
    channel_id~ : @model.ChannelId,
    message_id~ : @model.MessageId,
    emoji~ : String,
    user_id~ : @model.UserId
  )
  DeleteAllReactions(
    channel_id~ : @model.ChannelId,
    message_id~ : @model.MessageId
  )
  DeleteAllReactionsForEmoji(
    channel_id~ : @model.ChannelId,
    message_id~ : @model.MessageId,
    emoji~ : String
  )
  CrosspostMessage(
    channel_id~ : @model.ChannelId,
    message_id~ : @model.MessageId
  )
  GetReactions(
    channel_id~ : @model.ChannelId,
    message_id~ : @model.MessageId,
    emoji~ : String,
    query~ : String
  )
  GetPollAnswerVoters(
    channel_id~ : @model.ChannelId,
    message_id~ : @model.MessageId,
    answer_id~ : Int,
    query~ : String
  )
  ExpirePoll(channel_id~ : @model.ChannelId, message_id~ : @model.MessageId)
  SendSoundboardSound(channel_id~ : @model.ChannelId)
  TriggerTypingIndicator(channel_id~ : @model.ChannelId)
  PinMessage(channel_id~ : @model.ChannelId, message_id~ : @model.MessageId)
  UnpinMessage(channel_id~ : @model.ChannelId, message_id~ : @model.MessageId)
  GetChannelPins(channel_id~ : @model.ChannelId, query~ : String)
  // Kept for source compatibility with the deprecated array-returning API.
  GetPinnedMessages(channel_id~ : @model.ChannelId)
  EditChannelPermissions(
    channel_id~ : @model.ChannelId,
    overwrite_id~ : @model.GenericId
  )
  DeleteChannelPermission(
    channel_id~ : @model.ChannelId,
    overwrite_id~ : @model.GenericId
  )
  GetChannelInvites(channel_id~ : @model.ChannelId)
  CreateChannelInvite(channel_id~ : @model.ChannelId)
  FollowAnnouncementChannel(channel_id~ : @model.ChannelId)
  SetVoiceChannelStatus(channel_id~ : @model.ChannelId)
  GroupDmAddRecipient(channel_id~ : @model.ChannelId, user_id~ : @model.UserId)
  GroupDmRemoveRecipient(
    channel_id~ : @model.ChannelId,
    user_id~ : @model.UserId
  )
  CreateWebhook(channel_id~ : @model.ChannelId)
  GetChannelWebhooks(channel_id~ : @model.ChannelId)
  StartThreadFromMessage(
    channel_id~ : @model.ChannelId,
    message_id~ : @model.MessageId
  )
  StartThreadWithoutMessage(channel_id~ : @model.ChannelId)
  JoinThread(channel_id~ : @model.ChannelId)
  LeaveThread(channel_id~ : @model.ChannelId)
  ListThreadMembers(channel_id~ : @model.ChannelId, query~ : String)
  GetThreadMember(
    channel_id~ : @model.ChannelId,
    user_id~ : @model.UserId,
    query~ : String
  )
  AddThreadMember(channel_id~ : @model.ChannelId, user_id~ : @model.UserId)
  RemoveThreadMember(channel_id~ : @model.ChannelId, user_id~ : @model.UserId)
  ListPublicArchivedThreads(channel_id~ : @model.ChannelId, query~ : String)
  ListPrivateArchivedThreads(channel_id~ : @model.ChannelId, query~ : String)
  ListJoinedPrivateArchivedThreads(
    channel_id~ : @model.ChannelId,
    query~ : String
  )
  ListActiveGuildThreads(guild_id~ : @model.GuildId)
  SearchGuildMessages(guild_id~ : @model.GuildId, query~ : String)
  GetGuild(guild_id~ : @model.GuildId)
  GetGuildWithCounts(guild_id~ : @model.GuildId, query~ : String)
  ModifyGuild(guild_id~ : @model.GuildId)
  GetGuildPreview(guild_id~ : @model.GuildId)
  GetGuildChannels(guild_id~ : @model.GuildId)
  CreateGuildChannel(guild_id~ : @model.GuildId)
  ModifyGuildChannelPositions(guild_id~ : @model.GuildId)
  GetGuildMember(guild_id~ : @model.GuildId, user_id~ : @model.UserId)
  ListGuildMembers(guild_id~ : @model.GuildId, query~ : String)
  SearchGuildMembers(guild_id~ : @model.GuildId, query~ : String)
  ModifyGuildMember(guild_id~ : @model.GuildId, user_id~ : @model.UserId)
  ModifyCurrentMember(guild_id~ : @model.GuildId)
  AddGuildMember(guild_id~ : @model.GuildId, user_id~ : @model.UserId)
  GetGuildRoles(guild_id~ : @model.GuildId)
  GetGuildRole(guild_id~ : @model.GuildId, role_id~ : @model.RoleId)
  CreateGuildRole(guild_id~ : @model.GuildId)
  ModifyGuildRolePositions(guild_id~ : @model.GuildId)
  ModifyGuildRole(guild_id~ : @model.GuildId, role_id~ : @model.RoleId)
  DeleteGuildRole(guild_id~ : @model.GuildId, role_id~ : @model.RoleId)
  AddGuildMemberRole(
    guild_id~ : @model.GuildId,
    user_id~ : @model.UserId,
    role_id~ : @model.RoleId
  )
  RemoveGuildMemberRole(
    guild_id~ : @model.GuildId,
    user_id~ : @model.UserId,
    role_id~ : @model.RoleId
  )
  RemoveGuildMember(guild_id~ : @model.GuildId, user_id~ : @model.UserId)
  CreateGuildBan(guild_id~ : @model.GuildId, user_id~ : @model.UserId)
  RemoveGuildBan(guild_id~ : @model.GuildId, user_id~ : @model.UserId)
  GetGuildBan(guild_id~ : @model.GuildId, user_id~ : @model.UserId)
  GetGuildBans(guild_id~ : @model.GuildId, query~ : String)
  BulkGuildBan(guild_id~ : @model.GuildId)
  GetGuildPruneCount(guild_id~ : @model.GuildId, query~ : String)
  BeginGuildPrune(guild_id~ : @model.GuildId)
  GetGuildVoiceRegions(guild_id~ : @model.GuildId)
  GetGuildInvites(guild_id~ : @model.GuildId)
  GetGuildIntegrations(guild_id~ : @model.GuildId)
  DeleteGuildIntegration(
    guild_id~ : @model.GuildId,
    integration_id~ : @model.IntegrationId
  )
  GetGuildVanityUrl(guild_id~ : @model.GuildId)
  GetGuildWidgetSettings(guild_id~ : @model.GuildId)
  ModifyGuildWidget(guild_id~ : @model.GuildId)
  GetGuildWidget(guild_id~ : @model.GuildId)
  GetGuildWelcomeScreen(guild_id~ : @model.GuildId)
  ModifyGuildWelcomeScreen(guild_id~ : @model.GuildId)
  GetGuildOnboarding(guild_id~ : @model.GuildId)
  ModifyGuildOnboarding(guild_id~ : @model.GuildId)
  ModifyGuildIncidentActions(guild_id~ : @model.GuildId)
  GetGuildAuditLog(guild_id~ : @model.GuildId, query~ : String)
  ListAutoModerationRules(guild_id~ : @model.GuildId)
  GetAutoModerationRule(
    guild_id~ : @model.GuildId,
    rule_id~ : @model.AutoModerationRuleId
  )
  CreateAutoModerationRule(guild_id~ : @model.GuildId)
  ModifyAutoModerationRule(
    guild_id~ : @model.GuildId,
    rule_id~ : @model.AutoModerationRuleId
  )
  DeleteAutoModerationRule(
    guild_id~ : @model.GuildId,
    rule_id~ : @model.AutoModerationRuleId
  )
  ListGuildStickers(guild_id~ : @model.GuildId)
  GetGuildSticker(guild_id~ : @model.GuildId, sticker_id~ : @model.StickerId)
  CreateGuildSticker(guild_id~ : @model.GuildId)
  ModifyGuildSticker(guild_id~ : @model.GuildId, sticker_id~ : @model.StickerId)
  DeleteGuildSticker(guild_id~ : @model.GuildId, sticker_id~ : @model.StickerId)
  ListGuildScheduledEvents(guild_id~ : @model.GuildId, query~ : String)
  CreateGuildScheduledEvent(guild_id~ : @model.GuildId)
  GetGuildScheduledEvent(
    guild_id~ : @model.GuildId,
    event_id~ : @model.ScheduledEventId,
    query~ : String
  )
  ModifyGuildScheduledEvent(
    guild_id~ : @model.GuildId,
    event_id~ : @model.ScheduledEventId
  )
  DeleteGuildScheduledEvent(
    guild_id~ : @model.GuildId,
    event_id~ : @model.ScheduledEventId
  )
  ListGuildScheduledEventUsers(
    guild_id~ : @model.GuildId,
    event_id~ : @model.ScheduledEventId,
    query~ : String
  )
  ListGuildSoundboardSounds(guild_id~ : @model.GuildId)
  CreateGuildSoundboardSound(guild_id~ : @model.GuildId)
  GetGuildSoundboardSound(
    guild_id~ : @model.GuildId,
    sound_id~ : @model.SoundboardSoundId
  )
  ModifyGuildSoundboardSound(
    guild_id~ : @model.GuildId,
    sound_id~ : @model.SoundboardSoundId
  )
  DeleteGuildSoundboardSound(
    guild_id~ : @model.GuildId,
    sound_id~ : @model.SoundboardSoundId
  )
  GetGuildWebhooks(guild_id~ : @model.GuildId)
  ListGuildEmojis(guild_id~ : @model.GuildId)
  GetGuildEmoji(guild_id~ : @model.GuildId, emoji_id~ : @model.EmojiId)
  CreateGuildEmoji(guild_id~ : @model.GuildId)
  ModifyGuildEmoji(guild_id~ : @model.GuildId, emoji_id~ : @model.EmojiId)
  DeleteGuildEmoji(guild_id~ : @model.GuildId, emoji_id~ : @model.EmojiId)
  GetSticker(sticker_id~ : @model.StickerId)
  ListStickerPacks
  GetStickerPack(pack_id~ : @model.StickerPackId)
  ListDefaultSoundboardSounds
  ListVoiceRegions
  GetCurrentUserVoiceState(guild_id~ : @model.GuildId)
  GetUserVoiceState(guild_id~ : @model.GuildId, user_id~ : @model.UserId)
  ModifyCurrentUserVoiceState(guild_id~ : @model.GuildId)
  ModifyUserVoiceState(guild_id~ : @model.GuildId, user_id~ : @model.UserId)
  GetGuildTemplate(template_code~ : String)
  CreateGuildFromTemplate(template_code~ : String)
  GetGuildTemplates(guild_id~ : @model.GuildId)
  CreateGuildTemplate(guild_id~ : @model.GuildId)
  SyncGuildTemplate(guild_id~ : @model.GuildId, template_code~ : String)
  ModifyGuildTemplate(guild_id~ : @model.GuildId, template_code~ : String)
  DeleteGuildTemplate(guild_id~ : @model.GuildId, template_code~ : String)
  CreateStageInstance
  GetStageInstance(channel_id~ : @model.ChannelId)
  ModifyStageInstance(channel_id~ : @model.ChannelId)
  DeleteStageInstance(channel_id~ : @model.ChannelId)
  GetInvite(code~ : String, query~ : String)
  DeleteInvite(code~ : String)
  UpdateInviteTargetUsers(code~ : String)
  GetInviteTargetUsersJobStatus(code~ : String)
  AddInviteTargetUser(code~ : String, user_id~ : @model.UserId)
  RemoveInviteTargetUser(code~ : String, user_id~ : @model.UserId)
  BulkAddInviteTargetUsers(code~ : String)
  BulkDeleteInviteTargetUsers(code~ : String)
  GetWebhook(webhook_id~ : @model.WebhookId)
  ModifyWebhook(webhook_id~ : @model.WebhookId)
  DeleteWebhook(webhook_id~ : @model.WebhookId)
  GetWebhookWithToken(webhook_id~ : @model.WebhookId, token~ : String)
  ModifyWebhookWithToken(webhook_id~ : @model.WebhookId, token~ : String)
  DeleteWebhookWithToken(webhook_id~ : @model.WebhookId, token~ : String)
  ExecuteWebhook(
    webhook_id~ : @model.WebhookId,
    token~ : String,
    query~ : String
  )
  ExecuteSlackCompatibleWebhook(
    webhook_id~ : @model.WebhookId,
    token~ : String,
    query~ : String
  )
  ExecuteGithubCompatibleWebhook(
    webhook_id~ : @model.WebhookId,
    token~ : String,
    query~ : String
  )
  GetWebhookMessage(
    webhook_id~ : @model.WebhookId,
    token~ : String,
    message_id~ : @model.MessageId,
    query~ : String
  )
  EditWebhookMessage(
    webhook_id~ : @model.WebhookId,
    token~ : String,
    message_id~ : @model.MessageId,
    query~ : String
  )
  DeleteWebhookMessage(
    webhook_id~ : @model.WebhookId,
    token~ : String,
    message_id~ : @model.MessageId,
    query~ : String
  )
  CreateInteractionResponse(
    interaction_id~ : @model.InteractionId,
    token~ : String,
    query~ : String
  )
  GetOriginalInteractionResponse(
    application_id~ : @model.ApplicationId,
    token~ : String
  )
  EditOriginalInteractionResponse(
    application_id~ : @model.ApplicationId,
    token~ : String
  )
  DeleteOriginalInteractionResponse(
    application_id~ : @model.ApplicationId,
    token~ : String
  )
  CreateFollowupMessage(application_id~ : @model.ApplicationId, token~ : String)
  GetFollowupMessage(
    application_id~ : @model.ApplicationId,
    token~ : String,
    message_id~ : @model.MessageId
  )
  EditFollowupMessage(
    application_id~ : @model.ApplicationId,
    token~ : String,
    message_id~ : @model.MessageId
  )
  DeleteFollowupMessage(
    application_id~ : @model.ApplicationId,
    token~ : String,
    message_id~ : @model.MessageId
  )
  GetGlobalCommands(application_id~ : @model.ApplicationId, query~ : String)
  CreateGlobalCommand(application_id~ : @model.ApplicationId)
  GetGlobalCommand(
    application_id~ : @model.ApplicationId,
    command_id~ : @model.CommandId
  )
  EditGlobalCommand(
    application_id~ : @model.ApplicationId,
    command_id~ : @model.CommandId
  )
  DeleteGlobalCommand(
    application_id~ : @model.ApplicationId,
    command_id~ : @model.CommandId
  )
  BulkOverwriteGlobalCommands(application_id~ : @model.ApplicationId)
  GetGuildCommands(
    application_id~ : @model.ApplicationId,
    guild_id~ : @model.GuildId,
    query~ : String
  )
  CreateGuildCommand(
    application_id~ : @model.ApplicationId,
    guild_id~ : @model.GuildId
  )
  GetGuildCommand(
    application_id~ : @model.ApplicationId,
    guild_id~ : @model.GuildId,
    command_id~ : @model.CommandId
  )
  EditGuildCommand(
    application_id~ : @model.ApplicationId,
    guild_id~ : @model.GuildId,
    command_id~ : @model.CommandId
  )
  DeleteGuildCommand(
    application_id~ : @model.ApplicationId,
    guild_id~ : @model.GuildId,
    command_id~ : @model.CommandId
  )
  BulkOverwriteGuildCommands(
    application_id~ : @model.ApplicationId,
    guild_id~ : @model.GuildId
  )
  GetGuildApplicationCommandPermissions(
    application_id~ : @model.ApplicationId,
    guild_id~ : @model.GuildId
  )
  GetApplicationCommandPermissions(
    application_id~ : @model.ApplicationId,
    guild_id~ : @model.GuildId,
    command_id~ : @model.CommandId
  )
  EditApplicationCommandPermissions(
    application_id~ : @model.ApplicationId,
    guild_id~ : @model.GuildId,
    command_id~ : @model.CommandId
  )
}

///|
/// Construct a route for a Discord REST endpoint without a typed wrapper.
///
/// `path` is relative to the configured API base and must start with `/`; it
/// may include a query string. When `bucket` is omitted, the rate limiter uses
/// a custom-route namespace plus the HTTP method and query-free concrete path.
/// Supply a bucket explicitly to group minor resource IDs, for example
/// `PATCH:/guilds/123/auto-moderation/rules/{}`.
///
/// Set `is_interaction=true` only for interaction or webhook-token endpoints:
/// these skip the global rate limit and omit bot-token authentication.
///
/// ```mbt check
/// test "derive stable metadata for a custom route" {
///   let route = @http.Route::custom(
///     request_method=Get,
///     path="/guilds/100/stickers?limit=25",
///   )
///   inspect(route.path(), content="/guilds/100/stickers?limit=25")
///   inspect(route.bucket(), content="CUSTOM:GET:/guilds/100/stickers")
///   assert_true(route.needs_auth())
/// }
/// ```
pub fn Route::custom(
  request_method~ : @ahttp.RequestMethod,
  path~ : String,
  bucket? : String,
  is_interaction? : Bool = false,
  supports_reason? : Bool = false,
) -> Route raise CustomRouteError {
  guard path.has_prefix("/") && !path.has_prefix("//") && !path.contains("#") else {
    raise InvalidPath(path~)
  }
  let bucket_key = match bucket {
    Some(value) => {
      guard !value.is_empty() else { raise EmptyBucket }
      value
    }
    None => {
      let bucket_path = match path.split_once("?") {
        Some((value, _)) => value.to_owned()
        None => path
      }
      "CUSTOM:\{@debug.to_string(request_method).to_upper()}:\{bucket_path}"
    }
  }
  Custom(request_method~, path~, bucket_key~, is_interaction~, supports_reason~)
}

///|
/// The HTTP method this route is requested with.
pub fn Route::method_(self : Route) -> @ahttp.RequestMethod {
  match self {
    Custom(request_method~, ..) => request_method
    GetGateway
    | GetGatewayBot
    | GetCurrentApplication
    | GetApplicationActivityInstance(..)
    | GetApplicationIdentityProfile(..)
    | GetApplicationIdentitiesByUserId(..)
    | GetApplicationIdentitiesByExternalId(..)
    | GetApplicationRoleConnectionMetadataRecords(..)
    | ListApplicationEmojis(..)
    | GetApplicationEmoji(..)
    | ListEntitlements(..)
    | GetEntitlement(..)
    | ListSkus(..)
    | ListSkuSubscriptions(..)
    | GetSkuSubscription(..)
    | GetCurrentUser
    | GetCurrentUserGuilds(..)
    | GetCurrentUserConnections
    | GetCurrentUserGuildMember(..)
    | GetCurrentUserApplicationRoleConnection(..)
    | GetCurrentAuthorizationInformation
    | GetCurrentBotApplicationInformation
    | GetUser(..)
    | GetChannel(..)
    | GetChannelMessages(..)
    | GetChannelMessage(..)
    | SearchGuildMessages(..)
    | GetReactions(..)
    | GetPollAnswerVoters(..)
    | GetChannelPins(..)
    | GetPinnedMessages(..)
    | GetChannelInvites(..)
    | GetChannelWebhooks(..)
    | ListThreadMembers(..)
    | GetThreadMember(..)
    | ListPublicArchivedThreads(..)
    | ListPrivateArchivedThreads(..)
    | ListJoinedPrivateArchivedThreads(..)
    | ListActiveGuildThreads(..)
    | GetGuild(..)
    | GetGuildWithCounts(..)
    | GetGuildPreview(..)
    | GetGuildChannels(..)
    | GetGuildMember(..)
    | ListGuildMembers(..)
    | SearchGuildMembers(..)
    | GetGuildRole(..)
    | GetGuildRoles(..)
    | GetGuildBan(..)
    | GetGuildBans(..)
    | GetGuildPruneCount(..)
    | GetGuildVoiceRegions(..)
    | GetGuildInvites(..)
    | GetGuildIntegrations(..)
    | GetGuildVanityUrl(..)
    | GetGuildWidgetSettings(..)
    | GetGuildWidget(..)
    | GetGuildWelcomeScreen(..)
    | GetGuildOnboarding(..)
    | GetGuildAuditLog(..)
    | ListAutoModerationRules(..)
    | GetAutoModerationRule(..)
    | ListGuildStickers(..)
    | GetGuildSticker(..)
    | ListGuildScheduledEvents(..)
    | GetGuildScheduledEvent(..)
    | ListGuildScheduledEventUsers(..)
    | ListGuildSoundboardSounds(..)
    | GetGuildSoundboardSound(..)
    | GetGuildWebhooks(..)
    | ListGuildEmojis(..)
    | GetGuildEmoji(..)
    | GetSticker(..)
    | ListStickerPacks
    | GetStickerPack(..)
    | ListDefaultSoundboardSounds
    | ListVoiceRegions
    | GetCurrentUserVoiceState(..)
    | GetUserVoiceState(..)
    | GetGuildTemplate(..)
    | GetGuildTemplates(..)
    | GetStageInstance(..)
    | GetInvite(..)
    | GetInviteTargetUsersJobStatus(..)
    | GetWebhook(..)
    | GetWebhookWithToken(..)
    | GetWebhookMessage(..)
    | GetOriginalInteractionResponse(..)
    | GetFollowupMessage(..)
    | GetGlobalCommands(..)
    | GetGlobalCommand(..)
    | GetGuildCommands(..)
    | GetGuildCommand(..)
    | GetGuildApplicationCommandPermissions(..)
    | GetApplicationCommandPermissions(..) => Get
    CreateDm
    | CreateMessage(..)
    | CreateTestEntitlement(..)
    | ConsumeEntitlement(..)
    | ExpirePoll(..)
    | SendSoundboardSound(..)
    | BulkDeleteMessages(..)
    | CrosspostMessage(..)
    | FollowAnnouncementChannel(..)
    | TriggerTypingIndicator(..)
    | StartThreadFromMessage(..)
    | StartThreadWithoutMessage(..)
    | CreateGuildChannel(..)
    | CreateGuildRole(..)
    | BulkGuildBan(..)
    | BeginGuildPrune(..)
    | CreateChannelInvite(..)
    | CreateWebhook(..)
    | CreateGuildEmoji(..)
    | CreateApplicationEmoji(..)
    | CreateAutoModerationRule(..)
    | CreateGuildSticker(..)
    | CreateGuildScheduledEvent(..)
    | CreateGuildSoundboardSound(..)
    | CreateGuildFromTemplate(..)
    | CreateGuildTemplate(..)
    | CreateStageInstance
    | ExecuteWebhook(..)
    | ExecuteSlackCompatibleWebhook(..)
    | ExecuteGithubCompatibleWebhook(..)
    | CreateInteractionResponse(..)
    | CreateFollowupMessage(..)
    | CreateGlobalCommand(..)
    | CreateGuildCommand(..)
    | DeleteApplicationIdentity(..)
    | BulkAddInviteTargetUsers(..)
    | BulkDeleteInviteTargetUsers(..) => Post
    ModifyCurrentUser
    | EditCurrentApplication
    | UpdateApplicationIdentityProfile(..)
    | ModifyChannel(..)
    | EditMessage(..)
    | ModifyGuild(..)
    | ModifyGuildChannelPositions(..)
    | ModifyGuildMember(..)
    | ModifyCurrentMember(..)
    | ModifyGuildRole(..)
    | ModifyGuildRolePositions(..)
    | ModifyGuildWidget(..)
    | ModifyGuildWelcomeScreen(..)
    | ModifyWebhook(..)
    | ModifyWebhookWithToken(..)
    | EditWebhookMessage(..)
    | ModifyGuildEmoji(..)
    | ModifyApplicationEmoji(..)
    | ModifyAutoModerationRule(..)
    | ModifyGuildSticker(..)
    | ModifyGuildScheduledEvent(..)
    | ModifyGuildSoundboardSound(..)
    | ModifyCurrentUserVoiceState(..)
    | ModifyUserVoiceState(..)
    | ModifyGuildTemplate(..)
    | ModifyStageInstance(..)
    | EditOriginalInteractionResponse(..)
    | EditFollowupMessage(..)
    | EditGlobalCommand(..)
    | EditGuildCommand(..) => Patch
    DeleteChannel(..)
    | DeleteMessage(..)
    | DeleteOwnReaction(..)
    | DeleteUserReaction(..)
    | DeleteAllReactions(..)
    | DeleteAllReactionsForEmoji(..)
    | GroupDmRemoveRecipient(..)
    | DeleteChannelPermission(..)
    | UnpinMessage(..)
    | LeaveThread(..)
    | RemoveThreadMember(..)
    | DeleteGuildRole(..)
    | DeleteGuildIntegration(..)
    | RemoveGuildMemberRole(..)
    | RemoveGuildMember(..)
    | RemoveGuildBan(..)
    | DeleteInvite(..)
    | DeleteWebhook(..)
    | DeleteWebhookWithToken(..)
    | DeleteWebhookMessage(..)
    | DeleteGuildEmoji(..)
    | DeleteApplicationEmoji(..)
    | DeleteTestEntitlement(..)
    | DeleteAutoModerationRule(..)
    | DeleteGuildSticker(..)
    | DeleteGuildScheduledEvent(..)
    | DeleteGuildSoundboardSound(..)
    | DeleteGuildTemplate(..)
    | DeleteStageInstance(..)
    | DeleteOriginalInteractionResponse(..)
    | DeleteFollowupMessage(..)
    | DeleteGlobalCommand(..)
    | DeleteGuildCommand(..)
    | DeleteCurrentUserApplicationRoleConnection(..)
    | LeaveGuild(..)
    | RemoveInviteTargetUser(..) => Delete
    CreateReaction(..)
    | EditChannelPermissions(..)
    | PinMessage(..)
    | JoinThread(..)
    | AddThreadMember(..)
    | SetVoiceChannelStatus(..)
    | GroupDmAddRecipient(..)
    | AddGuildMemberRole(..)
    | AddGuildMember(..)
    | CreateGuildBan(..)
    | BulkOverwriteGlobalCommands(..)
    | BulkOverwriteGuildCommands(..)
    | EditApplicationCommandPermissions(..)
    | UpdateApplicationRoleConnectionMetadataRecords(..)
    | UpdateCurrentUserApplicationRoleConnection(..)
    | SyncGuildTemplate(..)
    | UpdateInviteTargetUsers(..)
    | AddInviteTargetUser(..) => Put
    ModifyGuildOnboarding(..) | ModifyGuildIncidentActions(..) => Put
  }
}

///|
/// The request path relative to the API base URL, with all route parameters
/// substituted.
pub fn Route::path(self : Route) -> String {
  match self {
    Custom(path~, ..) => path
    GetGateway => "/gateway"
    GetGatewayBot => "/gateway/bot"
    GetCurrentApplication | EditCurrentApplication => "/applications/@me"
    GetApplicationActivityInstance(application_id~, instance_id~) =>
      "/applications/\{application_id}/activity-instances/\{percent_encode(instance_id)}"
    UpdateApplicationIdentityProfile(
      application_id~,
      user_id~,
      provider_issued_user_id~
    )
    | GetApplicationIdentityProfile(
      application_id~,
      user_id~,
      provider_issued_user_id~
    ) =>
      "/applications/\{application_id}/users/\{user_id}/identities/\{percent_encode(provider_issued_user_id)}/profile"
    GetApplicationIdentitiesByUserId(user_id~, application_id~) =>
      "/users/\{user_id}/application-identities/\{application_id}"
    GetApplicationIdentitiesByExternalId(
      application_id~,
      provider_type~,
      provider_issued_user_id~,
      query~
    ) =>
      "/applications/\{application_id}/application-identities/\{percent_encode(provider_type)}/\{percent_encode(provider_issued_user_id)}\{query}"
    DeleteApplicationIdentity(
      user_id~,
      application_id~,
      provider_type~,
      provider_issued_user_id~
    ) =>
      "/users/\{user_id}/application-identities/\{application_id}/\{percent_encode(provider_type)}/\{percent_encode(provider_issued_user_id)}/delete"
    GetApplicationRoleConnectionMetadataRecords(application_id~)
    | UpdateApplicationRoleConnectionMetadataRecords(application_id~) =>
      "/applications/\{application_id}/role-connections/metadata"
    ListApplicationEmojis(application_id~)
    | CreateApplicationEmoji(application_id~) =>
      "/applications/\{application_id}/emojis"
    GetApplicationEmoji(application_id~, emoji_id~)
    | ModifyApplicationEmoji(application_id~, emoji_id~)
    | DeleteApplicationEmoji(application_id~, emoji_id~) =>
      "/applications/\{application_id}/emojis/\{emoji_id}"
    ListEntitlements(application_id~, query~) =>
      "/applications/\{application_id}/entitlements\{query}"
    CreateTestEntitlement(application_id~) =>
      "/applications/\{application_id}/entitlements"
    GetEntitlement(application_id~, entitlement_id~)
    | DeleteTestEntitlement(application_id~, entitlement_id~) =>
      "/applications/\{application_id}/entitlements/\{entitlement_id}"
    ConsumeEntitlement(application_id~, entitlement_id~) =>
      "/applications/\{application_id}/entitlements/\{entitlement_id}/consume"
    ListSkus(application_id~) => "/applications/\{application_id}/skus"
    ListSkuSubscriptions(sku_id~, query~) =>
      "/skus/\{sku_id}/subscriptions\{query}"
    GetSkuSubscription(sku_id~, subscription_id~) =>
      "/skus/\{sku_id}/subscriptions/\{subscription_id}"
    GetCurrentUser | ModifyCurrentUser => "/users/@me"
    GetCurrentUserGuilds(query~) => "/users/@me/guilds\{query}"
    GetCurrentUserConnections => "/users/@me/connections"
    GetCurrentUserGuildMember(guild_id~) =>
      "/users/@me/guilds/\{guild_id}/member"
    GetCurrentUserApplicationRoleConnection(application_id~)
    | UpdateCurrentUserApplicationRoleConnection(application_id~)
    | DeleteCurrentUserApplicationRoleConnection(application_id~) =>
      "/users/@me/applications/\{application_id}/role-connection"
    LeaveGuild(guild_id~) => "/users/@me/guilds/\{guild_id}"
    GetUser(user_id~) => "/users/\{user_id}"
    CreateDm => "/users/@me/channels"
    GetCurrentAuthorizationInformation => "/oauth2/@me"
    GetCurrentBotApplicationInformation => "/oauth2/applications/@me"
    GetChannel(channel_id~)
    | ModifyChannel(channel_id~)
    | DeleteChannel(channel_id~) => "/channels/\{channel_id}"
    GetChannelMessages(channel_id~, query~) =>
      "/channels/\{channel_id}/messages\{query}"
    GetChannelMessage(channel_id~, message_id~)
    | EditMessage(channel_id~, message_id~)
    | DeleteMessage(channel_id~, message_id~) =>
      "/channels/\{channel_id}/messages/\{message_id}"
    CreateMessage(channel_id~) => "/channels/\{channel_id}/messages"
    BulkDeleteMessages(channel_id~) =>
      "/channels/\{channel_id}/messages/bulk-delete"
    CreateReaction(channel_id~, message_id~, emoji~)
    | DeleteOwnReaction(channel_id~, message_id~, emoji~) =>
      "/channels/\{channel_id}/messages/\{message_id}/reactions/\{percent_encode(emoji)}/@me"
    DeleteUserReaction(channel_id~, message_id~, emoji~, user_id~) =>
      "/channels/\{channel_id}/messages/\{message_id}/reactions/\{percent_encode(emoji)}/\{user_id}"
    DeleteAllReactions(channel_id~, message_id~) =>
      "/channels/\{channel_id}/messages/\{message_id}/reactions"
    DeleteAllReactionsForEmoji(channel_id~, message_id~, emoji~) =>
      "/channels/\{channel_id}/messages/\{message_id}/reactions/\{percent_encode(emoji)}"
    CrosspostMessage(channel_id~, message_id~) =>
      "/channels/\{channel_id}/messages/\{message_id}/crosspost"
    GetReactions(channel_id~, message_id~, emoji~, query~) =>
      "/channels/\{channel_id}/messages/\{message_id}/reactions/\{percent_encode(emoji)}\{query}"
    GetPollAnswerVoters(channel_id~, message_id~, answer_id~, query~) =>
      "/channels/\{channel_id}/polls/\{message_id}/answers/\{answer_id}\{query}"
    ExpirePoll(channel_id~, message_id~) =>
      "/channels/\{channel_id}/polls/\{message_id}/expire"
    SendSoundboardSound(channel_id~) =>
      "/channels/\{channel_id}/send-soundboard-sound"
    TriggerTypingIndicator(channel_id~) => "/channels/\{channel_id}/typing"
    PinMessage(channel_id~, message_id~)
    | UnpinMessage(channel_id~, message_id~) =>
      "/channels/\{channel_id}/messages/pins/\{message_id}"
    GetChannelPins(channel_id~, query~) =>
      "/channels/\{channel_id}/messages/pins\{query}"
    GetPinnedMessages(channel_id~) => "/channels/\{channel_id}/pins"
    EditChannelPermissions(channel_id~, overwrite_id~)
    | DeleteChannelPermission(channel_id~, overwrite_id~) =>
      "/channels/\{channel_id}/permissions/\{overwrite_id}"
    GetChannelInvites(channel_id~) | CreateChannelInvite(channel_id~) =>
      "/channels/\{channel_id}/invites"
    FollowAnnouncementChannel(channel_id~) =>
      "/channels/\{channel_id}/followers"
    SetVoiceChannelStatus(channel_id~) => "/channels/\{channel_id}/voice-status"
    GroupDmAddRecipient(channel_id~, user_id~)
    | GroupDmRemoveRecipient(channel_id~, user_id~) =>
      "/channels/\{channel_id}/recipients/\{user_id}"
    CreateWebhook(channel_id~) | GetChannelWebhooks(channel_id~) =>
      "/channels/\{channel_id}/webhooks"
    StartThreadFromMessage(channel_id~, message_id~) =>
      "/channels/\{channel_id}/messages/\{message_id}/threads"
    StartThreadWithoutMessage(channel_id~) => "/channels/\{channel_id}/threads"
    JoinThread(channel_id~) | LeaveThread(channel_id~) =>
      "/channels/\{channel_id}/thread-members/@me"
    ListThreadMembers(channel_id~, query~) =>
      "/channels/\{channel_id}/thread-members\{query}"
    GetThreadMember(channel_id~, user_id~, query~) =>
      "/channels/\{channel_id}/thread-members/\{user_id}\{query}"
    AddThreadMember(channel_id~, user_id~)
    | RemoveThreadMember(channel_id~, user_id~) =>
      "/channels/\{channel_id}/thread-members/\{user_id}"
    ListPublicArchivedThreads(channel_id~, query~) =>
      "/channels/\{channel_id}/threads/archived/public\{query}"
    ListPrivateArchivedThreads(channel_id~, query~) =>
      "/channels/\{channel_id}/threads/archived/private\{query}"
    ListJoinedPrivateArchivedThreads(channel_id~, query~) =>
      "/channels/\{channel_id}/users/@me/threads/archived/private\{query}"
    ListActiveGuildThreads(guild_id~) => "/guilds/\{guild_id}/threads/active"
    SearchGuildMessages(guild_id~, query~) =>
      "/guilds/\{guild_id}/messages/search\{query}"
    GetGuild(guild_id~) => "/guilds/\{guild_id}"
    GetGuildWithCounts(guild_id~, query~) => "/guilds/\{guild_id}\{query}"
    ModifyGuild(guild_id~) => "/guilds/\{guild_id}"
    GetGuildPreview(guild_id~) => "/guilds/\{guild_id}/preview"
    GetGuildChannels(guild_id~)
    | CreateGuildChannel(guild_id~)
    | ModifyGuildChannelPositions(guild_id~) => "/guilds/\{guild_id}/channels"
    GetGuildMember(guild_id~, user_id~)
    | ModifyGuildMember(guild_id~, user_id~)
    | AddGuildMember(guild_id~, user_id~)
    | RemoveGuildMember(guild_id~, user_id~) =>
      "/guilds/\{guild_id}/members/\{user_id}"
    ListGuildMembers(guild_id~, query~) => "/guilds/\{guild_id}/members\{query}"
    SearchGuildMembers(guild_id~, query~) =>
      "/guilds/\{guild_id}/members/search\{query}"
    ModifyCurrentMember(guild_id~) => "/guilds/\{guild_id}/members/@me"
    GetGuildRoles(guild_id~)
    | CreateGuildRole(guild_id~)
    | ModifyGuildRolePositions(guild_id~) => "/guilds/\{guild_id}/roles"
    GetGuildRole(guild_id~, role_id~)
    | ModifyGuildRole(guild_id~, role_id~)
    | DeleteGuildRole(guild_id~, role_id~) =>
      "/guilds/\{guild_id}/roles/\{role_id}"
    AddGuildMemberRole(guild_id~, user_id~, role_id~)
    | RemoveGuildMemberRole(guild_id~, user_id~, role_id~) =>
      "/guilds/\{guild_id}/members/\{user_id}/roles/\{role_id}"
    GetGuildBan(guild_id~, user_id~)
    | CreateGuildBan(guild_id~, user_id~)
    | RemoveGuildBan(guild_id~, user_id~) =>
      "/guilds/\{guild_id}/bans/\{user_id}"
    GetGuildBans(guild_id~, query~) => "/guilds/\{guild_id}/bans\{query}"
    BulkGuildBan(guild_id~) => "/guilds/\{guild_id}/bulk-ban"
    GetGuildPruneCount(guild_id~, query~) => "/guilds/\{guild_id}/prune\{query}"
    BeginGuildPrune(guild_id~) => "/guilds/\{guild_id}/prune"
    GetGuildVoiceRegions(guild_id~) => "/guilds/\{guild_id}/regions"
    GetGuildInvites(guild_id~) => "/guilds/\{guild_id}/invites"
    GetGuildIntegrations(guild_id~) => "/guilds/\{guild_id}/integrations"
    DeleteGuildIntegration(guild_id~, integration_id~) =>
      "/guilds/\{guild_id}/integrations/\{integration_id}"
    GetGuildVanityUrl(guild_id~) => "/guilds/\{guild_id}/vanity-url"
    GetGuildWidgetSettings(guild_id~) | ModifyGuildWidget(guild_id~) =>
      "/guilds/\{guild_id}/widget"
    GetGuildWidget(guild_id~) => "/guilds/\{guild_id}/widget.json"
    GetGuildWelcomeScreen(guild_id~) | ModifyGuildWelcomeScreen(guild_id~) =>
      "/guilds/\{guild_id}/welcome-screen"
    GetGuildOnboarding(guild_id~) | ModifyGuildOnboarding(guild_id~) =>
      "/guilds/\{guild_id}/onboarding"
    ModifyGuildIncidentActions(guild_id~) =>
      "/guilds/\{guild_id}/incident-actions"
    GetGuildAuditLog(guild_id~, query~) =>
      "/guilds/\{guild_id}/audit-logs\{query}"
    ListAutoModerationRules(guild_id~) | CreateAutoModerationRule(guild_id~) =>
      "/guilds/\{guild_id}/auto-moderation/rules"
    GetAutoModerationRule(guild_id~, rule_id~)
    | ModifyAutoModerationRule(guild_id~, rule_id~)
    | DeleteAutoModerationRule(guild_id~, rule_id~) =>
      "/guilds/\{guild_id}/auto-moderation/rules/\{rule_id}"
    ListGuildStickers(guild_id~) | CreateGuildSticker(guild_id~) =>
      "/guilds/\{guild_id}/stickers"
    GetGuildSticker(guild_id~, sticker_id~)
    | ModifyGuildSticker(guild_id~, sticker_id~)
    | DeleteGuildSticker(guild_id~, sticker_id~) =>
      "/guilds/\{guild_id}/stickers/\{sticker_id}"
    ListGuildScheduledEvents(guild_id~, query~) =>
      "/guilds/\{guild_id}/scheduled-events\{query}"
    CreateGuildScheduledEvent(guild_id~) =>
      "/guilds/\{guild_id}/scheduled-events"
    GetGuildScheduledEvent(guild_id~, event_id~, query~) =>
      "/guilds/\{guild_id}/scheduled-events/\{event_id}\{query}"
    ModifyGuildScheduledEvent(guild_id~, event_id~)
    | DeleteGuildScheduledEvent(guild_id~, event_id~) =>
      "/guilds/\{guild_id}/scheduled-events/\{event_id}"
    ListGuildScheduledEventUsers(guild_id~, event_id~, query~) =>
      "/guilds/\{guild_id}/scheduled-events/\{event_id}/users\{query}"
    ListGuildSoundboardSounds(guild_id~)
    | CreateGuildSoundboardSound(guild_id~) =>
      "/guilds/\{guild_id}/soundboard-sounds"
    GetGuildSoundboardSound(guild_id~, sound_id~)
    | ModifyGuildSoundboardSound(guild_id~, sound_id~)
    | DeleteGuildSoundboardSound(guild_id~, sound_id~) =>
      "/guilds/\{guild_id}/soundboard-sounds/\{sound_id}"
    GetGuildWebhooks(guild_id~) => "/guilds/\{guild_id}/webhooks"
    ListGuildEmojis(guild_id~) | CreateGuildEmoji(guild_id~) =>
      "/guilds/\{guild_id}/emojis"
    GetGuildEmoji(guild_id~, emoji_id~)
    | ModifyGuildEmoji(guild_id~, emoji_id~)
    | DeleteGuildEmoji(guild_id~, emoji_id~) =>
      "/guilds/\{guild_id}/emojis/\{emoji_id}"
    GetSticker(sticker_id~) => "/stickers/\{sticker_id}"
    ListStickerPacks => "/sticker-packs"
    GetStickerPack(pack_id~) => "/sticker-packs/\{pack_id}"
    ListDefaultSoundboardSounds => "/soundboard-default-sounds"
    ListVoiceRegions => "/voice/regions"
    GetCurrentUserVoiceState(guild_id~)
    | ModifyCurrentUserVoiceState(guild_id~) =>
      "/guilds/\{guild_id}/voice-states/@me"
    GetUserVoiceState(guild_id~, user_id~)
    | ModifyUserVoiceState(guild_id~, user_id~) =>
      "/guilds/\{guild_id}/voice-states/\{user_id}"
    GetGuildTemplate(template_code~)
    | CreateGuildFromTemplate(template_code~) =>
      "/guilds/templates/\{percent_encode(template_code)}"
    GetGuildTemplates(guild_id~) | CreateGuildTemplate(guild_id~) =>
      "/guilds/\{guild_id}/templates"
    SyncGuildTemplate(guild_id~, template_code~)
    | ModifyGuildTemplate(guild_id~, template_code~)
    | DeleteGuildTemplate(guild_id~, template_code~) =>
      "/guilds/\{guild_id}/templates/\{percent_encode(template_code)}"
    CreateStageInstance => "/stage-instances"
    GetStageInstance(channel_id~)
    | ModifyStageInstance(channel_id~)
    | DeleteStageInstance(channel_id~) => "/stage-instances/\{channel_id}"
    GetInvite(code~, query~) => "/invites/\{percent_encode(code)}\{query}"
    DeleteInvite(code~) => "/invites/\{percent_encode(code)}"
    UpdateInviteTargetUsers(code~) =>
      "/invites/\{percent_encode(code)}/target-users"
    GetInviteTargetUsersJobStatus(code~) =>
      "/invites/\{percent_encode(code)}/target-users/job-status"
    AddInviteTargetUser(code~, user_id~)
    | RemoveInviteTargetUser(code~, user_id~) =>
      "/invites/\{percent_encode(code)}/target-users/\{user_id}"
    BulkAddInviteTargetUsers(code~) =>
      "/invites/\{percent_encode(code)}/target-users/bulk-add"
    BulkDeleteInviteTargetUsers(code~) =>
      "/invites/\{percent_encode(code)}/target-users/bulk-delete"
    GetWebhook(webhook_id~)
    | ModifyWebhook(webhook_id~)
    | DeleteWebhook(webhook_id~) => "/webhooks/\{webhook_id}"
    GetWebhookWithToken(webhook_id~, token~)
    | ModifyWebhookWithToken(webhook_id~, token~)
    | DeleteWebhookWithToken(webhook_id~, token~) =>
      "/webhooks/\{webhook_id}/\{token}"
    ExecuteWebhook(webhook_id~, token~, query~) =>
      "/webhooks/\{webhook_id}/\{token}\{query}"
    ExecuteSlackCompatibleWebhook(webhook_id~, token~, query~) =>
      "/webhooks/\{webhook_id}/\{token}/slack\{query}"
    ExecuteGithubCompatibleWebhook(webhook_id~, token~, query~) =>
      "/webhooks/\{webhook_id}/\{token}/github\{query}"
    GetWebhookMessage(webhook_id~, token~, message_id~, query~)
    | EditWebhookMessage(webhook_id~, token~, message_id~, query~)
    | DeleteWebhookMessage(webhook_id~, token~, message_id~, query~) =>
      "/webhooks/\{webhook_id}/\{token}/messages/\{message_id}\{query}"
    CreateInteractionResponse(interaction_id~, token~, query~) =>
      "/interactions/\{interaction_id}/\{token}/callback\{query}"
    GetOriginalInteractionResponse(application_id~, token~)
    | EditOriginalInteractionResponse(application_id~, token~)
    | DeleteOriginalInteractionResponse(application_id~, token~) =>
      "/webhooks/\{application_id}/\{token}/messages/@original"
    CreateFollowupMessage(application_id~, token~) =>
      "/webhooks/\{application_id}/\{token}"
    GetFollowupMessage(application_id~, token~, message_id~)
    | EditFollowupMessage(application_id~, token~, message_id~)
    | DeleteFollowupMessage(application_id~, token~, message_id~) =>
      "/webhooks/\{application_id}/\{token}/messages/\{message_id}"
    GetGlobalCommands(application_id~, query~) =>
      "/applications/\{application_id}/commands\{query}"
    CreateGlobalCommand(application_id~)
    | BulkOverwriteGlobalCommands(application_id~) =>
      "/applications/\{application_id}/commands"
    GetGlobalCommand(application_id~, command_id~)
    | EditGlobalCommand(application_id~, command_id~)
    | DeleteGlobalCommand(application_id~, command_id~) =>
      "/applications/\{application_id}/commands/\{command_id}"
    GetGuildCommands(application_id~, guild_id~, query~) =>
      "/applications/\{application_id}/guilds/\{guild_id}/commands\{query}"
    CreateGuildCommand(application_id~, guild_id~)
    | BulkOverwriteGuildCommands(application_id~, guild_id~) =>
      "/applications/\{application_id}/guilds/\{guild_id}/commands"
    GetGuildCommand(application_id~, guild_id~, command_id~)
    | EditGuildCommand(application_id~, guild_id~, command_id~)
    | DeleteGuildCommand(application_id~, guild_id~, command_id~) =>
      "/applications/\{application_id}/guilds/\{guild_id}/commands/\{command_id}"
    GetGuildApplicationCommandPermissions(application_id~, guild_id~) =>
      "/applications/\{application_id}/guilds/\{guild_id}/commands/permissions"
    GetApplicationCommandPermissions(application_id~, guild_id~, command_id~)
    | EditApplicationCommandPermissions(application_id~, guild_id~, command_id~) =>
      "/applications/\{application_id}/guilds/\{guild_id}/commands/\{command_id}/permissions"
  }
}

///|
/// Rate-limit bucket key: method plus path template with application, channel,
/// guild, and webhook ID/token majors kept while minor resource IDs are
/// squashed.
pub fn Route::bucket(self : Route) -> String {
  match self {
    Custom(bucket_key~, ..) => bucket_key
    GetGateway => "GET:/gateway"
    GetGatewayBot => "GET:/gateway/bot"
    GetCurrentApplication => "GET:/applications/@me"
    EditCurrentApplication => "PATCH:/applications/@me"
    GetApplicationActivityInstance(application_id~, ..) =>
      "GET:/applications/\{application_id}/activity-instances/{}"
    UpdateApplicationIdentityProfile(application_id~, ..) =>
      "PATCH:/applications/\{application_id}/users/{}/identities/{}/profile"
    GetApplicationIdentityProfile(application_id~, ..) =>
      "GET:/applications/\{application_id}/users/{}/identities/{}/profile"
    GetApplicationIdentitiesByUserId(application_id~, ..) =>
      "GET:/users/{}/application-identities/\{application_id}"
    GetApplicationIdentitiesByExternalId(application_id~, ..) =>
      "GET:/applications/\{application_id}/application-identities/{}/{}"
    DeleteApplicationIdentity(application_id~, ..) =>
      "POST:/users/{}/application-identities/\{application_id}/{}/{}/delete"
    GetApplicationRoleConnectionMetadataRecords(application_id~) =>
      "GET:/applications/\{application_id}/role-connections/metadata"
    UpdateApplicationRoleConnectionMetadataRecords(application_id~) =>
      "PUT:/applications/\{application_id}/role-connections/metadata"
    ListApplicationEmojis(application_id~) =>
      "GET:/applications/\{application_id}/emojis"
    GetApplicationEmoji(application_id~, ..) =>
      "GET:/applications/\{application_id}/emojis/{}"
    CreateApplicationEmoji(application_id~) =>
      "POST:/applications/\{application_id}/emojis"
    ModifyApplicationEmoji(application_id~, ..) =>
      "PATCH:/applications/\{application_id}/emojis/{}"
    DeleteApplicationEmoji(application_id~, ..) =>
      "DELETE:/applications/\{application_id}/emojis/{}"
    ListEntitlements(application_id~, ..) =>
      "GET:/applications/\{application_id}/entitlements"
    GetEntitlement(application_id~, ..) =>
      "GET:/applications/\{application_id}/entitlements/{}"
    CreateTestEntitlement(application_id~) =>
      "POST:/applications/\{application_id}/entitlements"
    ConsumeEntitlement(application_id~, ..) =>
      "POST:/applications/\{application_id}/entitlements/{}/consume"
    DeleteTestEntitlement(application_id~, ..) =>
      "DELETE:/applications/\{application_id}/entitlements/{}"
    ListSkus(application_id~) => "GET:/applications/\{application_id}/skus"
    ListSkuSubscriptions(..) => "GET:/skus/{}/subscriptions"
    GetSkuSubscription(..) => "GET:/skus/{}/subscriptions/{}"
    GetCurrentUser => "GET:/users/@me"
    GetCurrentUserGuilds(..) => "GET:/users/@me/guilds"
    GetCurrentUserConnections => "GET:/users/@me/connections"
    GetCurrentUserGuildMember(guild_id~) =>
      "GET:/users/@me/guilds/\{guild_id}/member"
    GetCurrentUserApplicationRoleConnection(application_id~) =>
      "GET:/users/@me/applications/\{application_id}/role-connection"
    UpdateCurrentUserApplicationRoleConnection(application_id~) =>
      "PUT:/users/@me/applications/\{application_id}/role-connection"
    DeleteCurrentUserApplicationRoleConnection(application_id~) =>
      "DELETE:/users/@me/applications/\{application_id}/role-connection"
    LeaveGuild(guild_id~) => "DELETE:/users/@me/guilds/\{guild_id}"
    ModifyCurrentUser => "PATCH:/users/@me"
    GetUser(..) => "GET:/users/{}"
    CreateDm => "POST:/users/@me/channels"
    GetCurrentAuthorizationInformation => "GET:/oauth2/@me"
    GetCurrentBotApplicationInformation => "GET:/oauth2/applications/@me"
    GetChannel(channel_id~) => "GET:/channels/\{channel_id}"
    ModifyChannel(channel_id~) => "PATCH:/channels/\{channel_id}"
    DeleteChannel(channel_id~) => "DELETE:/channels/\{channel_id}"
    GetChannelMessages(channel_id~, ..) =>
      "GET:/channels/\{channel_id}/messages"
    GetChannelMessage(channel_id~, ..) =>
      "GET:/channels/\{channel_id}/messages/{}"
    CreateMessage(channel_id~) => "POST:/channels/\{channel_id}/messages"
    EditMessage(channel_id~, ..) => "PATCH:/channels/\{channel_id}/messages/{}"
    DeleteMessage(channel_id~, ..) =>
      "DELETE:/channels/\{channel_id}/messages/{}"
    BulkDeleteMessages(channel_id~) =>
      "POST:/channels/\{channel_id}/messages/bulk-delete"
    CreateReaction(channel_id~, ..) =>
      "PUT:/channels/\{channel_id}/messages/{}/reactions/{}"
    DeleteOwnReaction(channel_id~, ..) =>
      "DELETE:/channels/\{channel_id}/messages/{}/reactions/{}"
    DeleteUserReaction(channel_id~, ..) =>
      "DELETE:/channels/\{channel_id}/messages/{}/reactions/{}"
    DeleteAllReactions(channel_id~, ..) =>
      "DELETE:/channels/\{channel_id}/messages/{}/reactions"
    DeleteAllReactionsForEmoji(channel_id~, ..) =>
      "DELETE:/channels/\{channel_id}/messages/{}/reactions/{}"
    CrosspostMessage(channel_id~, ..) =>
      "POST:/channels/\{channel_id}/messages/{}/crosspost"
    GetReactions(channel_id~, ..) =>
      "GET:/channels/\{channel_id}/messages/{}/reactions/{}"
    GetPollAnswerVoters(channel_id~, ..) =>
      "GET:/channels/\{channel_id}/polls/{}/answers/{}"
    ExpirePoll(channel_id~, ..) =>
      "POST:/channels/\{channel_id}/polls/{}/expire"
    SendSoundboardSound(channel_id~) =>
      "POST:/channels/\{channel_id}/send-soundboard-sound"
    TriggerTypingIndicator(channel_id~) => "POST:/channels/\{channel_id}/typing"
    PinMessage(channel_id~, ..) =>
      "PUT:/channels/\{channel_id}/messages/pins/{}"
    UnpinMessage(channel_id~, ..) =>
      "DELETE:/channels/\{channel_id}/messages/pins/{}"
    GetChannelPins(channel_id~, ..) =>
      "GET:/channels/\{channel_id}/messages/pins"
    GetPinnedMessages(channel_id~) => "GET:/channels/\{channel_id}/pins"
    EditChannelPermissions(channel_id~, ..) =>
      "PUT:/channels/\{channel_id}/permissions/{}"
    DeleteChannelPermission(channel_id~, ..) =>
      "DELETE:/channels/\{channel_id}/permissions/{}"
    GetChannelInvites(channel_id~) => "GET:/channels/\{channel_id}/invites"
    CreateChannelInvite(channel_id~) => "POST:/channels/\{channel_id}/invites"
    FollowAnnouncementChannel(channel_id~) =>
      "POST:/channels/\{channel_id}/followers"
    SetVoiceChannelStatus(channel_id~) =>
      "PUT:/channels/\{channel_id}/voice-status"
    GroupDmAddRecipient(channel_id~, ..) =>
      "PUT:/channels/\{channel_id}/recipients/{}"
    GroupDmRemoveRecipient(channel_id~, ..) =>
      "DELETE:/channels/\{channel_id}/recipients/{}"
    CreateWebhook(channel_id~) => "POST:/channels/\{channel_id}/webhooks"
    GetChannelWebhooks(channel_id~) => "GET:/channels/\{channel_id}/webhooks"
    StartThreadFromMessage(channel_id~, ..) =>
      "POST:/channels/\{channel_id}/messages/{}/threads"
    StartThreadWithoutMessage(channel_id~) =>
      "POST:/channels/\{channel_id}/threads"
    JoinThread(channel_id~) => "PUT:/channels/\{channel_id}/thread-members/@me"
    LeaveThread(channel_id~) =>
      "DELETE:/channels/\{channel_id}/thread-members/@me"
    ListThreadMembers(channel_id~, ..) =>
      "GET:/channels/\{channel_id}/thread-members"
    GetThreadMember(channel_id~, ..) =>
      "GET:/channels/\{channel_id}/thread-members/{}"
    AddThreadMember(channel_id~, ..) =>
      "PUT:/channels/\{channel_id}/thread-members/{}"
    RemoveThreadMember(channel_id~, ..) =>
      "DELETE:/channels/\{channel_id}/thread-members/{}"
    ListPublicArchivedThreads(channel_id~, ..) =>
      "GET:/channels/\{channel_id}/threads/archived/public"
    ListPrivateArchivedThreads(channel_id~, ..) =>
      "GET:/channels/\{channel_id}/threads/archived/private"
    ListJoinedPrivateArchivedThreads(channel_id~, ..) =>
      "GET:/channels/\{channel_id}/users/@me/threads/archived/private"
    ListActiveGuildThreads(guild_id~) =>
      "GET:/guilds/\{guild_id}/threads/active"
    SearchGuildMessages(guild_id~, ..) =>
      "GET:/guilds/\{guild_id}/messages/search"
    GetGuild(guild_id~) | GetGuildWithCounts(guild_id~, ..) =>
      "GET:/guilds/\{guild_id}"
    ModifyGuild(guild_id~) => "PATCH:/guilds/\{guild_id}"
    GetGuildPreview(guild_id~) => "GET:/guilds/\{guild_id}/preview"
    GetGuildChannels(guild_id~) => "GET:/guilds/\{guild_id}/channels"
    CreateGuildChannel(guild_id~) => "POST:/guilds/\{guild_id}/channels"
    ModifyGuildChannelPositions(guild_id~) =>
      "PATCH:/guilds/\{guild_id}/channels"
    GetGuildMember(guild_id~, ..) => "GET:/guilds/\{guild_id}/members/{}"
    ListGuildMembers(guild_id~, ..) => "GET:/guilds/\{guild_id}/members"
    SearchGuildMembers(guild_id~, ..) =>
      "GET:/guilds/\{guild_id}/members/search"
    ModifyGuildMember(guild_id~, ..) => "PATCH:/guilds/\{guild_id}/members/{}"
    AddGuildMember(guild_id~, ..) => "PUT:/guilds/\{guild_id}/members/{}"
    ModifyCurrentMember(guild_id~) => "PATCH:/guilds/\{guild_id}/members/@me"
    GetGuildRoles(guild_id~) => "GET:/guilds/\{guild_id}/roles"
    GetGuildRole(guild_id~, ..) => "GET:/guilds/\{guild_id}/roles/{}"
    CreateGuildRole(guild_id~) => "POST:/guilds/\{guild_id}/roles"
    ModifyGuildRolePositions(guild_id~) => "PATCH:/guilds/\{guild_id}/roles"
    ModifyGuildRole(guild_id~, ..) => "PATCH:/guilds/\{guild_id}/roles/{}"
    DeleteGuildRole(guild_id~, ..) => "DELETE:/guilds/\{guild_id}/roles/{}"
    AddGuildMemberRole(guild_id~, ..) =>
      "PUT:/guilds/\{guild_id}/members/{}/roles/{}"
    RemoveGuildMemberRole(guild_id~, ..) =>
      "DELETE:/guilds/\{guild_id}/members/{}/roles/{}"
    RemoveGuildMember(guild_id~, ..) => "DELETE:/guilds/\{guild_id}/members/{}"
    CreateGuildBan(guild_id~, ..) => "PUT:/guilds/\{guild_id}/bans/{}"
    RemoveGuildBan(guild_id~, ..) => "DELETE:/guilds/\{guild_id}/bans/{}"
    GetGuildBan(guild_id~, ..) => "GET:/guilds/\{guild_id}/bans/{}"
    GetGuildBans(guild_id~, ..) => "GET:/guilds/\{guild_id}/bans"
    BulkGuildBan(guild_id~) => "POST:/guilds/\{guild_id}/bulk-ban"
    GetGuildPruneCount(guild_id~, ..) => "GET:/guilds/\{guild_id}/prune"
    BeginGuildPrune(guild_id~) => "POST:/guilds/\{guild_id}/prune"
    GetGuildVoiceRegions(guild_id~) => "GET:/guilds/\{guild_id}/regions"
    GetGuildInvites(guild_id~) => "GET:/guilds/\{guild_id}/invites"
    GetGuildIntegrations(guild_id~) => "GET:/guilds/\{guild_id}/integrations"
    DeleteGuildIntegration(guild_id~, ..) =>
      "DELETE:/guilds/\{guild_id}/integrations/{}"
    GetGuildVanityUrl(guild_id~) => "GET:/guilds/\{guild_id}/vanity-url"
    GetGuildWidgetSettings(guild_id~) => "GET:/guilds/\{guild_id}/widget"
    ModifyGuildWidget(guild_id~) => "PATCH:/guilds/\{guild_id}/widget"
    GetGuildWidget(guild_id~) => "GET:/guilds/\{guild_id}/widget.json"
    GetGuildWelcomeScreen(guild_id~) => "GET:/guilds/\{guild_id}/welcome-screen"
    ModifyGuildWelcomeScreen(guild_id~) =>
      "PATCH:/guilds/\{guild_id}/welcome-screen"
    GetGuildOnboarding(guild_id~) => "GET:/guilds/\{guild_id}/onboarding"
    ModifyGuildOnboarding(guild_id~) => "PUT:/guilds/\{guild_id}/onboarding"
    ModifyGuildIncidentActions(guild_id~) =>
      "PUT:/guilds/\{guild_id}/incident-actions"
    GetGuildAuditLog(guild_id~, ..) => "GET:/guilds/\{guild_id}/audit-logs"
    ListAutoModerationRules(guild_id~) =>
      "GET:/guilds/\{guild_id}/auto-moderation/rules"
    GetAutoModerationRule(guild_id~, ..) =>
      "GET:/guilds/\{guild_id}/auto-moderation/rules/{}"
    CreateAutoModerationRule(guild_id~) =>
      "POST:/guilds/\{guild_id}/auto-moderation/rules"
    ModifyAutoModerationRule(guild_id~, ..) =>
      "PATCH:/guilds/\{guild_id}/auto-moderation/rules/{}"
    DeleteAutoModerationRule(guild_id~, ..) =>
      "DELETE:/guilds/\{guild_id}/auto-moderation/rules/{}"
    ListGuildStickers(guild_id~) => "GET:/guilds/\{guild_id}/stickers"
    GetGuildSticker(guild_id~, ..) => "GET:/guilds/\{guild_id}/stickers/{}"
    CreateGuildSticker(guild_id~) => "POST:/guilds/\{guild_id}/stickers"
    ModifyGuildSticker(guild_id~, ..) => "PATCH:/guilds/\{guild_id}/stickers/{}"
    DeleteGuildSticker(guild_id~, ..) =>
      "DELETE:/guilds/\{guild_id}/stickers/{}"
    ListGuildScheduledEvents(guild_id~, ..) =>
      "GET:/guilds/\{guild_id}/scheduled-events"
    CreateGuildScheduledEvent(guild_id~) =>
      "POST:/guilds/\{guild_id}/scheduled-events"
    GetGuildScheduledEvent(guild_id~, ..) =>
      "GET:/guilds/\{guild_id}/scheduled-events/{}"
    ModifyGuildScheduledEvent(guild_id~, ..) =>
      "PATCH:/guilds/\{guild_id}/scheduled-events/{}"
    DeleteGuildScheduledEvent(guild_id~, ..) =>
      "DELETE:/guilds/\{guild_id}/scheduled-events/{}"
    ListGuildScheduledEventUsers(guild_id~, ..) =>
      "GET:/guilds/\{guild_id}/scheduled-events/{}/users"
    ListGuildSoundboardSounds(guild_id~) =>
      "GET:/guilds/\{guild_id}/soundboard-sounds"
    CreateGuildSoundboardSound(guild_id~) =>
      "POST:/guilds/\{guild_id}/soundboard-sounds"
    GetGuildSoundboardSound(guild_id~, ..) =>
      "GET:/guilds/\{guild_id}/soundboard-sounds/{}"
    ModifyGuildSoundboardSound(guild_id~, ..) =>
      "PATCH:/guilds/\{guild_id}/soundboard-sounds/{}"
    DeleteGuildSoundboardSound(guild_id~, ..) =>
      "DELETE:/guilds/\{guild_id}/soundboard-sounds/{}"
    GetGuildWebhooks(guild_id~) => "GET:/guilds/\{guild_id}/webhooks"
    ListGuildEmojis(guild_id~) => "GET:/guilds/\{guild_id}/emojis"
    GetGuildEmoji(guild_id~, ..) => "GET:/guilds/\{guild_id}/emojis/{}"
    CreateGuildEmoji(guild_id~) => "POST:/guilds/\{guild_id}/emojis"
    ModifyGuildEmoji(guild_id~, ..) => "PATCH:/guilds/\{guild_id}/emojis/{}"
    DeleteGuildEmoji(guild_id~, ..) => "DELETE:/guilds/\{guild_id}/emojis/{}"
    GetSticker(..) => "GET:/stickers/{}"
    ListStickerPacks => "GET:/sticker-packs"
    GetStickerPack(..) => "GET:/sticker-packs/{}"
    ListDefaultSoundboardSounds => "GET:/soundboard-default-sounds"
    ListVoiceRegions => "GET:/voice/regions"
    GetCurrentUserVoiceState(guild_id~) =>
      "GET:/guilds/\{guild_id}/voice-states/@me"
    GetUserVoiceState(guild_id~, ..) =>
      "GET:/guilds/\{guild_id}/voice-states/{}"
    ModifyCurrentUserVoiceState(guild_id~) =>
      "PATCH:/guilds/\{guild_id}/voice-states/@me"
    ModifyUserVoiceState(guild_id~, ..) =>
      "PATCH:/guilds/\{guild_id}/voice-states/{}"
    GetGuildTemplate(..) => "GET:/guilds/templates/{}"
    CreateGuildFromTemplate(..) => "POST:/guilds/templates/{}"
    GetGuildTemplates(guild_id~) => "GET:/guilds/\{guild_id}/templates"
    CreateGuildTemplate(guild_id~) => "POST:/guilds/\{guild_id}/templates"
    SyncGuildTemplate(guild_id~, ..) => "PUT:/guilds/\{guild_id}/templates/{}"
    ModifyGuildTemplate(guild_id~, ..) =>
      "PATCH:/guilds/\{guild_id}/templates/{}"
    DeleteGuildTemplate(guild_id~, ..) =>
      "DELETE:/guilds/\{guild_id}/templates/{}"
    CreateStageInstance => "POST:/stage-instances"
    GetStageInstance(channel_id~) => "GET:/stage-instances/\{channel_id}"
    ModifyStageInstance(channel_id~) => "PATCH:/stage-instances/\{channel_id}"
    DeleteStageInstance(channel_id~) => "DELETE:/stage-instances/\{channel_id}"
    GetInvite(..) => "GET:/invites/{}"
    DeleteInvite(..) => "DELETE:/invites/{}"
    UpdateInviteTargetUsers(..) => "PUT:/invites/{}/target-users"
    GetInviteTargetUsersJobStatus(..) =>
      "GET:/invites/{}/target-users/job-status"
    AddInviteTargetUser(..) => "PUT:/invites/{}/target-users/{}"
    RemoveInviteTargetUser(..) => "DELETE:/invites/{}/target-users/{}"
    BulkAddInviteTargetUsers(..) => "POST:/invites/{}/target-users/bulk-add"
    BulkDeleteInviteTargetUsers(..) =>
      "POST:/invites/{}/target-users/bulk-delete"
    GetWebhook(webhook_id~) => "GET:/webhooks/\{webhook_id}"
    ModifyWebhook(webhook_id~) => "PATCH:/webhooks/\{webhook_id}"
    DeleteWebhook(webhook_id~) => "DELETE:/webhooks/\{webhook_id}"
    GetWebhookWithToken(webhook_id~, token~) =>
      "GET:/webhooks/\{webhook_id}/\{token}"
    ModifyWebhookWithToken(webhook_id~, token~) =>
      "PATCH:/webhooks/\{webhook_id}/\{token}"
    DeleteWebhookWithToken(webhook_id~, token~) =>
      "DELETE:/webhooks/\{webhook_id}/\{token}"
    ExecuteWebhook(webhook_id~, token~, ..) =>
      "POST:/webhooks/\{webhook_id}/\{token}"
    ExecuteSlackCompatibleWebhook(webhook_id~, token~, ..) =>
      "POST:/webhooks/\{webhook_id}/\{token}/slack"
    ExecuteGithubCompatibleWebhook(webhook_id~, token~, ..) =>
      "POST:/webhooks/\{webhook_id}/\{token}/github"
    GetWebhookMessage(webhook_id~, token~, ..) =>
      "GET:/webhooks/\{webhook_id}/\{token}/messages/{}"
    EditWebhookMessage(webhook_id~, token~, ..) =>
      "PATCH:/webhooks/\{webhook_id}/\{token}/messages/{}"
    DeleteWebhookMessage(webhook_id~, token~, ..) =>
      "DELETE:/webhooks/\{webhook_id}/\{token}/messages/{}"
    CreateInteractionResponse(..) => "POST:/interactions/{}/{}/callback"
    GetOriginalInteractionResponse(application_id~, token~) =>
      "GET:/webhooks/\{application_id}/\{token}/messages/@original"
    EditOriginalInteractionResponse(application_id~, token~) =>
      "PATCH:/webhooks/\{application_id}/\{token}/messages/@original"
    DeleteOriginalInteractionResponse(application_id~, token~) =>
      "DELETE:/webhooks/\{application_id}/\{token}/messages/@original"
    CreateFollowupMessage(application_id~, token~) =>
      "POST:/webhooks/\{application_id}/\{token}"
    GetFollowupMessage(application_id~, token~, ..) =>
      "GET:/webhooks/\{application_id}/\{token}/messages/{}"
    EditFollowupMessage(application_id~, token~, ..) =>
      "PATCH:/webhooks/\{application_id}/\{token}/messages/{}"
    DeleteFollowupMessage(application_id~, token~, ..) =>
      "DELETE:/webhooks/\{application_id}/\{token}/messages/{}"
    GetGlobalCommands(application_id~, ..) =>
      "GET:/applications/\{application_id}/commands"
    CreateGlobalCommand(application_id~) =>
      "POST:/applications/\{application_id}/commands"
    GetGlobalCommand(application_id~, ..) =>
      "GET:/applications/\{application_id}/commands/{}"
    EditGlobalCommand(application_id~, ..) =>
      "PATCH:/applications/\{application_id}/commands/{}"
    DeleteGlobalCommand(application_id~, ..) =>
      "DELETE:/applications/\{application_id}/commands/{}"
    BulkOverwriteGlobalCommands(application_id~) =>
      "PUT:/applications/\{application_id}/commands"
    GetGuildCommands(application_id~, guild_id~, ..) =>
      "GET:/applications/\{application_id}/guilds/\{guild_id}/commands"
    CreateGuildCommand(application_id~, guild_id~) =>
      "POST:/applications/\{application_id}/guilds/\{guild_id}/commands"
    GetGuildCommand(application_id~, guild_id~, ..) =>
      "GET:/applications/\{application_id}/guilds/\{guild_id}/commands/{}"
    EditGuildCommand(application_id~, guild_id~, ..) =>
      "PATCH:/applications/\{application_id}/guilds/\{guild_id}/commands/{}"
    DeleteGuildCommand(application_id~, guild_id~, ..) =>
      "DELETE:/applications/\{application_id}/guilds/\{guild_id}/commands/{}"
    BulkOverwriteGuildCommands(application_id~, guild_id~) =>
      "PUT:/applications/\{application_id}/guilds/\{guild_id}/commands"
    GetGuildApplicationCommandPermissions(application_id~, guild_id~) =>
      "GET:/applications/\{application_id}/guilds/\{guild_id}/commands/permissions"
    GetApplicationCommandPermissions(application_id~, guild_id~, ..) =>
      "GET:/applications/\{application_id}/guilds/\{guild_id}/commands/{}/permissions"
    EditApplicationCommandPermissions(application_id~, guild_id~, ..) =>
      "PUT:/applications/\{application_id}/guilds/\{guild_id}/commands/{}/permissions"
  }
}

///|
/// Interaction/webhook-token endpoints are exempt from the global limit.
pub fn Route::is_interaction(self : Route) -> Bool {
  match self {
    Custom(is_interaction~, ..) => is_interaction
    CreateInteractionResponse(..)
    | GetOriginalInteractionResponse(..)
    | EditOriginalInteractionResponse(..)
    | DeleteOriginalInteractionResponse(..)
    | CreateFollowupMessage(..)
    | GetFollowupMessage(..)
    | EditFollowupMessage(..)
    | DeleteFollowupMessage(..)
    | ExecuteWebhook(..)
    | GetWebhookWithToken(..)
    | ModifyWebhookWithToken(..)
    | DeleteWebhookWithToken(..)
    | ExecuteSlackCompatibleWebhook(..)
    | ExecuteGithubCompatibleWebhook(..)
    | GetWebhookMessage(..)
    | EditWebhookMessage(..)
    | DeleteWebhookMessage(..) => true
    _ => false
  }
}

///|
/// Whether the endpoint accepts the X-Audit-Log-Reason header.
pub fn Route::supports_reason(self : Route) -> Bool {
  match self {
    Custom(supports_reason~, ..) => supports_reason
    ModifyChannel(..)
    | DeleteChannel(..)
    | DeleteMessage(..)
    | BulkDeleteMessages(..)
    | PinMessage(..)
    | UnpinMessage(..)
    | EditChannelPermissions(..)
    | DeleteChannelPermission(..)
    | CreateChannelInvite(..)
    | FollowAnnouncementChannel(..)
    | SetVoiceChannelStatus(..)
    | CreateWebhook(..)
    | ModifyWebhook(..)
    | DeleteWebhook(..)
    | DeleteInvite(..)
    | CreateGuildEmoji(..)
    | ModifyGuildEmoji(..)
    | DeleteGuildEmoji(..)
    | StartThreadFromMessage(..)
    | StartThreadWithoutMessage(..)
    | ModifyGuild(..)
    | CreateGuildChannel(..)
    | ModifyGuildChannelPositions(..)
    | ModifyGuildRole(..)
    | ModifyGuildRolePositions(..)
    | CreateGuildRole(..)
    | DeleteGuildRole(..)
    | AddGuildMemberRole(..)
    | RemoveGuildMemberRole(..)
    | RemoveGuildMember(..)
    | CreateGuildBan(..)
    | BulkGuildBan(..)
    | RemoveGuildBan(..)
    | BeginGuildPrune(..)
    | DeleteGuildIntegration(..)
    | ModifyGuildWidget(..)
    | ModifyGuildWelcomeScreen(..)
    | ModifyGuildOnboarding(..)
    | ModifyGuildMember(..)
    | ModifyCurrentMember(..)
    | CreateAutoModerationRule(..)
    | ModifyAutoModerationRule(..)
    | DeleteAutoModerationRule(..)
    | CreateGuildSticker(..)
    | ModifyGuildSticker(..)
    | DeleteGuildSticker(..)
    | CreateGuildScheduledEvent(..)
    | ModifyGuildScheduledEvent(..)
    | DeleteGuildScheduledEvent(..)
    | CreateStageInstance
    | ModifyStageInstance(..)
    | DeleteStageInstance(..)
    | CreateGuildSoundboardSound(..)
    | ModifyGuildSoundboardSound(..)
    | DeleteGuildSoundboardSound(..) => true
    _ => false
  }
}

///|
/// Interaction callbacks and webhook-token routes are called without the bot
/// token because the token in the URL authenticates them.
pub fn Route::needs_auth(self : Route) -> Bool {
  !self.is_interaction()
}
