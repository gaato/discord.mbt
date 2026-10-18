///|
/// The client's transport behind its `closed` flag: once `Client::close` has
/// run, every exchange fails with `Connect` before reaching `inner`. The
/// runtime client checks for retries before its back-off and sends after
/// it, so this is what keeps a resend timed before `close` from going out
/// after it on a transport the client does not own.
priv struct ClosedGate {
  inner : &@ghttp.Transport
  closed : Ref[Bool]
}

///|
impl @ghttp.Transport for ClosedGate with fn send(self, request) {
  self.check()
  self.inner.send(request)
}

///|
impl @ghttp.Transport for ClosedGate with fn send_stream(self, request) {
  self.check()
  self.inner.send_stream(request)
}

///|
fn ClosedGate::check(self : ClosedGate) -> Unit raise @ghttp.HttpError {
  if self.closed.val {
    raise Connect("client is closed")
  }
}
