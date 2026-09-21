///|
fn Client::request_headers(
  self : Client,
  route : Route,
  audit_reason : String?,
) -> Map[String, String] {
  let headers : Map[String, String] = {
    "user-agent": "DiscordBot (https://github.com/gaato/discord.mbt, \{VERSION})",
    "accept": "application/json",
  }
  if route.needs_auth() {
    headers["authorization"] = "Bot \{self.token}"
  }
  if audit_reason is Some(reason) {
    headers["x-audit-log-reason"] = reason
  }
  headers
}

///|
fn to_http_headers(headers : Map[String, String]) -> @ahttp.Headers {
  let converted : @ahttp.Headers = Map([])
  for name, value in headers {
    converted[name] = value
  }
  converted
}

///|
/// Execute one HTTP exchange through the injected transport or a pooled
/// connection. Network response bodies are consumed before returning to the pool.
async fn Client::perform(
  self : Client,
  route : Route,
  body? : Json,
  audit_reason? : String,
  files? : Array[FileUpload],
  extra_headers : Map[String, String],
) -> HttpResponse {
  if self.closed_ {
    raise DiscordHttpError::Transport(message="client is closed")
  }
  let headers = self.request_headers(route, audit_reason)
  headers.merge_in_place(extra_headers)
  let path = self.base_path + route.path()
  if self.perform_override_.val is Some(perform) {
    return perform(route, path, headers, body, files)
  }
  self.pool.with_conn(conn => {
    let response = match (route, files, body) {
      (CreateGuildSticker(..), Some([file]), Some(json)) => {
        let payload = json.stringify()
        let seed = "\{@clock.now_ms()}-\{next_multipart_seq()}"
        let boundary = fresh_boundary(seed, payload, [file])
        headers["content-type"] = "multipart/form-data; boundary=\{boundary}"
        conn.request(
          route.method_(),
          path,
          extra_headers=to_http_headers(headers),
        )
        for
          part in multipart_form_parts(
            boundary,
            sticker_form_fields(json),
            "file",
            file,
          ) {
          match part {
            Text(text) => conn.write(text)
            Blob(bytes) => conn.write(bytes)
          }
        }
        conn.end_request()
      }
      (CreateChannelInvite(..), Some([file]), Some(json)) => {
        let payload = json.stringify()
        let seed = "\{@clock.now_ms()}-\{next_multipart_seq()}"
        let boundary = fresh_boundary(seed, payload, [file])
        headers["content-type"] = "multipart/form-data; boundary=\{boundary}"
        conn.request(
          route.method_(),
          path,
          extra_headers=to_http_headers(headers),
        )
        for
          part in multipart_payload_with_named_file(
            boundary, payload, "target_users_file", file,
          ) {
          match part {
            Text(text) => conn.write(text)
            Blob(bytes) => conn.write(bytes)
          }
        }
        conn.end_request()
      }
      (UpdateInviteTargetUsers(..), Some([file]), None) => {
        let seed = "\{@clock.now_ms()}-\{next_multipart_seq()}"
        let boundary = fresh_boundary(seed, "", [file])
        headers["content-type"] = "multipart/form-data; boundary=\{boundary}"
        conn.request(
          route.method_(),
          path,
          extra_headers=to_http_headers(headers),
        )
        for
          part in multipart_form_parts(boundary, [], "target_users_file", file) {
          match part {
            Text(text) => conn.write(text)
            Blob(bytes) => conn.write(bytes)
          }
        }
        conn.end_request()
      }
      (_, Some(fs), _) if fs.length() > 0 => {
        let payload = body.unwrap_or(Json::empty_object()).stringify()
        let seed = "\{@clock.now_ms()}-\{next_multipart_seq()}"
        let boundary = fresh_boundary(seed, payload, fs)
        headers["content-type"] = "multipart/form-data; boundary=\{boundary}"
        conn.request(
          route.method_(),
          path,
          extra_headers=to_http_headers(headers),
        )
        for part in multipart_parts(boundary, payload, fs) {
          match part {
            Text(text) => conn.write(text)
            Blob(bytes) => conn.write(bytes)
          }
        }
        conn.end_request()
      }
      (_, _, Some(json)) => {
        headers["content-type"] = "application/json"
        conn
        ..request(route.method_(), path, extra_headers=to_http_headers(headers))
        ..write(json)
        .end_request()
      }
      (_, _, None) => {
        conn.request(
          route.method_(),
          path,
          extra_headers=to_http_headers(headers),
        )
        conn.end_request()
      }
    }
    let lower_headers : Map[String, String] = Map([])
    for name, value in response.headers {
      lower_headers[name.to_string().to_lower()] = value
    }
    let body_data = conn.read_all()
    let body_json = if response.code == 204 {
      Json::null()
    } else {
      // A body that is not valid JSON (proxy error pages, empty replies) is
      // preserved as a JSON string so error paths can report its content.
      @json.parse(body_data.text()) catch {
        _ => Json::string(body_data.text())
      }
    }
    { status: response.code, headers: lower_headers, body: body_json, }
  })
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
  self.request_inner(request)
}

