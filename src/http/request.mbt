///|
/// The headers every call to `route` carries before the caller's own.
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
    headers["x-audit-log-reason"] = reason
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
/// Discord's retry rule: only a 429 is sent again, after the delay the
/// response asked for, and at most `max_retries` times. A timed-out or
/// otherwise failed attempt is never resent because it may already have
/// reached Discord; a status error is final.
priv struct DiscordRetry {
  max_retries : Int
}

///|
impl @runtime.RetryDecider for DiscordRetry with fn next_delay_ms(
  self,
  error,
  _request,
  attempt,
  _random,
) {
  guard error is @runtime.RateLimited(headers~, body~, ..) else { return None }
  if attempt >= self.max_retries {
    return None
  }
  let (retry_after_ms, _) = rate_limit_details(headers, body)
  Some(retry_after_ms.to_int() + 1)
}

///|
/// Retry delay and scope of a 429 response: the body's `retry_after` (in
/// seconds, the more precise source), then the `Retry-After` header, then one
/// second; `global` when the response says the whole account is limited.
fn rate_limit_details(headers : @ghttp.Headers, body : Bytes) -> (Int64, Bool) {
  let global = headers.get("x-ratelimit-global") is Some(_)
  let parsed : Json? = Some(@json.parse(@utf8.decode_lossy(body))) catch {
    _ => None
  }
  let from_body : Int64? = match parsed {
    Some({ "retry_after": Number(seconds, ..), .. }) =>
      Some((seconds * 1000.0).to_int64())
    _ => None
  }
  let retry_after_ms : Int64 = match from_body {
    Some(ms) => ms
    None =>
      match @runtime.retry_after_ms(headers) {
        Some(ms) => ms.to_int64()
        None => 1000L
      }
  }
  (retry_after_ms, global)
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
  let wire = @ghttp.Request::new(
    wire_method(route.method_()),
    self.base_url + self.base_path + route.path(),
  )
  for name, value in headers {
    wire.headers.set(name, value)
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
      wire.headers.set("content-type", "application/json")
      { head: wire.body_bytes(@utf8.encode(json.stringify())), body: None, }
    }
    (_, _, None) => { head: wire, body: None, }
  }
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
  status : Int,
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
/// Send a request through the rate limiter, retrying on 429 (bounded).
///
/// This is also the raw escape hatch: typed endpoint wrappers build a `Route`
/// plus JSON body and decode the returned JSON, while unwrapped endpoints use
/// `Route::custom`. Optional `headers` are merged after the client's base
/// headers, so caller-supplied values such as `authorization` take precedence.
///
/// `request_timeout_ms` bounds each network attempt, including reading its
/// response body. Rate-limit waits, 429 back-off, and user middleware are
/// outside it. A timed-out attempt raises `Timeout` and is not retried because
/// it may already have reached Discord. For a whole-operation deadline,
/// compose `@async.with_timeout` around the call.
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
        DiscordHttpError::Transport(message~) => raise Transport(message~)
        DiscordHttpError::Timeout(timeout_ms~) => raise Timeout(timeout_ms~)
        DiscordHttpError::Validation(message~) => raise Validation(message~)
        error => raise Transport(message="\{error}")
      }
    }
  }
  if response.status >= 400 {
    let error : ApiError = @json.from_json(response.body) catch {
      _ => {
        // Non-JSON bodies (proxy HTML, empty strings) surface verbatim so
        // the user-visible error keeps whatever the server actually said.
        let detail = match response.body {
          String(text) => text
          body => body.stringify()
        }
        {
          code: 0,
          message: "HTTP \{response.status}: \{detail}",
          errors: None,
        }
      }
    }
    raise Api(status=response.status, error~)
  }
  response.body
}

///|
async fn Client::execute(self : Client, request : HttpRequest) -> HttpResponse {
  if self.closed_ {
    raise DiscordHttpError::Transport(message="client is closed")
  }
  if request.files is Some(files) {
    validate_files(files)
  }
  if request.route is CreateGuildSticker(..) &&
    !(request.files is Some([_]) && request.body is Some(_)) {
    raise DiscordHttpError::Validation(
      message="create guild sticker requires exactly one file and form fields",
    )
  }
  if request.route is UpdateInviteTargetUsers(..) &&
    !(request.files is Some([_]) && request.body is None) {
    raise DiscordHttpError::Validation(
      message="update invite target users requires exactly one file and no JSON body",
    )
  }
  if request.route is CreateGuildSticker(..) && request.body is Some(body) {
    ignore(sticker_form_fields(body))
  }
  if request.route is CreateChannelInvite(..) &&
    request.files is Some(files) &&
    !(files is [_] && request.body is Some(_)) {
    raise DiscordHttpError::Validation(
      message="create channel invite accepts exactly one target-users file next to its JSON params",
    )
  }
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
  let started_at = @clock.now_ms()
  let response = {
    errdefer self.emit_telemetry(
      HttpRequest(
        route_bucket=bucket,
        method_name~,
        status=0,
        duration_ms=@clock.now_ms() - started_at,
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
      duration_ms=@clock.now_ms() - started_at,
      retries=0,
    ),
  )
  if response.status == 429 {
    let (retry_after_ms, global) = offline_rate_limit_details(response)
    self.emit_telemetry(
      HttpRateLimited(route_bucket=bucket, global~, retry_after_ms~),
    )
    raise DiscordHttpError::RateLimited(retry_after_ms~, global~)
  }
  response
}

///|
/// `rate_limit_details` for a response an offline handler produced.
fn offline_rate_limit_details(response : HttpResponse) -> (Int64, Bool) {
  let global = response.headers.get("x-ratelimit-global") is Some(_)
  let retry_after_ms : Int64 = match response.body {
    { "retry_after": Number(seconds, ..), .. } => (seconds * 1000.0).to_int64()
    _ => 1000L
  }
  (retry_after_ms, global)
}

///|
/// One logical call on the wire: the runtime admits it through the rate
/// limiter, sends it, releases the bucket, reports the attempt to telemetry,
/// and resends a 429 as `DiscordRetry` directs. Every status comes back as a
/// response so middleware sees it raw; a 429 that outlived its retries, a
/// transport failure, and a timed-out attempt come back as errors.
async fn Client::request_online(
  self : Client,
  runtime : @runtime.Client,
  request : HttpRequest,
) -> HttpResponse {
  let wire = self.wire_request(request)
  let response = runtime.send(
    wire.head,
    bucket=request.route.bucket(),
    global_exempt=request.route.is_interaction(),
    body?=wire.body,
  ) catch {
    @runtime.Status(status~, headers~, body~) =>
      return decode_response(status, headers, body)
    @runtime.RateLimited(headers~, body~, ..) => {
      let (retry_after_ms, global) = rate_limit_details(headers, body)
      raise DiscordHttpError::RateLimited(retry_after_ms~, global~)
    }
    @runtime.Transport(@ghttp.HttpError::Timeout(_)) =>
      raise DiscordHttpError::Timeout(timeout_ms=self.request_timeout_ms_)
    @runtime.Transport(error) =>
      raise DiscordHttpError::Transport(message=@debug.to_string(error))
    @runtime.Decode(message~, ..) | @runtime.Config(message) =>
      raise DiscordHttpError::Transport(message~)
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
