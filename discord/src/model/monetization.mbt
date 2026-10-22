///|
/// A grant of access to a Discord application SKU.
pub(all) struct Entitlement {
  id : EntitlementId
  sku_id : SkuId
  application_id : ApplicationId
  user_id : UserId?
  typ : EntitlementType
  deleted : Bool
  starts_at : Nullable[Timestamp]?
  ends_at : Nullable[Timestamp]?
  guild_id : GuildId?
  consumed : Bool?
  // Not modeled: fulfillment fields appear in OpenAPI but not in the public documentation.
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// The origin of an application entitlement.
#non_exhaustive
pub(all) enum EntitlementType {
  Purchase
  PremiumSubscription
  DeveloperGift
  TestModePurchase
  FreePurchase
  UserGift
  PremiumPurchase
  ApplicationSubscription
  Unknown(Int32)
} derive(Eq, Debug)

///|
/// The Discord integer value of this `EntitlementType`.
pub fn EntitlementType::to_int(self : EntitlementType) -> Int32 {
  match self {
    Purchase => 1
    PremiumSubscription => 2
    DeveloperGift => 3
    TestModePurchase => 4
    FreePurchase => 5
    UserGift => 6
    PremiumPurchase => 7
    ApplicationSubscription => 8
    Unknown(value) => value
  }
}

///|
/// The `EntitlementType` for its Discord integer value; unknown values become `Unknown(n)`.
pub fn EntitlementType::from_int(value : Int32) -> EntitlementType {
  match value {
    1 => Purchase
    2 => PremiumSubscription
    3 => DeveloperGift
    4 => TestModePurchase
    5 => FreePurchase
    6 => UserGift
    7 => PremiumPurchase
    8 => ApplicationSubscription
    value => Unknown(value)
  }
}

///|
/// Encodes the `EntitlementType` as its Discord integer value.
pub impl ToJson for EntitlementType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
/// Decodes the `EntitlementType` from a JSON number; unknown values become `Unknown(n)`.
pub impl @json.FromJson for EntitlementType with fn from_json(json, path) {
  match json {
    Number(value, ..) => EntitlementType::from_int(value.to_int())
    _ =>
      raise JsonDecodeError(
        (path, "expected the origin of an application entitlement (number)"),
      )
  }
}

///|
/// The owner scope used when creating a test entitlement.
#non_exhaustive
pub(all) enum EntitlementOwnerType {
  Guild
  User
  Unknown(Int32)
} derive(Eq, Debug)

///|
/// The Discord integer value of this `EntitlementOwnerType`.
pub fn EntitlementOwnerType::to_int(self : EntitlementOwnerType) -> Int32 {
  match self {
    Guild => 1
    User => 2
    Unknown(value) => value
  }
}

///|
/// The `EntitlementOwnerType` for its Discord integer value; unknown values become `Unknown(n)`.
pub fn EntitlementOwnerType::from_int(value : Int32) -> EntitlementOwnerType {
  match value {
    1 => Guild
    2 => User
    value => Unknown(value)
  }
}

///|
/// Encodes the `EntitlementOwnerType` as its Discord integer value.
pub impl ToJson for EntitlementOwnerType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
/// Decodes the `EntitlementOwnerType` from a JSON number; unknown values become `Unknown(n)`.
pub impl @json.FromJson for EntitlementOwnerType with fn from_json(json, path) {
  match json {
    Number(value, ..) => EntitlementOwnerType::from_int(value.to_int())
    _ =>
      raise JsonDecodeError((path, "expected entitlement owner type (number)"))
  }
}

///|
/// A purchasable Discord application product.
pub(all) struct Sku {
  id : SkuId
  typ : SkuType
  application_id : ApplicationId
  name : String
  slug : String
  flags : SkuFlags
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// The product category represented by a SKU.
#non_exhaustive
pub(all) enum SkuType {
  Durable
  Consumable
  Subscription
  SubscriptionGroup
  Unknown(Int32)
} derive(Eq, Debug)

///|
/// The Discord integer value of this `SkuType`.
pub fn SkuType::to_int(self : SkuType) -> Int32 {
  match self {
    Durable => 2
    Consumable => 3
    Subscription => 5
    SubscriptionGroup => 6
    Unknown(value) => value
  }
}

///|
/// The `SkuType` for its Discord integer value; unknown values become `Unknown(n)`.
pub fn SkuType::from_int(value : Int32) -> SkuType {
  match value {
    2 => Durable
    3 => Consumable
    5 => Subscription
    6 => SubscriptionGroup
    value => Unknown(value)
  }
}

///|
/// Encodes the `SkuType` as its Discord integer value.
pub impl ToJson for SkuType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
/// Decodes the `SkuType` from a JSON number; unknown values become `Unknown(n)`.
pub impl @json.FromJson for SkuType with fn from_json(json, path) {
  match json {
    Number(value, ..) => SkuType::from_int(value.to_int())
    _ =>
      raise JsonDecodeError(
        (path, "expected the product category represented by a sku (number)"),
      )
  }
}

///|
/// Bit flags describing availability and subscription scope for a SKU.
pub(all) struct SkuFlags(UInt64) derive(Eq)

///|
/// No flags set.
pub fn SkuFlags::none() -> SkuFlags {
  SkuFlags(0)
}

///|
/// Flags from a raw bit field; unknown bits are kept.
pub fn SkuFlags::from_bits(bits : UInt64) -> SkuFlags {
  SkuFlags(bits)
}

///|
/// The raw bit field.
pub fn SkuFlags::bits(self : SkuFlags) -> UInt64 {
  self.0
}

///|
/// Whether every flag in `other` is set.
pub fn SkuFlags::contains(self : SkuFlags, other : SkuFlags) -> Bool {
  (self.0 & other.0) == other.0
}

///|
/// Combines flags: every flag set in either operand is set.
pub impl BitOr for SkuFlags with fn lor(a, b) {
  SkuFlags(a.0 | b.0)
}

///|
/// Keeps the flags set in both operands.
pub impl BitAnd for SkuFlags with fn land(a, b) {
  SkuFlags(a.0 & b.0)
}

///|
/// Debug output is the raw bit field.
pub impl Debug for SkuFlags with fn to_repr(self) {
  Repr(self.0)
}

///|
/// Encodes the flags as a JSON number.
pub impl ToJson for SkuFlags with fn to_json(self) {
  Json::number(self.0.to_double(), repr=self.0.to_string())
}

///|
/// Decodes the flags from a JSON number; unknown bits are kept.
pub impl @json.FromJson for SkuFlags with fn from_json(json, path) {
  match json {
    Number(_, repr=Some(repr)) =>
      SkuFlags(
        @string.parse_uint64(repr.to_string()) catch {
          _ =>
            raise JsonDecodeError(
              (path, "expected SKU flags (number), got \\{repr}"),
            )
        },
      )
    Number(value, repr=None) => SkuFlags(value.to_uint64())
    _ => raise JsonDecodeError((path, "expected SKU flags (number)"))
  }
}

///|
/// The SKU is available for purchase.
pub fn SkuFlags::available() -> SkuFlags {
  SkuFlags(1UL << 2)
}

///|
/// The SKU is a recurring subscription purchased by a guild.
pub fn SkuFlags::guild_subscription() -> SkuFlags {
  SkuFlags(1UL << 7)
}

///|
/// The SKU is a recurring subscription purchased by a user.
pub fn SkuFlags::user_subscription() -> SkuFlags {
  SkuFlags(1UL << 8)
}

///|
/// A user's recurring subscription to one or more application SKUs.
pub(all) struct Subscription {
  id : GenericId
  user_id : UserId
  sku_ids : Array[SkuId]
  entitlement_ids : Array[EntitlementId]
  renewal_sku_ids : Nullable[Array[SkuId]]
  current_period_start : Timestamp
  current_period_end : Timestamp
  status : SubscriptionStatus
  canceled_at : Nullable[Timestamp]
  country : String?
} derive(ToJson, FromJson, Debug)

///|
/// The renewal state of a Discord application subscription.
#non_exhaustive
pub(all) enum SubscriptionStatus {
  Active
  Ending
  Inactive
  Unknown(Int32)
} derive(Eq, Debug)

///|
/// The Discord integer value of this `SubscriptionStatus`.
pub fn SubscriptionStatus::to_int(self : SubscriptionStatus) -> Int32 {
  match self {
    Active => 0
    Inactive => 1
    Ending => 2
    Unknown(value) => value
  }
}

///|
/// The `SubscriptionStatus` for its Discord integer value; unknown values become `Unknown(n)`.
pub fn SubscriptionStatus::from_int(value : Int32) -> SubscriptionStatus {
  match value {
    0 => Active
    1 => Inactive
    2 => Ending
    value => Unknown(value)
  }
}

///|
/// Encodes the `SubscriptionStatus` as its Discord integer value.
pub impl ToJson for SubscriptionStatus with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
/// Decodes the `SubscriptionStatus` from a JSON number; unknown values become `Unknown(n)`.
pub impl @json.FromJson for SubscriptionStatus with fn from_json(json, path) {
  match json {
    Number(value, ..) => SubscriptionStatus::from_int(value.to_int())
    _ => raise JsonDecodeError((path, "expected subscription status (number)"))
  }
}
