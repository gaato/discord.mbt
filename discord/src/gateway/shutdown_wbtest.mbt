///|
/// A byte peer that stops consuming output after Identify. A protected
/// Pong/Close reply therefore remains blocked until the connection closes.
priv struct UnreadingGatewayConn {
  inner : @sim.SimConn
  stopped : Ref[Bool]
  entered : &@hclock.Signal
  closed : &@hclock.Signal
  writes : Ref[Int32]
}

///|
impl @hclock.Conn for UnreadingGatewayConn with fn read(self, max_len~) {
  self.inner.read(max_len~)
}

///|
impl @hclock.Conn for UnreadingGatewayConn with fn write(self, bytes) {
  if self.stopped.val {
    self.writes.val += 1
    defer {
      self.writes.val -= 1
    }
    self.entered.notify()
    // Model a stalled socket/TLS write whose cancellation cleanup itself
    // needs the connection closed. Cancelling the receiver cannot wake it.
    @transport.RuntimeCoordination::new().protect(work=() => self.closed.wait())
    raise @hmodel.TransportError(
      kind=Closed,
      phase=Write,
      detail="peer stopped reading",
    )
  }
  self.inner.write(bytes)
}

///|
impl @hclock.Conn for UnreadingGatewayConn with fn close(self) {
  self.inner.close()
  self.closed.notify()
}

///|
async test "shard shutdown aborts a protected reply to a peer that stopped reading" {
  for control in [b"\x89\x01p", b"\x88\x02\x0f\xa0"] {
    let coordination = @transport.RuntimeCoordination::new()
    let (inner, peer) = @sim.pair(coordination)
    defer peer.close()
    let conn = UnreadingGatewayConn::{
      inner,
      stopped: Ref(false),
      entered: coordination.signal(),
      closed: coordination.signal(),
      writes: Ref(0),
    }
    let clock = @transport.AsyncClock::new()
    let session = @core_ws.session_over_conn(
      conn,
      role=Client,
      pending=b"",
      clock~,
      timer=@transport.ClockTimer::new(clock~),
      coordination~,
      entropy=n => Some(Bytes::make(n, b'\x01')),
      limits={ ..@ws.WsLimits::default(), close_timeout_ms: 1000, },
    )
    defer session.abort()
    let wire : &GatewayTransport = WsTransport::{
      conn: session,
      closed: Ref(false),
    }
    let gateway_clock = @transport.VirtualClock()
    @async.with_task_group(group => {
      let shard = Shard::start(
        group,
        token="local-test",
        intents=@model.Intents::none(),
        connector=_ => wire,
        clock=gateway_clock,
      )
      let hello = @utf8.encode(
        "{\"op\":10,\"d\":{\"heartbeat_interval\":60000}}",
      )
      let head = @wsframe.encode_head(
        @wsframe.FrameHead::new(
          fin=true,
          opcode=Text,
          masked=false,
          length=hello.length().to_int64(),
        ),
      )
      peer.write(head + hello)
      // Drain Identify, then stop reading before provoking a control reply.
      assert_true(peer.read(max_len=65536) is Some(_))
      conn.stopped.val = true
      peer.write(control)
      @async.with_timeout(1000, () => conn.entered.wait())
      // Shorter than Session's one-second close bound: success must come
      // from abort waking the write, rather than its control deadline.
      let started = clock.now_unix_ms()
      @async.with_timeout(250, () => shard.close())
      // with_timeout may return a protected result after its deadline, so
      // also measure the join instead of treating a returned Unit as proof.
      let elapsed = clock.now_unix_ms() - started
      assert_true(elapsed < 500L, msg="shutdown waited \{elapsed} ms")
      assert_eq(conn.writes.val, 0)
      assert_eq(inner.closes(), 1)
      assert_eq(shard.state(), Disconnected(reconnect_attempts=0))
    })
    assert_eq(gateway_clock.pending(), [])
  }
}
