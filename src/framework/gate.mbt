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
/// How a failed callback delivery left the interaction's callback window.
pub(all) enum DeliveryFailure {
  /// Discord definitively refused the callback; the window is still unused.
  Rejected
  /// Discord no longer accepts any initial callback for this interaction.
  Expired
  /// Discord may or may not have accepted the callback.
  Uncertain
} derive(Debug, Eq)

///|
/// A single-use interaction callback gate.
pub struct ResponseGate {
  priv kind : @model.InteractionType
  priv mut state : ResponseState
  priv sink : async (@model.InteractionResponse, Array[@dhttp.FileUpload]?) -> Unit
  priv classify : (Error) -> DeliveryFailure
  priv deadline_at : Int64?
  priv mut placeholder_open : Bool
  priv mut in_flight : Bool
  priv settled : @cond_var.Cond
  priv reply_lock : @async.Mutex
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
/// The default initial-response budget in milliseconds, measured from the
/// moment an executor receives an interaction. Discord invalidates the
/// interaction token three seconds after sending it; the remaining 500 ms
/// absorb delivery latency.
pub const DEFAULT_INTERACTION_DEADLINE_MS : Int = 2500

///|
/// Construct a gate around an injected callback sink.
///
/// `classify` decides how a failed delivery leaves the callback window; it
/// defaults to `Uncertain`. Cancellation is always `Uncertain`, regardless of
/// the classifier. With `deadline_ms`, the window closes that many
/// milliseconds after construction: a later `send` expires the gate instead
/// of contacting Discord.
pub fn ResponseGate::ResponseGate(
  kind : @model.InteractionType,
  sink : async (@model.InteractionResponse, Array[@dhttp.FileUpload]?) -> Unit,
  classify? : (Error) -> DeliveryFailure = _ => Uncertain,
  deadline_ms? : Int,
) -> ResponseGate {
  {
    kind,
    state: Pending,
    sink,
    classify,
    deadline_at: deadline_ms.map(ms => @clock.now_ms() + ms.to_int64()),
    placeholder_open: false,
    in_flight: false,
    settled: @cond_var.Cond(),
    reply_lock: @async.Mutex(),
  }
}

///|
/// Classify a failed `POST /interactions/{id}/{token}/callback`.
///
/// Unknown Interaction (10062) closes the window. Already Acknowledged (40060),
/// rate limits, server errors, and transport failures are uncertain. Other
/// client errors are definitive refusals of that payload.
pub fn classify_rest_callback_failure(error : Error) -> DeliveryFailure {
  match error {
    @dhttp.DiscordHttpError::Validation(..) => Rejected
    @dhttp.DiscordHttpError::Api(status~, error~) =>
      if error.code == 10062 {
        Expired
      } else if status >= 400 &&
        status < 500 &&
        status != 429 &&
        error.code != 40060 {
        Rejected
      } else {
        Uncertain
      }
    _ => Uncertain
  }
}

///|
/// Construct a gate that delivers its callback through Discord's REST API.
/// The deadline is measured from this call, so construct the gate as soon as
/// the interaction arrives.
pub fn ResponseGate::rest(
  client : @dhttp.Client,
  interaction : @model.Interaction,
  deadline_ms? : Int = DEFAULT_INTERACTION_DEADLINE_MS,
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
    classify=classify_rest_callback_failure,
    deadline_ms~,
  )
}

///|
/// Construct an in-memory gate and a receiver for the first callback value.
/// The deadline is measured from this call.
pub fn ResponseGate::capture(
  interaction : @model.Interaction,
  deadline_ms? : Int = DEFAULT_INTERACTION_DEADLINE_MS,
) -> (ResponseGate, ResponseCapture) {
  let queue : @aqueue.Queue[CapturedResponse] = Queue(kind=Blocking(1))
  let capture = ResponseCapture::{ queue, }
  let gate = ResponseGate(
    interaction.typ,
    (response, files) => queue.put({ response, files, }),
    deadline_ms~,
  )
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
/// A call made while another callback is being delivered waits for that
/// delivery to settle, then observes its outcome.
pub async fn ResponseGate::send(
  self : ResponseGate,
  response : @model.InteractionResponse,
  files? : Array[@dhttp.FileUpload],
) -> Unit {
  self.wait_settled()
  match self.state() {
    Pending => ()
    Expired => raise ResponseGateError::Expired
    Sent(_) | Unconfirmed(_) => raise ResponseGateError::AlreadyResponded
  }
  if !callback_allowed(self.kind, response.typ) {
    raise ResponseGateError::InvalidCallback(kind=self.kind, typ=response.typ)
  }
  self.state = Sent(response.typ)
  // Mark the placeholder before the sink runs so a concurrent `reply` never
  // mistakes an in-flight deferral for a plain message.
  self.placeholder_open = response.typ == DeferredChannelMessageWithSource
  self.in_flight = true
  defer {
    self.in_flight = false
    self.settled.broadcast()
  }
  errdefer (if self.state is Sent(_) { self.state = Unconfirmed(response.typ) })
  (self.sink)(response, files) catch {
    error if @async.is_being_cancelled() => raise error
    error => {
      match (self.classify)(error) {
        Rejected => {
          self.state = Pending
          self.placeholder_open = false
        }
        Expired => {
          self.state = Expired
          self.placeholder_open = false
        }
        Uncertain => ()
      }
      raise error
    }
  }
}

///|
/// Run one follow-up reply at a time. A reply decides between editing the
/// placeholder and sending a followup, then performs the request; without
/// this, two concurrent replies could both see the placeholder open and the
/// second edit would overwrite the first reply.
async fn[T] ResponseGate::exclusive_reply(
  self : ResponseGate,
  body : async () -> T,
) -> T {
  self.reply_lock.acquire()
  defer self.reply_lock.release()
  body()
}

///|
/// Wait until no initial callback is being delivered. Follow-up operations
/// call this so they never race an in-flight callback.
async fn ResponseGate::wait_settled(self : ResponseGate) -> Unit {
  while self.in_flight {
    self.settled.wait()
  }
}

///|
/// Milliseconds left before the callback window closes, clamped at zero, or
/// `None` when this gate has no deadline.
pub fn ResponseGate::remaining_ms(self : ResponseGate) -> Int? {
  match self.deadline_at {
    None => None
    Some(deadline) => {
      let left = deadline - @clock.now_ms()
      Some(if left <= 0L { 0 } else { left.to_int() })
    }
  }
}

///|
/// Whether a deferred message's loading placeholder is still showing: the
/// callback was `DeferredChannelMessageWithSource` and the original response
/// has not been edited, deleted, or answered with a followup since.
pub fn ResponseGate::placeholder_open(self : ResponseGate) -> Bool {
  self.placeholder_open
}

///|
/// Record that the original response no longer shows the deferred
/// placeholder. Response helpers call this after editing or deleting the
/// original response, or after sending a followup.
pub fn ResponseGate::close_placeholder(self : ResponseGate) -> Unit {
  self.placeholder_open = false
}

///|
/// The current state of this interaction's initial callback. A pending
/// callback whose deadline has passed reads as `Expired`.
pub fn ResponseGate::state(self : ResponseGate) -> ResponseState {
  if self.state == Pending && self.remaining_ms() is Some(0) {
    self.state = Expired
  }
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
///   assert_false(gate.is_pending())
/// }
/// ```
pub fn ResponseGate::expire(self : ResponseGate) -> Unit {
  if self.state == Pending {
    self.state = Expired
  }
}

///|
/// Whether the initial callback can still be sent.
pub fn ResponseGate::is_pending(self : ResponseGate) -> Bool {
  self.state() == Pending
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
