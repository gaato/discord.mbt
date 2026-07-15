///|
/// A guild integration. All fields are optional because audit logs and user
/// connections carry documented partial forms of this object.
pub(all) struct Integration {
  id : IntegrationId?
  name : String?
  typ : String?
  enabled : Bool?
  syncing : Bool?
  role_id : RoleId?
  enable_emoticons : Bool?
  expire_behavior : IntegrationExpireBehavior?
  expire_grace_period : Int?
  user : User?
  account : IntegrationAccount?
  synced_at : Timestamp?
  subscriber_count : Int?
  revoked : Bool?
  application : IntegrationApplication?
  application_id : ApplicationId?
  scopes : Array[String]?
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// The provider-side account an integration is linked to.
pub(all) struct IntegrationAccount {
  id : String
  name : String
} derive(ToJson, FromJson, Debug)

///|
/// The OAuth2 application backing a Discord-app integration.
pub(all) struct IntegrationApplication {
  id : ApplicationId
  name : String
  icon : Nullable[ImageHash]
  description : String
  bot : User?
} derive(ToJson, FromJson, Debug)

///|
/// What happens to a subscriber when their integration expires.
pub(all) enum IntegrationExpireBehavior {
  RemoveRole
  Kick
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn IntegrationExpireBehavior::to_int(
  self : IntegrationExpireBehavior,
) -> Int {
  match self {
    RemoveRole => 0
    Kick => 1
    Unknown(value) => value
  }
}

///|
pub fn IntegrationExpireBehavior::from_int(
  value : Int,
) -> IntegrationExpireBehavior {
  match value {
    0 => RemoveRole
    1 => Kick
    value => Unknown(value)
  }
}

///|
pub impl ToJson for IntegrationExpireBehavior with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
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
