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
  // TODO(collectibles): Reuse collectible types when that domain is ported.
} derive(ToJson, FromJson, Debug)

///|
/// Bit flags describing onboarding, verification, and moderation member state.
pub(all) struct GuildMemberFlags(UInt64) derive(Eq)

///|
pub fn GuildMemberFlags::none() -> GuildMemberFlags {
  GuildMemberFlags(0)
}

///|
pub fn GuildMemberFlags::from_bits(bits : UInt64) -> GuildMemberFlags {
  GuildMemberFlags(bits)
}

///|
pub fn GuildMemberFlags::bits(self : GuildMemberFlags) -> UInt64 {
  self.0
}

///|
pub fn GuildMemberFlags::contains(
  self : GuildMemberFlags,
  other : GuildMemberFlags,
) -> Bool {
  (self.0 & other.0) == other.0
}

///|
pub impl BitOr for GuildMemberFlags with fn lor(a, b) {
  GuildMemberFlags(a.0 | b.0)
}

///|
pub impl BitAnd for GuildMemberFlags with fn land(a, b) {
  GuildMemberFlags(a.0 & b.0)
}

///|
pub impl Debug for GuildMemberFlags with fn to_repr(self) {
  to_repr(self.0)
}

///|
pub impl ToJson for GuildMemberFlags with fn to_json(self) {
  Json::number(self.0.to_double(), repr=self.0.to_string())
}

///|
pub impl @json.FromJson for GuildMemberFlags with fn from_json(json, path) {
  match json {
    Number(_, repr=Some(repr)) =>
      GuildMemberFlags(
        @string.parse_uint64(repr.to_string()) catch {
          _ =>
            raise @json.JsonDecodeError(
              (path, "expected guild member flags (number), got \{repr}"),
            )
        },
      )
    Number(value, repr=None) => GuildMemberFlags(value.to_uint64())
    _ =>
      raise @json.JsonDecodeError(
        (path, "expected guild member flags (number)"),
      )
  }
}

///|
pub fn GuildMemberFlags::did_rejoin() -> GuildMemberFlags {
  GuildMemberFlags(1UL << 0)
}

///|
pub fn GuildMemberFlags::completed_onboarding() -> GuildMemberFlags {
  GuildMemberFlags(1UL << 1)
}

///|
pub fn GuildMemberFlags::bypasses_verification() -> GuildMemberFlags {
  GuildMemberFlags(1UL << 2)
}

///|
pub fn GuildMemberFlags::started_onboarding() -> GuildMemberFlags {
  GuildMemberFlags(1UL << 3)
}

///|
pub fn GuildMemberFlags::is_guest() -> GuildMemberFlags {
  GuildMemberFlags(1UL << 4)
}

///|
pub fn GuildMemberFlags::started_home_actions() -> GuildMemberFlags {
  GuildMemberFlags(1UL << 5)
}

///|
pub fn GuildMemberFlags::completed_home_actions() -> GuildMemberFlags {
  GuildMemberFlags(1UL << 6)
}

///|
pub fn GuildMemberFlags::automod_quarantined_username_or_guild_nickname() -> GuildMemberFlags {
  GuildMemberFlags(1UL << 7)
}

///|
pub fn GuildMemberFlags::automod_quarantined_bio() -> GuildMemberFlags {
  GuildMemberFlags(1UL << 8)
}

///|
pub fn GuildMemberFlags::dm_settings_upsell_acknowledged() -> GuildMemberFlags {
  GuildMemberFlags(1UL << 9)
}

///|
pub fn GuildMemberFlags::auto_mod_quarantined_guild_tag() -> GuildMemberFlags {
  GuildMemberFlags(1UL << 10)
}
