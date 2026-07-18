///|
priv suberror UdpTestFailure {
  UdpTestFailure
} derive(Debug)

///|
struct FailingVoiceUdp {}

///|
impl @voice.VoiceUdp for FailingVoiceUdp with fn recv(_self, _buffer) {
  raise UdpTestFailure
}

///|
impl @voice.VoiceUdp for FailingVoiceUdp with fn send(_self, _bytes) {

}

///|
impl @voice.VoiceUdp for FailingVoiceUdp with fn close(_self) {

}

///|
fn expect_discovery_error(bytes : Bytes, expected : String) -> Unit raise {
  try @voice.parse_ip_discovery_response(bytes, expected_ssrc=7U) catch {
    @voice.VoiceUdpError::InvalidDiscoveryPacket(reason~) =>
      assert_eq(reason, expected)
    _ => fail("unexpected UDP error for: \{expected}")
  } noraise {
    _ => fail("expected a discovery parse error: \{expected}")
  }
}

///|
test "IP discovery parsing rejects each malformed response" {
  expect_discovery_error(Bytes::new(73), "response must contain 74 bytes")
  let wrong_type = discovery_response(7U, "203.0.113.9", 62000).to_array()
  wrong_type[1] = 3
  expect_discovery_error(
    Bytes::from_array(wrong_type),
    "expected discovery response type 2 with length 70",
  )
  let bad_utf8 = discovery_response(7U, "", 62000).to_array()
  bad_utf8[8] = b'\xFF'
  bad_utf8[9] = b'\xFF'
  expect_discovery_error(
    Bytes::from_array(bad_utf8),
    "response address is not UTF-8",
  )
  expect_discovery_error(
    discovery_response(7U, "", 62000),
    "response address is empty",
  )
}

///|
async test "IP discovery validates its retry configuration" {
  let fake = FakeVoiceUdp()
  try
    @voice.discover_external_address(
      (fake : &@voice.VoiceUdp),
      42U,
      retries=0,
      timeout_ms=10,
    )
  catch {
    @voice.VoiceUdpError::IpDiscoveryFailed(attempts=0, reason~) =>
      assert_eq(reason, "retries and timeout_ms must be positive")
    error => fail("unexpected error: \{error}")
  } noraise {
    _ => fail("expected a configuration error")
  }
}

///|
async test "IP discovery re-raises non-timeout receive errors" {
  try
    @voice.discover_external_address(
      (FailingVoiceUdp::{  } : &@voice.VoiceUdp),
      42U,
      retries=2,
      timeout_ms=1000,
    )
  catch {
    UdpTestFailure => ()
    error => fail("unexpected error: \{error}")
  } noraise {
    _ => fail("expected the receive error to propagate")
  }
}

///|
struct SilentVoiceUdp {
  sends : Array[Bytes]
}

///|
impl @voice.VoiceUdp for SilentVoiceUdp with fn recv(_self, _buffer) {
  // never responds: the caller's receive timeout must fire
  @async.sleep(3_600_000)
  0
}

///|
impl @voice.VoiceUdp for SilentVoiceUdp with fn send(self, bytes) {
  self.sends.push(bytes)
}

///|
impl @voice.VoiceUdp for SilentVoiceUdp with fn close(_self) {

}

///|
async test "IP discovery retries receive timeouts and then raises" {
  let udp = SilentVoiceUdp::{ sends: [] }
  try
    @voice.discover_external_address(udp, 42U, retries=2, timeout_ms=5)
  catch {
    @voice.VoiceUdpError::IpDiscoveryFailed(attempts~, reason~) => {
      assert_eq(attempts, 2)
      assert_true(reason.contains("timed out"))
    }
    error => fail("unexpected discovery error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected discovery to fail")
  }
  // one request per attempt went out before each timeout
  assert_eq(udp.sends.length(), 2)
}

///|
async test "IP discovery rejects non-positive retries and timeouts" {
  let udp = SilentVoiceUdp::{ sends: [] }
  try @voice.discover_external_address(udp, 42U, retries=0) catch {
    @voice.VoiceUdpError::IpDiscoveryFailed(attempts~, ..) =>
      assert_eq(attempts, 0)
    error => fail("unexpected discovery error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected discovery to fail fast")
  }
  assert_eq(udp.sends.length(), 0)
}
