///|
/// Where an application command is installed.
pub(all) enum ApplicationIntegrationType {
  GuildInstall
  UserInstall
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn ApplicationIntegrationType::to_int(
  self : ApplicationIntegrationType,
) -> Int {
  match self {
    GuildInstall => 0
    UserInstall => 1
    Unknown(value) => value
  }
}

///|
pub fn ApplicationIntegrationType::from_int(
  value : Int,
) -> ApplicationIntegrationType {
  match value {
    0 => GuildInstall
    1 => UserInstall
    value => Unknown(value)
  }
}

///|
pub impl ToJson for ApplicationIntegrationType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for ApplicationIntegrationType with fn from_json(
  json,
  path,
) {
  match json {
    Number(value, ..) => ApplicationIntegrationType::from_int(value.to_int())
    _ =>
      raise @json.JsonDecodeError(
        (path, "expected an application integration type (number)"),
      )
  }
}

///|
/// Where an interaction was triggered.
pub(all) enum InteractionContextType {
  Guild
  BotDm
  PrivateChannel
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn InteractionContextType::to_int(self : InteractionContextType) -> Int {
  match self {
    Guild => 0
    BotDm => 1
    PrivateChannel => 2
    Unknown(value) => value
  }
}

///|
pub fn InteractionContextType::from_int(value : Int) -> InteractionContextType {
  match value {
    0 => Guild
    1 => BotDm
    2 => PrivateChannel
    value => Unknown(value)
  }
}

///|
pub impl ToJson for InteractionContextType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for InteractionContextType with fn from_json(json, path) {
  match json {
    Number(value, ..) => InteractionContextType::from_int(value.to_int())
    _ =>
      raise @json.JsonDecodeError(
        (path, "expected an interaction context type (number)"),
      )
  }
}
