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
  // TODO(fulfillment): fulfilled_at/fulfillment_status/gifter_user_id appear in
  // the OpenAPI spec but are not documented yet; add once the docs list them.
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// The origin of an application entitlement.
pub(all) enum EntitlementType {
  Purchase
  PremiumSubscription
  DeveloperGift
  TestModePurchase
  FreePurchase
  UserGift
  PremiumPurchase
  ApplicationSubscription
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn EntitlementType::to_int(self : EntitlementType) -> Int {
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
pub fn EntitlementType::from_int(value : Int) -> EntitlementType {
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
pub impl ToJson for EntitlementType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for EntitlementType with fn from_json(json, path) {
  match json {
    Number(value, ..) => EntitlementType::from_int(value.to_int())
    _ =>
      raise @json.JsonDecodeError(
        (path, "expected the origin of an application entitlement (number)"),
      )
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
pub(all) enum SkuType {
  Durable
  Consumable
  Subscription
  SubscriptionGroup
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn SkuType::to_int(self : SkuType) -> Int {
  match self {
    Durable => 2
    Consumable => 3
    Subscription => 5
    SubscriptionGroup => 6
    Unknown(value) => value
  }
}

///|
pub fn SkuType::from_int(value : Int) -> SkuType {
  match value {
    2 => Durable
    3 => Consumable
    5 => Subscription
    6 => SubscriptionGroup
    value => Unknown(value)
  }
}

///|
pub impl ToJson for SkuType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for SkuType with fn from_json(json, path) {
  match json {
    Number(value, ..) => SkuType::from_int(value.to_int())
    _ =>
      raise @json.JsonDecodeError(
        (path, "expected the product category represented by a sku (number)"),
      )
  }
}

///|
/// Bit flags describing availability and subscription scope for a SKU.
pub(all) struct SkuFlags(UInt64) derive(Eq)

///|
pub fn SkuFlags::none() -> SkuFlags {
  SkuFlags(0)
}

///|
pub fn SkuFlags::from_bits(bits : UInt64) -> SkuFlags {
  SkuFlags(bits)
}

///|
pub fn SkuFlags::bits(self : SkuFlags) -> UInt64 {
  self.0
}

///|
pub fn SkuFlags::contains(self : SkuFlags, other : SkuFlags) -> Bool {
  (self.0 & other.0) == other.0
}

///|
pub impl BitOr for SkuFlags with fn lor(a, b) {
  SkuFlags(a.0 | b.0)
}

///|
pub impl BitAnd for SkuFlags with fn land(a, b) {
  SkuFlags(a.0 & b.0)
}

///|
pub impl Debug for SkuFlags with fn to_repr(self) {
  to_repr(self.0)
}

///|
pub impl ToJson for SkuFlags with fn to_json(self) {
  Json::number(self.0.to_double(), repr=self.0.to_string())
}

///|
pub impl @json.FromJson for SkuFlags with fn from_json(json, path) {
  match json {
    Number(_, repr=Some(repr)) =>
      SkuFlags(
        @string.parse_uint64(repr.to_string()) catch {
          _ =>
            raise @json.JsonDecodeError(
              (path, "expected SKU flags (number), got \\{repr}"),
            )
        },
      )
    Number(value, repr=None) => SkuFlags(value.to_uint64())
    _ => raise @json.JsonDecodeError((path, "expected SKU flags (number)"))
  }
}

///|
pub fn SkuFlags::available() -> SkuFlags {
  SkuFlags(1UL << 2)
}

///|
pub fn SkuFlags::guild_subscription() -> SkuFlags {
  SkuFlags(1UL << 7)
}

///|
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
pub(all) enum SubscriptionStatus {
  Active
  Ending
  Inactive
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn SubscriptionStatus::to_int(self : SubscriptionStatus) -> Int {
  match self {
    Active => 0
    Ending => 1
    Inactive => 2
    Unknown(value) => value
  }
}

///|
pub fn SubscriptionStatus::from_int(value : Int) -> SubscriptionStatus {
  match value {
    0 => Active
    1 => Ending
    2 => Inactive
    value => Unknown(value)
  }
}

///|
pub impl ToJson for SubscriptionStatus with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for SubscriptionStatus with fn from_json(json, path) {
  match json {
    Number(value, ..) => SubscriptionStatus::from_int(value.to_int())
    _ =>
      raise @json.JsonDecodeError(
        (path, "expected subscription status (number)"),
      )
  }
}
