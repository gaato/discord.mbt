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
/// Users returned by the poll answer-voters endpoint.
pub(all) struct PollAnswerVoters {
  users : Array[User]
} derive(ToJson, FromJson, Debug)

///|
/// Poll definition attached when creating a message or executing a webhook.
/// Answers carry their media directly; Discord assigns the answer ids.
/// `duration` is the number of hours the poll stays open (up to 32 days,
/// default 24).
pub(all) struct PollCreateRequest {
  question : PollMedia
  answers : Array[PollMedia]
  duration : Int?
  allow_multiselect : Bool?
  layout_type : PollLayoutType?
} derive(Debug)

///|
/// Request-side poll media omits absent fields instead of sending nulls.
fn poll_media_request_json(media : PollMedia) -> Json {
  ObjBuilder().opt("text", media.text).opt("emoji", media.emoji).build()
}

///|
pub impl ToJson for PollCreateRequest with fn to_json(self) {
  ObjBuilder()
  .field("question", poll_media_request_json(self.question))
  .field(
    "answers",
    self.answers.map(media => {
      ({ "poll_media": poll_media_request_json(media) } : Json)
    }),
  )
  .opt("duration", self.duration)
  .opt("allow_multiselect", self.allow_multiselect)
  .opt("layout_type", self.layout_type)
  .build()
}

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
      raise JsonDecodeError(
        (path, "expected the presentation layout used by a poll (number)"),
      )
  }
}
