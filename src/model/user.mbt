///|
/// A Discord user account returned by the API.
pub(all) struct User {
  id : UserId
  username : String
  discriminator : String
  global_name : Nullable[String]?
  avatar : Nullable[ImageHash]
  bot : Bool?
  system : Bool?
  mfa_enabled : Bool?
  banner : Nullable[ImageHash]?
  accent_color : Nullable[Int]?
  locale : String?
  verified : Bool?
  email : Nullable[String]?
  flags : UserFlags?
  premium_type : PremiumType?
  public_flags : UserFlags?
  avatar_decoration : Nullable[ImageHash]?
  avatar_decoration_data : Nullable[AvatarDecorationData]?
  // TODO(collectibles): Port collectible and nameplate wire types together.
  // TODO(primary_guild): Port the user primary-guild object with its domain.
} derive(ToJson, FromJson, Debug)

///|
/// Bit flags describing badges and account properties assigned to a user.
pub(all) struct UserFlags(UInt64) derive(Eq)

///|
pub fn UserFlags::none() -> UserFlags {
  UserFlags(0)
}

///|
pub fn UserFlags::from_bits(bits : UInt64) -> UserFlags {
  UserFlags(bits)
}

///|
pub fn UserFlags::bits(self : UserFlags) -> UInt64 {
  self.0
}

///|
pub fn UserFlags::contains(self : UserFlags, other : UserFlags) -> Bool {
  (self.0 & other.0) == other.0
}

///|
pub impl BitOr for UserFlags with fn lor(a, b) {
  UserFlags(a.0 | b.0)
}

///|
pub impl BitAnd for UserFlags with fn land(a, b) {
  UserFlags(a.0 & b.0)
}

///|
pub impl Debug for UserFlags with fn to_repr(self) {
  to_repr(self.0)
}

///|
pub impl ToJson for UserFlags with fn to_json(self) {
  Json::number(self.0.to_double(), repr=self.0.to_string())
}

///|
pub impl @json.FromJson for UserFlags with fn from_json(json, path) {
  match json {
    Number(_, repr=Some(r)) =>
      UserFlags(
        @string.parse_uint64(r.to_string()) catch {
          _ =>
            raise @json.JsonDecodeError(
              (path, "expected user flags (number), got \{r}"),
            )
        },
      )
    Number(n, repr=None) => UserFlags(n.to_uint64())
    _ => raise @json.JsonDecodeError((path, "expected user flags (number)"))
  }
}

///|
pub fn UserFlags::staff() -> UserFlags {
  UserFlags(1UL << 0)
}

///|
pub fn UserFlags::partner() -> UserFlags {
  UserFlags(1UL << 1)
}

///|
pub fn UserFlags::hypesquad() -> UserFlags {
  UserFlags(1UL << 2)
}

///|
pub fn UserFlags::bug_hunter_level_1() -> UserFlags {
  UserFlags(1UL << 3)
}

///|
pub fn UserFlags::mfa_sms() -> UserFlags {
  UserFlags(1UL << 4)
}

///|
pub fn UserFlags::premium_promo_dismissed() -> UserFlags {
  UserFlags(1UL << 5)
}

///|
pub fn UserFlags::hype_squad_online_house_1() -> UserFlags {
  UserFlags(1UL << 6)
}

///|
pub fn UserFlags::hype_squad_online_house_2() -> UserFlags {
  UserFlags(1UL << 7)
}

///|
pub fn UserFlags::hype_squad_online_house_3() -> UserFlags {
  UserFlags(1UL << 8)
}

///|
pub fn UserFlags::premium_early_supporter() -> UserFlags {
  UserFlags(1UL << 9)
}

///|
pub fn UserFlags::team_pseudo_user() -> UserFlags {
  UserFlags(1UL << 10)
}

///|
pub fn UserFlags::has_unread_urgent_messages() -> UserFlags {
  UserFlags(1UL << 13)
}

///|
pub fn UserFlags::bug_hunter_level_2() -> UserFlags {
  UserFlags(1UL << 14)
}

///|
pub fn UserFlags::verified_bot() -> UserFlags {
  UserFlags(1UL << 16)
}

///|
pub fn UserFlags::verified_developer() -> UserFlags {
  UserFlags(1UL << 17)
}

///|
pub fn UserFlags::certified_moderator() -> UserFlags {
  UserFlags(1UL << 18)
}

///|
pub fn UserFlags::bot_http_interactions() -> UserFlags {
  UserFlags(1UL << 19)
}

///|
pub fn UserFlags::spammer() -> UserFlags {
  UserFlags(1UL << 20)
}

///|
pub fn UserFlags::disable_premium() -> UserFlags {
  UserFlags(1UL << 21)
}

///|
pub fn UserFlags::active_developer() -> UserFlags {
  UserFlags(1UL << 22)
}

///|
pub fn UserFlags::quarantined() -> UserFlags {
  UserFlags(1UL << 44)
}

///|
pub fn UserFlags::collaborator() -> UserFlags {
  UserFlags(1UL << 50)
}

///|
pub fn UserFlags::restricted_collaborator() -> UserFlags {
  UserFlags(1UL << 51)
}

///|
/// The type of Nitro subscription on a user's account.
pub(all) enum PremiumType {
  None
  NitroClassic
  Nitro
  NitroBasic
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn PremiumType::to_int(self : PremiumType) -> Int {
  match self {
    None => 0
    NitroClassic => 1
    Nitro => 2
    NitroBasic => 3
    Unknown(v) => v
  }
}

///|
pub fn PremiumType::from_int(value : Int) -> PremiumType {
  match value {
    0 => None
    1 => NitroClassic
    2 => Nitro
    3 => NitroBasic
    v => Unknown(v)
  }
}

///|
pub impl ToJson for PremiumType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for PremiumType with fn from_json(json, path) {
  match json {
    Number(n, ..) => PremiumType::from_int(n.to_int())
    _ => raise @json.JsonDecodeError((path, "expected a premium type (number)"))
  }
}

///|
/// Metadata identifying the decoration displayed over a user's avatar.
pub(all) struct AvatarDecorationData {
  asset : ImageHash
  sku_id : SkuId
} derive(ToJson, FromJson, Debug, Eq)
