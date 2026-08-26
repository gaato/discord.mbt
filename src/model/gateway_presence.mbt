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
    _ => raise JsonDecodeError((path, "expected presence status (string)"))
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
    _ => raise JsonDecodeError((path, "expected activity type (number)"))
  }
}

///|
/// A Discord presence activity, including the documented Rich Presence fields.
pub(all) struct Activity {
  name : String
  typ : ActivityType
  url : Nullable[String]?
  created_at : Int64
  timestamps : ActivityTimestamps?
  application_id : ApplicationId?
  status_display_type : Nullable[Int]?
  details : Nullable[String]?
  details_url : Nullable[String]?
  state : Nullable[String]?
  state_url : Nullable[String]?
  emoji : Nullable[ActivityEmoji]?
  party : ActivityParty?
  assets : ActivityAssets?
  secrets : ActivitySecrets?
  instance : Bool?
  flags : ActivityFlags?
  buttons : Array[ActivityButton]?
} derive(ToJson(fields(typ(rename="type"))), Debug)

///|
struct ActivityWire {
  name : String
  typ : ActivityType
  url : Nullable[String]?
  created_at : Double
  timestamps : ActivityTimestamps?
  application_id : ApplicationId?
  status_display_type : Nullable[Int]?
  details : Nullable[String]?
  details_url : Nullable[String]?
  state : Nullable[String]?
  state_url : Nullable[String]?
  emoji : Nullable[ActivityEmoji]?
  party : ActivityParty?
  assets : ActivityAssets?
  secrets : ActivitySecrets?
  instance : Bool?
  flags : ActivityFlags?
  buttons : Array[ActivityButton]?
} derive(FromJson(fields(typ(rename="type"))))

///|
pub impl @json.FromJson for Activity with fn from_json(json, path) {
  let wire : ActivityWire = @json.from_json(json, path~)
  {
    name: wire.name,
    typ: wire.typ,
    url: wire.url,
    created_at: wire.created_at.to_int64(),
    timestamps: wire.timestamps,
    application_id: wire.application_id,
    status_display_type: wire.status_display_type,
    details: wire.details,
    details_url: wire.details_url,
    state: wire.state,
    state_url: wire.state_url,
    emoji: wire.emoji,
    party: wire.party,
    assets: wire.assets,
    secrets: wire.secrets,
    instance: wire.instance,
    flags: wire.flags,
    buttons: wire.buttons,
  }
}

///|
/// Unix millisecond start and end times of an activity.
pub(all) struct ActivityTimestamps {
  start : Int64?
  end : Int64?
} derive(Debug)

///|
struct ActivityTimestampsWire {
  start : Double?
  end : Double?
} derive(FromJson)

///|
pub impl ToJson for ActivityTimestamps with fn to_json(self) {
  let fields : Map[String, Json] = Map([])
  if self.start is Some(value) {
    fields["start"] = Json::number(value.to_double(), repr=value.to_string())
  }
  if self.end is Some(value) {
    fields["end"] = Json::number(value.to_double(), repr=value.to_string())
  }
  Json::object(fields)
}

///|
pub impl @json.FromJson for ActivityTimestamps with fn from_json(json, path) {
  let wire : ActivityTimestampsWire = @json.from_json(json, path~)
  {
    start: wire.start.map(value => value.to_int64()),
    end: wire.end.map(value => value.to_int64()),
  }
}

///|
/// The custom or unicode emoji attached to a custom status.
pub(all) struct ActivityEmoji {
  name : String
  id : EmojiId?
  animated : Bool?
} derive(ToJson, FromJson, Debug)

///|
/// The rich-presence party, with `size` as `[current, max]` when present.
pub(all) struct ActivityParty {
  id : String?
  size : Array[Int]?
} derive(ToJson, FromJson, Debug)

///|
/// Rich-presence artwork references and their hover texts.
pub(all) struct ActivityAssets {
  large_image : String?
  large_text : String?
  large_url : String?
  small_image : String?
  small_text : String?
  small_url : String?
  invite_cover_image : String?
} derive(ToJson, FromJson, Debug)

///|
/// Secrets for joining or spectating a rich-presence session.
pub(all) struct ActivitySecrets {
  join : String?
  spectate : String?
  match_ : String?
} derive (
  ToJson(fields(match_(rename="match"))),
  FromJson(fields(match_(rename="match"))),
  Debug,
)

///|
/// A custom label/url button shown on a rich presence.
pub(all) struct ActivityButton {
  label : String
  url : String
} derive(ToJson, FromJson, Debug)

///|
/// Bit set describing which rich-presence interactions an activity supports.
pub(all) struct ActivityFlags(UInt64) derive(Eq)

///|
pub fn ActivityFlags::from_bits(bits : UInt64) -> ActivityFlags {
  ActivityFlags(bits)
}

///|
pub fn ActivityFlags::bits(self : ActivityFlags) -> UInt64 {
  self.0
}

///|
pub impl Debug for ActivityFlags with fn to_repr(self) {
  Repr(self.0)
}

///|
pub impl ToJson for ActivityFlags with fn to_json(self) {
  Json::number(self.0.to_double(), repr=self.0.to_string())
}

///|
pub impl @json.FromJson for ActivityFlags with fn from_json(json, path) {
  match json {
    Number(_, repr=Some(repr)) =>
      ActivityFlags(
        @string.parse_uint64(repr.to_string()) catch {
          _ => raise JsonDecodeError((path, "expected activity flags (number)"))
        },
      )
    Number(value, repr=None) => ActivityFlags(value.to_uint64())
    _ => raise JsonDecodeError((path, "expected activity flags (number)"))
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
    raise JsonDecodeError((path, "expected presence user (object)"))
  }
  { id: lenient_presence_field(fields, "id", path) }
}

///|
pub impl @json.FromJson for ClientStatus with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise JsonDecodeError((path, "expected client status (object)"))
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
    raise JsonDecodeError((path, "expected presence update (object)"))
  }
  {
    user: lenient_presence_field(fields, "user", path),
    guild_id: lenient_presence_field(fields, "guild_id", path),
    status: lenient_presence_field(fields, "status", path),
    activities: lenient_presence_field(fields, "activities", path),
    client_status: lenient_presence_field(fields, "client_status", path),
  }
}
