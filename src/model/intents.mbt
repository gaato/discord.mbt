///|
/// Gateway intents: the server-side event subscription bitfield sent in
/// Identify. Unknown bits are preserved. Wire format: JSON number.
///
/// ```mbt check
/// test "compose the gateway event subscriptions a bot needs" {
///   let intents = @model.Intents::guilds() |
///     @model.Intents::guild_messages() |
///     @model.Intents::message_content()
///   inspect(
///     intents.bits(),
///     content=(
///       #|33281
///     ),
///   )
///   assert_true(intents.contains(@model.Intents::message_content()))
/// }
/// ```
pub(all) struct Intents(UInt) derive(Eq)

///|
pub fn Intents::none() -> Intents {
  Intents(0)
}

///|
pub fn Intents::from_bits(bits : UInt) -> Intents {
  Intents(bits)
}

///|
pub fn Intents::bits(self : Intents) -> UInt {
  self.0
}

///|
pub fn Intents::contains(self : Intents, other : Intents) -> Bool {
  (self.0 & other.0) == other.0
}

///|
pub impl BitOr for Intents with fn lor(a, b) {
  Intents(a.0 | b.0)
}

///|
pub impl BitAnd for Intents with fn land(a, b) {
  Intents(a.0 & b.0)
}

///|
pub impl Debug for Intents with fn to_repr(self) {
  Repr(self.0)
}

///|
pub impl ToJson for Intents with fn to_json(self) {
  Json::number(self.0.to_uint64().to_double())
}

///|
pub impl @json.FromJson for Intents with fn from_json(json, path) {
  match json {
    Number(n, ..) => Intents(n.to_uint())
    _ => raise JsonDecodeError((path, "expected intents (number)"))
  }
}

///|
/// `GUILDS`: guild, channel, thread, role, and stage lifecycle events.
pub fn Intents::guilds() -> Intents {
  Intents(1U << 0)
}

///|
/// `GUILD_MEMBERS` (privileged): member join, leave, and update events.
/// Must also be enabled in the developer portal.
pub fn Intents::guild_members() -> Intents {
  Intents(1U << 1)
}

///|
/// `GUILD_MODERATION`: ban events and audit log entry creation.
pub fn Intents::guild_moderation() -> Intents {
  Intents(1U << 2)
}

///|
/// `GUILD_EXPRESSIONS`: emoji, sticker, and soundboard sound updates.
pub fn Intents::guild_expressions() -> Intents {
  Intents(1U << 3)
}

///|
/// `GUILD_INTEGRATIONS`: integration create, update, and delete events.
pub fn Intents::guild_integrations() -> Intents {
  Intents(1U << 4)
}

///|
/// `GUILD_WEBHOOKS`: webhook update events.
pub fn Intents::guild_webhooks() -> Intents {
  Intents(1U << 5)
}

///|
/// `GUILD_INVITES`: invite create and delete events.
pub fn Intents::guild_invites() -> Intents {
  Intents(1U << 6)
}

///|
/// `GUILD_VOICE_STATES`: voice state updates and voice channel effects.
pub fn Intents::guild_voice_states() -> Intents {
  Intents(1U << 7)
}

///|
/// `GUILD_PRESENCES` (privileged): member presence updates. Must also be
/// enabled in the developer portal.
pub fn Intents::guild_presences() -> Intents {
  Intents(1U << 8)
}

///|
/// `GUILD_MESSAGES`: message events in guilds. Content fields also need
/// `message_content`.
pub fn Intents::guild_messages() -> Intents {
  Intents(1U << 9)
}

///|
/// `GUILD_MESSAGE_REACTIONS`: reaction events in guilds.
pub fn Intents::guild_message_reactions() -> Intents {
  Intents(1U << 10)
}

///|
/// `GUILD_MESSAGE_TYPING`: typing indicators in guilds.
pub fn Intents::guild_message_typing() -> Intents {
  Intents(1U << 11)
}

///|
/// `DIRECT_MESSAGES`: message events in DM channels.
pub fn Intents::direct_messages() -> Intents {
  Intents(1U << 12)
}

///|
/// `DIRECT_MESSAGE_REACTIONS`: reaction events in DM channels.
pub fn Intents::direct_message_reactions() -> Intents {
  Intents(1U << 13)
}

///|
/// `DIRECT_MESSAGE_TYPING`: typing indicators in DM channels.
pub fn Intents::direct_message_typing() -> Intents {
  Intents(1U << 14)
}

///|
/// `MESSAGE_CONTENT` (privileged): unlocks `content`, `embeds`,
/// `attachments`, and `components` on guild messages not addressed to
/// the bot. Delivers no events by itself; must also be enabled in the
/// developer portal.
pub fn Intents::message_content() -> Intents {
  Intents(1U << 15)
}

///|
/// `GUILD_SCHEDULED_EVENTS`: scheduled event lifecycle and user
/// subscription events.
pub fn Intents::guild_scheduled_events() -> Intents {
  Intents(1U << 16)
}

///|
/// `AUTO_MODERATION_CONFIGURATION`: auto moderation rule events.
pub fn Intents::auto_moderation_configuration() -> Intents {
  Intents(1U << 20)
}

///|
/// `AUTO_MODERATION_EXECUTION`: auto moderation action execution events.
pub fn Intents::auto_moderation_execution() -> Intents {
  Intents(1U << 21)
}

///|
/// `GUILD_MESSAGE_POLLS`: poll vote events in guilds.
pub fn Intents::guild_message_polls() -> Intents {
  Intents(1U << 24)
}

///|
/// `DIRECT_MESSAGE_POLLS`: poll vote events in DM channels.
pub fn Intents::direct_message_polls() -> Intents {
  Intents(1U << 25)
}
