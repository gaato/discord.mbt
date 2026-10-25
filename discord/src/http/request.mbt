///|
/// The headers every call to `route` carries before the caller's own.
///
/// Discord reads `X-Audit-Log-Reason` as URL-encoded UTF-8, so the reason
/// (validated in `validate_request`) is percent-encoded here. A reason set
/// directly through the caller's `headers` is sent as is.
fn base_headers(
  token : String,
  route : Route,
  audit_reason : String?,
) -> Map[String, String] {
  let headers : Map[String, String] = {
    "user-agent": "DiscordBot (https://github.com/gaato/discord.mbt, \{VERSION})",
    "accept": "application/json",
  }
  if route.needs_auth() {
    headers["authorization"] = "Bot \{token}"
  }
  if audit_reason is Some(reason) {
    headers["x-audit-log-reason"] = @ghttp.percent_encode(reason)
  }
  headers
}

///|
fn wire_method(meth : @ahttp.RequestMethod) -> String {
  match meth {
    Get => "GET"
    Head => "HEAD"
    Post => "POST"
    Put => "PUT"
    Delete => "DELETE"
    Connect => "CONNECT"
    Options => "OPTIONS"
    Trace => "TRACE"
    Patch => "PATCH"
  }
}

///|
/// The telemetry spelling of a wire method: `GET` is reported as `Get`.
fn method_name(wire : String) -> String {
  match wire {
    "" => ""
    _ => wire[:1].to_owned().to_upper() + wire[1:].to_owned().to_lower()
  }
}

///|
/// Retry delay and scope of a 429 response: the body's `retry_after` (in
/// seconds, the more precise source), then the `Retry-After-Ms` or
/// `Retry-After` header, then one second; `global` when the
/// `X-RateLimit-Global` header or `X-RateLimit-Scope: global` says the whole
/// account is limited.
fn rate_limit_from_json(headers : @ghttp.Headers, body : Json) -> (Int64, Bool) {
  let global = headers.get("x-ratelimit-global") is Some(_) ||
    headers.get("x-ratelimit-scope").map(value => value.trim().to_lower()) ==
    Some("global")
  let retry_after_ms : Int64 = match body {
    { "retry_after": Number(seconds, ..), .. } => (seconds * 1000.0).to_int64()
    _ =>
      match @ghttp.retry_after_ms(headers) {
        Some(ms) => ms.to_int64()
        None => 1000L
      }
  }
  (retry_after_ms, global)
}

///|
/// `rate_limit_from_json` for a wire body; one that is not JSON counts as no
/// body.
fn rate_limit_details(headers : @ghttp.Headers, body : Bytes) -> (Int64, Bool) {
  rate_limit_from_json(headers, json_body(body).unwrap_or(Json::null()))
}

///|
/// Build the wire request for one logical call: base headers, caller
/// headers, and the JSON or multipart body the route takes.
fn Client::wire_request(
  self : Client,
  request : HttpRequest,
) -> WireRequest raise DiscordHttpError {
  let route = request.route
  let headers = base_headers(self.token, route, request.audit_reason)
  headers.merge_in_place(request.headers)
  let mut wire = @ghttp.Request::new(
    @ghttp.Method::parse(wire_method(route.method_())),
    self.base_url + self.base_path + route.path(),
  )
  for name, value in headers {
    wire = { ..wire, headers: wire.headers.set(name, value), }
  }
  // Only the client decides that a call is safe to resend.
  wire = { ..wire, headers: wire.headers.remove(REPLAY_SAFE_HEADER), }
  if is_replay_safe(route, request.body) {
    wire = wire.header(REPLAY_SAFE_HEADER, "1")
  }
  match (route, request.files, request.body) {
    (CreateGuildSticker(..), Some([file]), Some(json)) =>
      multipart_request(
        wire,
        form_parts(sticker_form_fields(json), "file", file),
      )
    (CreateChannelInvite(..), Some([file]), Some(json)) =>
      multipart_request(wire, [
        payload_part(json.stringify()),
        file_part("target_users_file", file),
      ])
    (UpdateInviteTargetUsers(..), Some([file]), None) =>
      multipart_request(wire, [file_part("target_users_file", file)])
    (_, Some(fs), _) if fs.length() > 0 =>
      multipart_request(
        wire,
        upload_parts(
          request.body.unwrap_or(Json::empty_object()).stringify(),
          fs,
        ),
      )
    (_, _, Some(json)) => {
      wire = wire.header("content-type", "application/json")
      { head: wire.body_bytes(@utf8.encode(json.stringify())), body: None, }
    }
    (_, _, None) => { head: wire, body: None, }
  }
}

