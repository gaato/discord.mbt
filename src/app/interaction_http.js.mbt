///|
/// A JavaScript `{ response, background }` object for one interaction dispatch.
#external
pub type InteractionHttpDispatch

///|
extern "js" fn js_dispatch(
  response : @js_async.Promise[InteractionHttpJsResponse],
  background : @js_async.Promise[Unit],
) -> InteractionHttpDispatch =
  #| (response, background) => ({ response, background })

///|
pub extern "js" fn InteractionHttpDispatch::response(
  self : Self,
) -> @js_async.Promise[InteractionHttpJsResponse] =
  #| (dispatch) => dispatch.response

///|
pub extern "js" fn InteractionHttpDispatch::background(
  self : Self,
) -> @js_async.Promise[Unit] =
  #| (dispatch) => dispatch.background

///|
/// `{ status: number, contentType: string | null, body: Uint8Array | ReadableStream | null }`.
#external
pub type InteractionHttpJsResponse

///|
extern "js" fn js_empty_response(status : Int) -> InteractionHttpJsResponse =
  #| (status) => ({ status, contentType: null, body: null })

///|
extern "js" fn js_bytes_response(
  status : Int,
  content_type : String,
  body : Bytes,
) -> InteractionHttpJsResponse =
  #| (status, contentType, body) => ({
  #|   status,
  #|   contentType: contentType === "" ? null : contentType,
  #|   body,
  #| })

///|
extern "js" fn js_stream_response(
  status : Int,
  content_type : String,
  chunks : FixedArray[Bytes],
) -> InteractionHttpJsResponse =
  #| (status, contentType, chunks) => {
  #|   let index = 0;
  #|   const stream = new ReadableStream({
  #|     pull(controller) {
  #|       if (index >= chunks.length) return controller.close();
  #|       controller.enqueue(chunks[index++]);
  #|     },
  #|   });
  #|   return {
  #|     status,
  #|     contentType: contentType === "" ? null : contentType,
  #|     body: stream,
  #|   };
  #| }

///|
extern "js" fn js_signal_aborted(signal : @js_async.AbortSignal) -> Bool =
  #| (signal) => signal.aborted

///|
extern "js" fn js_rejected_response(
  signal : @js_async.AbortSignal,
) -> @js_async.Promise[InteractionHttpJsResponse] =
  #| (signal) => Promise.reject(
  #|   signal.reason ?? new DOMException("The operation was aborted", "AbortError"),
  #| )

///|
fn encode_js_response(
  response : InteractionHttpResponse,
) -> InteractionHttpJsResponse {
  let content_type = response.content_type.unwrap_or("")
  match response.body {
    Empty => js_empty_response(response.status)
    Bytes(body) => js_bytes_response(response.status, content_type, body)
    Chunks(chunks) => {
      let parts : Array[Bytes] = []
      for chunk in chunks {
        match chunk {
          Text(text) => parts.push(@utf8.encode(text))
          Blob(bytes) => parts.push(bytes)
        }
      }
      js_stream_response(
        response.status,
        content_type,
        FixedArray::from_array(parts),
      )
    }
  }
}

///|
priv struct CachedInteractionVerifier {
  public_key : String
  verifier : @verify.InteractionVerifier
}

///|
let interaction_verifier_cache : Ref[CachedInteractionVerifier?] = Ref(None)

///|
fn cached_interaction_verifier(
  public_key : String,
) -> @verify.InteractionVerifier? {
  match interaction_verifier_cache.val {
    Some(cached) if cached.public_key == public_key => Some(cached.verifier)
    _ => {
      let verifier = @verify.InteractionVerifier::new(public_key) catch {
        _ => return None
      }
      interaction_verifier_cache.val = Some({ public_key, verifier, })
      Some(verifier)
    }
  }
}

///|
async fn run_signed_http(
  app : App,
  request : InteractionHttpRequest,
  responses : @aqueue.Queue[InteractionHttpJsResponse],
  token : String,
  application_id : @model.ApplicationId,
  public_key : String,
  api_base_url : String?,
  deadline_ms : Int?,
) -> Unit {
  let mut response_sent = false
  errdefer @async.protect_from_cancel(() => {
    if !response_sent {
      responses.put(
        js_bytes_response(
          500,
          "text/plain; charset=utf-8",
          @utf8.encode("internal server error"),
        ),
      )
    }
  })
  @async.with_task_group(group => {
    guard cached_interaction_verifier(public_key) is Some(verifier) else {
      responses.put(
        js_bytes_response(
          401,
          "text/plain; charset=utf-8",
          @utf8.encode("invalid signature"),
        ),
      )
      response_sent = true
      return
    }
    let client = @dhttp.Client(token, base_url?=api_base_url)
    group.add_defer(() => client.close())
    let endpoint = app.serve(group, client~, application_id~)
    responses.put(
      encode_js_response(
        endpoint.handle_signed_http(request, verifier, deadline_ms?),
      ),
    )
    response_sent = true
  })
}

///|
/// Dispatch one signed interaction request as two JavaScript promises.
///
/// Both promises are created synchronously at call time, so a host that must
/// register `waitUntil` before awaiting anything (Fastly, for example) can
/// hand `background` to the runtime first and await `response` afterwards.
///
/// `response` carries the initial Discord callback and is the only half that
/// `abort_signal` cancels: a client disconnect rejects it while `background`
/// keeps running until the dispatch task group and every deferred handler
/// have finished.
///
/// The dispatch owns one REST `Client` built from `token` and `api_base_url`
/// and closes it when the group ends, so connections are never reused across
/// dispatches. `public_key` is expanded into a cached
/// `@verify.InteractionVerifier` — a single process-wide entry keyed by the
/// key string; an unusable key answers 401 and is not cached. Passing
/// `application_id` is required so the dispatch makes no startup request.
pub fn App::start_signed_http(
  self : App,
  request : InteractionHttpRequest,
  token~ : String,
  application_id~ : @model.ApplicationId,
  public_key~ : String,
  api_base_url? : String,
  deadline_ms? : Int,
  abort_signal? : @js_async.AbortSignal,
) -> InteractionHttpDispatch {
  let responses : @aqueue.Queue[InteractionHttpJsResponse] = Queue(
    kind=Unbounded,
  )
  let background = @js_async.Promise::from_async(() => {
    run_signed_http(
      self, request, responses, token, application_id, public_key, api_base_url,
      deadline_ms,
    )
  })
  // A client disconnect only cancels the initial-response waiter; the task
  // group belongs to the background promise so deferred handlers can finish
  // after the HTTP request ends.
  let response = if abort_signal is Some(signal) && js_signal_aborted(signal) {
    js_rejected_response(signal)
  } else {
    @js_async.Promise::from_async(() => responses.get(), abort_signal?)
  }
  js_dispatch(response, background)
}
