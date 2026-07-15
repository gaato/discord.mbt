///|
struct ConnectionTestTransport {
  incoming : @aqueue.Queue[@voice.VoiceFrame]
  outgoing_text : @aqueue.Queue[Json]
}

///|
fn ConnectionTestTransport::new() -> ConnectionTestTransport {
  { incoming: Queue(kind=Unbounded), outgoing_text: Queue(kind=Unbounded) }
}

///|
fn ConnectionTestTransport::server_close(
  self : ConnectionTestTransport,
  code : Int,
) -> Unit {
  self.incoming.close(
    error=@voice.VoiceTransportClosed(code=Some(code), reason="server close"),
  )
}

///|
impl @voice.VoiceTransport for ConnectionTestTransport with fn recv(self) {
  self.incoming.get()
}

///|
impl @voice.VoiceTransport for ConnectionTestTransport with fn send_text(
  self,
  text,
) {
  self.outgoing_text.put(@json.parse(text))
}

///|
impl @voice.VoiceTransport for ConnectionTestTransport with fn send_binary(
  _self,
  _bytes,
) {

}

///|
impl @voice.VoiceTransport for ConnectionTestTransport with fn close(
  self,
  code~,
) {
  self.incoming.close(
    error=@voice.VoiceTransportClosed(code=Some(code), reason="client close"),
  )
}

///|
struct ConnectionTestUdp {
  incoming : @aqueue.Queue[Bytes]
  outgoing : @aqueue.Queue[Bytes]
}

///|
fn ConnectionTestUdp::new() -> ConnectionTestUdp {
  { incoming: Queue(kind=Unbounded), outgoing: Queue(kind=Unbounded) }
}

///|
impl @voice.VoiceUdp for ConnectionTestUdp with fn recv(self, buffer) {
  let packet = self.incoming.get()
  let length = packet.length().min(buffer.length())
  for index in 0..<length {
    buffer[index] = packet[index]
  }
  length
}

///|
impl @voice.VoiceUdp for ConnectionTestUdp with fn send(self, bytes) {
  self.outgoing.put(bytes)
}

///|
impl @voice.VoiceUdp for ConnectionTestUdp with fn close(self) {
  self.incoming.close(
    error=@voice.VoiceUdpError::IpDiscoveryFailed(attempts=0, reason="closed"),
  )
}

///|
struct OneConnectionFrame {
  mut sent : Bool
}

///|
impl @voice.AudioSource for OneConnectionFrame with fn next_frame(self) {
  if self.sent {
    None
  } else {
    self.sent = true
    Some(b"voice-frame")
  }
}

///|
fn connection_credentials(
  session_id? : String = "session",
  endpoint? : String = "voice.example",
) -> @voice.VoiceCredentials {
  { server_id: "guild", session_id, token: "token", endpoint }
}

///|
fn connection_discovery_response(ssrc : UInt) -> Bytes {
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
  for byte in @utf8.encode("203.0.113.8") {
    bytes.push(byte)
  }
  bytes.push(0)
  while bytes.length() < 72 {
    bytes.push(0)
  }
  bytes.push(0xF2)
  bytes.push(0x30)
  Bytes::from_array(bytes)
}

///|
fn connection_hello() -> @voice.VoiceFrame {
  Text("{\"op\":8,\"d\":{\"heartbeat_interval\":60000}}")
}

///|
fn connection_ready(sequence : Int) -> @voice.VoiceFrame {
  Text(
    "{\"op\":2,\"seq\":\{sequence},\"d\":{\"ssrc\":42,\"ip\":\"198.51.100.1\",\"port\":5000,\"modes\":[\"aead_aes256_gcm_rtpsize\"]}}",
  )
}

///|
fn connection_session_description(
  sequence : Int,
  dave_protocol_version? : Int = 0,
) -> @voice.VoiceFrame {
  Text(
    "{\"op\":4,\"seq\":\{sequence},\"d\":{\"mode\":\"aead_aes256_gcm_rtpsize\",\"secret_key\":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\"dave_protocol_version\":\{dave_protocol_version}}}",
  )
}

