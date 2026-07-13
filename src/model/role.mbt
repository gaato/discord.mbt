///|
/// A Discord guild role and its permissions.
pub(all) struct Role {
  id : RoleId
  name : String
  color : Int
  // TODO(role_colors): Port APIRoleColors when it joins the requested surface.
  hoist : Bool
  icon : Nullable[ImageHash]?
  unicode_emoji : Nullable[String]?
  position : Int
  permissions : Permissions
  managed : Bool
  mentionable : Bool
  tags : RoleTags?
  flags : RoleFlags
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
pub impl ToJson for RoleTags with fn to_json(self) {
  let fields : Map[String, Json] = {}
  if self.bot_id is Some(value) {
    fields["bot_id"] = value.to_json()
  }
  if self.premium_subscriber {
    fields["premium_subscriber"] = Json::null()
  }
  if self.integration_id is Some(value) {
    fields["integration_id"] = value.to_json()
  }
  if self.subscription_listing_id is Some(value) {
    fields["subscription_listing_id"] = value.to_json()
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
pub impl @json.FromJson for RoleTags with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "expected role tags (object)"))
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
pub fn RoleFlags::none() -> RoleFlags {
  RoleFlags(0)
}

///|
pub fn RoleFlags::from_bits(bits : UInt64) -> RoleFlags {
  RoleFlags(bits)
}

///|
pub fn RoleFlags::bits(self : RoleFlags) -> UInt64 {
  self.0
}

///|
pub fn RoleFlags::contains(self : RoleFlags, other : RoleFlags) -> Bool {
  (self.0 & other.0) == other.0
}

///|
pub impl BitOr for RoleFlags with fn lor(a, b) {
  RoleFlags(a.0 | b.0)
}

///|
pub impl BitAnd for RoleFlags with fn land(a, b) {
  RoleFlags(a.0 & b.0)
}

///|
pub impl Debug for RoleFlags with fn to_repr(self) {
  to_repr(self.0)
}

///|
pub impl ToJson for RoleFlags with fn to_json(self) {
  Json::number(self.0.to_double(), repr=self.0.to_string())
}

///|
pub impl @json.FromJson for RoleFlags with fn from_json(json, path) {
  match json {
    Number(_, repr=Some(r)) =>
      RoleFlags(
        @string.parse_uint64(r.to_string()) catch {
          _ =>
            raise @json.JsonDecodeError(
              (path, "expected role flags (number), got \{r}"),
            )
        },
      )
    Number(n, repr=None) => RoleFlags(n.to_uint64())
    _ => raise @json.JsonDecodeError((path, "expected role flags (number)"))
  }
}

///|
pub fn RoleFlags::in_prompt() -> RoleFlags {
  RoleFlags(1UL << 0)
}
