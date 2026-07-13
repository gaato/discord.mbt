///|
/// A minimal Discord application record used by interaction payloads.
pub(all) struct Application {
  id : ApplicationId
  name : String
  icon : Nullable[ImageHash]
  description : String
  bot : User?
  owner : User?
  flags : ApplicationFlags?
  approximate_guild_count : Int?
  approximate_user_install_count : Int?
  // TODO(application-full): Port RPC, verification, team, installation, and remaining application metadata.
} derive(ToJson, FromJson, Debug)

///|
/// Bit flags describing capabilities and privileged access for an application.
pub(all) struct ApplicationFlags(UInt64) derive(Eq)

///|
pub fn ApplicationFlags::none() -> ApplicationFlags {
  ApplicationFlags(0)
}

///|
pub fn ApplicationFlags::from_bits(bits : UInt64) -> ApplicationFlags {
  ApplicationFlags(bits)
}

///|
pub fn ApplicationFlags::bits(self : ApplicationFlags) -> UInt64 {
  self.0
}

///|
pub fn ApplicationFlags::contains(
  self : ApplicationFlags,
  other : ApplicationFlags,
) -> Bool {
  (self.0 & other.0) == other.0
}

///|
pub impl BitOr for ApplicationFlags with fn lor(a, b) {
  ApplicationFlags(a.0 | b.0)
}

///|
pub impl BitAnd for ApplicationFlags with fn land(a, b) {
  ApplicationFlags(a.0 & b.0)
}

///|
pub impl Debug for ApplicationFlags with fn to_repr(self) {
  to_repr(self.0)
}

///|
pub impl ToJson for ApplicationFlags with fn to_json(self) {
  Json::number(self.0.to_double(), repr=self.0.to_string())
}

///|
pub impl @json.FromJson for ApplicationFlags with fn from_json(json, path) {
  match json {
    Number(_, repr=Some(repr)) =>
      ApplicationFlags(
        @string.parse_uint64(repr.to_string()) catch {
          _ =>
            raise @json.JsonDecodeError(
              (path, "expected application flags (number), got \\{repr}"),
            )
        },
      )
    Number(value, repr=None) => ApplicationFlags(value.to_uint64())
    _ =>
      raise @json.JsonDecodeError((path, "expected application flags (number)"))
  }
}

///|
pub fn ApplicationFlags::embedded_released() -> ApplicationFlags {
  ApplicationFlags(1UL << 1)
}

///|
pub fn ApplicationFlags::managed_emoji() -> ApplicationFlags {
  ApplicationFlags(1UL << 2)
}

///|
pub fn ApplicationFlags::embedded_iap() -> ApplicationFlags {
  ApplicationFlags(1UL << 3)
}

///|
pub fn ApplicationFlags::group_dm_create() -> ApplicationFlags {
  ApplicationFlags(1UL << 4)
}

///|
pub fn ApplicationFlags::application_auto_moderation_rule_create_badge() -> ApplicationFlags {
  ApplicationFlags(1UL << 6)
}

///|
pub fn ApplicationFlags::rpc_has_connected() -> ApplicationFlags {
  ApplicationFlags(1UL << 11)
}

///|
pub fn ApplicationFlags::gateway_presence() -> ApplicationFlags {
  ApplicationFlags(1UL << 12)
}

///|
pub fn ApplicationFlags::gateway_presence_limited() -> ApplicationFlags {
  ApplicationFlags(1UL << 13)
}

///|
pub fn ApplicationFlags::gateway_guild_members() -> ApplicationFlags {
  ApplicationFlags(1UL << 14)
}

///|
pub fn ApplicationFlags::gateway_guild_members_limited() -> ApplicationFlags {
  ApplicationFlags(1UL << 15)
}

///|
pub fn ApplicationFlags::verification_pending_guild_limit() -> ApplicationFlags {
  ApplicationFlags(1UL << 16)
}

///|
pub fn ApplicationFlags::embedded() -> ApplicationFlags {
  ApplicationFlags(1UL << 17)
}

///|
pub fn ApplicationFlags::gateway_message_content() -> ApplicationFlags {
  ApplicationFlags(1UL << 18)
}

///|
pub fn ApplicationFlags::gateway_message_content_limited() -> ApplicationFlags {
  ApplicationFlags(1UL << 19)
}

///|
pub fn ApplicationFlags::embedded_first_party() -> ApplicationFlags {
  ApplicationFlags(1UL << 20)
}

///|
pub fn ApplicationFlags::application_command_badge() -> ApplicationFlags {
  ApplicationFlags(1UL << 23)
}
