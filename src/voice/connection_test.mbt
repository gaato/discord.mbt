///|
struct ConnectionTestTransport {
  incoming : @aqueue.Queue[@voice.VoiceFrame]
  outgoing_text : @aqueue.Queue[Json]
  outgoing_binary : @aqueue.Queue[Bytes]
}

///|
fn ConnectionTestTransport::new() -> ConnectionTestTransport {
  {
    incoming: Queue(kind=Unbounded),
    outgoing_text: Queue(kind=Unbounded),
    outgoing_binary: Queue(kind=Unbounded),
  }
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
  self,
  bytes,
) {
  self.outgoing_binary.put(bytes)
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
struct CancelledDiscoveryUdp {
  outgoing : @aqueue.Queue[Bytes]
  recv_started : @aqueue.Queue[Unit]
  close_calls : Ref[Int]
}

///|
fn CancelledDiscoveryUdp::new() -> CancelledDiscoveryUdp {
  {
    outgoing: Queue(kind=Unbounded),
    recv_started: Queue(kind=Unbounded),
    close_calls: Ref(0),
  }
}

///|
impl @voice.VoiceUdp for CancelledDiscoveryUdp with fn recv(self, _buffer) {
  self.recv_started.put(())
  @async.sleep(3_600_000)
  0
}

///|
impl @voice.VoiceUdp for CancelledDiscoveryUdp with fn send(self, bytes) {
  self.outgoing.put(bytes)
}

///|
impl @voice.VoiceUdp for CancelledDiscoveryUdp with fn close(self) {
  self.close_calls.val += 1
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
struct ConnectionTestDave {
  proposal_calls : Array[Array[String]]
}

///|
impl @voice.DaveProvider for ConnectionTestDave with fn max_protocol_version(
  _self,
) {
  1
}

///|
impl @voice.DaveProvider for ConnectionTestDave with fn reinit(
  _self,
  protocol_version~,
) {
  assert_eq(protocol_version, 1)
}

///|
impl @voice.DaveProvider for ConnectionTestDave with fn set_external_sender(
  _self,
  _payload,
) {

}

///|
impl @voice.DaveProvider for ConnectionTestDave with fn key_package(_self) {
  b"connection-key-package"
}

///|
impl @voice.DaveProvider for ConnectionTestDave with fn process_proposals(
  self,
  op_type~,
  _payload,
  recognized~,
) {
  assert_eq(op_type, 0)
  self.proposal_calls.push(recognized.copy())
  (None, None)
}

///|
impl @voice.DaveProvider for ConnectionTestDave with fn process_commit(
  _self,
  _payload,
) {

}

///|
impl @voice.DaveProvider for ConnectionTestDave with fn process_welcome(
  _self,
  _payload,
) {

}

///|
impl @voice.DaveProvider for ConnectionTestDave with fn encrypt_frame(
  _self,
  frame,
) {
  frame
}

///|
impl @voice.DaveProvider for ConnectionTestDave with fn decrypt_frame(
  _self,
  user_id~,
  frame,
) {
  ignore(user_id)
  frame
}

///|
impl @voice.DaveProvider for ConnectionTestDave with fn status(_self) {
  0
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
  guard! transport.outgoing_text.get() is { "op": Number(0, ..), .. }
  transport.incoming.put(connection_ready(1))
  assert_eq(udp.outgoing.get(), @voice.build_ip_discovery_request(42U))
  udp.incoming.put(connection_discovery_response(42U))
  guard! transport.outgoing_text.get() is { "op": Number(1, ..), .. }
}

///|
async fn wait_for_proposal_calls(
  fake : ConnectionTestDave,
  expected : Int,
) -> Unit {
  @async.with_timeout(1000, () => {
    while fake.proposal_calls.length() < expected {
      @async.sleep(1)
    }
  })
}

///|
async test "cancelled voice discovery closes only its candidate UDP" {
  let transport = ConnectionTestTransport::new()
  let udp = CancelledDiscoveryUdp::new()
  let connections : @aqueue.Queue[@voice.VoiceConnection] = Queue(
    kind=Unbounded,
  )
  @async.with_task_group(group => {
    let owner = group.spawn(no_wait=true, allow_failure=true, () => {
      @async.with_task_group(connection_group => {
        let connection = @voice.VoiceConnection::start(
          connection_group,
          connection_credentials(),
          user_id="self",
          channel_id=7UL,
          leave=() => (),
          rejoin=() => connection_credentials(),
          connector=_ => (transport : &@voice.VoiceTransport),
          udp_opener=(_, _) => (udp : &@voice.VoiceUdp),
          receive=false,
        )
        connections.put(connection)
        @async.sleep(3_600_000)
      })
    })
    let connection = connections.get()
    transport.incoming.put(connection_hello())
    guard transport.outgoing_text.get() is { "op": Number(0, ..), .. } else {
      fail("expected voice identify before discovery")
    }
    transport.incoming.put(connection_ready(1))
    assert_eq(udp.outgoing.get(), @voice.build_ip_discovery_request(42U))
    udp.recv_started.get()

    owner.cancel()
    try owner.wait() catch {
      error if @async.is_cancellation_error(error) => ()
      error => fail("unexpected discovery cancellation error: \{Repr(error)}")
    } noraise {
      _ => fail("cancelled discovery unexpectedly completed")
    }
    assert_eq(udp.close_calls.val, 1)
    try connection.wait_ready(timeout_ms=10) catch {
      IpDiscoveryFailed(reason~) =>
        fail("cancellation was converted to IpDiscoveryFailed: \{reason}")
      JoinTimeout | Disconnected => ()
      error => fail("unexpected post-cancellation error: \{Repr(error)}")
    } noraise {
      _ => fail("cancelled discovery unexpectedly became ready")
    }
  })
}

///|
async test "voice connection seeds its pre-session DAVE roster and sends key packages" {
  if !@voice.shim_available() {
    return
  }
  let transport = ConnectionTestTransport::new()
  let udp = ConnectionTestUdp::new()
  let fake = ConnectionTestDave::{ proposal_calls: [] }
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
      dave_factory=(protocol_version, user_id, channel_id) => {
        assert_eq(protocol_version, 1)
        assert_eq(user_id, "self")
        assert_eq(channel_id, 7UL)
        (fake : &@voice.DaveProvider)
      },
      receive=false,
    )
    connection_finish_protocol_selection(transport, udp)
    transport.incoming.put(
      Text("{\"op\":11,\"seq\":2,\"d\":{\"user_ids\":[\"member\"]}}"),
    )
    transport.incoming.put(
      connection_session_description(3, dave_protocol_version=1),
    )
    connection.wait_ready(timeout_ms=1000)
    assert_eq(transport.outgoing_binary.get(), b"\x1Aconnection-key-package")
    transport.incoming.put(Binary(b"\x00\x04\x1B\x00proposal"))
    wait_for_proposal_calls(fake, 1)
    assert_eq(fake.proposal_calls[0], ["member", "self"])

    // A newly established DAVE machine receives the connection's same roster.
    transport.incoming.put(
      connection_session_description(5, dave_protocol_version=1),
    )
    assert_eq(transport.outgoing_binary.get(), b"\x1Aconnection-key-package")
    transport.incoming.put(Binary(b"\x00\x06\x1B\x00proposal"))
    wait_for_proposal_calls(fake, 2)
    assert_eq(fake.proposal_calls[1], ["member", "self"])
    connection.disconnect()
  })
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
    guard! transport.outgoing_text.get()
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
    guard! connection.next_event() is OpusReceived(sequence=1, ..)
    udp.incoming.put(packet(3, 2880U))
    @async.sleep(65)
    udp.incoming.put(packet(4, 3840U))
    assert_eq(
      connection.next_event(),
      PacketsLost(user_id=None, ssrc=55U, count=1),
    )
    guard! connection.next_event() is OpusReceived(sequence=3, ..)
    guard! connection.next_event() is OpusReceived(sequence=4, ..)
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
    guard! identify
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