///|
async fn connection_finish_protocol_selection(
  transport : ConnectionTestTransport,
  udp : ConnectionTestUdp,
) -> Unit {
  transport.incoming.put(connection_hello())
  guard transport.outgoing_text.get() is { "op": Number(0, ..), .. }
  transport.incoming.put(connection_ready(1))
  assert_eq(udp.outgoing.get(), @voice.build_ip_discovery_request(42U))
  udp.incoming.put(connection_discovery_response(42U))
  guard transport.outgoing_text.get() is { "op": Number(1, ..), .. }
}

///|
async test "voice connection becomes ready, plays, receives, and disconnects idempotently" {
  if !@voice.shim_available() {
    return
  }
  let transport = ConnectionTestTransport::new()
  let udp = ConnectionTestUdp::new()
  let leave_calls = Ref(0)
  @async.with_task_group(group => {
    let connection = @voice.VoiceConnection::start(
      group,
      connection_credentials(),
      user_id="self",
      channel_id=7UL,
      leave=() => leave_calls.val += 1,
      rejoin=() => connection_credentials(),
      connector=_ => (transport : &@voice.VoiceTransport),
      udp_opener=(_, _) => (udp : &@voice.VoiceUdp),
    )
    connection_finish_protocol_selection(transport, udp)
    transport.incoming.put(connection_session_description(2))
    connection.wait_ready(timeout_ms=1000)
    assert_eq(connection.state(), Ready)
    assert_eq(connection.next_event(), ConnectionReady)

    let source : &@voice.AudioSource = OneConnectionFrame::{ sent: false }
    connection.play(source)
    guard transport.outgoing_text.get()
      is { "op": Number(5, ..), "d": { "speaking": Number(1, ..), .. }, .. }
    let encrypted = udp.outgoing.get()
    let decryptor = @voice.TransportCipher::new(
      AeadAes256GcmRtpsize,
      Bytes::new(32),
    )
    let plain = decryptor.open(encrypted, header_len=12)
    assert_eq(@voice.parse_rtp_packet(plain).payload, b"voice-frame")

    transport.incoming.put(
      Text(
        "{\"op\":5,\"seq\":3,\"d\":{\"ssrc\":77,\"user_id\":\"speaker\",\"speaking\":1}}",
      ),
    )
    assert_eq(
      connection.next_event(),
      SpeakingChanged(user_id="speaker", ssrc=77U, flags=1),
    )
    let sender = @voice.TransportCipher::new(
      AeadAes256GcmRtpsize,
      Bytes::new(32),
    )
    let header = @voice.build_rtp_header(sequence=10, timestamp=960U, ssrc=77U)
    udp.incoming.put(sender.seal(header~, b"received-opus"))
    assert_eq(
      connection.next_event(),
      OpusReceived(
        user_id=Some("speaker"),
        ssrc=77U,
        sequence=10,
        timestamp=960U,
        opus=b"received-opus",
      ),
    )

    let unknown_header = @voice.build_rtp_header(
      sequence=1,
      timestamp=1920U,
      ssrc=99U,
    )
    udp.incoming.put(sender.seal(header=unknown_header, b"unknown"))
    assert_eq(
      connection.next_event(),
      OpusReceived(
        user_id=None,
        ssrc=99U,
        sequence=1,
        timestamp=1920U,
        opus=b"unknown",
      ),
    )

    connection.disconnect()
    connection.disconnect()
    assert_eq(leave_calls.val, 1)
    assert_eq(connection.state(), Closed(code=None))
  })
}

