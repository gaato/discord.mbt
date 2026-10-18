///|
/// Discord's JSON error body (`{"code": 50008, "message": "...", "errors": {...}}`).
pub(all) struct ApiError {
  code : Int32
  message : String
  errors : Json?
} derive(FromJson, ToJson, Debug)

///|
/// Everything a REST call can raise, from client-side validation to decoded
/// Discord API errors.
///
/// `Transport` and `Timeout` carry the `phase` of the exchange that failed.
/// `Pool` and `Dial` mean no byte of the request was sent, so Discord cannot
/// have acted on it (`is_unsent`); any other phase means it may have.
pub(all) suberror DiscordHttpError {
  /// Discord answered with an error status; `error` is the decoded body.
  Api(status~ : Int32, error~ : ApiError)
  /// Rate limited and retries were exhausted.
  RateLimited(retry_after_ms~ : Int64, global~ : Bool)
  /// The 2xx response body did not decode into the expected model.
  Deserialize(message~ : String)
  /// The exchange failed below HTTP during `phase`: `Pool` when the client
  /// is closed, `Dial` when no connection was made or a proxy refused the
  /// tunnel, `Write`, `Head` or `Body` after connecting, and `Unknown` when
  /// the step cannot be told (a malformed response, a failing rate limiter,
  /// or an error raised by middleware). `message` describes the failure and
  /// never holds the request's URL, headers, or body.
  Transport(phase~ : @ghttp.Phase, message~ : String)
  /// A limit of `timeout_ms` milliseconds ran out during `phase` of one
  /// network attempt (`request_timeout_ms` for the default transport).
  Timeout(phase~ : @ghttp.Phase, timeout_ms~ : Int32)
  /// The request was rejected client-side before any I/O.
  Validation(message~ : String)
} derive(Debug)

///|
/// Whether the error proves that no byte of the request reached Discord, so
/// Discord cannot have acted on it and even a non-idempotent request may be
/// sent again: a `Validation` failure, or a `Transport` failure or `Timeout`
/// in the `Pool` or `Dial` phase. The client already resends such a transport
/// failure up to `max_retries` times before raising it.
///
/// ```mbt check
/// test {
///   assert_true(@http.Transport(phase=Dial, message="refused").is_unsent())
///   assert_true(@http.Timeout(phase=Pool, timeout_ms=100).is_unsent())
///   assert_false(@http.Transport(phase=Write, message="reset").is_unsent())
///   assert_false(@http.Timeout(phase=Head, timeout_ms=100).is_unsent())
/// }
/// ```
pub fn DiscordHttpError::is_unsent(self : DiscordHttpError) -> Bool {
  match self {
    Validation(_)
    | Transport(phase=Pool | Dial, ..)
    | Timeout(phase=Pool | Dial, ..) => true
    Transport(..) | Timeout(..) | Api(..) | RateLimited(..) | Deserialize(_) =>
      false
  }
}