///|
/// Whether sending `route` with `body` twice has the effect of sending it
/// once although its method is not idempotent: a message create with a
/// `nonce` and `enforce_nonce: true`. Discord then checks the nonce against
/// the author's messages of the past few minutes and returns the existing
/// message instead of creating a second one ("Create Message" in Discord's
/// documentation), so a create whose response was lost can be sent again.
fn is_replay_safe(route : Route, body : Json?) -> Bool {
  route is CreateMessage(..) &&
  body is Some({ "nonce": String(_) | Number(_), "enforce_nonce": True, .. })
}

///|
/// A wire request: its head, and its body when that is built only after
/// rate-limit admission (a multipart upload's).
priv struct WireRequest {
  head : @ghttp.Request
  body : (() -> Bytes)?
}

///|
/// The logical response for one wire response, before status-code-to-error
/// mapping: lowercase header names and a JSON body.
fn decode_response(
  status : Int32,
  headers : @ghttp.Headers,
  body : Bytes,
) -> HttpResponse {
  let lower_headers : Map[String, String] = Map([])
  for pair in headers.iter() {
    lower_headers[pair.0] = pair.1
  }
  let body_json = if status == 204 {
    Json::null()
  } else {
    // A body that is not valid JSON (proxy error pages, empty replies) is
    // preserved as a JSON string so error paths can report its content.
    let text = @utf8.decode(body) catch { _ => @utf8.decode_lossy(body) }
    @json.parse(text) catch {
      _ => Json::string(text)
    }
  }
  { status, headers: lower_headers, body: body_json, }
}

///|
/// The `ApiError` an error response carries: its decoded body, or a message
/// holding the status and the body as received.
fn api_error_of(response : HttpResponse) -> ApiError {
  @json.from_json(response.body) catch {
    _ => {
      // Non-JSON bodies (proxy HTML, empty strings) surface verbatim so
      // the user-visible error keeps whatever the server actually said.
      let detail = match response.body {
        String(text) => text
        body => body.stringify()
      }
      { code: 0, message: "HTTP \{response.status}: \{detail}", errors: None, }
    }
  }
}

///|
/// Send a request through the rate limiter, retrying on 429 (bounded).
///
/// This is also the raw escape hatch: typed endpoint wrappers build a `Route`
/// plus JSON body and decode the returned JSON, while unwrapped endpoints use
/// `Route::custom`. Optional `headers` are merged after the client's base
/// headers, so caller-supplied values such as `authorization` take precedence.
///
/// `request_timeout_ms` bounds each network attempt, including reading its
/// response body. Rate-limit waits, retry back-off, and user middleware are
/// outside it. A failed or timed-out attempt is resent only when it proves
/// nothing reached Discord (`DiscordHttpError::is_unsent`); otherwise it
/// raises `Transport` or `Timeout` at once, because Discord may already have
/// acted on it. For a whole-operation deadline, compose `@async.with_timeout`
/// around the call.
pub async fn Client::request(
  self : Client,
  route : Route,
  body? : Json,
  audit_reason? : String,
  files? : Array[FileUpload],
  headers? : Map[String, String],
) -> Json raise DiscordHttpError {
  let request = HttpRequest::{
    route,
    body,
    audit_reason,
    files,
    headers: headers.unwrap_or(Map([])),
  }
  let response = self.run_middleware(0, request) catch {
    error => {
      if @async.is_being_cancelled() {
        // Resume cancellation at this typed-error boundary before mapping errors.
        @async.pause()
      }
      match error {
        DiscordHttpError::Api(status~, error~) => raise Api(status~, error~)
        DiscordHttpError::RateLimited(retry_after_ms~, global~) =>
          raise RateLimited(retry_after_ms~, global~)
        DiscordHttpError::Deserialize(message~) => raise Deserialize(message~)
        DiscordHttpError::Transport(phase~, message~) =>
          raise Transport(phase~, message~)
        DiscordHttpError::Timeout(phase~, timeout_ms~) =>
          raise Timeout(phase~, timeout_ms~)
        DiscordHttpError::Validation(message~) => raise Validation(message~)
        // Middleware or an offline handler raised something else: nothing
        // says whether the request had gone out.
        error => raise Transport(phase=Unknown, message="\{Repr(error)}")
      }
    }
  }
  if response.status >= 400 {
    raise Api(status=response.status, error=api_error_of(response))
  }
  response.body
}

///|
/// Client-side checks on a request about to be sent: file names, the audit
/// reason's length (Discord accepts 1-512 characters), and the file and body
/// shape of the routes that upload in a fixed form.
fn validate_request(request : HttpRequest) -> Unit raise DiscordHttpError {
  if request.files is Some(files) {
    validate_files(files)
  }
  validate_length("audit_reason", request.audit_reason, min=1, max=512)
  match (request.route, request.files, request.body) {
    (CreateGuildSticker(..), Some([_]), Some(body)) =>
      ignore(sticker_form_fields(body))
    (CreateGuildSticker(..), _, _) =>
      raise Validation(
        message="create guild sticker requires exactly one file and form fields",
      )
    (UpdateInviteTargetUsers(..), Some([_]), None) => ()
    (UpdateInviteTargetUsers(..), _, _) =>
      raise Validation(
        message="update invite target users requires exactly one file and no JSON body",
      )
    (CreateChannelInvite(..), Some([_]), Some(_)) => ()
    (CreateChannelInvite(..), Some(_), _) =>
      raise Validation(
        message="create channel invite accepts exactly one target-users file next to its JSON params",
      )
    _ => ()
  }
}

