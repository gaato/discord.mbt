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
  GetCurrentUser
  GetUser(user_id~ : @model.UserId)
  ModifyCurrentUser
  CreateDm
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
  // TODO(pins-v2): Discord added /channels/{id}/messages/pins; these legacy
  // /channels/{id}/pins routes still work but should migrate eventually.
  PinMessage(channel_id~ : @model.ChannelId, message_id~ : @model.MessageId)
  UnpinMessage(channel_id~ : @model.ChannelId, message_id~ : @model.MessageId)
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
  CreateWebhook(channel_id~ : @model.ChannelId)
  GetChannelWebhooks(channel_id~ : @model.ChannelId)
  StartThreadFromMessage(
    channel_id~ : @model.ChannelId,
    message_id~ : @model.MessageId
  )
  StartThreadWithoutMessage(channel_id~ : @model.ChannelId)
  JoinThread(channel_id~ : @model.ChannelId)
  LeaveThread(channel_id~ : @model.ChannelId)
  GetGuild(guild_id~ : @model.GuildId)
  GetGuildWithCounts(guild_id~ : @model.GuildId, query~ : String)
  ModifyGuild(guild_id~ : @model.GuildId)
  GetGuildChannels(guild_id~ : @model.GuildId)
  CreateGuildChannel(guild_id~ : @model.GuildId)
  ModifyGuildChannelPositions(guild_id~ : @model.GuildId)
  GetGuildMember(guild_id~ : @model.GuildId, user_id~ : @model.UserId)
  ListGuildMembers(guild_id~ : @model.GuildId, query~ : String)
  SearchGuildMembers(guild_id~ : @model.GuildId, query~ : String)
  ModifyGuildMember(guild_id~ : @model.GuildId, user_id~ : @model.UserId)
  ModifyCurrentMember(guild_id~ : @model.GuildId)
  GetGuildRoles(guild_id~ : @model.GuildId)
  CreateGuildRole(guild_id~ : @model.GuildId)
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
  GetGuildBans(guild_id~ : @model.GuildId, query~ : String)
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
  CreateStageInstance
  GetStageInstance(channel_id~ : @model.ChannelId)
  ModifyStageInstance(channel_id~ : @model.ChannelId)
  DeleteStageInstance(channel_id~ : @model.ChannelId)
  GetInvite(code~ : String, query~ : String)
  DeleteInvite(code~ : String)
  GetWebhook(webhook_id~ : @model.WebhookId)
  ModifyWebhook(webhook_id~ : @model.WebhookId)
  DeleteWebhook(webhook_id~ : @model.WebhookId)
  ExecuteWebhook(
    webhook_id~ : @model.WebhookId,
    token~ : String,
    query~ : String
  )
  GetWebhookMessage(
    webhook_id~ : @model.WebhookId,
    token~ : String,
    message_id~ : @model.MessageId
  )
  EditWebhookMessage(
    webhook_id~ : @model.WebhookId,
    token~ : String,
    message_id~ : @model.MessageId
  )
  DeleteWebhookMessage(
    webhook_id~ : @model.WebhookId,
    token~ : String,
    message_id~ : @model.MessageId
  )
  CreateInteractionResponse(
    interaction_id~ : @model.InteractionId,
    token~ : String
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
  GetGlobalCommands(application_id~ : @model.ApplicationId)
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
    guild_id~ : @model.GuildId
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
      "CUSTOM:\{request_method.to_string().to_upper()}:\{bucket_path}"
    }
  }
  Custom(request_method~, path~, bucket_key~, is_interaction~, supports_reason~)
}

