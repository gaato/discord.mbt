///|
/// A gateway dispatch event decoded by its wire event name.
///
/// Unknown event names retain both the name and payload for forward
/// compatibility.
pub(all) enum Event {
  ApplicationCommandPermissionsUpdate(GuildApplicationCommandPermissions)
  AutoModerationActionExecution(AutoModerationActionExecutionEvent)
  AutoModerationRuleCreate(AutoModerationRule)
  AutoModerationRuleDelete(AutoModerationRule)
  AutoModerationRuleUpdate(AutoModerationRule)
  ChannelCreate(Channel)
  ChannelDelete(Channel)
  ChannelInfo(ChannelInfoEvent)
  ChannelPinsUpdate(ChannelPinsUpdateEvent)
  ChannelUpdate(Channel)
  EntitlementCreate(Entitlement)
  EntitlementDelete(Entitlement)
  EntitlementUpdate(Entitlement)
  GuildAuditLogEntryCreate(GuildAuditLogEntryCreateEvent)
  GuildBanAdd(GuildBanEvent)
  GuildBanRemove(GuildBanEvent)
  GuildCreate(GuildCreateEvent)
  GuildDelete(UnavailableGuild)
  GuildEmojisUpdate(GuildEmojisUpdateEvent)
  GuildIntegrationsUpdate(GuildIntegrationsUpdateEvent)
  GuildMemberAdd(GuildMemberAddEvent)
  GuildMemberRemove(GuildMemberRemoveEvent)
  GuildMembersChunk(GuildMembersChunkEvent)
  GuildMemberUpdate(GuildMemberUpdateEvent)
  GuildRoleCreate(GuildRoleEvent)
  GuildRoleDelete(GuildRoleDeleteEvent)
  GuildRoleUpdate(GuildRoleEvent)
  GuildScheduledEventCreate(GuildScheduledEvent)
  GuildScheduledEventDelete(GuildScheduledEvent)
  GuildScheduledEventUpdate(GuildScheduledEvent)
  GuildScheduledEventUserAdd(GuildScheduledEventUserEvent)
  GuildScheduledEventUserRemove(GuildScheduledEventUserEvent)
  GuildSoundboardSoundCreate(SoundboardSound)
  GuildSoundboardSoundDelete(GuildSoundboardSoundDeleteEvent)
  GuildSoundboardSoundsUpdate(SoundboardSoundsEvent)
  GuildSoundboardSoundUpdate(SoundboardSound)
  SoundboardSounds(SoundboardSoundsEvent)
  GuildStickersUpdate(GuildStickersUpdateEvent)
  GuildUpdate(Guild)
  IntegrationCreate(IntegrationEvent)
  IntegrationDelete(IntegrationDeleteEvent)
  IntegrationUpdate(IntegrationEvent)
  InteractionCreate(Interaction)
  InviteCreate(InviteCreateEvent)
  InviteDelete(InviteDeleteEvent)
  MessageCreate(MessageCreateEvent)
  MessageDelete(MessageDeleteEvent)
  MessageDeleteBulk(MessageDeleteBulkEvent)
  MessagePollVoteAdd(MessagePollVoteEvent)
  MessagePollVoteRemove(MessagePollVoteEvent)
  MessageReactionAdd(MessageReactionAddEvent)
  MessageReactionRemove(MessageReactionRemoveEvent)
  MessageReactionRemoveAll(MessageReactionRemoveAllEvent)
  MessageReactionRemoveEmoji(MessageReactionRemoveEmojiEvent)
  MessageUpdate(MessageUpdateEvent)
  PresenceUpdate(PresenceUpdateEvent)
  RateLimited(GatewayRateLimitedEvent)
  Ready(Ready)
  Resumed
  StageInstanceCreate(StageInstance)
  StageInstanceDelete(StageInstance)
  StageInstanceUpdate(StageInstance)
  SubscriptionCreate(Subscription)
  SubscriptionDelete(Subscription)
  SubscriptionUpdate(Subscription)
  ThreadCreate(ThreadCreateEvent)
  ThreadDelete(ThreadDeleteEvent)
  ThreadListSync(ThreadListSyncEvent)
  ThreadMembersUpdate(ThreadMembersUpdateEvent)
  ThreadMemberUpdate(ThreadMemberUpdateEvent)
  ThreadUpdate(Channel)
  TypingStart(TypingStartEvent)
  UserUpdate(User)
  VoiceChannelEffectSend(VoiceChannelEffectSendEvent)
  VoiceChannelStartTimeUpdate(VoiceChannelStartTimeUpdateEvent)
  VoiceChannelStatusUpdate(VoiceChannelStatusUpdateEvent)
  VoiceServerUpdate(VoiceServerUpdateEvent)
  VoiceStateUpdate(VoiceState)
  WebhooksUpdate(WebhooksUpdateEvent)
  Unknown(t~ : String, d~ : Json)
} derive(Debug)