///|
async test "voice connection reports reordered packet loss" {
  if !@voice.shim_available() {
    return
  }
  let transport = ConnectionTestTransport::new()
  let udp = ConnectionTestUdp::new()
  @async.with_task_group(group => {
    let connection = @voice.VoiceConnection::start(
      group,
      connection_credentials(),
      user_id="self",
      channel_id=7UL,
      leave=() => (),
      rejoin=() => connection_credentials(),
      connector=_ => (transport : &@voice.VoiceTransport),
      udp_opener=(_, _) => (udp : &@voice.VoiceUdp),
    )
    connection_finish_protocol_selection(transport, udp)
    transport.incoming.put(connection_session_description(2))
    connection.wait_ready(timeout_ms=1000)
    connection.next_event() |> ignore
    let sender = @voice.TransportCipher::new(
      AeadAes256GcmRtpsize,
      Bytes::new(32),
    )
    let packet = (sequence : Int, timestamp : UInt) => {
      let header = @voice.build_rtp_header(
        sequence=sequence.to_uint16(),
        timestamp~,
        ssrc=55U,
      )
      sender.seal(header~, b"opus-\{sequence}")
    }
    udp.incoming.put(packet(1, 960U))
    guard connection.next_event() is OpusReceived(sequence=1, ..)
    udp.incoming.put(packet(3, 2880U))
    @async.sleep(65)
    udp.incoming.put(packet(4, 3840U))
    assert_eq(
      connection.next_event(),
      PacketsLost(user_id=None, ssrc=55U, count=1),
    )
    guard connection.next_event() is OpusReceived(sequence=3, ..)
    guard connection.next_event() is OpusReceived(sequence=4, ..)
    connection.disconnect()
  })
}

///|
async test "voice connection rebuilds the whole session after NeedsRejoin" {
  let first_transport = ConnectionTestTransport::new()
  let second_transport = ConnectionTestTransport::new()
  let first_udp = ConnectionTestUdp::new()
  let pending_transports : Array[ConnectionTestTransport] = [
    second_transport, first_transport,
  ]
  let rejoin_calls = Ref(0)
  @async.with_task_group(group => {
    let connection = @voice.VoiceConnection::start(
      group,
      connection_credentials(),
      user_id="self",
      channel_id=7UL,
      leave=() => (),
      rejoin=() => {
        rejoin_calls.val += 1
        connection_credentials(
          session_id="session-2",
          endpoint="voice-2.example",
        )
      },
      connector=_ => {
        guard pending_transports.pop() is Some(transport) else {
          raise @voice.VoiceTransportClosed(code=None, reason="no transport")
        }
        (transport : &@voice.VoiceTransport)
      },
      udp_opener=(_, _) => (first_udp : &@voice.VoiceUdp),
      receive=false,
    )
    connection_finish_protocol_selection(first_transport, first_udp)
    first_transport.server_close(4006)
    second_transport.incoming.put(connection_hello())
    let identify = second_transport.outgoing_text.get()
    guard identify
      is {
        "op": Number(0, ..),
        "d": { "session_id": String("session-2"), .. },
        ..
      }
    assert_eq(rejoin_calls.val, 1)
    assert_eq(connection.state(), Connecting)
    connection.disconnect()
  })
}

///|
async test "voice connection wait_ready reports JoinTimeout" {
  let transport = ConnectionTestTransport::new()
  @async.with_task_group(group => {
    let connection = @voice.VoiceConnection::start(
      group,
      connection_credentials(),
      user_id="self",
      channel_id=7UL,
      leave=() => (),
      rejoin=() => connection_credentials(),
      connector=_ => (transport : &@voice.VoiceTransport),
      receive=false,
    )
    try connection.wait_ready(timeout_ms=10) catch {
      JoinTimeout => ()
      error => fail("unexpected wait_ready error: \{to_repr(error)}")
    } noraise {
      _ => fail("expected JoinTimeout")
    }
    connection.disconnect()
  })
}

///|
async test "voice connection surfaces ShimUnavailable through wait_ready" {
  if @voice.shim_available() {
    return
  }
  let transport = ConnectionTestTransport::new()
  let udp = ConnectionTestUdp::new()
  @async.with_task_group(group => {
    let connection = @voice.VoiceConnection::start(
      group,
      connection_credentials(),
      user_id="self",
      channel_id=7UL,
      leave=() => (),
      rejoin=() => connection_credentials(),
      connector=_ => (transport : &@voice.VoiceTransport),
      udp_opener=(_, _) => (udp : &@voice.VoiceUdp),
      receive=false,
    )
    connection_finish_protocol_selection(transport, udp)
    transport.incoming.put(
      connection_session_description(2, dave_protocol_version=1),
    )
    try connection.wait_ready(timeout_ms=1000) catch {
      ShimUnavailable(reason~) => assert_true(!reason.is_empty())
      error => fail("unexpected wait_ready error: \{to_repr(error)}")
    } noraise {
      _ => fail("expected ShimUnavailable")
    }
    connection.disconnect()
  })
}
