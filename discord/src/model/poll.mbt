///|
/// A poll attached to a Discord message.
#derive(ToJson, FromJson, Debug)
pub(all) struct Poll {
  question : PollMedia
  answers : Array[PollAnswer]
  expiry : Nullable[Timestamp]
  allow_multiselect : Bool
  layout_type : PollLayoutType
  results : PollResults?
}

///|
/// Text and emoji content used by a poll question or answer.
#derive(ToJson, FromJson, Debug)
pub(all) struct PollMedia {
  text : String?
  emoji : Emoji?
}

///|
/// A selectable answer in a poll.
#derive(ToJson, FromJson, Debug)
pub(all) struct PollAnswer {
  answer_id : Int32
  poll_media : PollMedia
}

///|
/// Aggregated results for a poll.
#derive(ToJson, FromJson, Debug)
pub(all) struct PollResults {
  is_finalized : Bool
  answer_counts : Array[PollAnswerCount]
}

///|
/// Vote count and current-user state for one poll answer.
#derive(ToJson, FromJson, Debug)
pub(all) struct PollAnswerCount {
  id : Int32
  count : Int32
  me_voted : Bool
}

///|
/// Users returned by the poll answer-voters endpoint.
#derive(ToJson, FromJson, Debug)
pub(all) struct PollAnswerVoters {
  users : Array[User]
}

///|
/// Poll definition attached when creating a message or executing a webhook.
/// Answers carry their media directly; Discord assigns the answer ids.
/// `duration` is the number of hours the poll stays open (up to 32 days,
/// default 24).
#derive(Debug)
pub(all) struct PollCreateRequest {
  question : PollMedia
  answers : Array[PollMedia]
  duration : Int32?
  allow_multiselect : Bool?
  layout_type : PollLayoutType?
}

///|
/// Request-side poll media omits absent fields instead of sending nulls.
fn poll_media_request_json(media : PollMedia) -> Json {
  @sdkjson.ObjBuilder::new()
  .opt("text", media.text)
  .opt("emoji", media.emoji)
  .build()
}

///|
/// Encodes the poll create request as its Discord JSON representation.
pub impl ToJson for PollCreateRequest with fn to_json(self) {
  @sdkjson.ObjBuilder::new()
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
#derive(Eq, Debug)
#non_exhaustive
pub(all) enum PollLayoutType {
  Default
  Unknown(Int32)
}

///|
/// The Discord integer value of this `PollLayoutType`.
pub fn PollLayoutType::to_int(self : PollLayoutType) -> Int32 {
  match self {
    Default => 1
    Unknown(value) => value
  }
}

///|
/// The `PollLayoutType` for its Discord integer value; unknown values become `Unknown(n)`.
pub fn PollLayoutType::from_int(value : Int32) -> PollLayoutType {
  match value {
    1 => Default
    value => Unknown(value)
  }
}

///|
/// Encodes the `PollLayoutType` as its Discord integer value.
pub impl ToJson for PollLayoutType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
/// Decodes the `PollLayoutType` from a JSON number; unknown values become `Unknown(n)`.
pub impl @json.FromJson for PollLayoutType with fn from_json(json, path) {
  match json {
    Number(value, ..) => PollLayoutType::from_int(value.to_int())
    _ =>
      raise JsonDecodeError(
        (path, "expected the presentation layout used by a poll (number)"),
      )
  }
}
