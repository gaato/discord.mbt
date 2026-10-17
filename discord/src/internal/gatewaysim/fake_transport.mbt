///|
/// Raised by a `FakeTransport` whose `fail_close` knob is set.
pub suberror SimFailure {
  SimFailure
} derive(Debug)

///|
/// In-memory Gateway connection. `incoming` feeds `recv`; every sent frame is
/// parsed onto `outgoing` and kept in `sent` for checks after the fact.
///
/// Closes are counted, not deduplicated: the first one closes `incoming`, and
/// any later call still increments `close_calls`, so a test can assert that a
/// connection was closed exactly once. A send after the first close is
/// recorded in `sends_after_close`.
///
/// With a `clock`, every send, receive, and close counts as progress for
/// `VirtualClock::settle`.
pub struct FakeTransport {
  incoming : @aqueue.Queue[@gateway.GatewayFrame]
  outgoing : @aqueue.Queue[Json]
  sent : Array[Json]
  /// Makes the next send signal `send_started` and then hang.
  block_next_send : Ref[Bool]
  send_started : @aqueue.Queue[Unit]
  /// Makes every close raise `SimFailure` after closing.
  fail_close : Ref[Bool]
  /// Virtual milliseconds the first close takes, on the transport's clock.
  close_takes_ms : Ref[Int32]
  close_calls : Ref[Int32]
  close_code : Ref[Int32?]
  close_during_send : Ref[Bool]
  close_during_recv : Ref[Bool]
  sends_after_close : Ref[Int32]
  send_in_flight : Ref[Bool]
  recv_in_flight : Ref[Bool]
  priv clock : @simclock.VirtualClock?
}

///|
pub fn FakeTransport::FakeTransport(
  clock? : @simclock.VirtualClock,
) -> FakeTransport {
  {
    incoming: Queue(kind=Unbounded),
    outgoing: Queue(kind=Unbounded),
    sent: [],
    block_next_send: Ref(false),
    send_started: Queue(kind=Unbounded),
    fail_close: Ref(false),
    close_takes_ms: Ref(0),
    close_calls: Ref(0),
    close_code: Ref(None),
    close_during_send: Ref(false),
    close_during_recv: Ref(false),
    sends_after_close: Ref(0),
    clock,
    send_in_flight: Ref(false),
    recv_in_flight: Ref(false),
  }
}

///|
/// Deliver a text frame.
pub async fn FakeTransport::put(self : FakeTransport, text : String) -> Unit {
  self.incoming.put(Text(text))
}

///|
/// End the connection from the server's side.
pub fn FakeTransport::server_close(self : FakeTransport, code : Int32?) -> Unit {
  self.incoming.close(
    error=@gateway.TransportClosed(code~, reason="server closed"),
  )
}

///|
fn FakeTransport::touch(self : FakeTransport) -> Unit {
  if self.clock is Some(clock) {
    clock.touch()
  }
}

///|
pub impl @gateway.GatewayTransport for FakeTransport with fn recv(self) {
  self.recv_in_flight.val = true
  defer {
    self.recv_in_flight.val = false
  }
  let frame = self.incoming.get()
  self.touch()
  frame
}

///|
pub impl @gateway.GatewayTransport for FakeTransport with fn send(self, text) {
  self.send_in_flight.val = true
  defer {
    self.send_in_flight.val = false
  }
  if self.block_next_send.val {
    self.block_next_send.val = false
    self.send_started.put(())
    @async.sleep(3_600_000)
  }
  if self.close_calls.val > 0 {
    self.sends_after_close.val += 1
  }
  let frame = @json.parse(text) catch { _ => Json::null() }
  self.sent.push(frame)
  self.outgoing.put(frame)
  self.touch()
}

///|
pub impl @gateway.GatewayTransport for FakeTransport with fn close(self, code~) {
  if self.send_in_flight.val {
    self.close_during_send.val = true
  }
  if self.recv_in_flight.val {
    self.close_during_recv.val = true
  }
  self.close_calls.val += 1
  self.touch()
  if self.close_calls.val > 1 {
    return
  }
  self.close_code.val = Some(code)
  if self.clock is Some(clock) && self.close_takes_ms.val > 0 {
    (clock : &@hclock.Clock).sleep(self.close_takes_ms.val)
  }
  self.incoming.close(
    error=@gateway.TransportClosed(code=Some(code), reason="client closed"),
  )
  if self.fail_close.val {
    raise SimFailure
  }
}
