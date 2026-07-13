///|
/// A guild event scheduled for a stage, voice channel, or external location.
pub(all) struct GuildScheduledEvent {
  id : ScheduledEventId
  guild_id : GuildId
  channel_id : Nullable[ChannelId]
  creator_id : Nullable[UserId]?
  name : String
  description : Nullable[String]?
  scheduled_start_time : Timestamp
  scheduled_end_time : Nullable[Timestamp]
  privacy_level : GuildScheduledEventPrivacyLevel
  status : GuildScheduledEventStatus
  entity_type : GuildScheduledEventEntityType
  entity_id : Nullable[GenericId]
  entity_metadata : Nullable[EntityMetadata]
  creator : User?
  user_count : Int?
  image : Nullable[ImageHash]?
  // TODO(recurrence-rule): Replace raw recurrence data when those types are ported.
  recurrence_rule : Nullable[Json]
} derive(ToJson, FromJson, Debug)

///|
/// The audience allowed to access a scheduled event.
pub(all) enum GuildScheduledEventPrivacyLevel {
  GuildOnly
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn GuildScheduledEventPrivacyLevel::to_int(
  self : GuildScheduledEventPrivacyLevel,
) -> Int {
  match self {
    GuildOnly => 2
    Unknown(value) => value
  }
}

///|
pub fn GuildScheduledEventPrivacyLevel::from_int(
  value : Int,
) -> GuildScheduledEventPrivacyLevel {
  match value {
    2 => GuildOnly
    value => Unknown(value)
  }
}

///|
pub impl ToJson for GuildScheduledEventPrivacyLevel with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for GuildScheduledEventPrivacyLevel with fn from_json(
  json,
  path,
) {
  match json {
    Number(value, ..) =>
      GuildScheduledEventPrivacyLevel::from_int(value.to_int())
    _ =>
      raise @json.JsonDecodeError(
        (
          path, "expected the audience allowed to access a scheduled event (number)",
        ),
      )
  }
}

///|
/// The lifecycle state of a scheduled event.
pub(all) enum GuildScheduledEventStatus {
  Scheduled
  Active
  Completed
  Canceled
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn GuildScheduledEventStatus::to_int(
  self : GuildScheduledEventStatus,
) -> Int {
  match self {
    Scheduled => 1
    Active => 2
    Completed => 3
    Canceled => 4
    Unknown(value) => value
  }
}

///|
pub fn GuildScheduledEventStatus::from_int(
  value : Int,
) -> GuildScheduledEventStatus {
  match value {
    1 => Scheduled
    2 => Active
    3 => Completed
    4 => Canceled
    value => Unknown(value)
  }
}

///|
pub impl ToJson for GuildScheduledEventStatus with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for GuildScheduledEventStatus with fn from_json(
  json,
  path,
) {
  match json {
    Number(value, ..) => GuildScheduledEventStatus::from_int(value.to_int())
    _ =>
      raise @json.JsonDecodeError(
        (path, "expected the lifecycle state of a scheduled event (number)"),
      )
  }
}

///|
/// The hosting entity used by a scheduled event.
pub(all) enum GuildScheduledEventEntityType {
  StageInstance
  Voice
  External
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn GuildScheduledEventEntityType::to_int(
  self : GuildScheduledEventEntityType,
) -> Int {
  match self {
    StageInstance => 1
    Voice => 2
    External => 3
    Unknown(value) => value
  }
}

///|
pub fn GuildScheduledEventEntityType::from_int(
  value : Int,
) -> GuildScheduledEventEntityType {
  match value {
    1 => StageInstance
    2 => Voice
    3 => External
    value => Unknown(value)
  }
}

///|
pub impl ToJson for GuildScheduledEventEntityType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for GuildScheduledEventEntityType with fn from_json(
  json,
  path,
) {
  match json {
    Number(value, ..) => GuildScheduledEventEntityType::from_int(value.to_int())
    _ =>
      raise @json.JsonDecodeError(
        (path, "expected the hosting entity used by a scheduled event (number)"),
      )
  }
}

///|
/// Optional metadata describing a scheduled event's external entity.
pub(all) struct EntityMetadata {
  location : String?
} derive(ToJson, FromJson, Debug)
