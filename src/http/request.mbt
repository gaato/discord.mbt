///|
priv enum TimedRequestResult {
  RequestSucceeded(HttpResponse)
  RequestFailed(DiscordHttpError)
}

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
/// Execute one HTTP exchange on a pooled connection. The response body is
/// fully consumed before the connection returns to the pool.
async fn Client::perform(
  self : Client,
  route : Route,
  body? : Json,
  audit_reason? : String,
  files? : Array[FileUpload],
  extra_headers : Map[String, String],
) -> HttpResponse {
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
        let seed = "\{@async.now()}-\{next_multipart_seq()}"
        let boundary = fresh_boundary(seed, payload, [file])
        headers["content-type"] = "multipart/form-data; boundary=\{boundary}"
        conn.request(route.method_(), path, extra_headers=headers)
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
      (_, Some(fs), _) if fs.length() > 0 => {
        let payload = body.unwrap_or(Json::object({})).stringify()
        let seed = "\{@async.now()}-\{next_multipart_seq()}"
        let boundary = fresh_boundary(seed, payload, fs)
        headers["content-type"] = "multipart/form-data; boundary=\{boundary}"
        conn.request(route.method_(), path, extra_headers=headers)
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
        ..request(route.method_(), path, extra_headers=headers)
        ..write(json)
        .end_request()
      }
      (_, _, None) => {
        conn.request(route.method_(), path, extra_headers=headers)
        conn.end_request()
      }
    }
    let lower_headers : Map[String, String] = {}
    for name, value in response.headers {
      lower_headers[name.to_lower()] = value
    }
    let body_data = conn.read_all()
    let body_json = if response.code == 204 {
      Json::null()
    } else {
      @json.parse(body_data.text()) catch {
        _ => Json::null()
      }
    }
    { status: response.code, headers: lower_headers, body: body_json }
  })
}

///|
/// Send a request through the rate limiter, retrying on 429 (bounded).
///
/// This is also the raw escape hatch: typed endpoint wrappers build a `Route`
/// plus JSON body and decode the returned JSON, while unwrapped endpoints use
/// `Route::custom`.
pub async fn Client::request(
  self : Client,
  route : Route,
  body? : Json,
  audit_reason? : String,
  files? : Array[FileUpload],
) -> Json raise DiscordHttpError {
  let request : HttpRequest = { route, body, audit_reason, files, headers: {} }
  let timed = @async.with_timeout_opt(self.request_timeout_ms_, () => {
    RequestSucceeded(self.run_middleware(0, request)) catch {
      error if @async.is_being_cancelled() ||
        @async.is_cancellation_error(error) => raise error
      DiscordHttpError::Api(status~, error~) =>
        RequestFailed(DiscordHttpError::Api(status~, error~))
      DiscordHttpError::RateLimited(retry_after_ms~, global~) =>
        RequestFailed(DiscordHttpError::RateLimited(retry_after_ms~, global~))
      DiscordHttpError::Deserialize(message~) =>
        RequestFailed(DiscordHttpError::Deserialize(message~))
      DiscordHttpError::Transport(message~) =>
        RequestFailed(DiscordHttpError::Transport(message~))
      DiscordHttpError::Timeout(timeout_ms~) =>
        RequestFailed(DiscordHttpError::Timeout(timeout_ms~))
      DiscordHttpError::Validation(message~) =>
        RequestFailed(DiscordHttpError::Validation(message~))
      error => RequestFailed(DiscordHttpError::Transport(message="\{error}"))
    }
  }) catch {
    error => raise DiscordHttpError::Transport(message="cancelled: \{error}")
  }
  match timed {
    Some(RequestSucceeded(response)) => {
      if response.status >= 400 {
        let error : ApiError = @json.from_json(response.body) catch {
          _ =>
            {
              code: 0,
              message: "HTTP \{response.status}: \{response.body.stringify()}",
              errors: None,
            }
        }
        raise DiscordHttpError::Api(status=response.status, error~)
      }
      response.body
    }
    Some(RequestFailed(error)) => raise error
    None => raise DiscordHttpError::Timeout(timeout_ms=self.request_timeout_ms_)
  }
}

///|
async fn Client::execute(self : Client, request : HttpRequest) -> HttpResponse {
  if request.files is Some(files) {
    validate_files(files)
  }
  if request.route is CreateGuildSticker(..) &&
    !(request.files is Some([_]) && request.body is Some(_)) {
    raise DiscordHttpError::Validation(
      message="create guild sticker requires exactly one file and form fields",
    )
  }
  self.request_inner(request)
}

///|
/// Rate-limit and retry implementation bounded by `Client::request`'s
/// whole-request timeout.
async fn Client::request_inner(
  self : Client,
  request : HttpRequest,
) -> HttpResponse {
  let bucket = request.route.bucket()
  let global_exempt = request.route.is_interaction()
  let max_attempts = self.max_retries_ + 1
  for attempt in 0..<max_attempts {
    self.limiter.acquire(bucket, global_exempt~) catch {
      e if @async.is_being_cancelled() || @async.is_cancellation_error(e) =>
        raise e
      e => raise DiscordHttpError::Transport(message="cancelled: \{e}")
    }
    let started_at = @async.now()
    let response = try
      self.perform(
        request.route,
        request.headers,
        body?=request.body,
        audit_reason?=request.audit_reason,
        files?=request.files,
      )
    catch {
      e => {
        self.limiter.release(bucket, status=0, headers={})
        self.emit_telemetry(
          @telemetry.TelemetryEvent::HttpRequest(
            route_bucket=bucket,
            method_name=request.route.method_().to_string(),
            status=0,
            duration_ms=@async.now() - started_at,
            retries=attempt,
          ),
        )
        if @async.is_being_cancelled() || @async.is_cancellation_error(e) {
          raise e
        }
        raise DiscordHttpError::Transport(message="\{e}")
      }
    } noraise {
      r => r
    }
    self.limiter.release(
      bucket,
      status=response.status,
      headers=response.headers,
    )
    self.emit_telemetry(
      @telemetry.TelemetryEvent::HttpRequest(
        route_bucket=bucket,
        method_name=request.route.method_().to_string(),
        status=response.status,
        duration_ms=@async.now() - started_at,
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
        @telemetry.TelemetryEvent::HttpRateLimited(
          route_bucket=bucket,
          global~,
          retry_after_ms~,
        ),
      )
      if attempt == max_attempts - 1 {
        raise DiscordHttpError::RateLimited(retry_after_ms~, global~)
      }
      @async.sleep(retry_after_ms.to_int() + 1) catch {
        e if @async.is_being_cancelled() || @async.is_cancellation_error(e) =>
          raise e
        e => raise DiscordHttpError::Transport(message="cancelled: \{e}")
      }
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
    e => raise DiscordHttpError::Deserialize(message="\{e}")
  }
}
