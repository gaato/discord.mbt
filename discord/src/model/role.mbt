///|
/// A Discord guild role and its permissions.
pub(all) struct Role {
  id : RoleId
  name : String
  color : Int32
  colors : RoleColors?
  hoist : Bool
  icon : Nullable[ImageHash]?
  unicode_emoji : Nullable[String]?
  position : Int32
  permissions : Permissions
  managed : Bool
  mentionable : Bool
  tags : RoleTags?
  flags : RoleFlags?
} derive(ToJson, FromJson, Debug)

///|
/// Primary and optional enhanced gradient colors of a role.
pub(all) struct RoleColors {
  primary_color : Int32
  secondary_color : Nullable[Int32]
  tertiary_color : Nullable[Int32]
} derive(ToJson, FromJson, Debug)

///|
/// Role ownership tags, including null-valued markers whose presence means true.
///
/// Discord represents `premium_subscriber`, `available_for_purchase`, and
/// `guild_connections` as optional fields whose only wire value is `null`.
/// Their Boolean values record whether each field was present.
pub(all) struct RoleTags {
  bot_id : UserId?
  premium_subscriber : Bool
  integration_id : IntegrationId?
  subscription_listing_id : SkuId?
  available_for_purchase : Bool
  guild_connections : Bool
} derive(Eq, Debug)

///|
/// Encodes the role tags as its Discord JSON representation.
pub impl ToJson for RoleTags with fn to_json(self) {
  let fields : Map[String, Json] = Map([])
  if self.bot_id is Some(value) {
    fields["bot_id"] = ToJson::to_json(value)
  }
  if self.premium_subscriber {
    fields["premium_subscriber"] = Json::null()
  }
  if self.integration_id is Some(value) {
    fields["integration_id"] = ToJson::to_json(value)
  }
  if self.subscription_listing_id is Some(value) {
    fields["subscription_listing_id"] = ToJson::to_json(value)
  }
  if self.available_for_purchase {
    fields["available_for_purchase"] = Json::null()
  }
  if self.guild_connections {
    fields["guild_connections"] = Json::null()
  }
  Json::object(fields)
}

///|
/// Decodes the role tags from its Discord JSON representation.
pub impl @json.FromJson for RoleTags with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise JsonDecodeError((path, "expected role tags (object)"))
  }
  let bot_id : UserId? = match fields.get("bot_id") {
    None => None
    Some(value) => Some(@json.from_json(value, path=path.add_key("bot_id")))
  }
  let premium_subscriber = match fields.get("premium_subscriber") {
    None => false
    // presence means true; be lenient about the value shape
    Some(_) => true
  }
  let integration_id : IntegrationId? = match fields.get("integration_id") {
    None => None
    Some(value) =>
      Some(@json.from_json(value, path=path.add_key("integration_id")))
  }
  let subscription_listing_id : SkuId? = match
    fields.get("subscription_listing_id") {
    None => None
    Some(value) =>
      Some(@json.from_json(value, path=path.add_key("subscription_listing_id")))
  }
  let available_for_purchase = match fields.get("available_for_purchase") {
    None => false
    // presence means true; be lenient about the value shape
    Some(_) => true
  }
  let guild_connections = match fields.get("guild_connections") {
    None => false
    // presence means true; be lenient about the value shape
    Some(_) => true
  }
  {
    bot_id,
    premium_subscriber,
    integration_id,
    subscription_listing_id,
    available_for_purchase,
    guild_connections,
  }
}

///|
/// Bit flags describing special behavior assigned to a role.
pub(all) struct RoleFlags(UInt64) derive(Eq)

///|
/// No flags set.
pub fn RoleFlags::none() -> RoleFlags {
  RoleFlags(0)
}

///|
/// Flags from a raw bit field; unknown bits are kept.
pub fn RoleFlags::from_bits(bits : UInt64) -> RoleFlags {
  RoleFlags(bits)
}

///|
/// The raw bit field.
pub fn RoleFlags::bits(self : RoleFlags) -> UInt64 {
  self.0
}

///|
/// Whether every flag in `other` is set.
pub fn RoleFlags::contains(self : RoleFlags, other : RoleFlags) -> Bool {
  (self.0 & other.0) == other.0
}

///|
/// Combines flags: every flag set in either operand is set.
pub impl BitOr for RoleFlags with fn lor(a, b) {
  RoleFlags(a.0 | b.0)
}

///|
/// Keeps the flags set in both operands.
pub impl BitAnd for RoleFlags with fn land(a, b) {
  RoleFlags(a.0 & b.0)
}

///|
/// Debug output is the raw bit field.
pub impl Debug for RoleFlags with fn to_repr(self) {
  Repr(self.0)
}

///|
/// Encodes the flags as a JSON number.
pub impl ToJson for RoleFlags with fn to_json(self) {
  Json::number(self.0.to_double(), repr=self.0.to_string())
}

///|
/// Decodes the flags from a JSON number; unknown bits are kept.
pub impl @json.FromJson for RoleFlags with fn from_json(json, path) {
  match json {
    Number(_, repr=Some(r)) =>
      RoleFlags(
        @string.parse_uint64(r.to_string()) catch {
          _ =>
            raise JsonDecodeError(
              (path, "expected role flags (number), got \{r}"),
            )
        },
      )
    Number(n, repr=None) => RoleFlags(n.to_uint64())
    _ => raise JsonDecodeError((path, "expected role flags (number)"))
  }
}

///|
/// The role can be selected by members in an onboarding prompt.
pub fn RoleFlags::in_prompt() -> RoleFlags {
  RoleFlags(1UL << 0)
}
