///|
/// Guild/channel permissions bitfield. Unknown bits are preserved.
///
/// Wire format: a decimal **string** (Discord serializes permissions as
/// strings because they exceed JavaScript's 53-bit safe-integer range).
pub(all) struct Permissions(UInt64) derive(Eq)

///|
/// No flags set.
pub fn Permissions::none() -> Permissions {
  Permissions(0)
}

///|
/// Flags from a raw bit field; unknown bits are kept.
pub fn Permissions::from_bits(bits : UInt64) -> Permissions {
  Permissions(bits)
}

///|
/// The raw bit field.
pub fn Permissions::bits(self : Permissions) -> UInt64 {
  self.0
}

///|
/// Whether every flag in `other` is set.
pub fn Permissions::contains(self : Permissions, other : Permissions) -> Bool {
  (self.0 & other.0) == other.0
}

///|
/// Combines flags: every flag set in either operand is set.
pub impl BitOr for Permissions with fn lor(a, b) {
  Permissions(a.0 | b.0)
}

///|
/// Keeps the flags set in both operands.
pub impl BitAnd for Permissions with fn land(a, b) {
  Permissions(a.0 & b.0)
}

///|
/// Debug output is the raw bit field.
pub impl Debug for Permissions with fn to_repr(self) {
  Repr(self.0)
}

///|
/// Encodes the permissions as a decimal string.
pub impl ToJson for Permissions with fn to_json(self) {
  Json::string(self.0.to_string())
}

///|
/// Decodes the permissions from a decimal string; unknown bits are kept.
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
/// Allows creating instant invites.
pub fn Permissions::create_instant_invite() -> Permissions {
  Permissions(1UL << 0)
}

///|
/// Allows kicking members from the guild.
pub fn Permissions::kick_members() -> Permissions {
  Permissions(1UL << 1)
}

///|
/// Allows banning members from the guild.
pub fn Permissions::ban_members() -> Permissions {
  Permissions(1UL << 2)
}

///|
/// Grants every permission and bypasses channel permission overwrites.
pub fn Permissions::administrator() -> Permissions {
  Permissions(1UL << 3)
}

///|
/// Allows creating, editing, and deleting channels.
pub fn Permissions::manage_channels() -> Permissions {
  Permissions(1UL << 4)
}

///|
/// Allows editing the guild's settings and adding bots to it.
pub fn Permissions::manage_guild() -> Permissions {
  Permissions(1UL << 5)
}

///|
/// Allows adding new reactions to messages.
pub fn Permissions::add_reactions() -> Permissions {
  Permissions(1UL << 6)
}

///|
/// Allows viewing the guild's audit log.
pub fn Permissions::view_audit_log() -> Permissions {
  Permissions(1UL << 7)
}

///|
/// Allows using priority speaker in a voice channel.
pub fn Permissions::priority_speaker() -> Permissions {
  Permissions(1UL << 8)
}

///|
/// Allows going live (video or screen share) in a voice channel.
pub fn Permissions::stream() -> Permissions {
  Permissions(1UL << 9)
}

///|
/// Allows viewing a channel, including reading its messages.
pub fn Permissions::view_channel() -> Permissions {
  Permissions(1UL << 10)
}

///|
/// Allows sending messages in a channel and creating posts in a forum (but not messages in threads).
pub fn Permissions::send_messages() -> Permissions {
  Permissions(1UL << 11)
}

///|
/// Allows sending text-to-speech messages.
pub fn Permissions::send_tts_messages() -> Permissions {
  Permissions(1UL << 12)
}

///|
/// Allows deleting other members' messages.
pub fn Permissions::manage_messages() -> Permissions {
  Permissions(1UL << 13)
}

///|
/// Allows links in the member's messages to be embedded.
pub fn Permissions::embed_links() -> Permissions {
  Permissions(1UL << 14)
}

///|
/// Allows uploading files and images.
pub fn Permissions::attach_files() -> Permissions {
  Permissions(1UL << 15)
}

///|
/// Allows reading the message history of a channel.
pub fn Permissions::read_message_history() -> Permissions {
  Permissions(1UL << 16)
}

///|
/// Allows mentioning `@everyone`, `@here`, and all roles.
pub fn Permissions::mention_everyone() -> Permissions {
  Permissions(1UL << 17)
}

///|
/// Allows using custom emojis from other guilds.
pub fn Permissions::use_external_emojis() -> Permissions {
  Permissions(1UL << 18)
}

///|
/// Allows viewing the guild's insights.
pub fn Permissions::view_guild_insights() -> Permissions {
  Permissions(1UL << 19)
}

///|
/// Allows joining voice channels.
pub fn Permissions::connect() -> Permissions {
  Permissions(1UL << 20)
}

