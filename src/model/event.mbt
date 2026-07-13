///|
/// A gateway dispatch event (opcode 0), decoded by event name (`t`).
///
/// Variants are added per domain; anything not yet typed (or newly added by
/// Discord) lands in `Unknown` with the raw payload, so consumers never
/// break on new event types.
pub(all) enum Event {
  Ready(Ready)
  Resumed
  MessageCreate(Message)
  MessageUpdate(Message)
  MessageDelete(MessageDeleteEvent)
  InteractionCreate(Interaction)
  GuildCreate(Json)
  GuildDelete(UnavailableGuild)
  ChannelCreate(Channel)
  ChannelUpdate(Channel)
  ChannelDelete(Channel)
  ThreadCreate(Channel)
  ThreadUpdate(Channel)
  ThreadDelete(Json)
  GuildMemberAdd(Json)
  GuildMemberRemove(Json)
  GuildMemberUpdate(Json)
  MessageReactionAdd(Json)
  MessageReactionRemove(Json)
  TypingStart(Json)
  PresenceUpdate(Json)
  VoiceStateUpdate(VoiceState)
  Unknown(t~ : String, d~ : Json)
} derive(Debug)

///|
/// Payload of MESSAGE_DELETE (the full message is not included).
pub(all) struct MessageDeleteEvent {
  id : MessageId
  channel_id : ChannelId
  guild_id : GuildId?
} derive(ToJson, FromJson, Debug)

///|
/// Event kind without payload, used for client-side filtering before the
/// payload is decoded.
pub(all) enum EventKind {
  KReady
  KResumed
  KMessageCreate
  KMessageUpdate
  KMessageDelete
  KInteractionCreate
  KGuildCreate
  KGuildDelete
  KChannelCreate
  KChannelUpdate
  KChannelDelete
  KThreadCreate
  KThreadUpdate
  KThreadDelete
  KGuildMemberAdd
  KGuildMemberRemove
  KGuildMemberUpdate
  KMessageReactionAdd
  KMessageReactionRemove
  KTypingStart
  KPresenceUpdate
  KVoiceStateUpdate
  KUnknown
} derive(Eq, Debug)

///|
pub fn EventKind::of_name(t : String) -> EventKind {
  match t {
    "READY" => KReady
    "RESUMED" => KResumed
    "MESSAGE_CREATE" => KMessageCreate
    "MESSAGE_UPDATE" => KMessageUpdate
    "MESSAGE_DELETE" => KMessageDelete
    "INTERACTION_CREATE" => KInteractionCreate
    "GUILD_CREATE" => KGuildCreate
    "GUILD_DELETE" => KGuildDelete
    "CHANNEL_CREATE" => KChannelCreate
    "CHANNEL_UPDATE" => KChannelUpdate
    "CHANNEL_DELETE" => KChannelDelete
    "THREAD_CREATE" => KThreadCreate
    "THREAD_UPDATE" => KThreadUpdate
    "THREAD_DELETE" => KThreadDelete
    "GUILD_MEMBER_ADD" => KGuildMemberAdd
    "GUILD_MEMBER_REMOVE" => KGuildMemberRemove
    "GUILD_MEMBER_UPDATE" => KGuildMemberUpdate
    "MESSAGE_REACTION_ADD" => KMessageReactionAdd
    "MESSAGE_REACTION_REMOVE" => KMessageReactionRemove
    "TYPING_START" => KTypingStart
    "PRESENCE_UPDATE" => KPresenceUpdate
    "VOICE_STATE_UPDATE" => KVoiceStateUpdate
    _ => KUnknown
  }
}

///|
/// Decode a dispatch payload by event name. Never raises for unknown names;
/// raises `@json.JsonDecodeError` only when a KNOWN event's payload fails to
/// decode (which indicates a model bug worth surfacing).
pub fn dispatch_event(t : String, d : Json) -> Event raise {
  match t {
    "READY" => Ready(@json.from_json(d))
    "RESUMED" => Resumed
    "MESSAGE_CREATE" => MessageCreate(@json.from_json(d))
    "MESSAGE_UPDATE" => MessageUpdate(@json.from_json(d))
    "MESSAGE_DELETE" => MessageDelete(@json.from_json(d))
    "INTERACTION_CREATE" => InteractionCreate(@json.from_json(d))
    // GUILD_CREATE payloads are huge; keep them raw until the guild-create
    // extra fields (members, channels, presences) are modeled.
    "GUILD_CREATE" => GuildCreate(d)
    "GUILD_DELETE" => GuildDelete(@json.from_json(d))
    "CHANNEL_CREATE" => ChannelCreate(@json.from_json(d))
    "CHANNEL_UPDATE" => ChannelUpdate(@json.from_json(d))
    "CHANNEL_DELETE" => ChannelDelete(@json.from_json(d))
    "THREAD_CREATE" => ThreadCreate(@json.from_json(d))
    "THREAD_UPDATE" => ThreadUpdate(@json.from_json(d))
    "THREAD_DELETE" => ThreadDelete(d)
    "GUILD_MEMBER_ADD" => GuildMemberAdd(d)
    "GUILD_MEMBER_REMOVE" => GuildMemberRemove(d)
    "GUILD_MEMBER_UPDATE" => GuildMemberUpdate(d)
    "MESSAGE_REACTION_ADD" => MessageReactionAdd(d)
    "MESSAGE_REACTION_REMOVE" => MessageReactionRemove(d)
    "TYPING_START" => TypingStart(d)
    "PRESENCE_UPDATE" => PresenceUpdate(d)
    "VOICE_STATE_UPDATE" => VoiceStateUpdate(@json.from_json(d))
    _ => Unknown(t~, d~)
  }
}
