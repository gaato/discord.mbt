///|
/// Discord's retry rule for one logical call, as `resend_delay_ms` decides.
/// `closed` is the client's own flag, so a closed client sends nothing more.
priv struct DiscordRetry {
  max_retries : Int32
  closed : Ref[Bool]
}

///|
impl @runtime.RetryDecider for DiscordRetry with fn next_delay_ms(
  self,
  error,
  _request,
  attempt,
  random,
) {
  resend_delay_ms(
    error,
    attempt~,
    max_retries=self.max_retries,
    closed=self.closed.val,
    random~,
  )
}

///|
/// How long to wait before sending a call again after the failed attempt
/// numbered `attempt` (from `0`), or `None` to raise the failure. Only a
/// call Discord cannot have acted on is resent, at most `max_retries` times
/// in all and never once the client is `closed`:
///
/// - a 429, after the delay the response asked for plus one millisecond;
/// - a transient transport failure that proves no byte was sent (a failed
///   connection, a proxy that could not reach Discord, or a timeout while
///   waiting for a connection slot or connecting), after the runtime's
///   default backoff. Nothing reached Discord, so this holds for every
///   method, `POST` included.
///
/// Anything else is final: a failure after connecting or a timed-out
/// exchange may already have reached Discord, and a status error is
/// Discord's answer.
fn resend_delay_ms(
  error : @runtime.SdkError,
  attempt~ : Int32,
  max_retries~ : Int32,
  closed~ : Bool,
  random~ : Double,
) -> Int32? {
  if closed || attempt >= max_retries {
    return None
  }
  match error {
    RateLimited(headers~, body~, ..) => {
      let (retry_after_ms, _) = rate_limit_details(headers, body)
      Some(retry_after_ms.to_int() + 1)
    }
    Transport(failure) if failure.is_unsent() && error.is_retryable() =>
      Some(@runtime.Backoff::default().delay_ms(attempt, random))
    _ => None
  }
}
