///|
/// Gateway intents that can cause this dispatch event to be delivered.
///
/// Events shared by guild and direct-message contexts return the union of
/// both intents. `MESSAGE_CONTENT` is deliberately absent because it controls
/// field visibility rather than event delivery.
pub fn EventKind::required_intents(self : EventKind) -> Intents {
  match self {
    KGuildCreate
    | KGuildDelete
    | KGuildRoleCreate
    | KGuildRoleDelete
    | KGuildRoleUpdate
    | KGuildUpdate
    | KChannelCreate
    | KChannelDelete
    | KChannelUpdate
    | KStageInstanceCreate
    | KStageInstanceDelete
    | KStageInstanceUpdate
    | KThreadCreate
    | KThreadDelete
    | KThreadListSync
    | KThreadMemberUpdate
    | KThreadUpdate
    | KVoiceChannelStartTimeUpdate
    | KVoiceChannelStatusUpdate => Intents::guilds()
    KChannelPinsUpdate => Intents::guilds() | Intents::direct_messages()
    KThreadMembersUpdate => Intents::guilds() | Intents::guild_members()
    KGuildMemberAdd | KGuildMemberRemove | KGuildMemberUpdate =>
      Intents::guild_members()
    KGuildAuditLogEntryCreate | KGuildBanAdd | KGuildBanRemove =>
      Intents::guild_moderation()
    KGuildEmojisUpdate
    | KGuildSoundboardSoundCreate
    | KGuildSoundboardSoundDelete
    | KGuildSoundboardSoundsUpdate
    | KGuildSoundboardSoundUpdate
    | KGuildStickersUpdate => Intents::guild_expressions()
    KGuildIntegrationsUpdate
    | KIntegrationCreate
    | KIntegrationDelete
    | KIntegrationUpdate => Intents::guild_integrations()
    KWebhooksUpdate => Intents::guild_webhooks()
    KInviteCreate | KInviteDelete => Intents::guild_invites()
    KVoiceChannelEffectSend | KVoiceStateUpdate => Intents::guild_voice_states()
    KPresenceUpdate => Intents::guild_presences()
    KMessageCreate | KMessageDelete | KMessageUpdate =>
      Intents::guild_messages() | Intents::direct_messages()
    KMessageDeleteBulk => Intents::guild_messages()
    KMessageReactionAdd
    | KMessageReactionRemove
    | KMessageReactionRemoveAll
    | KMessageReactionRemoveEmoji =>
      Intents::guild_message_reactions() | Intents::direct_message_reactions()
    KTypingStart =>
      Intents::guild_message_typing() | Intents::direct_message_typing()
    KGuildScheduledEventCreate
    | KGuildScheduledEventDelete
    | KGuildScheduledEventUpdate
    | KGuildScheduledEventUserAdd
    | KGuildScheduledEventUserRemove => Intents::guild_scheduled_events()
    KAutoModerationRuleCreate
    | KAutoModerationRuleDelete
    | KAutoModerationRuleUpdate => Intents::auto_moderation_configuration()
    KAutoModerationActionExecution => Intents::auto_moderation_execution()
    KMessagePollVoteAdd | KMessagePollVoteRemove =>
      Intents::guild_message_polls() | Intents::direct_message_polls()
    // These application-scoped dispatches are not gated by gateway intents.
    KApplicationCommandPermissionsUpdate
    | KSubscriptionCreate
    | KSubscriptionDelete
    | KSubscriptionUpdate => Intents::none()
    KChannelInfo
    | KEntitlementCreate
    | KEntitlementDelete
    | KEntitlementUpdate
    | KGuildMembersChunk
    | KInteractionCreate
    | KRateLimited
    | KReady
    | KResumed
    | KSoundboardSounds
    | KUserUpdate
    | KVoiceServerUpdate
    | KUnknown => Intents::none()
  }
}