///|
/// Allows speaking in voice channels.
pub fn Permissions::speak() -> Permissions {
  Permissions(1UL << 21)
}

///|
/// Allows muting other members in voice channels.
pub fn Permissions::mute_members() -> Permissions {
  Permissions(1UL << 22)
}

///|
/// Allows deafening other members in voice channels.
pub fn Permissions::deafen_members() -> Permissions {
  Permissions(1UL << 23)
}

///|
/// Allows moving members between voice channels.
pub fn Permissions::move_members() -> Permissions {
  Permissions(1UL << 24)
}

///|
/// Allows using voice activity detection instead of push-to-talk.
pub fn Permissions::use_vad() -> Permissions {
  Permissions(1UL << 25)
}

///|
/// Allows changing the member's own nickname.
pub fn Permissions::change_nickname() -> Permissions {
  Permissions(1UL << 26)
}

///|
/// Allows changing other members' nicknames.
pub fn Permissions::manage_nicknames() -> Permissions {
  Permissions(1UL << 27)
}

///|
/// Allows creating, editing, and deleting roles below the member's highest role.
pub fn Permissions::manage_roles() -> Permissions {
  Permissions(1UL << 28)
}

///|
/// Allows creating, editing, and deleting webhooks.
pub fn Permissions::manage_webhooks() -> Permissions {
  Permissions(1UL << 29)
}

///|
/// Allows editing and deleting emojis, stickers, and soundboard sounds.
pub fn Permissions::manage_guild_expressions() -> Permissions {
  Permissions(1UL << 30)
}

///|
/// Allows using application commands.
pub fn Permissions::use_application_commands() -> Permissions {
  Permissions(1UL << 31)
}

///|
/// Allows requesting to speak in stage channels.
pub fn Permissions::request_to_speak() -> Permissions {
  Permissions(1UL << 32)
}

///|
/// Allows creating, editing, and deleting scheduled events.
pub fn Permissions::manage_events() -> Permissions {
  Permissions(1UL << 33)
}

///|
/// Allows deleting and archiving threads and viewing all private threads.
pub fn Permissions::manage_threads() -> Permissions {
  Permissions(1UL << 34)
}

///|
/// Allows creating public and announcement threads.
pub fn Permissions::create_public_threads() -> Permissions {
  Permissions(1UL << 35)
}

///|
/// Allows creating private threads.
pub fn Permissions::create_private_threads() -> Permissions {
  Permissions(1UL << 36)
}

///|
/// Allows using custom stickers from other guilds.
pub fn Permissions::use_external_stickers() -> Permissions {
  Permissions(1UL << 37)
}

///|
/// Allows sending messages in threads.
pub fn Permissions::send_messages_in_threads() -> Permissions {
  Permissions(1UL << 38)
}

///|
/// Allows using Activities in a voice channel.
pub fn Permissions::use_embedded_activities() -> Permissions {
  Permissions(1UL << 39)
}

///|
/// Allows timing out members.
pub fn Permissions::moderate_members() -> Permissions {
  Permissions(1UL << 40)
}

///|
/// Allows viewing role subscription insights.
pub fn Permissions::view_creator_monetization_analytics() -> Permissions {
  Permissions(1UL << 41)
}

///|
/// Allows using the soundboard in a voice channel.
pub fn Permissions::use_soundboard() -> Permissions {
  Permissions(1UL << 42)
}

///|
/// Allows creating emojis, stickers, and soundboard sounds.
pub fn Permissions::create_guild_expressions() -> Permissions {
  Permissions(1UL << 43)
}

///|
/// Allows creating scheduled events.
pub fn Permissions::create_events() -> Permissions {
  Permissions(1UL << 44)
}

///|
/// Allows using custom soundboard sounds from other guilds.
pub fn Permissions::use_external_sounds() -> Permissions {
  Permissions(1UL << 45)
}

///|
/// Allows sending voice messages.
pub fn Permissions::send_voice_messages() -> Permissions {
  Permissions(1UL << 46)
}

///|
/// Allows setting the status of a voice channel.
pub fn Permissions::set_voice_channel_status() -> Permissions {
  Permissions(1UL << 48)
}

///|
/// Allows creating polls.
pub fn Permissions::send_polls() -> Permissions {
  Permissions(1UL << 49)
}

///|
/// Allows user-installed apps to send public responses in the channel.
pub fn Permissions::use_external_apps() -> Permissions {
  Permissions(1UL << 50)
}

///|
/// Allows pinning and unpinning messages.
pub fn Permissions::pin_messages() -> Permissions {
  Permissions(1UL << 51)
}

///|
/// Allows sending messages without being limited by channel slowmode.
pub fn Permissions::bypass_slowmode() -> Permissions {
  Permissions(1UL << 52)
}
