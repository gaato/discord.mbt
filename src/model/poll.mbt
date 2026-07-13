///|
/// A poll attached to a Discord message.
pub(all) struct Poll {
  question : PollMedia
  answers : Array[PollAnswer]
  expiry : Nullable[Timestamp]
  allow_multiselect : Bool
  layout_type : PollLayoutType
  results : PollResults?
} derive(ToJson, FromJson, Debug)

///|
/// Text and emoji content used by a poll question or answer.
pub(all) struct PollMedia {
  text : String?
  emoji : Emoji?
} derive(ToJson, FromJson, Debug)

///|
/// A selectable answer in a poll.
pub(all) struct PollAnswer {
  answer_id : Int
  poll_media : PollMedia
} derive(ToJson, FromJson, Debug)

///|
/// Aggregated results for a poll.
pub(all) struct PollResults {
  is_finalized : Bool
  answer_counts : Array[PollAnswerCount]
} derive(ToJson, FromJson, Debug)

///|
/// Vote count and current-user state for one poll answer.
pub(all) struct PollAnswerCount {
  id : Int
  count : Int
  me_voted : Bool
} derive(ToJson, FromJson, Debug)

///|
/// The presentation layout used by a poll.
pub(all) enum PollLayoutType {
  Default
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn PollLayoutType::to_int(self : PollLayoutType) -> Int {
  match self {
    Default => 1
    Unknown(value) => value
  }
}

///|
pub fn PollLayoutType::from_int(value : Int) -> PollLayoutType {
  match value {
    1 => Default
    value => Unknown(value)
  }
}

///|
pub impl ToJson for PollLayoutType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for PollLayoutType with fn from_json(json, path) {
  match json {
    Number(value, ..) => PollLayoutType::from_int(value.to_int())
    _ =>
      raise @json.JsonDecodeError(
        (path, "expected the presentation layout used by a poll (number)"),
      )
  }
}