///|
/// A dispatch event category without its payload.
pub(all) enum EventKind {
  KApplicationCommandPermissionsUpdate
  KAutoModerationActionExecution
  KAutoModerationRuleCreate
  KAutoModerationRuleDelete
  KAutoModerationRuleUpdate
  KChannelCreate
  KChannelDelete
  KChannelInfo
  KChannelPinsUpdate
  KChannelUpdate
  KEntitlementCreate
  KEntitlementDelete
  KEntitlementUpdate
  KGuildAuditLogEntryCreate
  KGuildBanAdd
  KGuildBanRemove
  KGuildCreate
  KGuildDelete
  KGuildEmojisUpdate
  KGuildIntegrationsUpdate
  KGuildMemberAdd
  KGuildMemberRemove
  KGuildMembersChunk
  KGuildMemberUpdate
  KGuildRoleCreate
  KGuildRoleDelete
  KGuildRoleUpdate
  KGuildScheduledEventCreate
  KGuildScheduledEventDelete
  KGuildScheduledEventUpdate
  KGuildScheduledEventUserAdd
  KGuildScheduledEventUserRemove
  KGuildSoundboardSoundCreate
  KGuildSoundboardSoundDelete
  KGuildSoundboardSoundsUpdate
  KGuildSoundboardSoundUpdate
  KSoundboardSounds
  KGuildStickersUpdate
  KGuildUpdate
  KIntegrationCreate
  KIntegrationDelete
  KIntegrationUpdate
  KInteractionCreate
  KInviteCreate
  KInviteDelete
  KMessageCreate
  KMessageDelete
  KMessageDeleteBulk
  KMessagePollVoteAdd
  KMessagePollVoteRemove
  KMessageReactionAdd
  KMessageReactionRemove
  KMessageReactionRemoveAll
  KMessageReactionRemoveEmoji
  KMessageUpdate
  KPresenceUpdate
  KRateLimited
  KReady
  KResumed
  KStageInstanceCreate
  KStageInstanceDelete
  KStageInstanceUpdate
  KSubscriptionCreate
  KSubscriptionDelete
  KSubscriptionUpdate
  KThreadCreate
  KThreadDelete
  KThreadListSync
  KThreadMembersUpdate
  KThreadMemberUpdate
  KThreadUpdate
  KTypingStart
  KUserUpdate
  KVoiceChannelEffectSend
  KVoiceChannelStartTimeUpdate
  KVoiceChannelStatusUpdate
  KVoiceServerUpdate
  KVoiceStateUpdate
  KWebhooksUpdate
  KUnknown
} derive(Eq, Debug)

