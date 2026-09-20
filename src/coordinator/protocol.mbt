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
fn decode_headers(fields : Map[String, Json]) -> Map[String, String] raise {
  let headers : Map[String, String] = Map([])
  for name, value in fields {
    guard value is String(text) else {
      raise CoordinatorError::InvalidResponse(
        message="header \{name} must be a string",
      )
    }
    headers[name.to_lower()] = text
  }
  headers
}

///|
fn json_nonnegative_int(value : Json) -> Int? {
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
  }
  { "ok": true, "retry_after_ms": Json::string(retry_after_ms.to_string()) }
}