///|
async fn Client::execute(self : Client, request : HttpRequest) -> HttpResponse {
  if self.closed_.val {
    raise DiscordHttpError::Transport(phase=Pool, message=CLOSED_MESSAGE)
  }
  // Checked after middleware, which may rewrite the request.
  validate_request(request)
  match self.backend {
    Offline(handler) => self.answer_offline(handler, request)
    Online(runtime) => self.request_online(runtime, request)
  }
}

///|
/// One attempt through the offline handler, reported through telemetry the
/// way a single network attempt is: status 0 when the handler raises, and a
/// 429 as `HttpRateLimited` followed by `RateLimited` without waiting.
async fn Client::answer_offline(
  self : Client,
  handler : async (HttpRequest) -> HttpResponse,
  request : HttpRequest,
) -> HttpResponse {
  let bucket = request.route.bucket()
  let method_name = @debug.to_string(request.route.method_())
  let started_at = self.clock_.now_unix_ms()
  let response = {
    errdefer self.emit_telemetry(
      HttpRequest(
        route_bucket=bucket,
        method_name~,
        status=0,
        duration_ms=self.clock_.now_unix_ms() - started_at,
        retries=0,
      ),
    )
    handler(request)
  }
  self.emit_telemetry(
    HttpRequest(
      route_bucket=bucket,
      method_name~,
      status=response.status,
      duration_ms=self.clock_.now_unix_ms() - started_at,
      retries=0,
    ),
  )
  if response.status == 429 {
    let (retry_after_ms, global) = rate_limit_from_json(
      @ghttp.Headers::of(response.headers.to_array()),
      response.body,
    )
    self.emit_telemetry(
      HttpRateLimited(route_bucket=bucket, global~, retry_after_ms~),
    )
    raise DiscordHttpError::RateLimited(retry_after_ms~, global~)
  }
  response
}

///|
/// What a failed runtime send means to the client: a status error is a
/// response for middleware to see, and the rest raise. A 429 here has
/// outlived its retries. A transport failure keeps its phase; a decoding or
/// rate-limiter failure (`Config`) may come after the exchange, so it may
/// have reached Discord (`Unknown`). `ClosedGate`'s refusal is the client's
/// closure, reported as the check before the call reports it.
fn settle_runtime_error(error : Error) -> HttpResponse raise DiscordHttpError {
  match error {
    @ghttp.TransportError(kind=Closed, detail=CLOSED_MESSAGE, ..) =>
      raise DiscordHttpError::Transport(phase=Pool, message=CLOSED_MESSAGE)
    @runtime.UnexpectedStatus(head, body~) if head.status == 429 => {
      let (retry_after_ms, global) = rate_limit_details(head.headers, body)
      raise DiscordHttpError::RateLimited(retry_after_ms~, global~)
    }
    @runtime.UnexpectedStatus(head, body~) =>
      decode_response(head.status, head.headers, body)
    @ghttp.TransportError(..) as error => raise transport_failure(error)
    @runtime.Deserialization(_, message~, ..)
    | @runtime.InvalidRequest(message~) =>
      raise DiscordHttpError::Transport(phase=Unknown, message~)
    error =>
      raise DiscordHttpError::Transport(
        phase=Unknown,
        message=error.to_string(),
      )
  }
}

///|
/// One logical call on the wire: the runtime admits it through the rate
/// limiter, sends it, releases the bucket, reports the attempt to telemetry,
/// and resends a 429 or an unsent attempt as `resend_delay_ms` directs. Every
/// status comes back as a response so middleware sees it raw; a 429 that
/// outlived its retries, a transport failure, and a timed-out attempt come
/// back as errors.
async fn Client::request_online(
  self : Client,
  runtime : @runtime.Client,
  request : HttpRequest,
) -> HttpResponse {
  let wire = self.wire_request(request)
  let call = @runtime.ClientRequest::new(wire.head, @runtime.as_bytes())
    .attribute(@runtime.rate_limit_bucket, request.route.bucket())
    .attribute(@runtime.global_exempt, request.route.is_interaction())
  let call = match wire.body {
    Some(body) => call.body_fn(body)
    None => call
  }
  let response = runtime.send(call) catch {
    error => return settle_runtime_error(error)
  }
  decode_response(response.status, response.headers, response.body)
}

///|
/// Decode helper shared by the typed endpoint wrappers.
fn[T : @json.FromJson] decode(json : Json) -> T raise DiscordHttpError {
  @json.from_json(json) catch {
    e => raise Deserialize(message="\{e}")
  }
}
