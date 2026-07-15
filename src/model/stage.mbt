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
pub(all) enum StagePrivacyLevel {
  Public
  GuildOnly
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn StagePrivacyLevel::to_int(self : StagePrivacyLevel) -> Int {
  match self {
    Public => 1
    GuildOnly => 2
    Unknown(value) => value
  }
}

///|
pub fn StagePrivacyLevel::from_int(value : Int) -> StagePrivacyLevel {
  match value {
    1 => Public
    2 => GuildOnly
    value => Unknown(value)
  }
}

///|
pub impl ToJson for StagePrivacyLevel with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
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
