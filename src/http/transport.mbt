///|
/// Validated request immediately before wire encoding. `path` includes the
/// API prefix; `route.path()` does not. Headers include authentication and
/// caller overrides, but not encoder-generated content type or boundaries.
/// Do not log this value without redacting credentials and payloads.
pub(all) struct PreparedHttpRequest {
  route : Route
  path : String
  headers : Map[String, String]
  body : Json?
  files : Array[FileUpload]?
}

///|
/// Replace only the wire exchange. Validation, middleware, rate limiting,
/// timeouts, retries, status handling and typed decoding remain active.
/// A failure never falls back to the pooled network transport. Response header
/// names must be lowercase, as with the built-in transport.
pub type HttpTransport = async (PreparedHttpRequest) -> HttpResponse