///|
async fn[X] ready_receive_connection(
  group : @async.TaskGroup[X],
  transport : ConnectionTestTransport,
  udp : ConnectionTestUdp,
) -> @voice.VoiceConnection {
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
  assert_eq(connection.next_event(), ConnectionReady)
  connection
}

///|
async fn map_connection_speaker(
  connection : @voice.VoiceConnection,
  transport : ConnectionTestTransport,
  user_id : String,
  ssrc : UInt,
  sequence : Int,
) -> Unit {
  transport.incoming.put(
    Text(
      "{\"op\":5,\"seq\":\{sequence},\"d\":{\"ssrc\":\{ssrc},\"user_id\":\"\{user_id}\",\"speaking\":1}}",
    ),
  )
  assert_eq(connection.next_event(), SpeakingChanged(user_id~, ssrc~, flags=1))
}

///|
fn connection_opus_datagram(
  ssrc : UInt,
  sequence : Int,
  opus : Bytes,
) -> Bytes raise {
  let sender = @voice.TransportCipher::new(AeadAes256GcmRtpsize, Bytes::new(32))
  let header = @voice.build_rtp_header(
    sequence=sequence.to_uint16(),
    timestamp=(sequence * 960).reinterpret_as_uint(),
    ssrc~,
  )
  sender.seal(header~, opus)
}

