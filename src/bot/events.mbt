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
/// The payload-free `Resumed` event and `Unknown` are available only through
/// the low-level event stream.
#warnings("-struct_never_constructed")
pub struct Events {}

///|
/// Typed descriptor for `APPLICATION_COMMAND_PERMISSIONS_UPDATE` — the
/// permission overwrites of an application command were updated.
/// Not gated by a gateway intent.
pub fn Events::application_command_permissions_update() -> EventType[
  @model.GuildApplicationCommandPermissions,
] {
  {
    kind_: KApplicationCommandPermissionsUpdate,
    project_: event => {
      match event {
        ApplicationCommandPermissionsUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
/// Typed descriptor for `AUTO_MODERATION_ACTION_EXECUTION` — an auto
/// moderation rule triggered and its action was executed. Delivered under
/// the `AUTO_MODERATION_EXECUTION` intent.
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
/// Typed descriptor for `AUTO_MODERATION_RULE_CREATE` — an auto moderation
/// rule was created. Delivered under the `AUTO_MODERATION_CONFIGURATION`
/// intent.
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
/// Typed descriptor for `AUTO_MODERATION_RULE_DELETE` — an auto moderation
/// rule was deleted. Delivered under the `AUTO_MODERATION_CONFIGURATION`
/// intent.
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
/// Typed descriptor for `AUTO_MODERATION_RULE_UPDATE` — an auto moderation
/// rule was updated. Delivered under the `AUTO_MODERATION_CONFIGURATION`
/// intent.
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
/// Typed descriptor for `CHANNEL_CREATE` — a guild channel was created.
/// Delivered under the `GUILDS` intent.
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
/// Typed descriptor for `CHANNEL_DELETE` — a guild channel was deleted.
/// Delivered under the `GUILDS` intent.
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
/// Typed descriptor for `CHANNEL_INFO` — ephemeral voice-channel status
/// and session data for a guild's channels. Not gated by a gateway
/// intent.
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
/// Typed descriptor for `CHANNEL_PINS_UPDATE` — a message was pinned or
/// unpinned (not fired when a pinned message is deleted). Delivered under
/// the `GUILDS` or `DIRECT_MESSAGES` intent.
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
/// Typed descriptor for `CHANNEL_UPDATE` — a guild channel was updated.
/// Delivered under the `GUILDS` intent.
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
/// Typed descriptor for `ENTITLEMENT_CREATE` — an entitlement was created,
/// e.g. a user purchased or was granted a premium offering. Not gated by
/// a gateway intent.
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
/// Typed descriptor for `ENTITLEMENT_DELETE` — an entitlement was deleted,
/// e.g. Discord refunded or revoked it (not fired on normal expiry). Not
/// gated by a gateway intent.
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
/// Typed descriptor for `ENTITLEMENT_UPDATE` — an entitlement was renewed
/// or ended. Not gated by a gateway intent.
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
/// Typed descriptor for `GUILD_AUDIT_LOG_ENTRY_CREATE` — an audit log
/// entry was created. Delivered under the `GUILD_MODERATION` intent; the
/// bot also needs the `View Audit Log` permission.
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
/// Typed descriptor for `GUILD_BAN_ADD` — a user was banned from a guild.
/// Delivered under the `GUILD_MODERATION` intent.
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
/// Typed descriptor for `GUILD_BAN_REMOVE` — a user was unbanned from a
/// guild. Delivered under the `GUILD_MODERATION` intent.
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
/// Typed descriptor for `GUILD_CREATE` — the initial lazy-load of each
/// guild after `READY`, a guild becoming available again, or the bot
/// joining a new guild. Delivered under the `GUILDS` intent.
pub fn Events::guild_create() -> EventType[@model.GuildCreateEvent] {
  {
    kind_: KGuildCreate,
    project_: event => {
      match event {
        GuildCreate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
/// Typed descriptor for `GUILD_DELETE` — the bot was removed from a guild,
/// or the guild became unavailable during an outage (check the
/// `unavailable` field to tell the two apart). Delivered under the
/// `GUILDS` intent.
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
/// Typed descriptor for `GUILD_EMOJIS_UPDATE` — a guild's custom emoji
/// set changed. Delivered under the `GUILD_EXPRESSIONS` intent.
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
/// Typed descriptor for `GUILD_INTEGRATIONS_UPDATE` — a guild integration
/// was created, updated, or deleted. Delivered under the
/// `GUILD_INTEGRATIONS` intent.
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
/// Typed descriptor for `GUILD_MEMBER_ADD` — a user joined a guild.
/// Delivered under the privileged `GUILD_MEMBERS` intent.
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
/// Typed descriptor for `GUILD_MEMBER_REMOVE` — a user left a guild, or
/// was kicked or banned. Delivered under the privileged `GUILD_MEMBERS`
/// intent.
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
/// Typed descriptor for `GUILD_MEMBERS_CHUNK` — one page of the response
/// to a Request Guild Members gateway command. Not gated by a gateway
/// intent.
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
/// Typed descriptor for `GUILD_MEMBER_UPDATE` — a guild member was
/// updated (roles, nick, timeout, ...). Delivered under the privileged
/// `GUILD_MEMBERS` intent.
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
/// Typed descriptor for `GUILD_ROLE_CREATE` — a role was created.
/// Delivered under the `GUILDS` intent.
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
/// Typed descriptor for `GUILD_ROLE_DELETE` — a role was deleted.
/// Delivered under the `GUILDS` intent.
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
/// Typed descriptor for `GUILD_ROLE_UPDATE` — a role was updated.
/// Delivered under the `GUILDS` intent.
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
/// Typed descriptor for `GUILD_SCHEDULED_EVENT_CREATE` — a scheduled
/// event was created. Delivered under the `GUILD_SCHEDULED_EVENTS`
/// intent.
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
/// Typed descriptor for `GUILD_SCHEDULED_EVENT_DELETE` — a scheduled
/// event was deleted. Delivered under the `GUILD_SCHEDULED_EVENTS`
/// intent.
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
/// Typed descriptor for `GUILD_SCHEDULED_EVENT_UPDATE` — a scheduled
/// event was updated. Delivered under the `GUILD_SCHEDULED_EVENTS`
/// intent.
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
/// Typed descriptor for `GUILD_SCHEDULED_EVENT_USER_ADD` — a user
/// subscribed to a scheduled event. Delivered under the
/// `GUILD_SCHEDULED_EVENTS` intent.
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
/// Typed descriptor for `GUILD_SCHEDULED_EVENT_USER_REMOVE` — a user
/// unsubscribed from a scheduled event. Delivered under the
/// `GUILD_SCHEDULED_EVENTS` intent.
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
/// Typed descriptor for `GUILD_SOUNDBOARD_SOUND_CREATE` — a soundboard
/// sound was created. Delivered under the `GUILD_EXPRESSIONS` intent.
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
/// Typed descriptor for `GUILD_SOUNDBOARD_SOUND_DELETE` — a soundboard
/// sound was deleted. Delivered under the `GUILD_EXPRESSIONS` intent.
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
/// Typed descriptor for `GUILD_SOUNDBOARD_SOUNDS_UPDATE` — multiple
/// soundboard sounds were updated at once. Delivered under the
/// `GUILD_EXPRESSIONS` intent.
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
/// Typed descriptor for `GUILD_SOUNDBOARD_SOUND_UPDATE` — a soundboard
/// sound was updated. Delivered under the `GUILD_EXPRESSIONS` intent.
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
/// Typed descriptor for `SOUNDBOARD_SOUNDS` — the response to a Request
/// Soundboard Sounds gateway command. Not gated by a gateway intent.
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
/// Typed descriptor for `GUILD_STICKERS_UPDATE` — a guild's sticker set
/// changed. Delivered under the `GUILD_EXPRESSIONS` intent.
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
/// Typed descriptor for `GUILD_UPDATE` — a guild's settings were updated.
/// Delivered under the `GUILDS` intent.
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
/// Typed descriptor for `INTEGRATION_CREATE` — an integration was created
/// in a guild. Delivered under the `GUILD_INTEGRATIONS` intent.
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
/// Typed descriptor for `INTEGRATION_DELETE` — an integration was deleted
/// from a guild. Delivered under the `GUILD_INTEGRATIONS` intent.
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
/// Typed descriptor for `INTEGRATION_UPDATE` — an integration was updated
/// in a guild. Delivered under the `GUILD_INTEGRATIONS` intent.
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
/// Typed descriptor for `INTERACTION_CREATE` — a user invoked a slash
/// command, component, modal, or autocomplete. Not gated by a gateway
/// intent. Most bots should route interactions through `App::attach`
/// instead of subscribing to this event directly.
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
/// Typed descriptor for `INVITE_CREATE` — an invite to a channel was
/// created. Delivered under the `GUILD_INVITES` intent; the bot also
/// needs the `Manage Channels` permission on the channel.
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
/// Typed descriptor for `INVITE_DELETE` — an invite to a channel was
/// deleted. Delivered under the `GUILD_INVITES` intent; the bot also
/// needs the `Manage Channels` permission on the channel.
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
/// Typed descriptor for `MESSAGE_CREATE` — a message was sent. Delivered
/// under the `GUILD_MESSAGES` or `DIRECT_MESSAGES` intent; `content`,
/// `embeds`, `attachments`, and `components` stay empty in guilds unless
/// the privileged `MESSAGE_CONTENT` intent is also enabled.
pub fn Events::message_create() -> EventType[@model.MessageCreateEvent] {
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
/// Typed descriptor for `MESSAGE_DELETE` — a message was deleted.
/// Delivered under the `GUILD_MESSAGES` or `DIRECT_MESSAGES` intent.
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
/// Typed descriptor for `MESSAGE_DELETE_BULK` — multiple messages were
/// deleted at once. Delivered under the `GUILD_MESSAGES` intent.
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
/// Typed descriptor for `MESSAGE_POLL_VOTE_ADD` — a user voted on a poll.
/// Delivered under the `GUILD_MESSAGE_POLLS` or `DIRECT_MESSAGE_POLLS`
/// intent.
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
/// Typed descriptor for `MESSAGE_POLL_VOTE_REMOVE` — a user removed a
/// poll vote. Delivered under the `GUILD_MESSAGE_POLLS` or
/// `DIRECT_MESSAGE_POLLS` intent.
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
/// Typed descriptor for `MESSAGE_REACTION_ADD`.
///
/// A classic use is reaction roles: subscribe to reaction add and remove
/// events, identify the configured emoji, then update the member role
/// through the REST client. The bot needs the `Manage Roles` permission,
/// and its highest role must be above the assigned role. Typed
/// subscriptions infer the non-privileged reaction delivery intents when
/// `Bot(...)` omits an explicit `intents` value; if intents are explicit,
/// include `Intents::guild_message_reactions()`. Production handlers should
/// also restrict the configured message and channel IDs and make the
/// add/remove operations idempotent at the application level.
///
/// ```mbt check
/// test "install a reaction role feature" {
///   fn install_reaction_role(bot : @bot.Bot, role_id : @model.RoleId) -> Unit {
///     bot.on(@bot.Events::message_reaction_add(), (ctx, event) => {
///       guard event.guild_id is Some(guild_id) else { return }
///       guard event.emoji.name.to_option() == Some("✅") else { return }
///       if event.user_id == ctx.ready().user.id {
///         return
///       }
///       ctx
///       .app()
///       .http()
///       .add_member_role(
///         guild_id,
///         event.user_id,
///         role_id,
///         audit_reason="reaction role",
///       )
///     })
///     bot.on(@bot.Events::message_reaction_remove(), (ctx, event) => {
///       guard event.guild_id is Some(guild_id) else { return }
///       guard event.emoji.name.to_option() == Some("✅") else { return }
///       ctx
///       .app()
///       .http()
///       .remove_member_role(
///         guild_id,
///         event.user_id,
///         role_id,
///         audit_reason="reaction role removed",
///       )
///     })
///   }
///
///   ignore(install_reaction_role)
/// }
/// ```
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
/// Typed descriptor for `MESSAGE_REACTION_REMOVE` — a user removed a
/// reaction from a message. Delivered under the
/// `GUILD_MESSAGE_REACTIONS` or `DIRECT_MESSAGE_REACTIONS` intent. See
/// `Events::message_reaction_add` for a worked reaction-role example.
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
/// Typed descriptor for `MESSAGE_REACTION_REMOVE_ALL` — all reactions
/// were cleared from a message. Delivered under the
/// `GUILD_MESSAGE_REACTIONS` or `DIRECT_MESSAGE_REACTIONS` intent.
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
/// Typed descriptor for `MESSAGE_REACTION_REMOVE_EMOJI` — all reactions
/// for a single emoji were cleared from a message. Delivered under the
/// `GUILD_MESSAGE_REACTIONS` or `DIRECT_MESSAGE_REACTIONS` intent.
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
/// Typed descriptor for `MESSAGE_UPDATE` — a message was edited (also
/// fired for embed unfurls and other partial edits). Delivered under the
/// `GUILD_MESSAGES` or `DIRECT_MESSAGES` intent; content visibility
/// follows the same `MESSAGE_CONTENT` rule as `MESSAGE_CREATE`.
pub fn Events::message_update() -> EventType[@model.MessageUpdateEvent] {
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
/// Typed descriptor for `PRESENCE_UPDATE` — a member's presence (status
/// or activities) changed. Delivered under the privileged
/// `GUILD_PRESENCES` intent.
pub fn Events::presence_update() -> EventType[@model.PresenceUpdateEvent] {
  {
    kind_: KPresenceUpdate,
    project_: event => {
      match event {
        PresenceUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
/// Typed descriptor for `RATE_LIMITED` — the gateway rejected a command
/// sent by this shard and reported when it may retry. Not gated by a
/// gateway intent.
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
/// Typed descriptor for `READY` — the initial state after identify
/// completes: the bot user, unavailable guilds, and session resume data.
/// Fired once per session (including after reconnects that re-identify).
/// Not gated by a gateway intent.
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
/// Typed descriptor for `STAGE_INSTANCE_CREATE` — a stage instance
/// (live stage) was created. Delivered under the `GUILDS` intent.
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
/// Typed descriptor for `STAGE_INSTANCE_DELETE` — a stage instance was
/// deleted. Delivered under the `GUILDS` intent.
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
/// Typed descriptor for `STAGE_INSTANCE_UPDATE` — a stage instance was
/// updated. Delivered under the `GUILDS` intent.
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
/// Typed descriptor for `SUBSCRIPTION_CREATE` — a premium app
/// subscription was created. Not gated by a gateway intent.
pub fn Events::subscription_create() -> EventType[@model.Subscription] {
  {
    kind_: KSubscriptionCreate,
    project_: event => {
      match event {
        SubscriptionCreate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
/// Typed descriptor for `SUBSCRIPTION_DELETE` — a premium app
/// subscription was deleted. Not gated by a gateway intent.
pub fn Events::subscription_delete() -> EventType[@model.Subscription] {
  {
    kind_: KSubscriptionDelete,
    project_: event => {
      match event {
        SubscriptionDelete(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
/// Typed descriptor for `SUBSCRIPTION_UPDATE` — a premium app
/// subscription was updated, e.g. renewed or ended. Not gated by a
/// gateway intent.
pub fn Events::subscription_update() -> EventType[@model.Subscription] {
  {
    kind_: KSubscriptionUpdate,
    project_: event => {
      match event {
        SubscriptionUpdate(value) => Some(value)
        _ => None
      }
    },
  }
}

///|
/// Typed descriptor for `THREAD_CREATE` — a thread was created, or the
/// bot was added to a private thread. Delivered under the `GUILDS`
/// intent.
pub fn Events::thread_create() -> EventType[@model.ThreadCreateEvent] {
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
/// Typed descriptor for `THREAD_DELETE` — a thread was deleted. Delivered
/// under the `GUILDS` intent.
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
/// Typed descriptor for `THREAD_LIST_SYNC` — the active threads of one or
/// more channels were synced after the bot gained access to them.
/// Delivered under the `GUILDS` intent.
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
/// Typed descriptor for `THREAD_MEMBERS_UPDATE` — users were added to or
/// removed from a thread. With only the `GUILDS` intent this fires for
/// changes involving the bot itself; the privileged `GUILD_MEMBERS`
/// intent extends it to all users.
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
/// Typed descriptor for `THREAD_MEMBER_UPDATE` — the bot's own thread
/// member object was updated. Delivered under the `GUILDS` intent.
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
/// Typed descriptor for `THREAD_UPDATE` — a thread was updated. Delivered
/// under the `GUILDS` intent.
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
/// Typed descriptor for `TYPING_START` — a user started typing in a
/// channel. Delivered under the `GUILD_MESSAGE_TYPING` or
/// `DIRECT_MESSAGE_TYPING` intent.
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
/// Typed descriptor for `USER_UPDATE` — the bot's own user object was
/// updated. Not gated by a gateway intent.
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
/// Typed descriptor for `VOICE_CHANNEL_EFFECT_SEND` — someone sent an
/// emoji or soundboard effect in a voice channel. Delivered under the
/// `GUILD_VOICE_STATES` intent.
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
/// Typed descriptor for `VOICE_CHANNEL_START_TIME_UPDATE` — a voice
/// channel's session start time changed. Delivered under the `GUILDS`
/// intent.
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
/// Typed descriptor for `VOICE_CHANNEL_STATUS_UPDATE` — a voice channel's
/// status text changed. Delivered under the `GUILDS` intent.
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
/// Typed descriptor for `VOICE_SERVER_UPDATE` — voice server credentials
/// for a pending voice connection (consumed internally by
/// `BotCtx::join_voice`). Not gated by a gateway intent.
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
/// Typed descriptor for `VOICE_STATE_UPDATE` — someone joined, left, or
/// moved between voice channels, or a voice state changed (mute, deaf,
/// ...). Delivered under the `GUILD_VOICE_STATES` intent.
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
/// Typed descriptor for `WEBHOOKS_UPDATE` — a webhook in a channel was
/// created, updated, or deleted. Delivered under the `GUILD_WEBHOOKS`
/// intent.
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