///|
pub fn EventKind::of_name(t : String) -> EventKind {
  match t {
    "APPLICATION_COMMAND_PERMISSIONS_UPDATE" =>
      KApplicationCommandPermissionsUpdate
    "AUTO_MODERATION_ACTION_EXECUTION" => KAutoModerationActionExecution
    "AUTO_MODERATION_RULE_CREATE" => KAutoModerationRuleCreate
    "AUTO_MODERATION_RULE_DELETE" => KAutoModerationRuleDelete
    "AUTO_MODERATION_RULE_UPDATE" => KAutoModerationRuleUpdate
    "CHANNEL_CREATE" => KChannelCreate
    "CHANNEL_DELETE" => KChannelDelete
    "CHANNEL_INFO" => KChannelInfo
    "CHANNEL_PINS_UPDATE" => KChannelPinsUpdate
    "CHANNEL_UPDATE" => KChannelUpdate
    "ENTITLEMENT_CREATE" => KEntitlementCreate
    "ENTITLEMENT_DELETE" => KEntitlementDelete
    "ENTITLEMENT_UPDATE" => KEntitlementUpdate
    "GUILD_AUDIT_LOG_ENTRY_CREATE" => KGuildAuditLogEntryCreate
    "GUILD_BAN_ADD" => KGuildBanAdd
    "GUILD_BAN_REMOVE" => KGuildBanRemove
    "GUILD_CREATE" => KGuildCreate
    "GUILD_DELETE" => KGuildDelete
    "GUILD_EMOJIS_UPDATE" => KGuildEmojisUpdate
    "GUILD_INTEGRATIONS_UPDATE" => KGuildIntegrationsUpdate
    "GUILD_MEMBER_ADD" => KGuildMemberAdd
    "GUILD_MEMBER_REMOVE" => KGuildMemberRemove
    "GUILD_MEMBERS_CHUNK" => KGuildMembersChunk
    "GUILD_MEMBER_UPDATE" => KGuildMemberUpdate
    "GUILD_ROLE_CREATE" => KGuildRoleCreate
    "GUILD_ROLE_DELETE" => KGuildRoleDelete
    "GUILD_ROLE_UPDATE" => KGuildRoleUpdate
    "GUILD_SCHEDULED_EVENT_CREATE" => KGuildScheduledEventCreate
    "GUILD_SCHEDULED_EVENT_DELETE" => KGuildScheduledEventDelete
    "GUILD_SCHEDULED_EVENT_UPDATE" => KGuildScheduledEventUpdate
    "GUILD_SCHEDULED_EVENT_USER_ADD" => KGuildScheduledEventUserAdd
    "GUILD_SCHEDULED_EVENT_USER_REMOVE" => KGuildScheduledEventUserRemove
    "GUILD_SOUNDBOARD_SOUND_CREATE" => KGuildSoundboardSoundCreate
    "GUILD_SOUNDBOARD_SOUND_DELETE" => KGuildSoundboardSoundDelete
    "GUILD_SOUNDBOARD_SOUNDS_UPDATE" => KGuildSoundboardSoundsUpdate
    "GUILD_SOUNDBOARD_SOUND_UPDATE" => KGuildSoundboardSoundUpdate
    "SOUNDBOARD_SOUNDS" => KSoundboardSounds
    "GUILD_STICKERS_UPDATE" => KGuildStickersUpdate
    "GUILD_UPDATE" => KGuildUpdate
    "INTEGRATION_CREATE" => KIntegrationCreate
    "INTEGRATION_DELETE" => KIntegrationDelete
    "INTEGRATION_UPDATE" => KIntegrationUpdate
    "INTERACTION_CREATE" => KInteractionCreate
    "INVITE_CREATE" => KInviteCreate
    "INVITE_DELETE" => KInviteDelete
    "MESSAGE_CREATE" => KMessageCreate
    "MESSAGE_DELETE" => KMessageDelete
    "MESSAGE_DELETE_BULK" => KMessageDeleteBulk
    "MESSAGE_POLL_VOTE_ADD" => KMessagePollVoteAdd
    "MESSAGE_POLL_VOTE_REMOVE" => KMessagePollVoteRemove
    "MESSAGE_REACTION_ADD" => KMessageReactionAdd
    "MESSAGE_REACTION_REMOVE" => KMessageReactionRemove
    "MESSAGE_REACTION_REMOVE_ALL" => KMessageReactionRemoveAll
    "MESSAGE_REACTION_REMOVE_EMOJI" => KMessageReactionRemoveEmoji
    "MESSAGE_UPDATE" => KMessageUpdate
    "PRESENCE_UPDATE" => KPresenceUpdate
    "RATE_LIMITED" => KRateLimited
    "READY" => KReady
    "RESUMED" => KResumed
    "STAGE_INSTANCE_CREATE" => KStageInstanceCreate
    "STAGE_INSTANCE_DELETE" => KStageInstanceDelete
    "STAGE_INSTANCE_UPDATE" => KStageInstanceUpdate
    "SUBSCRIPTION_CREATE" => KSubscriptionCreate
    "SUBSCRIPTION_DELETE" => KSubscriptionDelete
    "SUBSCRIPTION_UPDATE" => KSubscriptionUpdate
    "THREAD_CREATE" => KThreadCreate
    "THREAD_DELETE" => KThreadDelete
    "THREAD_LIST_SYNC" => KThreadListSync
    "THREAD_MEMBERS_UPDATE" => KThreadMembersUpdate
    "THREAD_MEMBER_UPDATE" => KThreadMemberUpdate
    "THREAD_UPDATE" => KThreadUpdate
    "TYPING_START" => KTypingStart
    "USER_UPDATE" => KUserUpdate
    "VOICE_CHANNEL_EFFECT_SEND" => KVoiceChannelEffectSend
    "VOICE_CHANNEL_START_TIME_UPDATE" => KVoiceChannelStartTimeUpdate
    "VOICE_CHANNEL_STATUS_UPDATE" => KVoiceChannelStatusUpdate
    "VOICE_SERVER_UPDATE" => KVoiceServerUpdate
    "VOICE_STATE_UPDATE" => KVoiceStateUpdate
    "WEBHOOKS_UPDATE" => KWebhooksUpdate
    _ => KUnknown
  }
}

