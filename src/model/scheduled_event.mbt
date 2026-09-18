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
  recurrence_rule : Nullable[GuildScheduledEventRecurrenceRule]
} derive(ToJson, FromJson, Debug)

///|
/// A user interested in a guild scheduled event.
pub(all) struct GuildScheduledEventUser {
  guild_scheduled_event_id : ScheduledEventId
  user : User
  guild_member : GuildMember?
} derive (
  ToJson(fields(guild_member(rename="member"))),
  FromJson(fields(guild_member(rename="member"))),
  Debug,
)

///|
/// A recurrence schedule attached to a guild scheduled event.
pub(all) struct GuildScheduledEventRecurrenceRule {
  start : Timestamp
  end : Nullable[Timestamp]?
  frequency : GuildScheduledEventRecurrenceRuleFrequency
  interval : Int
  by_weekday : Nullable[Array[GuildScheduledEventRecurrenceRuleWeekday]]?
  by_n_weekday : Nullable[Array[GuildScheduledEventRecurrenceRuleNWeekday]]?
  by_month : Nullable[Array[GuildScheduledEventRecurrenceRuleMonth]]?
  by_month_day : Nullable[Array[Int]]?
  by_year_day : Array[Int]?
  count : Int?
} derive(ToJson, FromJson, Debug)

///|
/// An ordinal weekday constraint such as the first Monday of a month.
pub(all) struct GuildScheduledEventRecurrenceRuleNWeekday {
  n : Int
  day : GuildScheduledEventRecurrenceRuleWeekday
} derive(ToJson, FromJson, Debug)

///|
/// The base period used by a scheduled-event recurrence rule.
pub(all) enum GuildScheduledEventRecurrenceRuleFrequency {
  Yearly
  Monthly
  Weekly
  Daily
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn GuildScheduledEventRecurrenceRuleFrequency::to_int(
  self : GuildScheduledEventRecurrenceRuleFrequency,
) -> Int {
  match self {
    Yearly => 0
    Monthly => 1
    Weekly => 2
    Daily => 3
    Unknown(value) => value
  }
}

///|
pub fn GuildScheduledEventRecurrenceRuleFrequency::from_int(
  value : Int,
) -> GuildScheduledEventRecurrenceRuleFrequency {
  match value {
    0 => Yearly
    1 => Monthly
    2 => Weekly
    3 => Daily
    value => Unknown(value)
  }
}

///|
pub impl ToJson for GuildScheduledEventRecurrenceRuleFrequency with fn to_json(
  self,
) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for GuildScheduledEventRecurrenceRuleFrequency with fn from_json(
  json,
  path,
) {
  match json {
    Number(value, ..) =>
      GuildScheduledEventRecurrenceRuleFrequency::from_int(value.to_int())
    _ =>
      raise JsonDecodeError(
        (path, "expected scheduled-event recurrence frequency (number)"),
      )
  }
}

///|
/// A weekday used by a scheduled-event recurrence rule (Monday is zero).
pub(all) enum GuildScheduledEventRecurrenceRuleWeekday {
  Monday
  Tuesday
  Wednesday
  Thursday
  Friday
  Saturday
  Sunday
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn GuildScheduledEventRecurrenceRuleWeekday::to_int(
  self : GuildScheduledEventRecurrenceRuleWeekday,
) -> Int {
  match self {
    Monday => 0
    Tuesday => 1
    Wednesday => 2
    Thursday => 3
    Friday => 4
    Saturday => 5
    Sunday => 6
    Unknown(value) => value
  }
}

///|
pub fn GuildScheduledEventRecurrenceRuleWeekday::from_int(
  value : Int,
) -> GuildScheduledEventRecurrenceRuleWeekday {
  match value {
    0 => Monday
    1 => Tuesday
    2 => Wednesday
    3 => Thursday
    4 => Friday
    5 => Saturday
    6 => Sunday
    value => Unknown(value)
  }
}

///|
pub impl ToJson for GuildScheduledEventRecurrenceRuleWeekday with fn to_json(
  self,
) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for GuildScheduledEventRecurrenceRuleWeekday with fn from_json(
  json,
  path,
) {
  match json {
    Number(value, ..) =>
      GuildScheduledEventRecurrenceRuleWeekday::from_int(value.to_int())
    _ =>
      raise JsonDecodeError(
        (path, "expected scheduled-event recurrence weekday (number)"),
      )
  }
}

///|
/// A calendar month used by a scheduled-event recurrence rule.
pub(all) enum GuildScheduledEventRecurrenceRuleMonth {
  January
  February
  March
  April
  May
  June
  July
  August
  September
  October
  November
  December
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn GuildScheduledEventRecurrenceRuleMonth::to_int(
  self : GuildScheduledEventRecurrenceRuleMonth,
) -> Int {
  match self {
    January => 1
    February => 2
    March => 3
    April => 4
    May => 5
    June => 6
    July => 7
    August => 8
    September => 9
    October => 10
    November => 11
    December => 12
    Unknown(value) => value
  }
}

///|
pub fn GuildScheduledEventRecurrenceRuleMonth::from_int(
  value : Int,
) -> GuildScheduledEventRecurrenceRuleMonth {
  match value {
    1 => January
    2 => February
    3 => March
    4 => April
    5 => May
    6 => June
    7 => July
    8 => August
    9 => September
    10 => October
    11 => November
    12 => December
    value => Unknown(value)
  }
}

///|
pub impl ToJson for GuildScheduledEventRecurrenceRuleMonth with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for GuildScheduledEventRecurrenceRuleMonth with fn from_json(
  json,
  path,
) {
  match json {
    Number(value, ..) =>
      GuildScheduledEventRecurrenceRuleMonth::from_int(value.to_int())
    _ =>
      raise JsonDecodeError(
        (path, "expected scheduled-event recurrence month (number)"),
      )
  }
}

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
      raise JsonDecodeError(
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
      raise JsonDecodeError(
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
      raise JsonDecodeError(
        (path, "expected the hosting entity used by a scheduled event (number)"),
      )
  }
}

///|
/// Optional metadata describing a scheduled event's external entity.
pub(all) struct EntityMetadata {
  location : String?
} derive(ToJson, FromJson, Debug)
