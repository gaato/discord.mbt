///|
/// A user's membership state and profile within a guild.
pub(all) struct GuildMember {
  user : User?
  nick : Nullable[String]?
  avatar : Nullable[ImageHash]?
  banner : Nullable[ImageHash]?
  roles : Array[RoleId]
  joined_at : Nullable[Timestamp]
  premium_since : Nullable[Timestamp]?
  // Absent on the partial members in interaction resolved data.
  deaf : Bool?
  mute : Bool?
  flags : GuildMemberFlags?
  pending : Bool?
  permissions : Permissions?
  communication_disabled_until : Nullable[Timestamp]?
  avatar_decoration_data : Nullable[AvatarDecorationData]?
  collectibles : Nullable[Collectibles]?
} derive(ToJson, FromJson, Debug)

///|
/// Bit flags describing onboarding, verification, and moderation member state.
pub(all) struct GuildMemberFlags(UInt64) derive(Eq)

///|
/// No flags set.
pub fn GuildMemberFlags::none() -> GuildMemberFlags {
  GuildMemberFlags(0)
}

///|
/// Flags from a raw bit field; unknown bits are kept.
pub fn GuildMemberFlags::from_bits(bits : UInt64) -> GuildMemberFlags {
  GuildMemberFlags(bits)
}

///|
/// The raw bit field.
pub fn GuildMemberFlags::bits(self : GuildMemberFlags) -> UInt64 {
  self.0
}

///|
/// Whether every flag in `other` is set.
pub fn GuildMemberFlags::contains(
  self : GuildMemberFlags,
  other : GuildMemberFlags,
) -> Bool {
  (self.0 & other.0) == other.0
}

///|
/// Combines flags: every flag set in either operand is set.
pub impl BitOr for GuildMemberFlags with fn lor(a, b) {
  GuildMemberFlags(a.0 | b.0)
}

///|
/// Keeps the flags set in both operands.
pub impl BitAnd for GuildMemberFlags with fn land(a, b) {
  GuildMemberFlags(a.0 & b.0)
}

///|
/// Debug output is the raw bit field.
pub impl Debug for GuildMemberFlags with fn to_repr(self) {
  Repr(self.0)
}

///|
/// Encodes the flags as a JSON number.
pub impl ToJson for GuildMemberFlags with fn to_json(self) {
  Json::number(self.0.to_double(), repr=self.0.to_string())
}

///|
/// Decodes the flags from a JSON number; unknown bits are kept.
pub impl @json.FromJson for GuildMemberFlags with fn from_json(json, path) {
  match json {
    Number(_, repr=Some(repr)) =>
      GuildMemberFlags(
        @string.parse_uint64(repr.to_string()) catch {
          _ =>
            raise JsonDecodeError(
              (path, "expected guild member flags (number), got \{repr}"),
            )
        },
      )
    Number(value, repr=None) => GuildMemberFlags(value.to_uint64())
    _ => raise JsonDecodeError((path, "expected guild member flags (number)"))
  }
}

///|
/// The member has left and rejoined the guild.
pub fn GuildMemberFlags::did_rejoin() -> GuildMemberFlags {
  GuildMemberFlags(1UL << 0)
}

///|
/// The member has completed onboarding.
pub fn GuildMemberFlags::completed_onboarding() -> GuildMemberFlags {
  GuildMemberFlags(1UL << 1)
}

///|
/// The member is exempt from guild verification requirements.
pub fn GuildMemberFlags::bypasses_verification() -> GuildMemberFlags {
  GuildMemberFlags(1UL << 2)
}

///|
/// The member has started onboarding.
pub fn GuildMemberFlags::started_onboarding() -> GuildMemberFlags {
  GuildMemberFlags(1UL << 3)
}

///|
/// The member is a guest and can only access the voice channel they were invited to.
pub fn GuildMemberFlags::is_guest() -> GuildMemberFlags {
  GuildMemberFlags(1UL << 4)
}

///|
/// The member has started the Server Guide actions.
pub fn GuildMemberFlags::started_home_actions() -> GuildMemberFlags {
  GuildMemberFlags(1UL << 5)
}

///|
/// The member has completed the Server Guide actions.
pub fn GuildMemberFlags::completed_home_actions() -> GuildMemberFlags {
  GuildMemberFlags(1UL << 6)
}

///|
/// The member's username or nickname was blocked by AutoMod.
pub fn GuildMemberFlags::automod_quarantined_username_or_guild_nickname() -> GuildMemberFlags {
  GuildMemberFlags(1UL << 7)
}

///|
/// Deprecated: the member's bio was blocked by AutoMod.
pub fn GuildMemberFlags::automod_quarantined_bio() -> GuildMemberFlags {
  GuildMemberFlags(1UL << 8)
}

///|
/// The member has dismissed the DM settings upsell.
pub fn GuildMemberFlags::dm_settings_upsell_acknowledged() -> GuildMemberFlags {
  GuildMemberFlags(1UL << 9)
}

///|
/// The member's guild tag was blocked by AutoMod.
pub fn GuildMemberFlags::auto_mod_quarantined_guild_tag() -> GuildMemberFlags {
  GuildMemberFlags(1UL << 10)
}
