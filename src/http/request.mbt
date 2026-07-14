///|
priv struct RawResponse {
  status : Int
  headers : Map[String, String]
  body : Json
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
) -> RawResponse {
  self.pool.with_conn(conn => {
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
    let path = self.base_path + route.path()
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
  if files is Some(fs) {
    validate_files(fs)
  }
  if route is CreateGuildSticker(..) && !(files is Some([_]) && body is Some(_)) {
    raise DiscordHttpError::Validation(
      message="create guild sticker requires exactly one file and form fields",
    )
  }
  let bucket = route.bucket()
  let global_exempt = route.is_interaction()
  let max_attempts = 4
  for attempt in 0..<max_attempts {
    self.limiter.acquire(bucket, global_exempt~) catch {
      e => raise DiscordHttpError::Transport(message="cancelled: \{e}")
    }
    let response = try self.perform(route, body?, audit_reason?, files?) catch {
      e => {
        self.limiter.release(bucket, status=0, headers={})
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
    if response.status == 429 {
      let global = response.headers.get("x-ratelimit-global") is Some(_)
      let retry_after_ms : Int64 = match response.body {
        { "retry_after": Number(seconds, ..), .. } =>
          (seconds * 1000.0).to_int64()
        _ => 1000L
      }
      if attempt == max_attempts - 1 {
        raise DiscordHttpError::RateLimited(retry_after_ms~, global~)
      }
      @async.sleep(retry_after_ms.to_int() + 1) catch {
        e => raise DiscordHttpError::Transport(message="cancelled: \{e}")
      }
      continue
    }
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
    return response.body
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
