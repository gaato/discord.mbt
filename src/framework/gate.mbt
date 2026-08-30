///|
/// An error raised when an interaction callback cannot be accepted.
pub(all) suberror ResponseGateError {
  AlreadyResponded
  InvalidCallback(
    kind~ : @model.InteractionType,
    typ~ : @model.InteractionResponseType
  )
} derive(Debug)

///|
priv enum ResponseGateState {
  Pending
  Sent
  Failed
} derive(Eq)

///|
/// A single-use interaction callback gate.
pub struct ResponseGate {
  priv kind : @model.InteractionType
  priv mut state : ResponseGateState
  priv sink : async (@model.InteractionResponse, Array[@dhttp.FileUpload]?) -> Unit
}

///|
/// A callback plus any multipart files captured by an in-memory gate.
pub(all) struct CapturedResponse {
  response : @model.InteractionResponse
  files : Array[@dhttp.FileUpload]?
}

///|
/// The receiving side of a capture gate.
pub struct ResponseCapture {
  priv queue : @aqueue.Queue[CapturedResponse]
}

///|
/// Construct a gate around an injected callback sink.
pub fn ResponseGate::ResponseGate(
  kind : @model.InteractionType,
  sink : async (@model.InteractionResponse, Array[@dhttp.FileUpload]?) -> Unit,
) -> ResponseGate {
  { kind, state: Pending, sink, }
}

///|
/// Construct a gate that delivers its callback through Discord's REST API.
pub fn ResponseGate::rest(
  client : @dhttp.Client,
  interaction : @model.Interaction,
) -> ResponseGate {
  ResponseGate(interaction.typ, (response, files) => {
    client.create_interaction_response(
      interaction.id,
      interaction.token,
      response,
      files?,
    )
  })
}

///|
/// Construct an in-memory gate and a receiver for the first callback value.
pub fn ResponseGate::capture(
  interaction : @model.Interaction,
) -> (ResponseGate, ResponseCapture) {
  let queue : @aqueue.Queue[CapturedResponse] = Queue(kind=Blocking(1))
  let capture = ResponseCapture::{ queue, }
  let gate = ResponseGate(interaction.typ, (response, files) => {
    queue.put({ response, files, })
  })
  (gate, capture)
}

///|
fn callback_allowed(
  kind : @model.InteractionType,
  typ : @model.InteractionResponseType,
) -> Bool {
  match kind {
    Ping => typ == Pong
    ApplicationCommand =>
      typ == ChannelMessageWithSource ||
      typ == DeferredChannelMessageWithSource ||
      typ == Modal ||
      typ == LaunchActivity
    MessageComponent =>
      typ == ChannelMessageWithSource ||
      typ == DeferredChannelMessageWithSource ||
      typ == DeferredUpdateMessage ||
      typ == UpdateMessage ||
      typ == Modal ||
      typ == LaunchActivity
    ApplicationCommandAutocomplete => typ == Autocomplete
    ModalSubmit =>
      typ == ChannelMessageWithSource ||
      typ == DeferredChannelMessageWithSource ||
      typ == DeferredUpdateMessage ||
      typ == UpdateMessage
    Unknown(_) => true
  }
}

///|
/// Validate and deliver the one allowed initial interaction callback.
pub async fn ResponseGate::send(
  self : ResponseGate,
  response : @model.InteractionResponse,
  files? : Array[@dhttp.FileUpload],
) -> Unit {
  if self.state != Pending {
    raise ResponseGateError::AlreadyResponded
  }
  if !callback_allowed(self.kind, response.typ) {
    raise ResponseGateError::InvalidCallback(kind=self.kind, typ=response.typ)
  }
  self.state = Sent
  errdefer {
    self.state = Failed
  }
  (self.sink)(response, files)
}

///|
/// Whether this gate has attempted its single callback delivery.
pub fn ResponseGate::responded(self : ResponseGate) -> Bool {
  self.state != Pending
}

///|
/// Wait for and remove the captured callback.
pub async fn ResponseCapture::get(self : ResponseCapture) -> CapturedResponse {
  self.queue.get()
}

///|
/// Remove the captured callback without waiting, if one is available.
pub fn ResponseCapture::try_get(
  self : ResponseCapture,
) -> CapturedResponse? raise {
  self.queue.try_get()
}
