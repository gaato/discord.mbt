///|
/// A guild's onboarding configuration.
pub(all) struct GuildOnboarding {
  guild_id : GuildId
  prompts : Array[OnboardingPrompt]
  default_channel_ids : Array[ChannelId]
  enabled : Bool
  mode : OnboardingMode
} derive(ToJson, FromJson, Debug)

///|
/// A question presented during guild onboarding.
pub(all) struct OnboardingPrompt {
  id : GenericId
  typ : OnboardingPromptType
  options : Array[OnboardingPromptOption]
  title : String
  single_select : Bool
  required : Bool
  in_onboarding : Bool
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// A selectable answer to an onboarding prompt.
pub(all) struct OnboardingPromptOption {
  id : GenericId
  channel_ids : Array[ChannelId]
  role_ids : Array[RoleId]
  emoji : Emoji?
  emoji_id : EmojiId?
  emoji_name : String?
  emoji_animated : Bool?
  title : String
  description : Nullable[String]
} derive(ToJson, FromJson, Debug)

///|
/// The input control used by an onboarding prompt.
pub(all) enum OnboardingPromptType {
  MultipleChoice
  Dropdown
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn OnboardingPromptType::to_int(self : OnboardingPromptType) -> Int {
  match self {
    MultipleChoice => 0
    Dropdown => 1
    Unknown(value) => value
  }
}

///|
pub fn OnboardingPromptType::from_int(value : Int) -> OnboardingPromptType {
  match value {
    0 => MultipleChoice
    1 => Dropdown
    value => Unknown(value)
  }
}

///|
pub impl ToJson for OnboardingPromptType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for OnboardingPromptType with fn from_json(json, path) {
  match json {
    Number(value, ..) => OnboardingPromptType::from_int(value.to_int())
    _ =>
      raise JsonDecodeError((path, "expected onboarding prompt type (number)"))
  }
}

///|
/// How extensively onboarding is configured for a guild.
pub(all) enum OnboardingMode {
  Default
  Advanced
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn OnboardingMode::to_int(self : OnboardingMode) -> Int {
  match self {
    Default => 0
    Advanced => 1
    Unknown(value) => value
  }
}

///|
pub fn OnboardingMode::from_int(value : Int) -> OnboardingMode {
  match value {
    0 => Default
    1 => Advanced
    value => Unknown(value)
  }
}

///|
pub impl ToJson for OnboardingMode with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for OnboardingMode with fn from_json(json, path) {
  match json {
    Number(value, ..) => OnboardingMode::from_int(value.to_int())
    _ => raise JsonDecodeError((path, "expected onboarding mode (number)"))
  }
}