///|
/// Decode a dispatch payload by event name.
///
/// Unknown names never raise. A known event raises only when its payload does
/// not match the modeled wire shape; the gateway converts that failure into an
/// unknown event so shard processing remains lenient.
pub fn dispatch_event(t : String, d : Json) -> Event raise {
  match t {
    "APPLICATION_COMMAND_PERMISSIONS_UPDATE" =>
      ApplicationCommandPermissionsUpdate(@json.from_json(d))
    "AUTO_MODERATION_ACTION_EXECUTION" =>
      AutoModerationActionExecution(@json.from_json(d))
    "AUTO_MODERATION_RULE_CREATE" =>
      AutoModerationRuleCreate(@json.from_json(d))
    "AUTO_MODERATION_RULE_DELETE" =>
      AutoModerationRuleDelete(@json.from_json(d))
    "AUTO_MODERATION_RULE_UPDATE" =>
      AutoModerationRuleUpdate(@json.from_json(d))
    "CHANNEL_CREATE" => ChannelCreate(@json.from_json(d))
    "CHANNEL_DELETE" => ChannelDelete(@json.from_json(d))
    "CHANNEL_INFO" => ChannelInfo(@json.from_json(d))
    "CHANNEL_PINS_UPDATE" => ChannelPinsUpdate(@json.from_json(d))
    "CHANNEL_UPDATE" => ChannelUpdate(@json.from_json(d))
    "ENTITLEMENT_CREATE" => EntitlementCreate(@json.from_json(d))
    "ENTITLEMENT_DELETE" => EntitlementDelete(@json.from_json(d))
    "ENTITLEMENT_UPDATE" => EntitlementUpdate(@json.from_json(d))
    "GUILD_AUDIT_LOG_ENTRY_CREATE" =>
      GuildAuditLogEntryCreate(@json.from_json(d))
    "GUILD_BAN_ADD" => GuildBanAdd(@json.from_json(d))
    "GUILD_BAN_REMOVE" => GuildBanRemove(@json.from_json(d))
    "GUILD_CREATE" => GuildCreate(@json.from_json(d))
    "GUILD_DELETE" => GuildDelete(@json.from_json(d))
    "GUILD_EMOJIS_UPDATE" => GuildEmojisUpdate(@json.from_json(d))
    "GUILD_INTEGRATIONS_UPDATE" => GuildIntegrationsUpdate(@json.from_json(d))
    "GUILD_MEMBER_ADD" => GuildMemberAdd(@json.from_json(d))
    "GUILD_MEMBER_REMOVE" => GuildMemberRemove(@json.from_json(d))
    "GUILD_MEMBERS_CHUNK" => GuildMembersChunk(@json.from_json(d))
    "GUILD_MEMBER_UPDATE" => GuildMemberUpdate(@json.from_json(d))
    "GUILD_ROLE_CREATE" => GuildRoleCreate(@json.from_json(d))
    "GUILD_ROLE_DELETE" => GuildRoleDelete(@json.from_json(d))
    "GUILD_ROLE_UPDATE" => GuildRoleUpdate(@json.from_json(d))
    "GUILD_SCHEDULED_EVENT_CREATE" =>
      GuildScheduledEventCreate(@json.from_json(d))
    "GUILD_SCHEDULED_EVENT_DELETE" =>
      GuildScheduledEventDelete(@json.from_json(d))
    "GUILD_SCHEDULED_EVENT_UPDATE" =>
      GuildScheduledEventUpdate(@json.from_json(d))
    "GUILD_SCHEDULED_EVENT_USER_ADD" =>
      GuildScheduledEventUserAdd(@json.from_json(d))
    "GUILD_SCHEDULED_EVENT_USER_REMOVE" =>
      GuildScheduledEventUserRemove(@json.from_json(d))
    "GUILD_SOUNDBOARD_SOUND_CREATE" =>
      GuildSoundboardSoundCreate(@json.from_json(d))
    "GUILD_SOUNDBOARD_SOUND_DELETE" =>
      GuildSoundboardSoundDelete(@json.from_json(d))
    "GUILD_SOUNDBOARD_SOUNDS_UPDATE" =>
      GuildSoundboardSoundsUpdate(@json.from_json(d))
    "GUILD_SOUNDBOARD_SOUND_UPDATE" =>
      GuildSoundboardSoundUpdate(@json.from_json(d))
    "SOUNDBOARD_SOUNDS" => SoundboardSounds(@json.from_json(d))
    "GUILD_STICKERS_UPDATE" => GuildStickersUpdate(@json.from_json(d))
    "GUILD_UPDATE" => GuildUpdate(@json.from_json(d))
    "INTEGRATION_CREATE" => IntegrationCreate(@json.from_json(d))
    "INTEGRATION_DELETE" => IntegrationDelete(@json.from_json(d))
    "INTEGRATION_UPDATE" => IntegrationUpdate(@json.from_json(d))
    "INTERACTION_CREATE" => InteractionCreate(@json.from_json(d))
    "INVITE_CREATE" => InviteCreate(@json.from_json(d))
    "INVITE_DELETE" => InviteDelete(@json.from_json(d))
    "MESSAGE_CREATE" => MessageCreate(@json.from_json(d))
    "MESSAGE_DELETE" => MessageDelete(@json.from_json(d))
    "MESSAGE_DELETE_BULK" => MessageDeleteBulk(@json.from_json(d))
    "MESSAGE_POLL_VOTE_ADD" => MessagePollVoteAdd(@json.from_json(d))
    "MESSAGE_POLL_VOTE_REMOVE" => MessagePollVoteRemove(@json.from_json(d))
    "MESSAGE_REACTION_ADD" => MessageReactionAdd(@json.from_json(d))
    "MESSAGE_REACTION_REMOVE" => MessageReactionRemove(@json.from_json(d))
    "MESSAGE_REACTION_REMOVE_ALL" =>
      MessageReactionRemoveAll(@json.from_json(d))
    "MESSAGE_REACTION_REMOVE_EMOJI" =>
      MessageReactionRemoveEmoji(@json.from_json(d))
    "MESSAGE_UPDATE" => MessageUpdate(@json.from_json(d))
    "PRESENCE_UPDATE" => PresenceUpdate(@json.from_json(d))
    "RATE_LIMITED" => RateLimited(@json.from_json(d))
    "READY" => Ready(@json.from_json(d))
    "RESUMED" => Resumed
    "STAGE_INSTANCE_CREATE" => StageInstanceCreate(@json.from_json(d))
    "STAGE_INSTANCE_DELETE" => StageInstanceDelete(@json.from_json(d))
    "STAGE_INSTANCE_UPDATE" => StageInstanceUpdate(@json.from_json(d))
    "SUBSCRIPTION_CREATE" => SubscriptionCreate(@json.from_json(d))
    "SUBSCRIPTION_DELETE" => SubscriptionDelete(@json.from_json(d))
    "SUBSCRIPTION_UPDATE" => SubscriptionUpdate(@json.from_json(d))
    "THREAD_CREATE" => ThreadCreate(@json.from_json(d))
    "THREAD_DELETE" => ThreadDelete(@json.from_json(d))
    "THREAD_LIST_SYNC" => ThreadListSync(@json.from_json(d))
    "THREAD_MEMBERS_UPDATE" => ThreadMembersUpdate(@json.from_json(d))
    "THREAD_MEMBER_UPDATE" => ThreadMemberUpdate(@json.from_json(d))
    "THREAD_UPDATE" => ThreadUpdate(@json.from_json(d))
    "TYPING_START" => TypingStart(@json.from_json(d))
    "USER_UPDATE" => UserUpdate(@json.from_json(d))
    "VOICE_CHANNEL_EFFECT_SEND" => VoiceChannelEffectSend(@json.from_json(d))
    "VOICE_CHANNEL_START_TIME_UPDATE" =>
      VoiceChannelStartTimeUpdate(@json.from_json(d))
    "VOICE_CHANNEL_STATUS_UPDATE" =>
      VoiceChannelStatusUpdate(@json.from_json(d))
    "VOICE_SERVER_UPDATE" => VoiceServerUpdate(@json.from_json(d))
    "VOICE_STATE_UPDATE" => VoiceStateUpdate(@json.from_json(d))
    "WEBHOOKS_UPDATE" => WebhooksUpdate(@json.from_json(d))
    _ => Unknown(t~, d~)
  }
}
