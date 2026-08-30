///|
struct FakeVoiceUdp {
  incoming : @aqueue.Queue[Bytes]
  outgoing : @aqueue.Queue[Bytes]
}

///|
fn FakeVoiceUdp::FakeVoiceUdp() -> FakeVoiceUdp {
  { incoming: Queue(kind=Unbounded), outgoing: Queue(kind=Unbounded), }
}

///|
impl @voice.VoiceUdp for FakeVoiceUdp with fn recv(self, buffer) {
  let packet = self.incoming.get()
  let length = packet.length().min(buffer.length())
  for index in 0..<length {
    buffer[index] = packet[index]
  }
  length
}

///|
impl @voice.VoiceUdp for FakeVoiceUdp with fn send(self, bytes) {
  self.outgoing.put(bytes)
}

///|
impl @voice.VoiceUdp for FakeVoiceUdp with fn close(self) {
  self.incoming.close()
}

///|
fn discovery_response(ssrc : UInt, address : String, port : Int) -> Bytes {
  let bytes : Array[Byte] = [
    0,
    2,
    0,
    70,
    (ssrc >> 24).to_byte(),
    (ssrc >> 16).to_byte(),
    (ssrc >> 8).to_byte(),
    ssrc.to_byte(),
  ]
  for byte in @utf8.encode(address) {
    bytes.push(byte)
  }
  bytes.push(0)
  while bytes.length() < 72 {
    bytes.push(0)
  }
  bytes.push((port >> 8).to_byte())
  bytes.push(port.to_byte())
  Bytes::from_array(bytes)
}

///|
test "IP discovery request and response use the 74-byte wire format" {
  let request = @voice.build_ip_discovery_request(0x12345678U)
  assert_eq(request.length(), 74)
  assert_eq(request[:8].to_owned(), b"\x00\x01\x00\x46\x12\x34\x56\x78")
  for index in 8..<request.length() {
    assert_eq(request[index], 0)
  }
  let response = discovery_response(0x12345678U, "203.0.113.9", 62000)
  assert_eq(
    @voice.parse_ip_discovery_response(response, expected_ssrc=0x12345678U),
    ("203.0.113.9", 62000),
  )
}

///|
test "IP discovery rejects mismatched SSRC and missing NUL" {
  let response = discovery_response(7U, "203.0.113.9", 62000)
  try @voice.parse_ip_discovery_response(response, expected_ssrc=8U) catch {
    InvalidDiscoveryPacket(reason~) => assert_true(reason.contains("SSRC"))
    _ => fail("unexpected UDP error")
  } noraise {
    _ => fail("expected an SSRC mismatch")
  }
  let bytes = response.to_array()
  for index in 8..<72 {
    bytes[index] = b'x'
  }
  try
    @voice.parse_ip_discovery_response(
      Bytes::from_array(bytes),
      expected_ssrc=7U,
    )
  catch {
    InvalidDiscoveryPacket(reason~) => assert_true(reason.contains("NUL"))
    _ => fail("unexpected UDP error")
  } noraise {
    _ => fail("expected a missing NUL terminator error")
  }
}

///|
async test "IP discovery retries a timeout and accepts the next response" {
  let fake = FakeVoiceUdp()
  @async.with_task_group(group => {
    let result = group.spawn(() => {
      @voice.discover_external_address(
        (fake : &@voice.VoiceUdp),
        42U,
        retries=2,
        timeout_ms=10,
      )
    })
    assert_eq(fake.outgoing.get(), @voice.build_ip_discovery_request(42U))
    assert_eq(fake.outgoing.get(), @voice.build_ip_discovery_request(42U))
    fake.incoming.put(discovery_response(42U, "198.51.100.8", 50000))
    assert_eq(result.wait(), ("198.51.100.8", 50000))
  })
}

///|
async test "IP discovery reports exhausted timeouts" {
  let fake = FakeVoiceUdp()
  try
    @voice.discover_external_address(
      (fake : &@voice.VoiceUdp),
      42U,
      retries=2,
      timeout_ms=2,
    )
  catch {
    @voice.VoiceUdpError::IpDiscoveryFailed(attempts=2, reason~) =>
      assert_true(reason.contains("timed out"))
    error => fail("unexpected error: \{error}")
  } noraise {
    _ => fail("expected discovery timeout")
  }
}