///|
pub fn Route::method_(self : Route) -> @ahttp.RequestMethod {
  match self {
    Custom(request_method~, ..) => request_method
    GetGateway
    | GetGatewayBot
    | GetCurrentApplication
    | GetCurrentUser
    | GetUser(..)
    | GetChannel(..)
    | GetChannelMessages(..)
    | GetChannelMessage(..)
    | GetReactions(..)
    | GetPollAnswerVoters(..)
    | GetPinnedMessages(..)
    | GetChannelInvites(..)
    | GetChannelWebhooks(..)
    | GetGuild(..)
    | GetGuildWithCounts(..)
    | GetGuildChannels(..)
    | GetGuildMember(..)
    | ListGuildMembers(..)
    | SearchGuildMembers(..)
    | GetGuildRoles(..)
    | GetGuildBans(..)
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
    | GetStageInstance(..)
    | GetInvite(..)
    | GetWebhook(..)
    | GetWebhookMessage(..)
    | GetOriginalInteractionResponse(..)
    | GetFollowupMessage(..)
    | GetGlobalCommands(..)
    | GetGlobalCommand(..)
    | GetGuildCommands(..)
    | GetGuildCommand(..) => Get
    CreateDm
    | CreateMessage(..)
    | ExpirePoll(..)
    | SendSoundboardSound(..)
    | BulkDeleteMessages(..)
    | TriggerTypingIndicator(..)
    | StartThreadFromMessage(..)
    | StartThreadWithoutMessage(..)
    | CreateGuildChannel(..)
    | CreateGuildRole(..)
    | CreateChannelInvite(..)
    | CreateWebhook(..)
    | CreateGuildEmoji(..)
    | CreateAutoModerationRule(..)
    | CreateGuildSticker(..)
    | CreateGuildScheduledEvent(..)
    | CreateGuildSoundboardSound(..)
    | CreateStageInstance
    | ExecuteWebhook(..)
    | CreateInteractionResponse(..)
    | CreateFollowupMessage(..)
    | CreateGlobalCommand(..)
    | CreateGuildCommand(..) => Post
    ModifyCurrentUser
    | ModifyChannel(..)
    | EditMessage(..)
    | ModifyGuild(..)
    | ModifyGuildChannelPositions(..)
    | ModifyGuildMember(..)
    | ModifyCurrentMember(..)
    | ModifyGuildRole(..)
    | ModifyWebhook(..)
    | EditWebhookMessage(..)
    | ModifyGuildEmoji(..)
    | ModifyAutoModerationRule(..)
    | ModifyGuildSticker(..)
    | ModifyGuildScheduledEvent(..)
    | ModifyGuildSoundboardSound(..)
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
    | DeleteChannelPermission(..)
    | UnpinMessage(..)
    | LeaveThread(..)
    | DeleteGuildRole(..)
    | RemoveGuildMemberRole(..)
    | RemoveGuildMember(..)
    | RemoveGuildBan(..)
    | DeleteInvite(..)
    | DeleteWebhook(..)
    | DeleteWebhookMessage(..)
    | DeleteGuildEmoji(..)
    | DeleteAutoModerationRule(..)
    | DeleteGuildSticker(..)
    | DeleteGuildScheduledEvent(..)
    | DeleteGuildSoundboardSound(..)
    | DeleteStageInstance(..)
    | DeleteOriginalInteractionResponse(..)
    | DeleteFollowupMessage(..)
    | DeleteGlobalCommand(..)
    | DeleteGuildCommand(..) => Delete
    CreateReaction(..)
    | EditChannelPermissions(..)
    | PinMessage(..)
    | JoinThread(..)
    | AddGuildMemberRole(..)
    | CreateGuildBan(..)
    | BulkOverwriteGlobalCommands(..)
    | BulkOverwriteGuildCommands(..) => Put
  }
}

