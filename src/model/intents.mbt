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
  to_repr(self.0)
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
pub fn Intents::guilds() -> Intents {
  Intents(1U << 0)
}

///|
pub fn Intents::guild_members() -> Intents {
  Intents(1U << 1)
}

///|
pub fn Intents::guild_moderation() -> Intents {
  Intents(1U << 2)
}

///|
pub fn Intents::guild_expressions() -> Intents {
  Intents(1U << 3)
}

///|
pub fn Intents::guild_integrations() -> Intents {
  Intents(1U << 4)
}

///|
pub fn Intents::guild_webhooks() -> Intents {
  Intents(1U << 5)
}

///|
pub fn Intents::guild_invites() -> Intents {
  Intents(1U << 6)
}

///|
pub fn Intents::guild_voice_states() -> Intents {
  Intents(1U << 7)
}

///|
pub fn Intents::guild_presences() -> Intents {
  Intents(1U << 8)
}

///|
pub fn Intents::guild_messages() -> Intents {
  Intents(1U << 9)
}

///|
pub fn Intents::guild_message_reactions() -> Intents {
  Intents(1U << 10)
}

///|
pub fn Intents::guild_message_typing() -> Intents {
  Intents(1U << 11)
}

///|
pub fn Intents::direct_messages() -> Intents {
  Intents(1U << 12)
}

///|
pub fn Intents::direct_message_reactions() -> Intents {
  Intents(1U << 13)
}

///|
pub fn Intents::direct_message_typing() -> Intents {
  Intents(1U << 14)
}

///|
pub fn Intents::message_content() -> Intents {
  Intents(1U << 15)
}

///|
pub fn Intents::guild_scheduled_events() -> Intents {
  Intents(1U << 16)
}

///|
pub fn Intents::auto_moderation_configuration() -> Intents {
  Intents(1U << 20)
}

///|
pub fn Intents::auto_moderation_execution() -> Intents {
  Intents(1U << 21)
}

///|
pub fn Intents::guild_message_polls() -> Intents {
  Intents(1U << 24)
}

///|
pub fn Intents::direct_message_polls() -> Intents {
  Intents(1U << 25)
}
