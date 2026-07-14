///|
/// The user fragment carried by a presence update.
///
/// Discord only normally requires `id`, but explicitly warns that presence
/// fields and their types are not validated. Keeping the id optional lets a
/// malformed user fragment remain observable without rejecting the event.
pub(all) struct PresenceUser {
  id : UserId?
} derive(ToJson, Debug)

///|
/// A user's overall presence state.
pub(all) enum PresenceStatus {
  Idle
  Dnd
  Online
  Offline
  Unknown(String)
} derive(Eq, Debug)

///|
pub fn PresenceStatus::to_string(self : PresenceStatus) -> String {
  match self {
    Idle => "idle"
    Dnd => "dnd"
    Online => "online"
    Offline => "offline"
    Unknown(value) => value
  }
}

///|
pub fn PresenceStatus::from_string(value : String) -> PresenceStatus {
  match value {
    "idle" => Idle
    "dnd" => Dnd
    "online" => Online
    "offline" => Offline
    value => Unknown(value)
  }
}

///|
pub impl ToJson for PresenceStatus with fn to_json(self) {
  Json::string(self.to_string())
}

///|
pub impl @json.FromJson for PresenceStatus with fn from_json(json, path) {
  match json {
    String(value) => PresenceStatus::from_string(value.to_string())
    _ =>
      raise @json.JsonDecodeError((path, "expected presence status (string)"))
  }
}

///|
/// The Discord client families on which a user is active.
pub(all) struct ClientStatus {
  desktop : PresenceStatus?
  mobile : PresenceStatus?
  web : PresenceStatus?
} derive(ToJson, Debug)

///|
/// An activity category reported in a presence update.
pub(all) enum ActivityType {
  Playing
  Streaming
  Listening
  Watching
  Custom
  Competing
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn ActivityType::to_int(self : ActivityType) -> Int {
  match self {
    Playing => 0
    Streaming => 1
    Listening => 2
    Watching => 3
    Custom => 4
    Competing => 5
    Unknown(value) => value
  }
}

///|
pub fn ActivityType::from_int(value : Int) -> ActivityType {
  match value {
    0 => Playing
    1 => Streaming
    2 => Listening
    3 => Watching
    4 => Custom
    5 => Competing
    value => Unknown(value)
  }
}

///|
pub impl ToJson for ActivityType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for ActivityType with fn from_json(json, path) {
  match json {
    Number(value, ..) => ActivityType::from_int(value.to_int())
    _ => raise @json.JsonDecodeError((path, "expected activity type (number)"))
  }
}

///|
/// Stable core fields of a Discord presence activity.
///
/// TODO(rich-presence): Model timestamps, emoji, party, assets, secrets,
/// flags, and buttons when the richer activity surface is needed.
pub(all) struct Activity {
  name : String
  typ : ActivityType
  url : Nullable[String]?
  created_at : Int64
  application_id : ApplicationId?
  details : Nullable[String]?
  state : Nullable[String]?
  instance : Bool?
} derive(ToJson(fields(typ(rename="type"))), Debug)

///|
struct ActivityWire {
  name : String
  typ : ActivityType
  url : Nullable[String]?
  created_at : Double
  application_id : ApplicationId?
  details : Nullable[String]?
  state : Nullable[String]?
  instance : Bool?
} derive(FromJson(fields(typ(rename="type"))))

///|
pub impl @json.FromJson for Activity with fn from_json(json, path) {
  let wire : ActivityWire = @json.from_json(json, path~)
  {
    name: wire.name,
    typ: wire.typ,
    url: wire.url,
    created_at: wire.created_at.to_int64(),
    application_id: wire.application_id,
    details: wire.details,
    state: wire.state,
    instance: wire.instance,
  }
}

///|
/// A gateway presence update decoded field-by-field.
///
/// Discord does not validate the presence payload. A missing field or a field
/// whose value has the wrong type is represented as `None`; one bad field never
/// prevents the rest of the event from being delivered.
pub(all) struct PresenceUpdateEvent {
  user : PresenceUser?
  guild_id : GuildId?
  status : PresenceStatus?
  activities : Array[Activity]?
  client_status : ClientStatus?
} derive(ToJson, Debug)

///|
fn[T : @json.FromJson] lenient_presence_field(
  fields : Map[String, Json],
  key : String,
  path : @json.JsonPath,
) -> T? {
  match fields.get(key) {
    None => None
    Some(value) =>
      Some(@json.from_json(value, path=path.add_key(key))) catch {
        _ => None
      }
  }
}

///|
pub impl @json.FromJson for PresenceUser with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "expected presence user (object)"))
  }
  { id: lenient_presence_field(fields, "id", path) }
}

///|
pub impl @json.FromJson for ClientStatus with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "expected client status (object)"))
  }
  {
    desktop: lenient_presence_field(fields, "desktop", path),
    mobile: lenient_presence_field(fields, "mobile", path),
    web: lenient_presence_field(fields, "web", path),
  }
}

///|
pub impl @json.FromJson for PresenceUpdateEvent with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "expected presence update (object)"))
  }
  {
    user: lenient_presence_field(fields, "user", path),
    guild_id: lenient_presence_field(fields, "guild_id", path),
    status: lenient_presence_field(fields, "status", path),
    activities: lenient_presence_field(fields, "activities", path),
    client_status: lenient_presence_field(fields, "client_status", path),
  }
}
