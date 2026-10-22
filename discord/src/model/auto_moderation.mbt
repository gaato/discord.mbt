///|
/// A guild auto-moderation rule and its configured actions.
pub(all) struct AutoModerationRule {
  id : AutoModerationRuleId
  guild_id : GuildId
  name : String
  creator_id : UserId
  event_type : AutoModerationEventType
  trigger_type : AutoModerationTriggerType
  trigger_metadata : TriggerMetadata
  actions : Array[AutoModerationAction]
  enabled : Bool
  exempt_roles : Array[RoleId]
  exempt_channels : Array[ChannelId]
} derive(ToJson, FromJson, Debug)

///|
/// The condition category that activates an auto-moderation rule.
#non_exhaustive
pub(all) enum AutoModerationTriggerType {
  Keyword
  Spam
  KeywordPreset
  MentionSpam
  MemberProfile
  Unknown(Int32)
} derive(Eq, Debug)

///|
/// The Discord integer value of this `AutoModerationTriggerType`.
pub fn AutoModerationTriggerType::to_int(
  self : AutoModerationTriggerType,
) -> Int32 {
  match self {
    Keyword => 1
    Spam => 3
    KeywordPreset => 4
    MentionSpam => 5
    MemberProfile => 6
    Unknown(value) => value
  }
}

///|
/// The `AutoModerationTriggerType` for its Discord integer value; unknown values become `Unknown(n)`.
pub fn AutoModerationTriggerType::from_int(
  value : Int32,
) -> AutoModerationTriggerType {
  match value {
    1 => Keyword
    3 => Spam
    4 => KeywordPreset
    5 => MentionSpam
    6 => MemberProfile
    value => Unknown(value)
  }
}

///|
/// Encodes the `AutoModerationTriggerType` as its Discord integer value.
pub impl ToJson for AutoModerationTriggerType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
/// Decodes the `AutoModerationTriggerType` from a JSON number; unknown values become `Unknown(n)`.
pub impl @json.FromJson for AutoModerationTriggerType with fn from_json(
  json,
  path,
) {
  match json {
    Number(value, ..) => AutoModerationTriggerType::from_int(value.to_int())
    _ =>
      raise JsonDecodeError(
        (
          path, "expected the condition category that activates an auto-moderation rule (number)",
        ),
      )
  }
}

///|
/// Optional condition settings used by auto-moderation triggers.
pub(all) struct TriggerMetadata {
  keyword_filter : Array[String]?
  presets : Array[AutoModerationKeywordPresetType]?
  allow_list : Array[String]?
  regex_patterns : Array[String]?
  mention_total_limit : Int32?
  mention_raid_protection_enabled : Bool?
} derive(ToJson, FromJson, Debug)

///|
/// A built-in keyword set used by auto moderation.
#non_exhaustive
pub(all) enum AutoModerationKeywordPresetType {
  Profanity
  SexualContent
  Slurs
  Unknown(Int32)
} derive(Eq, Debug)

///|
/// The Discord integer value of this `AutoModerationKeywordPresetType`.
pub fn AutoModerationKeywordPresetType::to_int(
  self : AutoModerationKeywordPresetType,
) -> Int32 {
  match self {
    Profanity => 1
    SexualContent => 2
    Slurs => 3
    Unknown(value) => value
  }
}

///|
/// The `AutoModerationKeywordPresetType` for its Discord integer value; unknown values become `Unknown(n)`.
pub fn AutoModerationKeywordPresetType::from_int(
  value : Int32,
) -> AutoModerationKeywordPresetType {
  match value {
    1 => Profanity
    2 => SexualContent
    3 => Slurs
    value => Unknown(value)
  }
}

