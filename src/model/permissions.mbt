///|
/// Guild/channel permissions bitfield. Unknown bits are preserved.
///
/// Wire format: a decimal **string** (Discord serializes permissions as
/// strings because they exceed JavaScript's 53-bit safe-integer range).
pub(all) struct Permissions(UInt64) derive(Eq)

///|
pub fn Permissions::none() -> Permissions {
  Permissions(0)
}

///|
pub fn Permissions::from_bits(bits : UInt64) -> Permissions {
  Permissions(bits)
}

///|
pub fn Permissions::bits(self : Permissions) -> UInt64 {
  self.0
}

///|
pub fn Permissions::contains(self : Permissions, other : Permissions) -> Bool {
  (self.0 & other.0) == other.0
}

///|
pub impl BitOr for Permissions with fn lor(a, b) {
  Permissions(a.0 | b.0)
}

///|
pub impl BitAnd for Permissions with fn land(a, b) {
  Permissions(a.0 & b.0)
}

///|
pub impl Debug for Permissions with fn to_repr(self) {
  Repr(self.0)
}

///|
pub impl ToJson for Permissions with fn to_json(self) {
  Json::string(self.0.to_string())
}

///|
pub impl @json.FromJson for Permissions with fn from_json(json, path) {
  match json {
    String(s) =>
      Permissions(
        @string.parse_uint64(s) catch {
          _ =>
            raise JsonDecodeError(
              (path, "expected permissions (decimal string), got \{s}"),
            )
        },
      )
    _ => raise JsonDecodeError((path, "expected permissions (string)"))
  }
}

///|
pub fn Permissions::create_instant_invite() -> Permissions {
  Permissions(1UL << 0)
}

///|
pub fn Permissions::kick_members() -> Permissions {
  Permissions(1UL << 1)
}

///|
pub fn Permissions::ban_members() -> Permissions {
  Permissions(1UL << 2)
}

///|
pub fn Permissions::administrator() -> Permissions {
  Permissions(1UL << 3)
}

///|
pub fn Permissions::manage_channels() -> Permissions {
  Permissions(1UL << 4)
}

///|
pub fn Permissions::manage_guild() -> Permissions {
  Permissions(1UL << 5)
}

///|
pub fn Permissions::add_reactions() -> Permissions {
  Permissions(1UL << 6)
}

///|
pub fn Permissions::view_audit_log() -> Permissions {
  Permissions(1UL << 7)
}

///|
pub fn Permissions::priority_speaker() -> Permissions {
  Permissions(1UL << 8)
}

///|
pub fn Permissions::stream() -> Permissions {
  Permissions(1UL << 9)
}

///|
pub fn Permissions::view_channel() -> Permissions {
  Permissions(1UL << 10)
}

///|
pub fn Permissions::send_messages() -> Permissions {
  Permissions(1UL << 11)
}

///|
pub fn Permissions::send_tts_messages() -> Permissions {
  Permissions(1UL << 12)
}

///|
pub fn Permissions::manage_messages() -> Permissions {
  Permissions(1UL << 13)
}

///|
pub fn Permissions::embed_links() -> Permissions {
  Permissions(1UL << 14)
}

///|
pub fn Permissions::attach_files() -> Permissions {
  Permissions(1UL << 15)
}

///|
pub fn Permissions::read_message_history() -> Permissions {
  Permissions(1UL << 16)
}

///|
pub fn Permissions::mention_everyone() -> Permissions {
  Permissions(1UL << 17)
}

///|
pub fn Permissions::use_external_emojis() -> Permissions {
  Permissions(1UL << 18)
}

///|
pub fn Permissions::view_guild_insights() -> Permissions {
  Permissions(1UL << 19)
}

///|
pub fn Permissions::connect() -> Permissions {
  Permissions(1UL << 20)
}

///|
pub fn Permissions::speak() -> Permissions {
  Permissions(1UL << 21)
}

///|
pub fn Permissions::mute_members() -> Permissions {
  Permissions(1UL << 22)
}

///|
pub fn Permissions::deafen_members() -> Permissions {
  Permissions(1UL << 23)
}

///|
pub fn Permissions::move_members() -> Permissions {
  Permissions(1UL << 24)
}

///|
pub fn Permissions::use_vad() -> Permissions {
  Permissions(1UL << 25)
}

///|
pub fn Permissions::change_nickname() -> Permissions {
  Permissions(1UL << 26)
}

///|
pub fn Permissions::manage_nicknames() -> Permissions {
  Permissions(1UL << 27)
}

///|
pub fn Permissions::manage_roles() -> Permissions {
  Permissions(1UL << 28)
}

///|
pub fn Permissions::manage_webhooks() -> Permissions {
  Permissions(1UL << 29)
}

///|
pub fn Permissions::manage_guild_expressions() -> Permissions {
  Permissions(1UL << 30)
}

///|
pub fn Permissions::use_application_commands() -> Permissions {
  Permissions(1UL << 31)
}

///|
pub fn Permissions::request_to_speak() -> Permissions {
  Permissions(1UL << 32)
}

///|
pub fn Permissions::manage_events() -> Permissions {
  Permissions(1UL << 33)
}

///|
pub fn Permissions::manage_threads() -> Permissions {
  Permissions(1UL << 34)
}

///|
pub fn Permissions::create_public_threads() -> Permissions {
  Permissions(1UL << 35)
}

///|
pub fn Permissions::create_private_threads() -> Permissions {
  Permissions(1UL << 36)
}

///|
pub fn Permissions::use_external_stickers() -> Permissions {
  Permissions(1UL << 37)
}

///|
pub fn Permissions::send_messages_in_threads() -> Permissions {
  Permissions(1UL << 38)
}

///|
pub fn Permissions::use_embedded_activities() -> Permissions {
  Permissions(1UL << 39)
}

///|
pub fn Permissions::moderate_members() -> Permissions {
  Permissions(1UL << 40)
}

///|
pub fn Permissions::view_creator_monetization_analytics() -> Permissions {
  Permissions(1UL << 41)
}

///|
pub fn Permissions::use_soundboard() -> Permissions {
  Permissions(1UL << 42)
}

///|
pub fn Permissions::create_guild_expressions() -> Permissions {
  Permissions(1UL << 43)
}

///|
pub fn Permissions::create_events() -> Permissions {
  Permissions(1UL << 44)
}

///|
pub fn Permissions::use_external_sounds() -> Permissions {
  Permissions(1UL << 45)
}

///|
pub fn Permissions::send_voice_messages() -> Permissions {
  Permissions(1UL << 46)
}

///|
pub fn Permissions::set_voice_channel_status() -> Permissions {
  Permissions(1UL << 48)
}

///|
pub fn Permissions::send_polls() -> Permissions {
  Permissions(1UL << 49)
}

///|
pub fn Permissions::use_external_apps() -> Permissions {
  Permissions(1UL << 50)
}

///|
pub fn Permissions::pin_messages() -> Permissions {
  Permissions(1UL << 51)
}

///|
pub fn Permissions::bypass_slowmode() -> Permissions {
  Permissions(1UL << 52)
}
