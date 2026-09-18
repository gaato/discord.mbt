///|
/// Gateway capabilities: the Identify bitfield that opts a client into
/// gateway behaviors (as opposed to `Intents`, which select events). Unknown
/// bits are preserved. Wire format: JSON number.
///
/// ```mbt check
/// test "opt into channel obfuscation ahead of general availability" {
///   let capabilities = @model.GatewayCapabilities::channel_obfuscation()
///   inspect(capabilities.bits(), content="32768")
/// }
/// ```
pub(all) struct GatewayCapabilities(UInt) derive(Eq)

///|
pub fn GatewayCapabilities::none() -> GatewayCapabilities {
  GatewayCapabilities(0)
}

///|
pub fn GatewayCapabilities::from_bits(bits : UInt) -> GatewayCapabilities {
  GatewayCapabilities(bits)
}

///|
pub fn GatewayCapabilities::bits(self : GatewayCapabilities) -> UInt {
  self.0
}

///|
pub fn GatewayCapabilities::contains(
  self : GatewayCapabilities,
  other : GatewayCapabilities,
) -> Bool {
  (self.0 & other.0) == other.0
}

///|
pub impl BitOr for GatewayCapabilities with fn lor(a, b) {
  GatewayCapabilities(a.0 | b.0)
}

///|
pub impl BitAnd for GatewayCapabilities with fn land(a, b) {
  GatewayCapabilities(a.0 & b.0)
}

///|
pub impl Debug for GatewayCapabilities with fn to_repr(self) {
  Repr(self.0)
}

///|
pub impl ToJson for GatewayCapabilities with fn to_json(self) {
  Json::number(self.0.to_uint64().to_double())
}

///|
/// Receive obfuscated metadata for guild channels the bot cannot view (see
/// `ChannelFlags::channel_obfuscated`). Discord documents this as a temporary
/// testing opt-in: obfuscation applies to every bot from 2026-11-16.
pub fn GatewayCapabilities::channel_obfuscation() -> GatewayCapabilities {
  GatewayCapabilities(1U << 15)
}
