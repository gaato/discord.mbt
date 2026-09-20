///|
/// Discord's JSON error body (`{"code": 50008, "message": "...", "errors": {...}}`).
pub(all) struct ApiError {
  code : Int
  message : String
  errors : Json?
} derive(FromJson, ToJson, Debug)

///|
/// Everything a REST call can raise, from client-side validation to decoded
/// Discord API errors.
pub(all) suberror DiscordHttpError {
  /// Discord answered with an error status; `error` is the decoded body.
  Api(status~ : Int, error~ : ApiError)
  /// Rate limited and retries were exhausted.
  RateLimited(retry_after_ms~ : Int64, global~ : Bool)
  /// The 2xx response body did not decode into the expected model.
  Deserialize(message~ : String)
  /// Connection-level failure (DNS, TLS, socket, protocol).
  Transport(message~ : String)
  /// One network attempt exceeded `request_timeout_ms`. The request may have
  /// reached Discord; it is not retried.
  Timeout(timeout_ms~ : Int)
  /// The request was rejected client-side before any I/O.
  Validation(message~ : String)
} derive(Debug)
