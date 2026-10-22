///|
/// A live stage instance associated with a guild stage channel.
pub(all) struct StageInstance {
  id : StageInstanceId
  guild_id : GuildId
  channel_id : ChannelId
  topic : String
  privacy_level : StagePrivacyLevel
  guild_scheduled_event_id : Nullable[ScheduledEventId]
} derive(ToJson, FromJson, Debug)

///|
/// The audience allowed to discover a stage instance.
#non_exhaustive
pub(all) enum StagePrivacyLevel {
  Public
  GuildOnly
  Unknown(Int32)
} derive(Eq, Debug)

///|
/// The Discord integer value of this `StagePrivacyLevel`.
pub fn StagePrivacyLevel::to_int(self : StagePrivacyLevel) -> Int32 {
  match self {
    Public => 1
    GuildOnly => 2
    Unknown(value) => value
  }
}

///|
/// The `StagePrivacyLevel` for its Discord integer value; unknown values become `Unknown(n)`.
pub fn StagePrivacyLevel::from_int(value : Int32) -> StagePrivacyLevel {
  match value {
    1 => Public
    2 => GuildOnly
    value => Unknown(value)
  }
}

///|
/// Encodes the `StagePrivacyLevel` as its Discord integer value.
pub impl ToJson for StagePrivacyLevel with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
/// Decodes the `StagePrivacyLevel` from a JSON number; unknown values become `Unknown(n)`.
pub impl @json.FromJson for StagePrivacyLevel with fn from_json(json, path) {
  match json {
    Number(value, ..) => StagePrivacyLevel::from_int(value.to_int())
    _ =>
      raise JsonDecodeError(
        (
          path, "expected the audience allowed to discover a stage instance (number)",
        ),
      )
  }
}
