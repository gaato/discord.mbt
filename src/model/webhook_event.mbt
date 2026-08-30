///|
/// An outbound HTTP webhook event payload sent by Discord.
pub(all) struct WebhookEventPayload {
  version : Int
  application_id : ApplicationId
  typ : WebhookPayloadType
  event : WebhookEventBody?
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// The outer category of an outbound Discord webhook payload.
pub(all) enum WebhookPayloadType {
  Ping
  Event
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn WebhookPayloadType::to_int(self : WebhookPayloadType) -> Int {
  match self {
    Ping => 0
    Event => 1
    Unknown(value) => value
  }
}

///|
pub fn WebhookPayloadType::from_int(value : Int) -> WebhookPayloadType {
  match value {
    0 => Ping
    1 => Event
    value => Unknown(value)
  }
}

///|
pub impl ToJson for WebhookPayloadType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for WebhookPayloadType with fn from_json(json, path) {
  match json {
    Number(value, ..) => WebhookPayloadType::from_int(value.to_int())
    _ =>
      raise JsonDecodeError(
        (path, "expected an outbound webhook payload type (number)"),
      )
  }
}

///|
/// The timestamped body nested inside an event webhook payload.
pub(all) struct WebhookEventBody {
  typ : WebhookEventType
  timestamp : Timestamp
  data : Json?
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// A subscribable outbound webhook event category.
pub(all) enum WebhookEventType {
  ApplicationAuthorized
  ApplicationDeauthorized
  EntitlementCreate
  EntitlementUpdate
  EntitlementDelete
  LobbyMessageCreate
  LobbyMessageUpdate
  LobbyMessageDelete
  GameDirectMessageCreate
  GameDirectMessageUpdate
  GameDirectMessageDelete
  QuestUserEnrollment
  Unknown(String)
} derive(Eq, Debug)

///|
pub fn WebhookEventType::to_string(self : WebhookEventType) -> String {
  match self {
    ApplicationAuthorized => "APPLICATION_AUTHORIZED"
    ApplicationDeauthorized => "APPLICATION_DEAUTHORIZED"
    EntitlementCreate => "ENTITLEMENT_CREATE"
    EntitlementUpdate => "ENTITLEMENT_UPDATE"
    EntitlementDelete => "ENTITLEMENT_DELETE"
    LobbyMessageCreate => "LOBBY_MESSAGE_CREATE"
    LobbyMessageUpdate => "LOBBY_MESSAGE_UPDATE"
    LobbyMessageDelete => "LOBBY_MESSAGE_DELETE"
    GameDirectMessageCreate => "GAME_DIRECT_MESSAGE_CREATE"
    GameDirectMessageUpdate => "GAME_DIRECT_MESSAGE_UPDATE"
    GameDirectMessageDelete => "GAME_DIRECT_MESSAGE_DELETE"
    QuestUserEnrollment => "QUEST_USER_ENROLLMENT"
    Unknown(value) => value
  }
}

///|
pub fn WebhookEventType::from_string(value : String) -> WebhookEventType {
  match value {
    "APPLICATION_AUTHORIZED" => ApplicationAuthorized
    "APPLICATION_DEAUTHORIZED" => ApplicationDeauthorized
    "ENTITLEMENT_CREATE" => EntitlementCreate
    "ENTITLEMENT_UPDATE" => EntitlementUpdate
    "ENTITLEMENT_DELETE" => EntitlementDelete
    "LOBBY_MESSAGE_CREATE" => LobbyMessageCreate
    "LOBBY_MESSAGE_UPDATE" => LobbyMessageUpdate
    "LOBBY_MESSAGE_DELETE" => LobbyMessageDelete
    "GAME_DIRECT_MESSAGE_CREATE" => GameDirectMessageCreate
    "GAME_DIRECT_MESSAGE_UPDATE" => GameDirectMessageUpdate
    "GAME_DIRECT_MESSAGE_DELETE" => GameDirectMessageDelete
    "QUEST_USER_ENROLLMENT" => QuestUserEnrollment
    value => Unknown(value)
  }
}

///|
pub impl ToJson for WebhookEventType with fn to_json(self) {
  Json::string(self.to_string())
}

///|
pub impl @json.FromJson for WebhookEventType with fn from_json(json, path) {
  match json {
    String(value) => WebhookEventType::from_string(value)
    _ =>
      raise JsonDecodeError(
        (path, "expected an outbound webhook event type (string)"),
      )
  }
}

///|
/// A webhook event projected into its documented payload shape.
///
/// Known event names always use a typed variant. Unknown names retain their
/// original name and optional data for forward compatibility.
pub(all) enum WebhookEvent {
  ApplicationAuthorized(ApplicationAuthorizedEvent)
  ApplicationDeauthorized(ApplicationDeauthorizedEvent)
  EntitlementCreate(Entitlement)
  EntitlementUpdate(Entitlement)
  EntitlementDelete(Entitlement)
  LobbyMessageCreate(LobbyMessage)
  LobbyMessageUpdate(LobbyMessage)
  LobbyMessageDelete(LobbyMessageDeleteEvent)
  GameDirectMessageCreate(GameDirectMessage)
  GameDirectMessageUpdate(GameDirectMessage)
  GameDirectMessageDelete(GameDirectMessage)
  QuestUserEnrollment
  Unknown(typ~ : String, data~ : Json?)
} derive(Debug)

///|
/// Decode the event-specific data carried by this body.
///
/// Unknown event names never raise. A known event raises when its data does
/// not match the documented wire shape.
pub fn WebhookEventBody::project(self : WebhookEventBody) -> WebhookEvent raise {
  let data = self.data.unwrap_or(Json::null())
  match self.typ {
    ApplicationAuthorized => ApplicationAuthorized(@json.from_json(data))
    ApplicationDeauthorized => ApplicationDeauthorized(@json.from_json(data))
    EntitlementCreate => EntitlementCreate(@json.from_json(data))
    EntitlementUpdate => EntitlementUpdate(@json.from_json(data))
    EntitlementDelete => EntitlementDelete(@json.from_json(data))
    LobbyMessageCreate => LobbyMessageCreate(@json.from_json(data))
    LobbyMessageUpdate => LobbyMessageUpdate(@json.from_json(data))
    LobbyMessageDelete => LobbyMessageDelete(@json.from_json(data))
    GameDirectMessageCreate => GameDirectMessageCreate(@json.from_json(data))
    GameDirectMessageUpdate => GameDirectMessageUpdate(@json.from_json(data))
    GameDirectMessageDelete => GameDirectMessageDelete(@json.from_json(data))
    QuestUserEnrollment => QuestUserEnrollment
    Unknown(typ) => Unknown(typ~, data=self.data)
  }
}

///|
/// Data sent when a user authorizes an application.
pub(all) struct ApplicationAuthorizedEvent {
  integration_type : ApplicationIntegrationType?
  user : User
  scopes : Array[String]
  guild : Guild?
} derive(ToJson, FromJson, Debug)

///|
/// Data sent when a user deauthorizes an application.
pub(all) struct ApplicationDeauthorizedEvent {
  user : User
} derive(ToJson, FromJson, Debug)

///|
/// A lobby message view for outbound webhook events.
///
/// The documented fields are decoded for direct use while `raw` preserves
/// the complete object, including SDK extensions that are not a Lobby domain.
pub(all) struct LobbyMessage {
  id : MessageId
  typ : MessageType
  content : String
  lobby_id : GenericId
  channel_id : ChannelId
  author : User
  metadata : Json?
  flags : MessageFlags
  application_id : ApplicationId?
  timestamp : Timestamp?
  edited_timestamp : Nullable[Timestamp]?
  raw : Json
} derive(Debug)

///|
priv struct LobbyMessageFields {
  id : MessageId
  typ : MessageType
  content : String
  lobby_id : GenericId
  channel_id : ChannelId
  author : User
  metadata : Json?
  flags : MessageFlags
  application_id : ApplicationId?
  timestamp : Timestamp?
  edited_timestamp : Nullable[Timestamp]?
} derive(FromJson(fields(typ(rename="type"))))

///|
pub impl @json.FromJson for LobbyMessage with fn from_json(json, path) {
  let fields : LobbyMessageFields = @json.from_json(json, path~)
  {
    id: fields.id,
    typ: fields.typ,
    content: fields.content,
    lobby_id: fields.lobby_id,
    channel_id: fields.channel_id,
    author: fields.author,
    metadata: fields.metadata,
    flags: fields.flags,
    application_id: fields.application_id,
    timestamp: fields.timestamp,
    edited_timestamp: fields.edited_timestamp,
    raw: json,
  }
}

///|
pub impl ToJson for LobbyMessage with fn to_json(self) {
  self.raw
}

///|
/// Identifiers for a lobby message that was deleted.
pub(all) struct LobbyMessageDeleteEvent {
  id : MessageId
  lobby_id : GenericId
  raw : Json
} derive(Debug)

///|
priv struct LobbyMessageDeleteFields {
  id : MessageId
  lobby_id : GenericId
} derive(FromJson)

///|
pub impl @json.FromJson for LobbyMessageDeleteEvent with fn from_json(
  json,
  path,
) {
  let fields : LobbyMessageDeleteFields = @json.from_json(json, path~)
  { id: fields.id, lobby_id: fields.lobby_id, raw: json, }
}

///|
pub impl ToJson for LobbyMessageDeleteEvent with fn to_json(self) {
  self.raw
}

///|
/// A compact, lossless view of a Social SDK direct message.
///
/// These webhook objects may be standard messages or the smaller SDK DM
/// shape. Fields that differ between those forms are optional, and `raw`
/// preserves all unmodeled standard-message and SDK extension fields.
pub(all) struct GameDirectMessage {
  id : MessageId
  typ : MessageType?
  content : String?
  channel_id : ChannelId?
  channel : Channel?
  author : User?
  recipient_id : UserId?
  timestamp : Timestamp?
  edited_timestamp : Nullable[Timestamp]?
  flags : MessageFlags?
  application_id : ApplicationId?
  attachments : Array[Attachment]?
  components : Array[Component]?
  activity : MessageActivity?
  application : Json?
  raw : Json
} derive(Debug)

///|
priv struct GameDirectMessageFields {
  id : MessageId
  typ : MessageType?
  content : String?
  channel_id : ChannelId?
  channel : Channel?
  author : User?
  recipient_id : UserId?
  timestamp : Timestamp?
  edited_timestamp : Nullable[Timestamp]?
  flags : MessageFlags?
  application_id : ApplicationId?
  attachments : Array[Attachment]?
  components : Array[Component]?
  activity : MessageActivity?
  application : Json?
} derive(FromJson(fields(typ(rename="type"))))

///|
pub impl @json.FromJson for GameDirectMessage with fn from_json(json, path) {
  let fields : GameDirectMessageFields = @json.from_json(json, path~)
  {
    id: fields.id,
    typ: fields.typ,
    content: fields.content,
    channel_id: fields.channel_id,
    channel: fields.channel,
    author: fields.author,
    recipient_id: fields.recipient_id,
    timestamp: fields.timestamp,
    edited_timestamp: fields.edited_timestamp,
    flags: fields.flags,
    application_id: fields.application_id,
    attachments: fields.attachments,
    components: fields.components,
    activity: fields.activity,
    application: fields.application,
    raw: json,
  }
}

///|
pub impl ToJson for GameDirectMessage with fn to_json(self) {
  self.raw
}
