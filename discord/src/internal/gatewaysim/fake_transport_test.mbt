///|
async test "fake transport counts every close and records late sends" {
  let clock = @netruntime.VirtualClock()
  let transport = @gatewaysim.FakeTransport(clock~)
  let port : &@gateway.GatewayTransport = transport
  transport.put("{\"op\":11}")
  guard port.recv() is Text("{\"op\":11}") else { fail("expected the frame") }
  port.send("{\"op\":1,\"d\":null}")
  transport.fail_close.val = true
  try port.close(code=4000) catch {
    @gatewaysim.SimFailure => ()
    error => fail("unexpected \{Repr(error)}")
  } noraise {
    _ => fail("expected SimFailure")
  }
  port.close(code=1000)
  port.send("{\"op\":3,\"d\":null}")
  assert_eq(transport.close_calls.val, 2)
  assert_eq(transport.close_code.val, Some(4000))
  assert_eq(transport.sends_after_close.val, 1)
  assert_eq(transport.sent.length(), 2)
  try port.recv() catch {
    @gateway.TransportClosed(code=Some(4000), ..) => ()
    error => fail("unexpected \{Repr(error)}")
  } noraise {
    _ => fail("expected the closed connection")
  }
}
