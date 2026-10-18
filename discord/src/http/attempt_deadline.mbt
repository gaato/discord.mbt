///|
/// The per-attempt deadline around a transport the caller supplied, timed
/// by the client's clock: the whole buffered exchange, or the response head
/// of a streaming one. Expiry raises `Timeout(phase=Unknown, ms)`, since the
/// deadline cannot see which phase the inner transport was in; the inner
/// transport's own failures pass through.
priv struct AttemptDeadline {
  inner : &@ghttp.Transport
  clock : &@hclock.Clock
  timeout_ms : Int32
}

///|
impl @ghttp.Transport for AttemptDeadline with fn send(self, request) {
  self.bounded(() => self.inner.send(request))
}

///|
impl @ghttp.Transport for AttemptDeadline with fn send_stream(self, request) {
  self.bounded(() => self.inner.send_stream(request))
}

///|
/// Runs `exchange` until it finishes or the deadline passes; a nonpositive
/// deadline expires at once.
async fn[X] AttemptDeadline::bounded(
  self : AttemptDeadline,
  exchange : async () -> X raise @ghttp.HttpError,
) -> X raise @ghttp.HttpError {
  let expired = @ghttp.HttpError::Timeout(phase=Unknown, ms=self.timeout_ms)
  if self.timeout_ms <= 0 {
    raise expired
  }
  // The exchange's failure travels as a value, so it keeps its type.
  let outcome = @transport.with_timeout_opt(self.clock, self.timeout_ms, () => {
    try exchange() catch {
      error => Err(error)
    } noraise {
      value => Ok(value)
    }
  }) catch {
    // The timer itself failed; the exchange may have been under way.
    error => raise Network(phase=Unknown, message=error.to_string())
  }
  match outcome {
    Some(Ok(value)) => value
    Some(Err(error)) => raise error
    None => raise expired
  }
}
