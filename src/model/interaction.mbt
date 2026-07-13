///|
/// An interaction delivered by Discord to an application.
pub(all) struct Interaction {
  id : InteractionId
  application_id : ApplicationId
  typ : InteractionType
  data : InteractionData?
  guild_id : GuildId?
  channel : Channel?
  channel_id : ChannelId?
  guild_member : GuildMember?
  user : User?
  token : String
  version : Int
  message : Message?
  app_permissions : Permissions?
  locale : String?
  guild_locale : String?
  // TODO(entitlement): Replace raw entries when the entitlement domain is ported.
  entitlements : Array[Json]?
  context : Int?
  // TODO(interaction-full): Port guild summary, authorization owners, and attachment size metadata later.
} derive(Debug)

///|
/// The dispatch category of an interaction.
pub(all) enum InteractionType {
  Ping
  ApplicationCommand
  MessageComponent
  ApplicationCommandAutocomplete
  ModalSubmit
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn InteractionType::to_int(self : InteractionType) -> Int {
  match self {
    Ping => 1
    ApplicationCommand => 2
    MessageComponent => 3
    ApplicationCommandAutocomplete => 4
    ModalSubmit => 5
    Unknown(value) => value
  }
}

///|
pub fn InteractionType::from_int(value : Int) -> InteractionType {
  match value {
    1 => Ping
    2 => ApplicationCommand
    3 => MessageComponent
    4 => ApplicationCommandAutocomplete
    5 => ModalSubmit
    value => Unknown(value)
  }
}

///|
pub impl ToJson for InteractionType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for InteractionType with fn from_json(json, path) {
  match json {
    Number(value, ..) => InteractionType::from_int(value.to_int())
    _ =>
      raise @json.JsonDecodeError(
        (path, "expected the dispatch category of an interaction (number)"),
      )
  }
}

///|
/// Polymorphic interaction data selected by the parent interaction type.
pub(all) enum InteractionData {
  Command(CommandData)
  Component(ComponentData)
  Modal(ModalData)
  Unknown(Json)
} derive(Debug)

///|
pub impl ToJson for InteractionData with fn to_json(self) {
  match self {
    Command(value) => value.to_json()
    Component(value) => value.to_json()
    Modal(value) => value.to_json()
    Unknown(value) => value
  }
}

///|
/// Mechanical interaction fields decoded independently from polymorphic data.
priv struct InteractionFields {
  id : InteractionId
  application_id : ApplicationId
  typ : InteractionType
  guild_id : GuildId?
  channel : Channel?
  channel_id : ChannelId?
  guild_member : GuildMember?
  user : User?
  token : String
  version : Int
  message : Message?
  app_permissions : Permissions?
  locale : String?
  guild_locale : String?
  entitlements : Array[Json]?
  context : Int?
} derive (
  ToJson(fields(typ(rename="type"), guild_member(rename="member"))),
  FromJson(fields(typ(rename="type"), guild_member(rename="member"))),
)

///|
fn Interaction::fields(self : Interaction) -> InteractionFields {
  {
    id: self.id,
    application_id: self.application_id,
    typ: self.typ,
    guild_id: self.guild_id,
    channel: self.channel,
    channel_id: self.channel_id,
    guild_member: self.guild_member,
    user: self.user,
    token: self.token,
    version: self.version,
    message: self.message,
    app_permissions: self.app_permissions,
    locale: self.locale,
    guild_locale: self.guild_locale,
    entitlements: self.entitlements,
    context: self.context,
  }
}

///|
fn decode_interaction_data(
  typ : InteractionType,
  raw : Json,
  path : @json.JsonPath,
) -> InteractionData raise @json.JsonDecodeError {
  match typ {
    ApplicationCommand | ApplicationCommandAutocomplete =>
      Command(@json.from_json(raw, path~))
    MessageComponent => Component(@json.from_json(raw, path~))
    ModalSubmit => Modal(@json.from_json(raw, path~))
    Ping | Unknown(_) => Unknown(raw)
  }
}

///|
pub impl ToJson for Interaction with fn to_json(self) {
  match self.fields().to_json() {
    Object(fields) => {
      if self.data is Some(data) {
        fields["data"] = data.to_json()
      }
      Json::object(fields)
    }
    value => value
  }
}

///|
pub impl @json.FromJson for Interaction with fn from_json(json, path) {
  let base : InteractionFields = @json.from_json(json, path~)
  let data : InteractionData? = match json {
    Object(fields) =>
      match fields.get("data") {
        None => None
        Some(raw) =>
          Some(decode_interaction_data(base.typ, raw, path.add_key("data")))
      }
    _ => None
  }
  {
    id: base.id,
    application_id: base.application_id,
    typ: base.typ,
    data,
    guild_id: base.guild_id,
    channel: base.channel,
    channel_id: base.channel_id,
    guild_member: base.guild_member,
    user: base.user,
    token: base.token,
    version: base.version,
    message: base.message,
    app_permissions: base.app_permissions,
    locale: base.locale,
    guild_locale: base.guild_locale,
    entitlements: base.entitlements,
    context: base.context,
  }
}

///|
/// Application-command data carried by command and autocomplete interactions.
pub(all) struct CommandData {
  id : CommandId
  name : String
  typ : ApplicationCommandType
  resolved : ResolvedData?
  options : Array[CommandDataOption]?
  guild_id : GuildId?
  target_id : GenericId?
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// A submitted command option with its raw scalar or nested option value.
pub(all) struct CommandDataOption {
  name : String
  typ : CommandOptionType
  value : Json?
  options : Array[CommandDataOption]?
  focused : Bool?
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// Component-specific data carried by a message component interaction.
pub(all) struct ComponentData {
  custom_id : String
  component_type : Int
  values : Array[String]?
  resolved : ResolvedData?
} derive(ToJson, FromJson, Debug)

///|
/// Submitted modal data containing the modal's component tree.
pub(all) struct ModalData {
  custom_id : String
  components : Array[Component]
} derive(ToJson, FromJson, Debug)

///|
/// Entity maps resolved alongside interaction option values.
pub(all) struct ResolvedData {
  users : Map[String, User]?
  members : Map[String, GuildMember]?
  roles : Map[String, Role]?
  channels : Map[String, Channel]?
  messages : Map[String, Message]?
  attachments : Map[String, Attachment]?
} derive(ToJson, FromJson, Debug)

///|
/// A response envelope sent for an interaction callback.
pub(all) struct InteractionResponse {
  typ : InteractionResponseType
  data : Json?
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// The callback behavior requested by an interaction response.
pub(all) enum InteractionResponseType {
  Pong
  ChannelMessageWithSource
  DeferredChannelMessageWithSource
  DeferredUpdateMessage
  UpdateMessage
  Autocomplete
  Modal
  PremiumRequired
  LaunchActivity
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn InteractionResponseType::to_int(self : InteractionResponseType) -> Int {
  match self {
    Pong => 1
    ChannelMessageWithSource => 4
    DeferredChannelMessageWithSource => 5
    DeferredUpdateMessage => 6
    UpdateMessage => 7
    Autocomplete => 8
    Modal => 9
    PremiumRequired => 10
    LaunchActivity => 12
    Unknown(value) => value
  }
}

///|
pub fn InteractionResponseType::from_int(
  value : Int,
) -> InteractionResponseType {
  match value {
    1 => Pong
    4 => ChannelMessageWithSource
    5 => DeferredChannelMessageWithSource
    6 => DeferredUpdateMessage
    7 => UpdateMessage
    8 => Autocomplete
    9 => Modal
    10 => PremiumRequired
    12 => LaunchActivity
    value => Unknown(value)
  }
}

///|
pub impl ToJson for InteractionResponseType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for InteractionResponseType with fn from_json(
  json,
  path,
) {
  match json {
    Number(value, ..) => InteractionResponseType::from_int(value.to_int())
    _ =>
      raise @json.JsonDecodeError(
        (
          path, "expected the callback behavior requested by an interaction response (number)",
        ),
      )
  }
}