///|
/// Rate-limit acquisition and 429 back-off stay outside the per-attempt
/// timeout. A timeout exits through the same cleanup as a transport failure
/// and is never retried.
async fn Client::request_inner(
  self : Client,
  request : HttpRequest,
) -> HttpResponse {
  let bucket = request.route.bucket()
  let global_exempt = request.route.is_interaction()
  let max_attempts = self.max_retries_ + 1
  for attempt in 0..<max_attempts {
    self.limiter.acquire(bucket, global_exempt~) catch {
      e if @async.is_being_cancelled() => raise e
      e => raise DiscordHttpError::Transport(message="cancelled: \{e}")
    }
    let started_at = @clock.now_ms()
    let response = try {
      errdefer @async.protect_from_cancel(() => {
        self.limiter.release(bucket, status=0, headers=Map([])) catch {
          _ => ()
        }
        self.emit_telemetry(
          HttpRequest(
            route_bucket=bucket,
            method_name=@debug.to_string(request.route.method_()),
            status=0,
            duration_ms=@clock.now_ms() - started_at,
            retries=attempt,
          ),
        )
      })
      @async.with_timeout(
        self.request_timeout_ms_,
        () => {
          self.perform(
            request.route,
            request.headers,
            body?=request.body,
            audit_reason?=request.audit_reason,
            files?=request.files,
          )
        },
        error=DiscordHttpError::Timeout(timeout_ms=self.request_timeout_ms_),
      )
    } catch {
      e if @async.is_being_cancelled() => raise e
      DiscordHttpError::Timeout(..) as e => raise e
      e => raise DiscordHttpError::Transport(message="\{e}")
    } noraise {
      r => r
    }
    self.limiter.release(
      bucket,
      status=response.status,
      headers=response.headers,
    )
    self.emit_telemetry(
      HttpRequest(
        route_bucket=bucket,
        method_name=@debug.to_string(request.route.method_()),
        status=response.status,
        duration_ms=@clock.now_ms() - started_at,
        retries=attempt,
      ),
    )
    if response.status == 429 {
      let global = response.headers.get("x-ratelimit-global") is Some(_)
      let retry_after_ms : Int64 = match response.body {
        { "retry_after": Number(seconds, ..), .. } =>
          (seconds * 1000.0).to_int64()
        _ => 1000L
      }
      self.emit_telemetry(
        HttpRateLimited(route_bucket=bucket, global~, retry_after_ms~),
      )
      if attempt == max_attempts - 1 {
        raise DiscordHttpError::RateLimited(retry_after_ms~, global~)
      }
      @async.sleep(retry_after_ms.to_int() + 1)
      continue
    }
    return response
  }
  // unreachable: the loop either returns or raises
  raise DiscordHttpError::Transport(message="retry loop exhausted")
}

///|
/// Decode helper shared by the typed endpoint wrappers.
fn[T : @json.FromJson] decode(json : Json) -> T raise DiscordHttpError {
  @json.from_json(json) catch {
    e => raise Deserialize(message="\{e}")
  }
}
