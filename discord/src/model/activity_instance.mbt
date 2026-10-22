///|
/// A live instance of an application activity.
pub(all) struct ActivityInstance {
  application_id : ApplicationId
  instance_id : String
  launch_id : GenericId
  location : ActivityLocation
  users : Array[UserId]
} derive(ToJson, FromJson, Debug)

///|
/// The Discord location hosting an application activity instance.
pub(all) struct ActivityLocation {
  id : String
  kind : ActivityLocationKind
  channel_id : ChannelId
  guild_id : Nullable[GuildId]?
} derive(ToJson, FromJson, Debug)

///|
/// The channel context hosting an application activity instance.
#non_exhaustive
pub(all) enum ActivityLocationKind {
  GuildChannel
  PrivateChannel
  Unknown(String)
} derive(Eq, Debug)

///|
/// The Discord string value of this `ActivityLocationKind`.
pub fn ActivityLocationKind::to_string(self : ActivityLocationKind) -> String {
  match self {
    GuildChannel => "gc"
    PrivateChannel => "pc"
    Unknown(value) => value
  }
}

///|
/// The `ActivityLocationKind` for its Discord string value; unknown values become `Unknown(s)`.
pub fn ActivityLocationKind::from_string(
  value : String,
) -> ActivityLocationKind {
  match value {
    "gc" => GuildChannel
    "pc" => PrivateChannel
    value => Unknown(value)
  }
}

///|
/// Encodes the `ActivityLocationKind` as its Discord string value.
pub impl ToJson for ActivityLocationKind with fn to_json(self) {
  Json::string(self.to_string())
}

///|
/// Decodes the `ActivityLocationKind` from a JSON string; unknown values become `Unknown(s)`.
pub impl @json.FromJson for ActivityLocationKind with fn from_json(json, path) {
  match json {
    String(value) => ActivityLocationKind::from_string(value.to_string())
    _ =>
      raise JsonDecodeError((path, "expected activity location kind (string)"))
  }
}