///|
pub fn Route::path(self : Route) -> String {
  match self {
    Custom(path~, ..) => path
    GetGateway => "/gateway"
    GetGatewayBot => "/gateway/bot"
    GetCurrentApplication => "/applications/@me"
    GetCurrentUser | ModifyCurrentUser => "/users/@me"
    GetUser(user_id~) => "/users/\{user_id}"
    CreateDm => "/users/@me/channels"
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
      "/channels/\{channel_id}/messages/\{message_id}/reactions/\{emoji}/@me"
    DeleteUserReaction(channel_id~, message_id~, emoji~, user_id~) =>
      "/channels/\{channel_id}/messages/\{message_id}/reactions/\{emoji}/\{user_id}"
    DeleteAllReactions(channel_id~, message_id~) =>
      "/channels/\{channel_id}/messages/\{message_id}/reactions"
    GetReactions(channel_id~, message_id~, emoji~, query~) =>
      "/channels/\{channel_id}/messages/\{message_id}/reactions/\{emoji}\{query}"
    GetPollAnswerVoters(channel_id~, message_id~, answer_id~, query~) =>
      "/channels/\{channel_id}/polls/\{message_id}/answers/\{answer_id}\{query}"
    ExpirePoll(channel_id~, message_id~) =>
      "/channels/\{channel_id}/polls/\{message_id}/expire"
    SendSoundboardSound(channel_id~) =>
      "/channels/\{channel_id}/send-soundboard-sound"
    TriggerTypingIndicator(channel_id~) => "/channels/\{channel_id}/typing"
    PinMessage(channel_id~, message_id~)
    | UnpinMessage(channel_id~, message_id~) =>
      "/channels/\{channel_id}/pins/\{message_id}"
    GetPinnedMessages(channel_id~) => "/channels/\{channel_id}/pins"
    EditChannelPermissions(channel_id~, overwrite_id~)
    | DeleteChannelPermission(channel_id~, overwrite_id~) =>
      "/channels/\{channel_id}/permissions/\{overwrite_id}"
    GetChannelInvites(channel_id~) | CreateChannelInvite(channel_id~) =>
      "/channels/\{channel_id}/invites"
    CreateWebhook(channel_id~) | GetChannelWebhooks(channel_id~) =>
      "/channels/\{channel_id}/webhooks"
    StartThreadFromMessage(channel_id~, message_id~) =>
      "/channels/\{channel_id}/messages/\{message_id}/threads"
    StartThreadWithoutMessage(channel_id~) => "/channels/\{channel_id}/threads"
    JoinThread(channel_id~) | LeaveThread(channel_id~) =>
      "/channels/\{channel_id}/thread-members/@me"
    GetGuild(guild_id~) => "/guilds/\{guild_id}"
    GetGuildWithCounts(guild_id~, query~) => "/guilds/\{guild_id}\{query}"
    ModifyGuild(guild_id~) => "/guilds/\{guild_id}"
    GetGuildChannels(guild_id~)
    | CreateGuildChannel(guild_id~)
    | ModifyGuildChannelPositions(guild_id~) => "/guilds/\{guild_id}/channels"
    GetGuildMember(guild_id~, user_id~)
    | ModifyGuildMember(guild_id~, user_id~)
    | RemoveGuildMember(guild_id~, user_id~) =>
      "/guilds/\{guild_id}/members/\{user_id}"
    ListGuildMembers(guild_id~, query~) => "/guilds/\{guild_id}/members\{query}"
    SearchGuildMembers(guild_id~, query~) =>
      "/guilds/\{guild_id}/members/search\{query}"
    ModifyCurrentMember(guild_id~) => "/guilds/\{guild_id}/members/@me"
    GetGuildRoles(guild_id~) | CreateGuildRole(guild_id~) =>
      "/guilds/\{guild_id}/roles"
    ModifyGuildRole(guild_id~, role_id~)
    | DeleteGuildRole(guild_id~, role_id~) =>
      "/guilds/\{guild_id}/roles/\{role_id}"
    AddGuildMemberRole(guild_id~, user_id~, role_id~)
    | RemoveGuildMemberRole(guild_id~, user_id~, role_id~) =>
      "/guilds/\{guild_id}/members/\{user_id}/roles/\{role_id}"
    CreateGuildBan(guild_id~, user_id~) | RemoveGuildBan(guild_id~, user_id~) =>
      "/guilds/\{guild_id}/bans/\{user_id}"
    GetGuildBans(guild_id~, query~) => "/guilds/\{guild_id}/bans\{query}"
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
    CreateStageInstance => "/stage-instances"
    GetStageInstance(channel_id~)
    | ModifyStageInstance(channel_id~)
    | DeleteStageInstance(channel_id~) => "/stage-instances/\{channel_id}"
    GetInvite(code~, query~) => "/invites/\{code}\{query}"
    DeleteInvite(code~) => "/invites/\{code}"
    GetWebhook(webhook_id~)
    | ModifyWebhook(webhook_id~)
    | DeleteWebhook(webhook_id~) => "/webhooks/\{webhook_id}"
    ExecuteWebhook(webhook_id~, token~, query~) =>
      "/webhooks/\{webhook_id}/\{token}\{query}"
    GetWebhookMessage(webhook_id~, token~, message_id~)
    | EditWebhookMessage(webhook_id~, token~, message_id~)
    | DeleteWebhookMessage(webhook_id~, token~, message_id~) =>
      "/webhooks/\{webhook_id}/\{token}/messages/\{message_id}"
    CreateInteractionResponse(interaction_id~, token~) =>
      "/interactions/\{interaction_id}/\{token}/callback"
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
    GetGlobalCommands(application_id~)
    | CreateGlobalCommand(application_id~)
    | BulkOverwriteGlobalCommands(application_id~) =>
      "/applications/\{application_id}/commands"
    GetGlobalCommand(application_id~, command_id~)
    | EditGlobalCommand(application_id~, command_id~)
    | DeleteGlobalCommand(application_id~, command_id~) =>
      "/applications/\{application_id}/commands/\{command_id}"
    GetGuildCommands(application_id~, guild_id~)
    | CreateGuildCommand(application_id~, guild_id~)
    | BulkOverwriteGuildCommands(application_id~, guild_id~) =>
      "/applications/\{application_id}/guilds/\{guild_id}/commands"
    GetGuildCommand(application_id~, guild_id~, command_id~)
    | EditGuildCommand(application_id~, guild_id~, command_id~)
    | DeleteGuildCommand(application_id~, guild_id~, command_id~) =>
      "/applications/\{application_id}/guilds/\{guild_id}/commands/\{command_id}"
  }
}

