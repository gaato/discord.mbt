///|
/// A typed projection from the general gateway event enum.
pub struct EventType[T] {
  priv kind_ : @model.EventKind
  priv project_ : (@model.Event) -> T?
}

///|
/// The untyped event kind used by gateway filtering and intent calculation.
pub fn[T] EventType::kind(self : EventType[T]) -> @model.EventKind {
  self.kind_
}

///|
/// Gateway intents that can deliver this event.
pub fn[T] EventType::required_intents(self : EventType[T]) -> @model.Intents {
  self.kind_.required_intents()
}

///|
/// Extract the typed payload when `event` is this descriptor's variant.
pub fn[T] EventType::project(self : EventType[T], event : @model.Event) -> T? {
  (self.project_)(event)
}

///|
/// Namespace for typed gateway event descriptors.
///
/// Variants whose payload is still raw `Json` are intentionally omitted:
/// application-command permissions, guild create, presence update, and
/// subscription events. The payload-free `Resumed` event and `Unknown` are
/// likewise available only through the low-level event stream.
#warnings("-struct_never_constructed")
pub struct Events {}

///|
pub fn Events::auto_moderation_action_execution() -> EventType[
  @model.AutoModerationActionExecutionEvent,
] {
  {
    kind_: KAutoModerationActionExecution,
    project_: event => {
      match event {
        AutoModerationActionExecution(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::auto_moderation_rule_create() -> EventType[
  @model.AutoModerationRule,
] {
  {
    kind_: KAutoModerationRuleCreate,
    project_: event => {
      match event {
        AutoModerationRuleCreate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::auto_moderation_rule_delete() -> EventType[
  @model.AutoModerationRule,
] {
  {
    kind_: KAutoModerationRuleDelete,
    project_: event => {
      match event {
        AutoModerationRuleDelete(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::auto_moderation_rule_update() -> EventType[
  @model.AutoModerationRule,
] {
  {
    kind_: KAutoModerationRuleUpdate,
    project_: event => {
      match event {
        AutoModerationRuleUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::channel_create() -> EventType[@model.Channel] {
  {
    kind_: KChannelCreate,
    project_: event => {
      match event {
        ChannelCreate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::channel_delete() -> EventType[@model.Channel] {
  {
    kind_: KChannelDelete,
    project_: event => {
      match event {
        ChannelDelete(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::channel_info() -> EventType[@model.ChannelInfoEvent] {
  {
    kind_: KChannelInfo,
    project_: event => {
      match event {
        ChannelInfo(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::channel_pins_update() -> EventType[@model.ChannelPinsUpdateEvent] {
  {
    kind_: KChannelPinsUpdate,
    project_: event => {
      match event {
        ChannelPinsUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::channel_update() -> EventType[@model.Channel] {
  {
    kind_: KChannelUpdate,
    project_: event => {
      match event {
        ChannelUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::entitlement_create() -> EventType[@model.Entitlement] {
  {
    kind_: KEntitlementCreate,
    project_: event => {
      match event {
        EntitlementCreate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::entitlement_delete() -> EventType[@model.Entitlement] {
  {
    kind_: KEntitlementDelete,
    project_: event => {
      match event {
        EntitlementDelete(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::entitlement_update() -> EventType[@model.Entitlement] {
  {
    kind_: KEntitlementUpdate,
    project_: event => {
      match event {
        EntitlementUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::guild_audit_log_entry_create() -> EventType[
  @model.GuildAuditLogEntryCreateEvent,
] {
  {
    kind_: KGuildAuditLogEntryCreate,
    project_: event => {
      match event {
        GuildAuditLogEntryCreate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::guild_ban_add() -> EventType[@model.GuildBanEvent] {
  {
    kind_: KGuildBanAdd,
    project_: event => {
      match event {
        GuildBanAdd(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::guild_ban_remove() -> EventType[@model.GuildBanEvent] {
  {
    kind_: KGuildBanRemove,
    project_: event => {
      match event {
        GuildBanRemove(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::guild_delete() -> EventType[@model.UnavailableGuild] {
  {
    kind_: KGuildDelete,
    project_: event => {
      match event {
        GuildDelete(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::guild_emojis_update() -> EventType[@model.GuildEmojisUpdateEvent] {
  {
    kind_: KGuildEmojisUpdate,
    project_: event => {
      match event {
        GuildEmojisUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::guild_integrations_update() -> EventType[
  @model.GuildIntegrationsUpdateEvent,
] {
  {
    kind_: KGuildIntegrationsUpdate,
    project_: event => {
      match event {
        GuildIntegrationsUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::guild_member_add() -> EventType[@model.GuildMemberAddEvent] {
  {
    kind_: KGuildMemberAdd,
    project_: event => {
      match event {
        GuildMemberAdd(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::guild_member_remove() -> EventType[@model.GuildMemberRemoveEvent] {
  {
    kind_: KGuildMemberRemove,
    project_: event => {
      match event {
        GuildMemberRemove(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::guild_members_chunk() -> EventType[@model.GuildMembersChunkEvent] {
  {
    kind_: KGuildMembersChunk,
    project_: event => {
      match event {
        GuildMembersChunk(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::guild_member_update() -> EventType[@model.GuildMemberUpdateEvent] {
  {
    kind_: KGuildMemberUpdate,
    project_: event => {
      match event {
        GuildMemberUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::guild_role_create() -> EventType[@model.GuildRoleEvent] {
  {
    kind_: KGuildRoleCreate,
    project_: event => {
      match event {
        GuildRoleCreate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::guild_role_delete() -> EventType[@model.GuildRoleDeleteEvent] {
  {
    kind_: KGuildRoleDelete,
    project_: event => {
      match event {
        GuildRoleDelete(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::guild_role_update() -> EventType[@model.GuildRoleEvent] {
  {
    kind_: KGuildRoleUpdate,
    project_: event => {
      match event {
        GuildRoleUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::guild_scheduled_event_create() -> EventType[
  @model.GuildScheduledEvent,
] {
  {
    kind_: KGuildScheduledEventCreate,
    project_: event => {
      match event {
        GuildScheduledEventCreate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::guild_scheduled_event_delete() -> EventType[
  @model.GuildScheduledEvent,
] {
  {
    kind_: KGuildScheduledEventDelete,
    project_: event => {
      match event {
        GuildScheduledEventDelete(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::guild_scheduled_event_update() -> EventType[
  @model.GuildScheduledEvent,
] {
  {
    kind_: KGuildScheduledEventUpdate,
    project_: event => {
      match event {
        GuildScheduledEventUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::guild_scheduled_event_user_add() -> EventType[
  @model.GuildScheduledEventUserEvent,
] {
  {
    kind_: KGuildScheduledEventUserAdd,
    project_: event => {
      match event {
        GuildScheduledEventUserAdd(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::guild_scheduled_event_user_remove() -> EventType[
  @model.GuildScheduledEventUserEvent,
] {
  {
    kind_: KGuildScheduledEventUserRemove,
    project_: event => {
      match event {
        GuildScheduledEventUserRemove(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::guild_soundboard_sound_create() -> EventType[
  @model.SoundboardSound,
] {
  {
    kind_: KGuildSoundboardSoundCreate,
    project_: event => {
      match event {
        GuildSoundboardSoundCreate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::guild_soundboard_sound_delete() -> EventType[
  @model.GuildSoundboardSoundDeleteEvent,
] {
  {
    kind_: KGuildSoundboardSoundDelete,
    project_: event => {
      match event {
        GuildSoundboardSoundDelete(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::guild_soundboard_sounds_update() -> EventType[
  @model.SoundboardSoundsEvent,
] {
  {
    kind_: KGuildSoundboardSoundsUpdate,
    project_: event => {
      match event {
        GuildSoundboardSoundsUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::guild_soundboard_sound_update() -> EventType[
  @model.SoundboardSound,
] {
  {
    kind_: KGuildSoundboardSoundUpdate,
    project_: event => {
      match event {
        GuildSoundboardSoundUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::soundboard_sounds() -> EventType[@model.SoundboardSoundsEvent] {
  {
    kind_: KSoundboardSounds,
    project_: event => {
      match event {
        SoundboardSounds(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::guild_stickers_update() -> EventType[
  @model.GuildStickersUpdateEvent,
] {
  {
    kind_: KGuildStickersUpdate,
    project_: event => {
      match event {
        GuildStickersUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::guild_update() -> EventType[@model.Guild] {
  {
    kind_: KGuildUpdate,
    project_: event => {
      match event {
        GuildUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::integration_create() -> EventType[@model.IntegrationEvent] {
  {
    kind_: KIntegrationCreate,
    project_: event => {
      match event {
        IntegrationCreate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::integration_delete() -> EventType[@model.IntegrationDeleteEvent] {
  {
    kind_: KIntegrationDelete,
    project_: event => {
      match event {
        IntegrationDelete(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::integration_update() -> EventType[@model.IntegrationEvent] {
  {
    kind_: KIntegrationUpdate,
    project_: event => {
      match event {
        IntegrationUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::interaction_create() -> EventType[@model.Interaction] {
  {
    kind_: KInteractionCreate,
    project_: event => {
      match event {
        InteractionCreate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::invite_create() -> EventType[@model.InviteCreateEvent] {
  {
    kind_: KInviteCreate,
    project_: event => {
      match event {
        InviteCreate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::invite_delete() -> EventType[@model.InviteDeleteEvent] {
  {
    kind_: KInviteDelete,
    project_: event => {
      match event {
        InviteDelete(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::message_create() -> EventType[@model.Message] {
  {
    kind_: KMessageCreate,
    project_: event => {
      match event {
        MessageCreate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::message_delete() -> EventType[@model.MessageDeleteEvent] {
  {
    kind_: KMessageDelete,
    project_: event => {
      match event {
        MessageDelete(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::message_delete_bulk() -> EventType[@model.MessageDeleteBulkEvent] {
  {
    kind_: KMessageDeleteBulk,
    project_: event => {
      match event {
        MessageDeleteBulk(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::message_poll_vote_add() -> EventType[@model.MessagePollVoteEvent] {
  {
    kind_: KMessagePollVoteAdd,
    project_: event => {
      match event {
        MessagePollVoteAdd(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::message_poll_vote_remove() -> EventType[
  @model.MessagePollVoteEvent,
] {
  {
    kind_: KMessagePollVoteRemove,
    project_: event => {
      match event {
        MessagePollVoteRemove(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::message_reaction_add() -> EventType[
  @model.MessageReactionAddEvent,
] {
  {
    kind_: KMessageReactionAdd,
    project_: event => {
      match event {
        MessageReactionAdd(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::message_reaction_remove() -> EventType[
  @model.MessageReactionRemoveEvent,
] {
  {
    kind_: KMessageReactionRemove,
    project_: event => {
      match event {
        MessageReactionRemove(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::message_reaction_remove_all() -> EventType[
  @model.MessageReactionRemoveAllEvent,
] {
  {
    kind_: KMessageReactionRemoveAll,
    project_: event => {
      match event {
        MessageReactionRemoveAll(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::message_reaction_remove_emoji() -> EventType[
  @model.MessageReactionRemoveEmojiEvent,
] {
  {
    kind_: KMessageReactionRemoveEmoji,
    project_: event => {
      match event {
        MessageReactionRemoveEmoji(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::message_update() -> EventType[@model.Message] {
  {
    kind_: KMessageUpdate,
    project_: event => {
      match event {
        MessageUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::rate_limited() -> EventType[@model.GatewayRateLimitedEvent] {
  {
    kind_: KRateLimited,
    project_: event => {
      match event {
        RateLimited(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::ready() -> EventType[@model.Ready] {
  {
    kind_: KReady,
    project_: event => {
      match event {
        Ready(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::stage_instance_create() -> EventType[@model.StageInstance] {
  {
    kind_: KStageInstanceCreate,
    project_: event => {
      match event {
        StageInstanceCreate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::stage_instance_delete() -> EventType[@model.StageInstance] {
  {
    kind_: KStageInstanceDelete,
    project_: event => {
      match event {
        StageInstanceDelete(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::stage_instance_update() -> EventType[@model.StageInstance] {
  {
    kind_: KStageInstanceUpdate,
    project_: event => {
      match event {
        StageInstanceUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::thread_create() -> EventType[@model.Channel] {
  {
    kind_: KThreadCreate,
    project_: event => {
      match event {
        ThreadCreate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::thread_delete() -> EventType[@model.ThreadDeleteEvent] {
  {
    kind_: KThreadDelete,
    project_: event => {
      match event {
        ThreadDelete(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::thread_list_sync() -> EventType[@model.ThreadListSyncEvent] {
  {
    kind_: KThreadListSync,
    project_: event => {
      match event {
        ThreadListSync(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::thread_members_update() -> EventType[
  @model.ThreadMembersUpdateEvent,
] {
  {
    kind_: KThreadMembersUpdate,
    project_: event => {
      match event {
        ThreadMembersUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::thread_member_update() -> EventType[
  @model.ThreadMemberUpdateEvent,
] {
  {
    kind_: KThreadMemberUpdate,
    project_: event => {
      match event {
        ThreadMemberUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::thread_update() -> EventType[@model.Channel] {
  {
    kind_: KThreadUpdate,
    project_: event => {
      match event {
        ThreadUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::typing_start() -> EventType[@model.TypingStartEvent] {
  {
    kind_: KTypingStart,
    project_: event => {
      match event {
        TypingStart(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::user_update() -> EventType[@model.User] {
  {
    kind_: KUserUpdate,
    project_: event => {
      match event {
        UserUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::voice_channel_effect_send() -> EventType[
  @model.VoiceChannelEffectSendEvent,
] {
  {
    kind_: KVoiceChannelEffectSend,
    project_: event => {
      match event {
        VoiceChannelEffectSend(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::voice_channel_start_time_update() -> EventType[
  @model.VoiceChannelStartTimeUpdateEvent,
] {
  {
    kind_: KVoiceChannelStartTimeUpdate,
    project_: event => {
      match event {
        VoiceChannelStartTimeUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::voice_channel_status_update() -> EventType[
  @model.VoiceChannelStatusUpdateEvent,
] {
  {
    kind_: KVoiceChannelStatusUpdate,
    project_: event => {
      match event {
        VoiceChannelStatusUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::voice_server_update() -> EventType[@model.VoiceServerUpdateEvent] {
  {
    kind_: KVoiceServerUpdate,
    project_: event => {
      match event {
        VoiceServerUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::voice_state_update() -> EventType[@model.VoiceState] {
  {
    kind_: KVoiceStateUpdate,
    project_: event => {
      match event {
        VoiceStateUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
pub fn Events::webhooks_update() -> EventType[@model.WebhooksUpdateEvent] {
  {
    kind_: KWebhooksUpdate,
    project_: event => {
      match event {
        WebhooksUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}
