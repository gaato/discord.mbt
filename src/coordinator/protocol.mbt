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
