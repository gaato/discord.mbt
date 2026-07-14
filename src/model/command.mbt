///|
/// A registered Discord application command.
pub(all) struct ApplicationCommand {
  id : CommandId
  typ : ApplicationCommandType?
  application_id : ApplicationId
  guild_id : GuildId?
  name : String
  name_localizations : Nullable[Map[String, String]]?
  description : String
  description_localizations : Nullable[Map[String, String]]?
  options : Array[CommandOption]?
  default_member_permissions : Nullable[Permissions]
  dm_permission : Bool?
  nsfw : Bool?
  integration_types : Array[ApplicationIntegrationType]?
  contexts : Nullable[Array[InteractionContextType]]?
  version : CommandVersionId
  handler : EntryPointCommandHandlerType?
  name_localized : String?
  description_localized : String?
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// The handler used for a primary entry-point command.
pub(all) enum EntryPointCommandHandlerType {
  AppHandler
  DiscordLaunchActivity
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn EntryPointCommandHandlerType::to_int(
  self : EntryPointCommandHandlerType,
) -> Int {
  match self {
    AppHandler => 1
    DiscordLaunchActivity => 2
    Unknown(value) => value
  }
}

///|
pub fn EntryPointCommandHandlerType::from_int(
  value : Int,
) -> EntryPointCommandHandlerType {
  match value {
    1 => AppHandler
    2 => DiscordLaunchActivity
    value => Unknown(value)
  }
}

///|
pub impl ToJson for EntryPointCommandHandlerType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for EntryPointCommandHandlerType with fn from_json(
  json,
  path,
) {
  match json {
    Number(value, ..) => EntryPointCommandHandlerType::from_int(value.to_int())
    _ =>
      raise @json.JsonDecodeError(
        (path, "expected entry-point command handler type (number)"),
      )
  }
}

///|
/// The invocation category of an application command.
pub(all) enum ApplicationCommandType {
  ChatInput
  User
  Message
  PrimaryEntryPoint
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn ApplicationCommandType::to_int(self : ApplicationCommandType) -> Int {
  match self {
    ChatInput => 1
    User => 2
    Message => 3
    PrimaryEntryPoint => 4
    Unknown(value) => value
  }
}

///|
pub fn ApplicationCommandType::from_int(value : Int) -> ApplicationCommandType {
  match value {
    1 => ChatInput
    2 => User
    3 => Message
    4 => PrimaryEntryPoint
    value => Unknown(value)
  }
}

///|
pub impl ToJson for ApplicationCommandType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for ApplicationCommandType with fn from_json(json, path) {
  match json {
    Number(value, ..) => ApplicationCommandType::from_int(value.to_int())
    _ =>
      raise @json.JsonDecodeError(
        (
          path, "expected the invocation category of an application command (number)",
        ),
      )
  }
}

///|
/// A flat command option supporting every current slash-command option shape.
pub(all) struct CommandOption {
  typ : CommandOptionType
  name : String
  name_localizations : Nullable[Map[String, String]]?
  description : String
  description_localizations : Nullable[Map[String, String]]?
  required : Bool?
  choices : Array[CommandOptionChoice]?
  options : Array[CommandOption]?
  channel_types : Array[ChannelType]?
  /// A numeric lower bound kept in its original integer or floating-point JSON form.
  min_value : Json?
  /// A numeric upper bound kept in its original integer or floating-point JSON form.
  max_value : Json?
  min_length : Int?
  max_length : Int?
  autocomplete : Bool?
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// The value category accepted by a command option.
pub(all) enum CommandOptionType {
  SubCommand
  SubCommandGroup
  String
  Integer
  Boolean
  User
  Channel
  Role
  Mentionable
  Number
  Attachment
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn CommandOptionType::to_int(self : CommandOptionType) -> Int {
  match self {
    SubCommand => 1
    SubCommandGroup => 2
    String => 3
    Integer => 4
    Boolean => 5
    User => 6
    Channel => 7
    Role => 8
    Mentionable => 9
    Number => 10
    Attachment => 11
    Unknown(value) => value
  }
}

///|
pub fn CommandOptionType::from_int(value : Int) -> CommandOptionType {
  match value {
    1 => SubCommand
    2 => SubCommandGroup
    3 => String
    4 => Integer
    5 => Boolean
    6 => User
    7 => Channel
    8 => Role
    9 => Mentionable
    10 => Number
    11 => Attachment
    value => Unknown(value)
  }
}

///|
pub impl ToJson for CommandOptionType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for CommandOptionType with fn from_json(json, path) {
  match json {
    Number(value, ..) => CommandOptionType::from_int(value.to_int())
    _ =>
      raise @json.JsonDecodeError(
        (
          path, "expected the value category accepted by a command option (number)",
        ),
      )
  }
}

///|
/// A named value offered as a predefined command option choice.
pub(all) struct CommandOptionChoice {
  name : String
  name_localizations : Nullable[Map[String, String]]?
  /// A string or number retained in its original JSON representation.
  value : Json
} derive(ToJson, FromJson, Debug)