///|
async test "voice subscriptions filter users without consuming main events" {
  if !@voice.shim_available() {
    return
  }
  let transport = ConnectionTestTransport::new()
  let udp = ConnectionTestUdp::new()
  @async.with_task_group(group => {
    let connection = ready_receive_connection(group, transport, udp)
    map_connection_speaker(connection, transport, "target", 77U, 3)
    map_connection_speaker(connection, transport, "other", 88U, 4)
    let stream = connection.subscribe(user_id="target")
    let audio : &@voice.AudioSource = stream
    udp.incoming.put(connection_opus_datagram(77U, 1, b"target-one"))
    udp.incoming.put(connection_opus_datagram(88U, 1, b"other"))
    udp.incoming.put(connection_opus_datagram(77U, 2, b"target-two"))
    assert_eq(
      connection.next_event(),
      OpusReceived(
        user_id=Some("target"),
        ssrc=77U,
        sequence=1,
        timestamp=960U,
        opus=b"target-one",
      ),
    )
    assert_eq(
      connection.next_event(),
      OpusReceived(
        user_id=Some("other"),
        ssrc=88U,
        sequence=1,
        timestamp=960U,
        opus=b"other",
      ),
    )
    assert_eq(
      connection.next_event(),
      OpusReceived(
        user_id=Some("target"),
        ssrc=77U,
        sequence=2,
        timestamp=1920U,
        opus=b"target-two",
      ),
    )
    assert_eq(audio.next_frame(), Some(b"target-one"))
    assert_eq(audio.next_frame(), Some(b"target-two"))
    stream.close()
    connection.disconnect()
  })
}

///|
async test "voice subscription ends and unregisters after silence" {
  if !@voice.shim_available() {
    return
  }
  let transport = ConnectionTestTransport::new()
  let udp = ConnectionTestUdp::new()
  @async.with_task_group(group => {
    let connection = ready_receive_connection(group, transport, udp)
    map_connection_speaker(connection, transport, "target", 77U, 3)
    let stream = connection.subscribe(
      user_id="target",
      end_after_silence_ms=Some(20),
    )
    let audio : &@voice.AudioSource = stream
    udp.incoming.put(connection_opus_datagram(77U, 1, b"first"))
    guard! connection.next_event() is OpusReceived(opus=b"first", ..)
    assert_eq(audio.next_frame(), Some(b"first"))
    assert_eq(@async.with_timeout(200, () => audio.next_frame()), None)
    udp.incoming.put(connection_opus_datagram(77U, 2, b"too-late"))
    guard! connection.next_event() is OpusReceived(opus=b"too-late", ..)
    assert_eq(audio.next_frame(), None)
    connection.disconnect()
  })
}

///|
async test "closing a voice subscription wakes a blocked reader" {
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
    let stream = connection.subscribe(user_id="target")
    let audio : &@voice.AudioSource = stream
    let blocked = group.spawn(() => audio.next_frame())
    @async.sleep(10)
    stream.close()
    assert_eq(@async.with_timeout(200, () => blocked.wait()), None)
    connection.disconnect()
  })
}

///|
async test "disconnect ends every voice subscription" {
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
    let first : &@voice.AudioSource = connection.subscribe(user_id="one")
    let second : &@voice.AudioSource = connection.subscribe(user_id="two")
    let first_read = group.spawn(() => first.next_frame())
    let second_read = group.spawn(() => second.next_frame())
    @async.sleep(10)
    connection.disconnect()
    assert_eq(@async.with_timeout(200, () => first_read.wait()), None)
    assert_eq(@async.with_timeout(200, () => second_read.wait()), None)
  })
}

///|
async test "manual voice subscription waits across a long gap" {
  if !@voice.shim_available() {
    return
  }
  let transport = ConnectionTestTransport::new()
  let udp = ConnectionTestUdp::new()
  @async.with_task_group(group => {
    let connection = ready_receive_connection(group, transport, udp)
    map_connection_speaker(connection, transport, "target", 77U, 3)
    let stream = connection.subscribe(
      user_id="target",
      end_after_silence_ms=None,
    )
    let audio : &@voice.AudioSource = stream
    let blocked = group.spawn(() => audio.next_frame())
    @async.sleep(60)
    udp.incoming.put(connection_opus_datagram(77U, 1, b"after-gap"))
    guard! connection.next_event() is OpusReceived(opus=b"after-gap", ..)
    assert_eq(
      @async.with_timeout(200, () => blocked.wait()),
      Some(b"after-gap"),
    )
    stream.close()
    connection.disconnect()
  })
}

///|
async test "voice keepalive cadence runs through the injected sleeper" {
  let transport = ConnectionTestTransport::new()
  let udp = ConnectionTestUdp::new()
  let gate = SleepGate()
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
      // only the keepalive loop sleeps exactly 5000ms; park everything else
      sleeper=ms => {
        if ms == 5000 {
          gate.sleep(ms)
        } else {
          @async.sleep(3_600_000)
        }
      },
    )
    // tick 1 elapses before the UDP socket exists: nothing is sent
    assert_eq(gate.requests.get(), 5000)
    gate.release()
    assert_eq(gate.requests.get(), 5000)
    // bring the socket up, then let tick 2 elapse: the 8-byte counter goes out
    connection_finish_protocol_selection(transport, udp)
    gate.release()
    assert_eq(udp.outgoing.get(), b"\x00\x00\x00\x00\x00\x00\x00\x00")
    // tick 3: the counter increments little-endian
    assert_eq(gate.requests.get(), 5000)
    gate.release()
    assert_eq(udp.outgoing.get(), b"\x01\x00\x00\x00\x00\x00\x00\x00")
    connection.disconnect()
  })
}
