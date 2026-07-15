///|
/// One role, user, or channel permission override for an application command.
pub(all) struct ApplicationCommandPermission {
  id : GenericId
  typ : ApplicationCommandPermissionType
  permission : Bool
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// The target kind of an application-command permission override.
pub(all) enum ApplicationCommandPermissionType {
  Role
  User
  Channel
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn ApplicationCommandPermissionType::to_int(
  self : ApplicationCommandPermissionType,
) -> Int {
  match self {
    Role => 1
    User => 2
    Channel => 3
    Unknown(value) => value
  }
}

///|
pub fn ApplicationCommandPermissionType::from_int(
  value : Int,
) -> ApplicationCommandPermissionType {
  match value {
    1 => Role
    2 => User
    3 => Channel
    value => Unknown(value)
  }
}

///|
pub impl ToJson for ApplicationCommandPermissionType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for ApplicationCommandPermissionType with fn from_json(
  json,
  path,
) {
  match json {
    Number(value, ..) =>
      ApplicationCommandPermissionType::from_int(value.to_int())
    _ =>
      raise JsonDecodeError(
        (path, "expected application command permission type (number)"),
      )
  }
}

///|
/// Guild-scoped permission overrides for one application command.
pub(all) struct GuildApplicationCommandPermissions {
  id : CommandId
  application_id : ApplicationId
  guild_id : GuildId
  permissions : Array[ApplicationCommandPermission]
} derive(ToJson, FromJson, Debug)
