///|
/// An error raised when an interaction callback cannot be accepted.
pub(all) suberror ResponseGateError {
  AlreadyResponded
  Expired
  InvalidCallback(
    kind~ : @model.InteractionType,
    typ~ : @model.InteractionResponseType
  )
} derive(Debug)

///|
/// What has happened to an interaction's single initial callback.
pub(all) enum ResponseState {
  Pending
  Sent(@model.InteractionResponseType)
  /// The sink raised; Discord may or may not have accepted the callback.
  Unconfirmed(@model.InteractionResponseType)
  /// The executor gave up the callback window.
  Expired
} derive(Debug, Eq)

///|
/// A single-use interaction callback gate.
pub struct ResponseGate {
  priv kind : @model.InteractionType
  priv mut state : ResponseState
  priv sink : async (@model.InteractionResponse, Array[@dhttp.FileUpload]?) -> Unit
  priv rejected : (Error) -> Bool
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
/// `rejected` identifies definitive refusals that leave the callback unused.
/// Cancellation always leaves delivery unconfirmed, regardless of the classifier.
pub fn ResponseGate::ResponseGate(
  kind : @model.InteractionType,
  sink : async (@model.InteractionResponse, Array[@dhttp.FileUpload]?) -> Unit,
  rejected? : (Error) -> Bool = _ => false,
) -> ResponseGate {
  { kind, state: Pending, sink, rejected, }
}

///|
/// Construct a gate that delivers its callback through Discord's REST API.
pub fn ResponseGate::rest(
  client : @dhttp.Client,
  interaction : @model.Interaction,
) -> ResponseGate {
  ResponseGate(
    interaction.typ,
    (response, files) => {
      client.create_interaction_response(
        interaction.id,
        interaction.token,
        response,
        files?,
      )
    },
    rejected=error => {
      match error {
        @dhttp.DiscordHttpError::Validation(..) => true
        @dhttp.DiscordHttpError::Api(status~, error~) =>
          status >= 400 && status < 500 && status != 429 && error.code != 40060
        _ => false
      }
    },
  )
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
  match self.state {
    Pending => ()
    Expired => raise ResponseGateError::Expired
    Sent(_) | Unconfirmed(_) => raise ResponseGateError::AlreadyResponded
  }
  if !callback_allowed(self.kind, response.typ) {
    raise ResponseGateError::InvalidCallback(kind=self.kind, typ=response.typ)
  }
  self.state = Sent(response.typ)
  errdefer (if self.state is Sent(_) { self.state = Unconfirmed(response.typ) })
  (self.sink)(response, files) catch {
    error if !@async.is_being_cancelled() && (self.rejected)(error) => {
      self.state = Pending
      raise error
    }
    error => raise error
  }
}

///|
/// The current state of this interaction's initial callback.
pub fn ResponseGate::state(self : ResponseGate) -> ResponseState {
  self.state
}

///|
/// Close an unused callback window. Other states remain unchanged.
///
/// ```mbt check
/// test "expire an unused callback window" {
///   let gate = @framework.ResponseGate(ApplicationCommand, (_, _) => ())
///   assert_eq(gate.state(), Pending)
///   gate.expire()
///   assert_eq(gate.state(), Expired)
///   assert_true(gate.responded())
/// }
/// ```
pub fn ResponseGate::expire(self : ResponseGate) -> Unit {
  if self.state == Pending {
    self.state = Expired
  }
}

///|
/// Whether the initial callback is no longer pending, including expiry.
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
