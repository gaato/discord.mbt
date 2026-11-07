///|
/// The client's transport behind its `closed` flag: once `Client::close` has
/// run, every exchange fails with `TransportError(kind=Closed, ...)` before reaching
/// `inner`, which `settle_runtime_error` reports as the closure:
/// `Transport(phase=Pool, message="client is closed")`. The
/// runtime client checks for retries before its back-off and sends after
/// it, so this is what keeps a resend timed before `close` from going out
/// after it on a transport the client does not own.
///
/// It also removes `REPLAY_SAFE_HEADER`, which only the retry decider reads,
/// from each attempt's request, so the transport never sends it to Discord.
priv struct ClosedGate {
  inner : &@runtime.Backend
  closed : Ref[Bool]
}

///|
impl @runtime.Backend for ClosedGate with fn send(self, request, options) {
  self.check()
  self.inner.send(strip_replay_safe(request), options)
}

///|
/// `request` without `REPLAY_SAFE_HEADER`, on its own copy of the headers:
/// the runtime resends the request it was given, which must keep the mark.
fn strip_replay_safe(request : @ghttp.Request) -> @ghttp.Request {
  guard request.headers.contains(REPLAY_SAFE_HEADER) else { return request }
  let headers = request.headers.remove(REPLAY_SAFE_HEADER)
  { ..request, headers, }
}

///|
fn ClosedGate::check(self : ClosedGate) -> Unit raise @ghttp.TransportError {
  if self.closed.val {
    raise @ghttp.TransportError(kind=Closed, phase=Pool, detail=CLOSED_MESSAGE)
  }
}

///|
/// What `ClosedGate` raises with, and how a closed client names itself.
const CLOSED_MESSAGE : String = "client is closed"