///|
/// Rate-limit bucket key: method plus path template with channel, guild, and
/// webhook ID/token majors kept while minor resource IDs are squashed.
pub fn Route::bucket(self : Route) -> String {
  match self {
    Custom(bucket_key~, ..) => bucket_key
    GetGateway => "GET:/gateway"
    GetGatewayBot => "GET:/gateway/bot"
    GetCurrentApplication => "GET:/applications/@me"
    GetCurrentUser => "GET:/users/@me"
    ModifyCurrentUser => "PATCH:/users/@me"
    GetUser(..) => "GET:/users/{}"
    CreateDm => "POST:/users/@me/channels"
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
    GetReactions(channel_id~, ..) =>
      "GET:/channels/\{channel_id}/messages/{}/reactions/{}"
    GetPollAnswerVoters(channel_id~, ..) =>
      "GET:/channels/\{channel_id}/polls/{}/answers/{}"
    ExpirePoll(channel_id~, ..) =>
      "POST:/channels/\{channel_id}/polls/{}/expire"
    SendSoundboardSound(channel_id~) =>
      "POST:/channels/\{channel_id}/send-soundboard-sound"
    TriggerTypingIndicator(channel_id~) => "POST:/channels/\{channel_id}/typing"
    PinMessage(channel_id~, ..) => "PUT:/channels/\{channel_id}/pins/{}"
    UnpinMessage(channel_id~, ..) => "DELETE:/channels/\{channel_id}/pins/{}"
    GetPinnedMessages(channel_id~) => "GET:/channels/\{channel_id}/pins"
    EditChannelPermissions(channel_id~, ..) =>
      "PUT:/channels/\{channel_id}/permissions/{}"
    DeleteChannelPermission(channel_id~, ..) =>
      "DELETE:/channels/\{channel_id}/permissions/{}"
    GetChannelInvites(channel_id~) => "GET:/channels/\{channel_id}/invites"
    CreateChannelInvite(channel_id~) => "POST:/channels/\{channel_id}/invites"
    CreateWebhook(channel_id~) => "POST:/channels/\{channel_id}/webhooks"
    GetChannelWebhooks(channel_id~) => "GET:/channels/\{channel_id}/webhooks"
    StartThreadFromMessage(channel_id~, ..) =>
      "POST:/channels/\{channel_id}/messages/{}/threads"
    StartThreadWithoutMessage(channel_id~) =>
      "POST:/channels/\{channel_id}/threads"
    JoinThread(channel_id~) => "PUT:/channels/\{channel_id}/thread-members/@me"
    LeaveThread(channel_id~) =>
      "DELETE:/channels/\{channel_id}/thread-members/@me"
    GetGuild(guild_id~) | GetGuildWithCounts(guild_id~, ..) =>
      "GET:/guilds/\{guild_id}"
    ModifyGuild(guild_id~) => "PATCH:/guilds/\{guild_id}"
    GetGuildChannels(guild_id~) => "GET:/guilds/\{guild_id}/channels"
    CreateGuildChannel(guild_id~) => "POST:/guilds/\{guild_id}/channels"
    ModifyGuildChannelPositions(guild_id~) =>
      "PATCH:/guilds/\{guild_id}/channels"
    GetGuildMember(guild_id~, ..) => "GET:/guilds/\{guild_id}/members/{}"
    ListGuildMembers(guild_id~, ..) => "GET:/guilds/\{guild_id}/members"
    SearchGuildMembers(guild_id~, ..) =>
      "GET:/guilds/\{guild_id}/members/search"
    ModifyGuildMember(guild_id~, ..) => "PATCH:/guilds/\{guild_id}/members/{}"
    ModifyCurrentMember(guild_id~) => "PATCH:/guilds/\{guild_id}/members/@me"
    GetGuildRoles(guild_id~) => "GET:/guilds/\{guild_id}/roles"
    CreateGuildRole(guild_id~) => "POST:/guilds/\{guild_id}/roles"
    ModifyGuildRole(guild_id~, ..) => "PATCH:/guilds/\{guild_id}/roles/{}"
    DeleteGuildRole(guild_id~, ..) => "DELETE:/guilds/\{guild_id}/roles/{}"
    AddGuildMemberRole(guild_id~, ..) =>
      "PUT:/guilds/\{guild_id}/members/{}/roles/{}"
    RemoveGuildMemberRole(guild_id~, ..) =>
      "DELETE:/guilds/\{guild_id}/members/{}/roles/{}"
    RemoveGuildMember(guild_id~, ..) => "DELETE:/guilds/\{guild_id}/members/{}"
    CreateGuildBan(guild_id~, ..) => "PUT:/guilds/\{guild_id}/bans/{}"
    RemoveGuildBan(guild_id~, ..) => "DELETE:/guilds/\{guild_id}/bans/{}"
    GetGuildBans(guild_id~, ..) => "GET:/guilds/\{guild_id}/bans"
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
    CreateStageInstance => "POST:/stage-instances"
    GetStageInstance(channel_id~) => "GET:/stage-instances/\{channel_id}"
    ModifyStageInstance(channel_id~) => "PATCH:/stage-instances/\{channel_id}"
    DeleteStageInstance(channel_id~) => "DELETE:/stage-instances/\{channel_id}"
    GetInvite(code~, ..) => "GET:/invites/\{code}"
    DeleteInvite(code~) => "DELETE:/invites/\{code}"
    GetWebhook(webhook_id~) => "GET:/webhooks/\{webhook_id}"
    ModifyWebhook(webhook_id~) => "PATCH:/webhooks/\{webhook_id}"
    DeleteWebhook(webhook_id~) => "DELETE:/webhooks/\{webhook_id}"
    ExecuteWebhook(webhook_id~, token~, ..) =>
      "POST:/webhooks/\{webhook_id}/\{token}"
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
    GetGlobalCommands(application_id~) =>
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
    GetGuildCommands(application_id~, guild_id~) =>
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
    | CreateGuildRole(..)
    | DeleteGuildRole(..)
    | AddGuildMemberRole(..)
    | RemoveGuildMemberRole(..)
    | RemoveGuildMember(..)
    | CreateGuildBan(..)
    | RemoveGuildBan(..)
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
