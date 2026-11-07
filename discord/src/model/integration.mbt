///|
/// A guild integration. All fields are optional because audit logs and user
/// connections carry documented partial forms of this object.
#derive(ToJson(fields(typ(rename="type"))), FromJson(fields(typ(rename="type"))), Debug)
pub(all) struct Integration {
  id : IntegrationId?
  name : String?
  typ : String?
  enabled : Bool?
  syncing : Bool?
  role_id : RoleId?
  enable_emoticons : Bool?
  expire_behavior : IntegrationExpireBehavior?
  expire_grace_period : Int32?
  user : User?
  account : IntegrationAccount?
  synced_at : Timestamp?
  subscriber_count : Int32?
  revoked : Bool?
  application : IntegrationApplication?
  application_id : ApplicationId?
  scopes : Array[String]?
}

///|
/// The provider-side account an integration is linked to.
#derive(ToJson, FromJson, Debug)
pub(all) struct IntegrationAccount {
  id : String
  name : String
}

///|
/// The OAuth2 application backing a Discord-app integration.
#derive(ToJson, FromJson, Debug)
pub(all) struct IntegrationApplication {
  id : ApplicationId
  name : String
  icon : Nullable[ImageHash]
  description : String
  bot : User?
}

///|
/// What happens to a subscriber when their integration expires.
#derive(Eq, Debug)
#non_exhaustive
pub(all) enum IntegrationExpireBehavior {
  RemoveRole
  Kick
  Unknown(Int32)
}

///|
/// The Discord integer value of this `IntegrationExpireBehavior`.
pub fn IntegrationExpireBehavior::to_int(
  self : IntegrationExpireBehavior,
) -> Int32 {
  match self {
    RemoveRole => 0
    Kick => 1
    Unknown(value) => value
  }
}

///|
/// The `IntegrationExpireBehavior` for its Discord integer value; unknown values become `Unknown(n)`.
pub fn IntegrationExpireBehavior::from_int(
  value : Int32,
) -> IntegrationExpireBehavior {
  match value {
    0 => RemoveRole
    1 => Kick
    value => Unknown(value)
  }
}

///|
/// Encodes the `IntegrationExpireBehavior` as its Discord integer value.
pub impl ToJson for IntegrationExpireBehavior with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
/// Decodes the `IntegrationExpireBehavior` from a JSON number; unknown values become `Unknown(n)`.
pub impl @json.FromJson for IntegrationExpireBehavior with fn from_json(
  json,
  path,
) {
  match json {
    Number(value, ..) => IntegrationExpireBehavior::from_int(value.to_int())
    _ =>
      raise JsonDecodeError(
        (path, "expected integration expire behavior (number)"),
      )
  }
}