///|
/// Encodes the `AutoModerationKeywordPresetType` as its Discord integer value.
pub impl ToJson for AutoModerationKeywordPresetType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
/// Decodes the `AutoModerationKeywordPresetType` from a JSON number; unknown values become `Unknown(n)`.
pub impl @json.FromJson for AutoModerationKeywordPresetType with fn from_json(
  json,
  path,
) {
  match json {
    Number(value, ..) =>
      AutoModerationKeywordPresetType::from_int(value.to_int())
    _ =>
      raise JsonDecodeError(
        (
          path, "expected a built-in keyword set used by auto moderation (number)",
        ),
      )
  }
}

///|
/// The guild event evaluated by an auto-moderation rule.
#non_exhaustive
pub(all) enum AutoModerationEventType {
  MessageSend
  MemberUpdate
  Unknown(Int32)
} derive(Eq, Debug)

///|
/// The Discord integer value of this `AutoModerationEventType`.
pub fn AutoModerationEventType::to_int(self : AutoModerationEventType) -> Int32 {
  match self {
    MessageSend => 1
    MemberUpdate => 2
    Unknown(value) => value
  }
}

///|
/// The `AutoModerationEventType` for its Discord integer value; unknown values become `Unknown(n)`.
pub fn AutoModerationEventType::from_int(
  value : Int32,
) -> AutoModerationEventType {
  match value {
    1 => MessageSend
    2 => MemberUpdate
    value => Unknown(value)
  }
}

///|
/// Encodes the `AutoModerationEventType` as its Discord integer value.
pub impl ToJson for AutoModerationEventType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
/// Decodes the `AutoModerationEventType` from a JSON number; unknown values become `Unknown(n)`.
pub impl @json.FromJson for AutoModerationEventType with fn from_json(
  json,
  path,
) {
  match json {
    Number(value, ..) => AutoModerationEventType::from_int(value.to_int())
    _ =>
      raise JsonDecodeError(
        (
          path, "expected the guild event evaluated by an auto-moderation rule (number)",
        ),
      )
  }
}

///|
/// An action executed when an auto-moderation rule matches.
pub(all) struct AutoModerationAction {
  typ : AutoModerationActionType
  metadata : ActionMetadata?
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// The operation performed by auto moderation.
#non_exhaustive
pub(all) enum AutoModerationActionType {
  BlockMessage
  SendAlertMessage
  Timeout
  BlockMemberInteraction
  Unknown(Int32)
} derive(Eq, Debug)

///|
/// The Discord integer value of this `AutoModerationActionType`.
pub fn AutoModerationActionType::to_int(
  self : AutoModerationActionType,
) -> Int32 {
  match self {
    BlockMessage => 1
    SendAlertMessage => 2
    Timeout => 3
    BlockMemberInteraction => 4
    Unknown(value) => value
  }
}

///|
/// The `AutoModerationActionType` for its Discord integer value; unknown values become `Unknown(n)`.
pub fn AutoModerationActionType::from_int(
  value : Int32,
) -> AutoModerationActionType {
  match value {
    1 => BlockMessage
    2 => SendAlertMessage
    3 => Timeout
    4 => BlockMemberInteraction
    value => Unknown(value)
  }
}

///|
/// Encodes the `AutoModerationActionType` as its Discord integer value.
pub impl ToJson for AutoModerationActionType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
/// Decodes the `AutoModerationActionType` from a JSON number; unknown values become `Unknown(n)`.
pub impl @json.FromJson for AutoModerationActionType with fn from_json(
  json,
  path,
) {
  match json {
    Number(value, ..) => AutoModerationActionType::from_int(value.to_int())
    _ =>
      raise JsonDecodeError(
        (path, "expected the operation performed by auto moderation (number)"),
      )
  }
}

///|
/// Optional execution settings for an auto-moderation action.
///
/// `custom_message` is nullable on the wire: `Some(Null)` is a rule that
/// explicitly has no custom message, and sending it clears one.
pub(all) struct ActionMetadata {
  channel_id : ChannelId?
  duration_seconds : Int32?
  custom_message : Nullable[String]?
} derive(ToJson, FromJson, Debug)
