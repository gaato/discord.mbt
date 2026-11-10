///|
/// The client's transport behind its `closed` flag: once `Client::close` has
/// run, every exchange fails with `TransportError(kind=Closed, ...)` before reaching
/// `inner`, which `settle_runtime_error` reports as the closure:
/// `Transport(phase=Pool, message="client is closed")`. The
/// runtime client checks for retries before its back-off and sends after
/// it, so this is what keeps a resend timed before `close` from going out
/// after it on a transport the client does not own.
priv struct ClosedGate {
  inner : &@ghttp.Backend
  closed : Ref[Bool]
}

///|
impl @ghttp.Backend for ClosedGate with fn send(self, request, options) {
  self.check()
  self.inner.send(request, options)
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
