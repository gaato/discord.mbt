///|
/// Failures reported by the coordinator server or a remote client.
pub(all) suberror CoordinatorError {
  InvalidConfig(message~ : String)
  Transport(message~ : String)
  Disconnected
  InvalidResponse(message~ : String)
  Remote(message~ : String)
} derive(Debug)

///|
fn ok_response() -> Json {
  { "ok": true }
}

///|
fn error_response(message : String) -> Json {
  { "ok": false, "error": Json::string(message) }
}

///|
/// The wire form of rate-limit headers: one JSON object, one value per name.
/// A repeated header collapses to its last value, which loses nothing for the
/// `x-ratelimit-*` and `retry-after` headers the limiter reads.
fn encode_headers(headers : @http.Headers) -> Json {
  let fields : Map[String, Json] = Map([])
  for pair in headers.iter() {
    fields[pair.0] = Json::string(pair.1)
  }
  Json::object(fields)
}

///|
/// Headers from their wire object, or why one of them is not a string.
fn decode_headers(fields : Map[String, Json]) -> Result[@http.Headers, String] {
  let mut headers = @http.Headers::empty()
  for name, value in fields {
    guard value is String(text) else {
      return Err("header \{name} must be a string")
    }
    headers = headers.set(name.to_lower(), text)
  }
  Ok(headers)
}

///|
fn json_nonnegative_int(value : Json) -> Int32? {
  guard value is Number(number, ..) else { return None }
  let integer = number.to_int()
  if integer >= 0 && integer.to_double() == number {
    Some(integer)
  } else {
    None
  }
}

///|
fn json_bool(value : Json) -> Bool? {
  match value {
    True => Some(true)
    False => Some(false)
    _ => None
  }
}

///|
// Cooldown durations use decimal strings to preserve all Int64 bits in JSON.
fn json_nonnegative_int64(value : Json) -> Int64? {
  guard value is String(text) else { return None }
  let integer = @string.parse_int64(text) catch { _ => return None }
  if integer >= 0L {
    Some(integer)
  } else {
    None
  }
}

///|
fn cooldown_acquire_request(key : String, window_ms : Int64) -> Json {
  {
    "op": "cooldown_acquire",
    "key": Json::string(key),
    "window_ms": Json::string(window_ms.to_string()),
  }
}

///|
fn cooldown_response(decision : @cooldown.CooldownDecision) -> Json {
  let retry_after_ms = match decision {
    Acquired => 0L
    Active(retry_after_ms~) => retry_after_ms
    // The coordinator's own store always answers; a substituted one may not.
    Unavailable(reason~) => return error_response(reason)
  }
  { "ok": true, "retry_after_ms": Json::string(retry_after_ms.to_string()) }
}

///|
/// A coordinator request after validation.
priv enum Request {
  Ping
  CooldownAcquire(key~ : String, window_ms~ : Int64)
  IdentifyAcquire(shard_id~ : Int32)
  HttpAcquire(bucket~ : String, global_exempt~ : Bool)
  HttpRelease(
    bucket~ : String,
    lease~ : String,
    status~ : Int32,
    headers~ : @http.Headers
  )
}

///|
/// Validate a request line's JSON. `Err` carries the message the server
/// answers with.
fn parse_request(request : Json) -> Result[Request, String] {
  guard request is { "op": String(op), .. } else {
    return Err("missing string op")
  }
  match op {
    "ping" => Ok(Ping)
    "cooldown_acquire" => {
      guard request is { "key": String(key), "window_ms": window_json, .. } &&
        json_nonnegative_int64(window_json) is Some(window_ms) else {
        return Err(
          "cooldown_acquire requires key and non-negative decimal string window_ms",
        )
      }
      Ok(CooldownAcquire(key~, window_ms~))
    }
    "identify_acquire" => {
      guard request is { "shard_id": shard_json, .. } &&
        json_nonnegative_int(shard_json) is Some(shard_id) else {
        return Err("identify_acquire requires a non-negative integer shard_id")
      }
      Ok(IdentifyAcquire(shard_id~))
    }
    "http_acquire" => {
      // A client that cannot read string leases would hold the bucket it is
      // granted; refuse it before anything is reserved.
      guard request is { "leases": "string", .. } else {
        return Err(
          "http_acquire from a client without string leases; upgrade it to match this coordinator",
        )
      }
      guard request
        is { "bucket": String(bucket), "global_exempt": exempt_json, .. } &&
        json_bool(exempt_json) is Some(global_exempt) else {
        return Err("http_acquire requires bucket and boolean global_exempt")
      }
      Ok(HttpAcquire(bucket~, global_exempt~))
    }
    "http_release" => {
      guard request
        is {
          "bucket": String(bucket),
          "lease": String(lease),
          "status": status_json,
          "headers": Object(header_fields),
          ..
        } &&
        json_nonnegative_int(status_json) is Some(status) else {
        return Err(
          "http_release requires bucket, string lease, non-negative integer status, and headers object",
        )
      }
      match decode_headers(header_fields) {
        Ok(headers) => Ok(HttpRelease(bucket~, lease~, status~, headers~))
        Err(message) => Err("invalid headers: \{message}")
      }
    }
    unknown => Err("unknown op: \{unknown}")
  }
}

///|
/// Decode a response line, raising the server's error message as `Remote`.
fn decode_response(line : String) -> Json raise CoordinatorError {
  let response = @json.parse(line) catch {
    error =>
      raise CoordinatorError::InvalidResponse(message="invalid JSON: \{error}")
  }
  match response {
    { "ok": True, .. } => response
    { "ok": False, "error": String(message), .. } =>
      raise CoordinatorError::Remote(message~)
    _ =>
      raise CoordinatorError::InvalidResponse(message="expected an ok response")
  }
}

///|
/// The inverse of `cooldown_response`.
fn decode_cooldown(
  response : Json,
) -> @cooldown.CooldownDecision raise CoordinatorError {
  guard response is { "retry_after_ms": retry_json, .. } &&
    json_nonnegative_int64(retry_json) is Some(retry_after_ms) else {
    raise CoordinatorError::InvalidResponse(
      message="missing non-negative decimal string retry_after_ms",
    )
  }
  if retry_after_ms == 0L {
    Acquired
  } else {
    Active(retry_after_ms~)
  }
}
