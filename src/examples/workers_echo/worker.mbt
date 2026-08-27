///|
#external
pub type WorkerResponse

///|
extern "js" fn WorkerResponse::WorkerResponse(
  kind : String,
  body : String,
  content_type : String,
) -> Self =
  #| (kind, body, contentType) => ({
  #|   kind,
  #|   body,
  #|   contentType,
  #|   stream: null,
  #| })

///|
extern "js" fn utf8_encode(text : String) -> Bytes =
  #| (text) => new TextEncoder().encode(text)

///|
extern "js" fn WorkerResponse::multipart(
  kind : String,
  content_type : String,
  chunks : FixedArray[Bytes],
) -> Self =
  #| (kind, contentType, chunks) => {
  #|   let pending = chunks;
  #|   let index = 0;
  #|   const stream = new ReadableStream({
  #|     pull(controller) {
  #|       if (index >= pending.length) {
  #|         controller.close();
  #|         pending = [];
  #|         return;
  #|       }
  #|       controller.enqueue(pending[index]);
  #|       index += 1;
  #|       if (index >= pending.length) {
  #|         controller.close();
  #|         pending = [];
  #|       }
  #|     },
  #|     cancel() {
  #|       pending = [];
  #|       index = 0;
  #|     },
  #|   });
  #|   return { kind, body: "", contentType, stream };
  #| }

///|
pub extern "js" fn WorkerResponse::kind(self : Self) -> String =
  #| (response) => response.kind

///|
pub extern "js" fn WorkerResponse::body(self : Self) -> String =
  #| (response) => response.body

///|
pub extern "js" fn WorkerResponse::content_type(self : Self) -> String =
  #| (response) => response.contentType

///|
#external
pub type WorkerDispatch

///|
extern "js" fn WorkerDispatch::WorkerDispatch(
  response : @js_async.Promise[WorkerResponse],
  background : @js_async.Promise[Unit],
) -> Self =
  #| (response, background) => ({ response, background })

///|
pub extern "js" fn WorkerDispatch::response(
  self : Self,
) -> @js_async.Promise[WorkerResponse] =
  #| (dispatch) => dispatch.response

///|
pub extern "js" fn WorkerDispatch::background(
  self : Self,
) -> @js_async.Promise[Unit] =
  #| (dispatch) => dispatch.background

///|
fn encode_outcome(
  outcome : @discord.InteractionOutcome,
) -> WorkerResponse raise @dhttp.DiscordHttpError {
  match outcome {
    Reply(response~, files=None) =>
      WorkerResponse(
        "Reply",
        response.to_json().stringify(),
        "application/json",
      )
    Reply(response~, files=Some(files)) => {
      let (content_type, parts) = @dhttp.encode_multipart_body(
        response.to_json().stringify(),
        files,
      )
      let chunks : Array[Bytes] = []
      for part in parts {
        match part {
          Text(text) => chunks.push(utf8_encode(text))
          Blob(bytes) => chunks.push(bytes)
        }
      }
      WorkerResponse::multipart(
        "Reply",
        content_type,
        FixedArray::from_array(chunks),
      )
    }
    NoRoute => WorkerResponse("NoRoute", "", "text/plain; charset=utf-8")
    NoResponse => WorkerResponse("NoResponse", "", "")
    TimedOut => WorkerResponse("TimedOut", "", "text/plain; charset=utf-8")
  }
}

///|
async fn run_interaction(
  token : String,
  body : String,
  responses : @aqueue.Queue[WorkerResponse],
) -> Unit {
  let mut response_sent = false
  errdefer @async.protect_from_cancel(() => {
    if !response_sent {
      responses.put(
        WorkerResponse("DispatchFailed", "", "text/plain; charset=utf-8"),
      )
    }
  })
  @async.with_task_group(group => {
    let interaction : @model.Interaction = @json.from_json(@json.parse(body)) catch {
      _ => {
        responses.put(
          WorkerResponse("InvalidPayload", "", "text/plain; charset=utf-8"),
        )
        response_sent = true
        return
      }
    }
    let client = @discord.Client(token)
    group.add_defer(() => client.close())
    let endpoint = worker_app().serve(
      group,
      client~,
      application_id=interaction.application_id,
      sync=false,
    )
    responses.put(encode_outcome(endpoint.handle_interaction(interaction)))
    response_sent = true
  })
}

///|
extern "js" fn abort_signal_aborted(signal : @js_async.AbortSignal) -> Bool =
  #| (signal) => signal.aborted

///|
extern "js" fn rejected_abort_response(
  signal : @js_async.AbortSignal,
) -> @js_async.Promise[WorkerResponse] =
  #| (signal) => Promise.reject(
  #|   signal.reason ?? new DOMException("The operation was aborted", "AbortError"),
  #| )

///|
/// Start one interaction dispatch as two JavaScript promises.
///
/// The `response` property resolves with `{ kind, body }` as soon as the
/// initial Discord callback is known. The `background` property resolves only
/// after the endpoint's task group and every deferred handler have completed.
pub fn start_interaction(
  token : String,
  body : String,
  abort_signal : @js_async.AbortSignal,
) -> WorkerDispatch {
  let responses : @aqueue.Queue[WorkerResponse] = Queue(kind=Unbounded)
  let background = @js_async.Promise::from_async(() => {
    run_interaction(token, body, responses)
  })
  // A client disconnect only cancels the initial-response waiter. The task
  // group belongs to the waitUntil background promise and must keep running
  // so deferred handlers can finish after the HTTP request ends.
  let response = if abort_signal_aborted(abort_signal) {
    rejected_abort_response(abort_signal)
  } else {
    @js_async.Promise::from_async(() => responses.get(), abort_signal~)
  }
  WorkerDispatch(response, background)
}

///|
priv struct CachedInteractionVerifier {
  public_key : String
  verifier : @discord.InteractionVerifier
}

///|
let interaction_verifier_cache : Ref[CachedInteractionVerifier?] = Ref(None)

///|
fn cached_interaction_verifier(
  public_key : String,
) -> @discord.InteractionVerifier? {
  match interaction_verifier_cache.val {
    Some(cached) if cached.public_key == public_key => Some(cached.verifier)
    _ => {
      let verifier = @discord.InteractionVerifier::new(public_key) catch {
        _ => return None
      }
      interaction_verifier_cache.val = Some({ public_key, verifier })
      Some(verifier)
    }
  }
}

///|
/// Verify raw request bytes with a key-aware reusable verifier cache.
pub fn verify_signature(
  public_key : String,
  signature : String,
  timestamp : String,
  body : Bytes,
) -> Bool {
  guard cached_interaction_verifier(public_key) is Some(verifier) else {
    return false
  }
  verifier.verify(signature~, timestamp~, body~)
}
