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
  code : Int32,
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
  close_calls : Ref[Int32]
  fail_close : Ref[Bool]
  recv_started : @aqueue.Queue[Unit]
  fail_recv : Ref[Bool]
  received : Ref[Int32]
}

///|
fn ConnectionTestUdp::new() -> ConnectionTestUdp {
  {
    incoming: Queue(kind=Unbounded),
    outgoing: Queue(kind=Unbounded),
    close_calls: Ref(0),
    fail_close: Ref(false),
    recv_started: Queue(kind=Unbounded),
    fail_recv: Ref(false),
    received: Ref(0),
  }
}

///|
impl @voice.VoiceUdp for ConnectionTestUdp with fn recv(self, buffer) {
  self.recv_started.put(())
  let packet = self.incoming.get()
  self.received.val += 1
  if self.fail_recv.val {
    raise VoiceTestFailure
  }
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
  self.close_calls.val += 1
  self.incoming.close(
    error=@voice.VoiceUdpError::IpDiscoveryFailed(attempts=0, reason="closed"),
  )
  if self.fail_close.val {
    raise VoiceTestFailure
  }
}

///|
async fn expect_connection_terminated(
  connection : @voice.VoiceConnection,
) -> Unit {
  try connection.next_event() |> ignore catch {
    @voice.VoiceError::Disconnected => ()
    error => fail("unexpected terminal error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the connection event queue to close")
  }
  assert_true(connection.state() is Closed(..))
}

///|
async test "voice connection rejects unsupported Ready modes before opening UDP" {
  let transport = ConnectionTestTransport::new()
  let opens = Ref(0)
  @async.with_task_group(group => {
    let connection = @voice.VoiceConnection::start(
      group,
      connection_credentials(),
      user_id="100",
      channel_id=7UL,
      leave=() => (),
      rejoin=() => fail("unexpected rejoin"),
      connector=_ => (transport : &@voice.VoiceTransport),
      udp_opener=(_, _) => {
        opens.val += 1
        raise VoiceTestFailure
      },
      receive=false,
      clock=@netruntime.VirtualClock(),
    )
    transport.incoming.put(connection_hello())
    transport.outgoing_text.get() |> ignore
    transport.incoming.put(
      Text(
        "{\"op\":2,\"d\":{\"ssrc\":42,\"ip\":\"198.51.100.1\",\"port\":5000,\"modes\":[\"unsupported\"]}}",
      ),
    )
    expect_connection_terminated(connection)
    try connection.wait_ready() catch {
      NoCompatibleMode(offered~) => assert_eq(offered, ["unsupported"])
      error => fail("unexpected negotiation error: \{Repr(error)}")
    } noraise {
      _ => fail("expected mode negotiation failure")
    }
    assert_eq(opens.val, 0)
  })
}

///|
async test "voice connection translates UDP open and discovery errors" {
  for failure in 0..<3 {
    let transport = ConnectionTestTransport::new()
    let udp = ConnectionTestUdp::new()
    @async.with_task_group(group => {
      let connection = @voice.VoiceConnection::start(
        group,
        connection_credentials(),
        user_id="100",
        channel_id=7UL,
        leave=() => (),
        rejoin=() => fail("unexpected rejoin"),
        connector=_ => (transport : &@voice.VoiceTransport),
        udp_opener=(_, _) => {
          if failure == 0 {
            raise VoiceTestFailure
          }
          (udp : &@voice.VoiceUdp)
        },
        receive=false,
        clock=@netruntime.VirtualClock(),
      )
      transport.incoming.put(connection_hello())
      transport.outgoing_text.get() |> ignore
      if failure == 1 {
        udp.incoming.close(
          error=@voice.VoiceUdpError::IpDiscoveryFailed(
            attempts=1,
            reason="fake discovery failure",
          ),
        )
      } else if failure == 2 {
        udp.incoming.put(b"malformed")
      }
      transport.incoming.put(connection_ready(1))
      expect_connection_terminated(connection)
      try connection.wait_ready() catch {
        IpDiscoveryFailed(reason~) =>
          if failure == 1 {
            assert_eq(reason, "fake discovery failure")
          } else if failure == 2 {
            assert_true(reason.contains("response must contain 74 bytes"))
          } else {
            assert_true(reason.contains("VoiceTestFailure"))
          }
        error => fail("unexpected discovery error: \{Repr(error)}")
      } noraise {
        _ => fail("expected discovery failure")
      }
      assert_eq(udp.close_calls.val, if failure == 0 { 0 } else { 1 })
    })
  }
}

///|
async test "voice connection cancellation interrupts a pending UDP opener" {
  let transport = ConnectionTestTransport::new()
  let opened : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let pending : @aqueue.Queue[&@voice.VoiceUdp] = Queue(kind=Unbounded)
  let leaves = Ref(0)
  @async.with_task_group(group => {
    let connection = @voice.VoiceConnection::start(
      group,
      connection_credentials(),
      user_id="100",
      channel_id=7UL,
      leave=() => leaves.val += 1,
      rejoin=() => fail("unexpected rejoin"),
      connector=_ => (transport : &@voice.VoiceTransport),
      udp_opener=(_, _) => {
        opened.put(())
        pending.get()
      },
      receive=false,
      clock=@netruntime.VirtualClock(),
    )
    transport.incoming.put(connection_hello())
    transport.outgoing_text.get() |> ignore
    transport.incoming.put(connection_ready(1))
    opened.get()
    connection.disconnect()
    expect_connection_terminated(connection)
    assert_eq(leaves.val, 1)
  })
}

///|
async test "voice connection rejects invalid Session Description modes and keys" {
  for bad_mode in [true, false] {
    let transport = ConnectionTestTransport::new()
    let udp = ConnectionTestUdp::new()
    @async.with_task_group(group => {
      let connection = @voice.VoiceConnection::start(
        group,
        connection_credentials(),
        user_id="100",
        channel_id=7UL,
        leave=() => (),
        rejoin=() => fail("unexpected rejoin"),
        connector=_ => (transport : &@voice.VoiceTransport),
        udp_opener=(_, _) => (udp : &@voice.VoiceUdp),
        receive=false,
        clock=@netruntime.VirtualClock(),
      )
      connection_finish_protocol_selection(transport, udp)
      let frame : Json = {
        "op": 4,
        "d": {
          "mode": if bad_mode {
            "unsupported"
          } else {
            "aead_aes256_gcm_rtpsize"
          },
          "secret_key": [],
          "dave_protocol_version": 0,
        },
      }
      transport.incoming.put(Text(frame.stringify()))
      expect_connection_terminated(connection)
      try connection.wait_ready() catch {
        NoCompatibleMode(offered~) => {
          assert_true(bad_mode)
          assert_eq(offered, ["unsupported"])
        }
        ShimUnavailable(reason~) => {
          assert_false(bad_mode)
          assert_true(reason.contains("InvalidSecretKey"))
        }
        error => fail("unexpected session error: \{Repr(error)}")
      } noraise {
        _ => fail("expected session establishment failure")
      }
      assert_eq(udp.close_calls.val, 1)
    })
  }
}

///|
async test "voice connection rejects an invalid DAVE version during session establishment" {
  if !@voice.shim_available() {
    return
  }
  let transport = ConnectionTestTransport::new()
  let udp = ConnectionTestUdp::new()
  @async.with_task_group(group => {
    let connection = @voice.VoiceConnection::start(
      group,
      connection_credentials(),
      user_id="100",
      channel_id=7UL,
      leave=() => (),
      rejoin=() => fail("unexpected rejoin"),
      connector=_ => (transport : &@voice.VoiceTransport),
      udp_opener=(_, _) => (udp : &@voice.VoiceUdp),
      receive=false,
      clock=@netruntime.VirtualClock(),
    )
    connection_finish_protocol_selection(transport, udp)
    transport.incoming.put(
      connection_session_description(2, dave_protocol_version=65536),
    )
    expect_connection_terminated(connection)
    try connection.wait_ready() catch {
      ShimUnavailable(reason~) => assert_true(reason.has_prefix("DAVE:"))
      error => fail("unexpected DAVE initialization error: \{Repr(error)}")
    } noraise {
      _ => fail("expected invalid DAVE version failure")
    }
  })
}

///|
async test "voice connection selects xchacha and exposes speaking and latency without a session" {
  let transport = ConnectionTestTransport::new()
  let udp = ConnectionTestUdp::new()
  @async.with_task_group(group => {
    let connection = @voice.VoiceConnection::start(
      group,
      connection_credentials(),
      user_id="100",
      channel_id=7UL,
      leave=() => raise VoiceTestFailure,
      rejoin=() => fail("unexpected rejoin"),
      connector=_ => (transport : &@voice.VoiceTransport),
      udp_opener=(_, _) => (udp : &@voice.VoiceUdp),
      receive=false,
      clock=@netruntime.VirtualClock(),
    )
    assert_eq(connection.latency_ms(), None)
    try connection.set_speaking(1) catch {
      @voice.VoiceError::Disconnected => ()
      error => fail("unexpected speaking error: \{Repr(error)}")
    } noraise {
      _ => fail("expected speaking before discovery to fail")
    }
    transport.incoming.put(connection_hello())
    transport.outgoing_text.get() |> ignore
    transport.incoming.put(
      Text(
        "{\"op\":2,\"d\":{\"ssrc\":42,\"ip\":\"198.51.100.1\",\"port\":5000,\"modes\":[\"aead_xchacha20_poly1305_rtpsize\"]}}",
      ),
    )
    assert_eq(udp.outgoing.get(), @voice.build_ip_discovery_request(42U))
    udp.incoming.put(connection_discovery_response(42U))
    guard transport.outgoing_text.get()
      is {
        "op": Number(1, ..),
        "d": {
          "data": { "mode": String("aead_xchacha20_poly1305_rtpsize"), .. },
          ..
        },
        ..
      } else {
      fail("expected xchacha protocol selection")
    }
    connection.set_speaking(3)
    assert_eq(transport.outgoing_text.get(), {
      "op": 5,
      "d": { "speaking": 3, "delay": 0, "ssrc": 42 },
    })
    connection.stop()
    udp.fail_close.val = true
    connection.disconnect()
    assert_eq(udp.close_calls.val, 1)
    assert_eq(connection.latency_ms(), None)
  })
}

///|
async test "voice connection preserves fatal close errors and failed rejoin credentials" {
  for fatal in [false, true] {
    let transport = ConnectionTestTransport::new()
    let rejoins = Ref(0)
    @async.with_task_group(group => {
      let connection = @voice.VoiceConnection::start(
        group,
        connection_credentials(),
        user_id="100",
        channel_id=7UL,
        leave=() => (),
        rejoin=() => {
          rejoins.val += 1
          raise VoiceTestFailure
        },
        connector=_ => (transport : &@voice.VoiceTransport),
        receive=false,
        clock=@netruntime.VirtualClock(),
      )
      transport.incoming.put(connection_hello())
      transport.outgoing_text.get() |> ignore
      transport.server_close(if fatal { 4014 } else { 4006 })
      expect_connection_terminated(connection)
      try connection.wait_ready() catch {
        GatewayClosed(code~) => {
          assert_true(fatal)
          assert_eq(code, Some(4014))
        }
        @voice.VoiceError::Disconnected => assert_false(fatal)
        error => fail("unexpected close error: \{Repr(error)}")
      } noraise {
        _ => fail("expected closed connection failure")
      }
      assert_eq(rejoins.val, if fatal { 0 } else { 1 })
    })
  }
}

///|
async test "voice connection keepalive ignores UDP send failure and keeps its cadence" {
  let transport = ConnectionTestTransport::new()
  let udp = ConnectionTestUdp::new()
  let clock = @netruntime.VirtualClock()
  @async.with_task_group(group => {
    let connection = @voice.VoiceConnection::start(
      group,
      connection_credentials(),
      user_id="100",
      channel_id=7UL,
      leave=() => (),
      rejoin=() => fail("unexpected rejoin"),
      connector=_ => (transport : &@voice.VoiceTransport),
      udp_opener=(_, _) => (udp : &@voice.VoiceUdp),
      receive=false,
      clock~,
    )
    connection_finish_protocol_selection(transport, udp)
    clock.settle(until=() => clock.pending() == [5000, 60000])
    // the keepalive and the gateway heartbeat
    assert_eq(clock.pending(), [5000, 60000])
    udp.outgoing.close(error=VoiceTestFailure)
    clock.advance(5000)
    clock.settle(until=() => clock.pending() == [5000, 60000])
    // the failed send is ignored and the next tick is scheduled at once
    assert_eq(clock.pending(), [5000, 60000])
    assert_eq(clock.next_deadline(), Some(clock.now_unix_ms() + 5000))
    connection.disconnect()
  })
}

///|
async test "voice connection ignores credentials returned after disconnect" {
  let transport = ConnectionTestTransport::new()
  let requested : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let credentials : @aqueue.Queue[@voice.VoiceCredentials] = Queue(
    kind=Unbounded,
  )
  let returned : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let connects = Ref(0)
  @async.with_task_group(group => {
    let connection = @voice.VoiceConnection::start(
      group,
      connection_credentials(),
      user_id="100",
      channel_id=7UL,
      leave=() => (),
      rejoin=() => {
        requested.put(())
        let result = credentials.get()
        returned.put(())
        result
      },
      connector=_ => {
        connects.val += 1
        (transport : &@voice.VoiceTransport)
      },
      receive=false,
      clock=@netruntime.VirtualClock(),
    )
    transport.incoming.put(connection_hello())
    transport.outgoing_text.get() |> ignore
    transport.server_close(4006)
    requested.get()
    assert_eq(connection.state(), Rejoining)
    connection.disconnect()
    credentials.put(connection_credentials(session_id="late"))
    returned.get()
    assert_eq(connects.val, 1)
    assert_eq(connection.state(), Closed(code=None))
  })
}

///|
async test "voice events arriving while disconnect leaves the channel are ignored" {
  let transport = ConnectionTestTransport::new()
  let leaving : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let left : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let rejoins = Ref(0)
  let clock = @netruntime.VirtualClock()
  @async.with_task_group(group => {
    let connection = @voice.VoiceConnection::start(
      group,
      connection_credentials(),
      user_id="100",
      channel_id=7UL,
      leave=() => {
        leaving.put(())
        left.get()
      },
      rejoin=() => {
        rejoins.val += 1
        connection_credentials(session_id="late")
      },
      connector=_ => (transport : &@voice.VoiceTransport),
      receive=false,
      clock~,
    )
    transport.incoming.put(connection_hello())
    transport.outgoing_text.get() |> ignore
    group.spawn_bg(() => connection.disconnect())
    // The leave is still on its way to the main gateway when the voice
    // server asks for a rejoin.
    leaving.get()
    transport.server_close(4006)
    clock.settle(until=() => connection.state() is Closed(..))
    assert_eq(rejoins.val, 0)
    assert_eq(connection.state(), Closed(code=None))
    left.put(())
  })
}

///|
async test "voice connection resumes its existing session after a transient close" {
  if !@voice.shim_available() {
    return
  }
  let first = ConnectionTestTransport::new()
  let second = ConnectionTestTransport::new()
  let transports = [second, first]
  let udp = ConnectionTestUdp::new()
  let clock = @netruntime.VirtualClock()
  let backoffs = BackoffDraws::new()
  @async.with_task_group(group => {
    let connection = @voice.VoiceConnection::start(
      group,
      connection_credentials(),
      user_id="100",
      channel_id=7UL,
      leave=() => (),
      rejoin=() => fail("resume must not rejoin"),
      connector=_ => (transports.pop().unwrap() : &@voice.VoiceTransport),
      udp_opener=(_, _) => (udp : &@voice.VoiceUdp),
      receive=false,
      clock~,
      rand=backoff_rand(),
    )
    connection_finish_protocol_selection(first, udp)
    first.incoming.put(connection_session_description(2))
    assert_eq(connection.next_event(), ConnectionReady)
    first.server_close(4015)
    clock.settle(until=() => {
      connection.state() is Reconnecting &&
      clock.pending().length() == 2 &&
      clock.pending().contains(5000) &&
      !clock.pending().contains(60000)
    })
    assert_eq(connection.state(), Reconnecting)
    // the backoff runs ahead of the keepalive; the old heartbeat is gone
    assert_eq(clock.pending(), [backoffs.next(attempts=1), 5000])
    assert_true(clock.advance_to_next())
    second.incoming.put(connection_hello())
    guard! second.outgoing_text.get() is { "op": Number(7, ..), .. }
    second.incoming.put(Text("{\"op\":9,\"d\":null}"))
    assert_eq(connection.next_event(), ConnectionResumed)
    assert_eq(connection.state(), Ready)
    assert_eq(udp.close_calls.val, 0)
    connection.disconnect()
  })
}

///|
async test "voice receiver discards empty datagrams and stops after UDP close" {
  if !@voice.shim_available() {
    return
  }
  let transport = ConnectionTestTransport::new()
  let udp = ConnectionTestUdp::new()
  let clock = @netruntime.VirtualClock()
  @async.with_task_group(group => {
    let connection = ready_receive_connection(group, transport, udp, clock~)
    map_connection_speaker(connection, transport, "200", 77U, 3)
    let stream = connection.subscribe(user_id="200")
    udp.recv_started.get()
    udp.recv_started.get()
    udp.fail_recv.val = true
    udp.incoming.put(b"failed receive")
    clock.settle(until=() => clock.pending().contains(5))
    clock.advance(5)
    udp.recv_started.get()
    udp.fail_recv.val = false
    udp.incoming.put(b"")
    udp.recv_started.get()
    let cipher = @voice.TransportCipher::new(
      AeadAes256GcmRtpsize,
      Bytes::new(32),
    )
    let header = @voice.build_rtp_header(sequence=1, timestamp=960U, ssrc=77U)
    udp.incoming.put(cipher.seal(header~, b"after-empty"))
    assert_eq(
      stream.next_packet(),
      Some(Opus(sequence=1, timestamp=960U, opus=b"after-empty")),
    )
    udp.recv_started.get()
    connection.disconnect()
    clock.settle(until=() => clock.pending().is_empty())
    expect_connection_terminated(connection)
  })
}

///|
async test "voice receiver backs off on the clock after a failed receive" {
  if !@voice.shim_available() {
    return
  }
  let transport = ConnectionTestTransport::new()
  let udp = ConnectionTestUdp::new()
  let clock = @netruntime.VirtualClock()
  @async.with_task_group(group => {
    let connection = ready_receive_connection(group, transport, udp, clock~)
    map_connection_speaker(connection, transport, "200", 77U, 3)
    let stream = connection.subscribe(user_id="200")
    udp.recv_started.get()
    udp.recv_started.get()
    udp.fail_recv.val = true
    udp.incoming.put(b"failed receive")
    clock.settle(until=() => clock.pending() == [5, 5000, 60000])
    // a 5ms backoff ahead of the keepalive and the heartbeat
    assert_eq(clock.pending(), [5, 5000, 60000])
    udp.fail_recv.val = false
    clock.advance(4)
    assert_eq(udp.recv_started.try_get(), None)
    clock.advance(1)
    udp.recv_started.get()
    udp.incoming.put(connection_opus_datagram(77U, 1, b"after-backoff"))
    assert_eq(
      stream.next_packet(),
      Some(Opus(sequence=1, timestamp=960U, opus=b"after-backoff")),
    )
    connection.disconnect()
  })
}

///|
async test "disconnect wakes the voice receiver waiting for a session" {
  let transport = ConnectionTestTransport::new()
  let udp = ConnectionTestUdp::new()
  let clock = @netruntime.VirtualClock()
  @async.with_task_group(group => {
    let connection = @voice.VoiceConnection::start(
      group,
      connection_credentials(),
      user_id="100",
      channel_id=7UL,
      leave=() => (),
      rejoin=() => fail("unexpected rejoin"),
      connector=_ => (transport : &@voice.VoiceTransport),
      udp_opener=(_, _) => (udp : &@voice.VoiceUdp),
      clock~,
    )
    connection_finish_protocol_selection(transport, udp)
    clock.settle(until=() => clock.pending() == [5000, 60000])
    connection.disconnect()
    clock.settle(until=() => clock.pending().is_empty())
    // only IP discovery ever read the socket
    assert_eq(udp.recv_started.try_get() is Some(_), true)
    assert_eq(udp.recv_started.try_get(), None)
    expect_connection_terminated(connection)
  })
}

///|
struct CancelledDiscoveryUdp {
  outgoing : @aqueue.Queue[Bytes]
  recv_started : @aqueue.Queue[Unit]
  close_calls : Ref[Int32]
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
fn connection_credentials(
  session_id~ : String = "session",
  endpoint~ : String = "voice.example",
) -> @voice.VoiceCredentials {
  { server_id: "guild", session_id, token: "token", endpoint, }
}

///|
fn connection_discovery_response(ssrc : UInt32) -> Bytes {
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
fn connection_ready(sequence : Int32) -> @voice.VoiceFrame {
  Text(
    "{\"op\":2,\"seq\":\{sequence},\"d\":{\"ssrc\":42,\"ip\":\"198.51.100.1\",\"port\":5000,\"modes\":[\"aead_aes256_gcm_rtpsize\"]}}",
  )
}

///|
fn connection_session_description(
  sequence : Int32,
  dave_protocol_version~ : Int32 = 0,
) -> @voice.VoiceFrame {
  Text(
    "{\"op\":4,\"seq\":\{sequence},\"d\":{\"mode\":\"aead_aes256_gcm_rtpsize\",\"secret_key\":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\"dave_protocol_version\":\{dave_protocol_version}}}",
  )
}

///|
fn connection_external_sender() -> Bytes {
  // RFC 9420 ExternalSender using the P-256 generator point and a basic
  // credential. The value is valid MLS TLS presentation data, not keying
  // material used by the test client.
  b"\x40\x41\x04\x6b\x17\xd1\xf2\xe1\x2c\x42\x47\xf8\xbc\xe6\xe5\x63\xa4\x40\xf2\x77\x03\x7d\x81\x2d\xeb\x33\xa0\xf4\xa1\x39\x45\xd8\x98\xc2\x96\x4f\xe3\x42\xe2\xfe\x1a\x7f\x9b\x8e\xe7\xeb\x4a\x7c\x0f\x9e\x16\x2b\xce\x33\x57\x6b\x31\x5e\xce\xcb\xb6\x40\x68\x37\xbf\x51\xf5\x00\x01\x05\x04\x00\x01\x01\x00"
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
          user_id="100",
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
      @async.WaitedTaskAlreadyCancelled => ()
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
async test "voice connection constructs official DAVE and sends a key package" {
  if !@voice.shim_available() || !@dave.available() {
    return
  }
  let transport = ConnectionTestTransport::new()
  let udp = ConnectionTestUdp::new()
  let telemetry : Array[@voice.VoiceTelemetry] = []
  @async.with_task_group(group => {
    let connection = @voice.VoiceConnection::start(
      group,
      connection_credentials(),
      user_id="100",
      channel_id=7UL,
      leave=() => (),
      rejoin=() => connection_credentials(),
      connector=_ => (transport : &@voice.VoiceTransport),
      udp_opener=(_, _) => (udp : &@voice.VoiceUdp),
      receive=false,
      telemetry=event => telemetry.push(event),
    )
    connection_finish_protocol_selection(transport, udp)
    transport.incoming.put(
      Text("{\"op\":11,\"seq\":2,\"d\":{\"user_ids\":[\"200\"]}}"),
    )
    transport.incoming.put(
      Binary(b"\x00\x03\x19" + connection_external_sender()),
    )
    transport.incoming.put(
      connection_session_description(4, dave_protocol_version=1),
    )
    connection.wait_ready(timeout_ms=1000)
    let key_package_frame = transport.outgoing_binary.get()
    assert_true(key_package_frame.length() > 1)
    assert_eq(key_package_frame[0], 26)
    assert_true(
      telemetry.any(event => {
        event is DaveBinaryControlSent(opcode=26, payload_bytes~) &&
        payload_bytes == key_package_frame.length() - 1
      }),
    )
    for event in telemetry {
      if event is PacketDropped(reason~) && reason.contains("DAVE") {
        fail("unexpected DAVE control failure: \{reason}")
      }
    }
    connection.disconnect()
  })
}

///|
async test "voice connection retains DAVE across an initial v0 upgrade" {
  if !@voice.shim_available() || !@dave.available() {
    return
  }
  let transport = ConnectionTestTransport::new()
  let udp = ConnectionTestUdp::new()
  let telemetry : Array[@voice.VoiceTelemetry] = []
  @async.with_task_group(group => {
    let connection = @voice.VoiceConnection::start(
      group,
      connection_credentials(),
      user_id="100",
      channel_id=7UL,
      leave=() => (),
      rejoin=() => connection_credentials(),
      connector=_ => (transport : &@voice.VoiceTransport),
      udp_opener=(_, _) => (udp : &@voice.VoiceUdp),
      receive=false,
      telemetry=event => telemetry.push(event),
    )
    connection_finish_protocol_selection(transport, udp)
    transport.incoming.put(connection_session_description(2))
    connection.wait_ready(timeout_ms=1000)
    assert_true(
      telemetry.any(event => {
        event is DaveMediaContextActivated(protocol_version=0)
      }),
    )
    transport.incoming.put(
      Binary(b"\x00\x03\x19" + connection_external_sender()),
    )
    transport.incoming.put(
      Text("{\"op\":24,\"seq\":4,\"d\":{\"epoch\":1,\"protocol_version\":1}}"),
    )
    let key_package_frame = @async.with_timeout(1000, () => {
      transport.outgoing_binary.get()
    })
    assert_true(key_package_frame.length() > 1)
    assert_eq(key_package_frame[0], 26)
    assert_true(
      telemetry.any(event => {
        event is DaveBinaryControlSent(opcode=26, payload_bytes~) &&
        payload_bytes == key_package_frame.length() - 1
      }),
    )
    for event in telemetry {
      if event is PacketDropped(reason~) && reason.contains("DAVE") {
        fail("unexpected DAVE control failure: \{reason}")
      }
    }
    connection.disconnect()
  })
}

///|
async test "voice connection reuses DAVE for a later v1 Session Description" {
  if !@voice.shim_available() || !@dave.available() {
    return
  }
  let transport = ConnectionTestTransport::new()
  let udp = ConnectionTestUdp::new()
  let telemetry : Array[@voice.VoiceTelemetry] = []
  @async.with_task_group(group => {
    let connection = @voice.VoiceConnection::start(
      group,
      connection_credentials(),
      user_id="100",
      channel_id=7UL,
      leave=() => (),
      rejoin=() => connection_credentials(),
      connector=_ => (transport : &@voice.VoiceTransport),
      udp_opener=(_, _) => (udp : &@voice.VoiceUdp),
      receive=false,
      telemetry=event => telemetry.push(event),
    )
    connection_finish_protocol_selection(transport, udp)
    transport.incoming.put(connection_session_description(2))
    connection.wait_ready(timeout_ms=1000)
    transport.incoming.put(
      Binary(b"\x00\x03\x19" + connection_external_sender()),
    )
    transport.incoming.put(
      connection_session_description(4, dave_protocol_version=1),
    )
    let key_package_frame = @async.with_timeout(1000, () => {
      transport.outgoing_binary.get()
    })
    assert_true(key_package_frame.length() > 1)
    assert_eq(key_package_frame[0], 26)
    for event in telemetry {
      if event is PacketDropped(reason~) && reason.contains("DAVE") {
        fail("unexpected DAVE control failure: \{reason}")
      }
    }
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
      user_id="100",
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

    let source : &@voice.AudioSource = OneConnectionFrame::{ sent: false, }
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
        "{\"op\":5,\"seq\":3,\"d\":{\"ssrc\":77,\"user_id\":\"200\",\"speaking\":1}}",
      ),
    )
    assert_eq(
      connection.next_event(),
      SpeakingChanged(user_id="200", ssrc=77U, flags=1),
    )
    let stream = connection.subscribe(user_id="200")
    let sender = @voice.TransportCipher::new(
      AeadAes256GcmRtpsize,
      Bytes::new(32),
    )
    // an SSRC nobody announced is discarded rather than surfaced
    let unknown_header = @voice.build_rtp_header(
      sequence=1,
      timestamp=1920U,
      ssrc=99U,
    )
    udp.incoming.put(sender.seal(header=unknown_header, b"unknown"))
    let header = @voice.build_rtp_header(sequence=10, timestamp=960U, ssrc=77U)
    udp.incoming.put(sender.seal(header~, b"received-opus"))
    assert_eq(
      stream.next_packet(),
      Some(Opus(sequence=10, timestamp=960U, opus=b"received-opus")),
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
  let clock = @netruntime.VirtualClock()
  @async.with_task_group(group => {
    let connection = ready_receive_connection(group, transport, udp, clock~)
    map_connection_speaker(connection, transport, "200", 55U, 3)
    let stream = connection.subscribe(user_id="200")
    let sender = @voice.TransportCipher::new(
      AeadAes256GcmRtpsize,
      Bytes::new(32),
    )
    let packet = (sequence : Int32, timestamp : UInt32) => {
      let header = @voice.build_rtp_header(
        sequence=sequence.to_uint16(),
        timestamp~,
        ssrc=55U,
      )
      sender.seal(header~, b"opus-\{sequence}")
    }
    udp.incoming.put(packet(1, 960U))
    guard! stream.next_packet() is Some(Opus(sequence=1, ..))
    // sequence 2 never arrives: 3 and 4 wait for it while the 60ms hold lasts
    let received_before = udp.received.val
    udp.incoming.put(packet(3, 2880U))
    clock.settle(until=() => udp.received.val == received_before + 1)
    clock.advance(59)
    udp.incoming.put(packet(4, 3840U))
    let reader = group.spawn(no_wait=true, () => stream.next_packet())
    clock.settle(until=() => udp.received.val == received_before + 2)
    assert_eq(reader.try_wait(), None)
    // the first arrival 60ms after 3 gives up on 2
    clock.advance(1)
    udp.incoming.put(packet(5, 4800U))
    assert_eq(reader.wait(), Some(Lost(count=1)))
    guard! stream.next_packet() is Some(Opus(sequence=3, ..))
    guard! stream.next_packet() is Some(Opus(sequence=4, ..))
    guard! stream.next_packet() is Some(Opus(sequence=5, ..))
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
      user_id="100",
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
async test "voice rejoin clears a pre-session external sender" {
  if !@voice.shim_available() || !@dave.available() {
    return
  }
  let first_transport = ConnectionTestTransport::new()
  let second_transport = ConnectionTestTransport::new()
  let first_udp = ConnectionTestUdp::new()
  let second_udp = ConnectionTestUdp::new()
  let pending_transports : Array[ConnectionTestTransport] = [
    second_transport, first_transport,
  ]
  let pending_udps : Array[ConnectionTestUdp] = [second_udp, first_udp]
  @async.with_task_group(group => {
    let connection = @voice.VoiceConnection::start(
      group,
      connection_credentials(),
      user_id="100",
      channel_id=7UL,
      leave=() => (),
      rejoin=() => {
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
      udp_opener=(_, _) => {
        guard pending_udps.pop() is Some(udp) else {
          raise @voice.VoiceUdpError::IpDiscoveryFailed(
            attempts=0,
            reason="no UDP transport",
          )
        }
        (udp : &@voice.VoiceUdp)
      },
      receive=false,
    )
    connection_finish_protocol_selection(first_transport, first_udp)
    first_transport.incoming.put(Binary(b"\x00\x02\x19invalid"))
    first_transport.incoming.put(
      Text(
        "{\"op\":5,\"seq\":3,\"d\":{\"ssrc\":77,\"user_id\":\"200\",\"speaking\":1}}",
      ),
    )
    assert_eq(
      connection.next_event(),
      SpeakingChanged(user_id="200", ssrc=77U, flags=1),
    )
    first_transport.server_close(4006)

    connection_finish_protocol_selection(second_transport, second_udp)
    second_transport.incoming.put(
      connection_session_description(2, dave_protocol_version=1),
    )
    connection.wait_ready(timeout_ms=1000)
    let key_package_frame = @async.with_timeout(1000, () => {
      second_transport.outgoing_binary.get()
    })
    assert_true(key_package_frame.length() > 1)
    assert_eq(key_package_frame[0], 26)
    connection.disconnect()
  })
}

///|
async test "fatal voice close performs terminal teardown" {
  let transport = ConnectionTestTransport::new()
  let leave_calls = Ref(0)
  let clock = @netruntime.VirtualClock()
  @async.with_task_group(group => {
    let connection = @voice.VoiceConnection::start(
      group,
      connection_credentials(),
      user_id="100",
      channel_id=7UL,
      leave=() => leave_calls.val += 1,
      rejoin=() => connection_credentials(),
      connector=_ => (transport : &@voice.VoiceTransport),
      receive=false,
      clock~,
    )
    transport.incoming.put(connection_hello())
    transport.outgoing_text.get() |> ignore
    transport.server_close(4014)
    clock.settle(until=() => {
      connection.state() is Closed(code=Some(4014)) && leave_calls.val == 1
    })
    assert_eq(connection.state(), Closed(code=Some(4014)))
    assert_eq(leave_calls.val, 1)
    try connection.next_event() |> ignore catch {
      @voice.VoiceError::Disconnected => ()
      error => fail("unexpected terminal queue error: \{Repr(error)}")
    } noraise {
      _ => fail("terminal event queue unexpectedly remained open")
    }
    connection.disconnect()
    assert_eq(leave_calls.val, 1)
  })
}

///|
async test "voice connection wait_ready reports JoinTimeout" {
  let transport = ConnectionTestTransport::new()
  let clock = @netruntime.VirtualClock()
  @async.with_task_group(group => {
    let connection = @voice.VoiceConnection::start(
      group,
      connection_credentials(),
      user_id="100",
      channel_id=7UL,
      leave=() => (),
      rejoin=() => connection_credentials(),
      connector=_ => (transport : &@voice.VoiceTransport),
      receive=false,
      clock~,
    )
    let waiting = group.spawn(no_wait=true, allow_failure=true, () => {
      connection.wait_ready(timeout_ms=10)
    })
    clock.settle(until=() => clock.pending().contains(10))
    clock.advance(9)
    assert_eq(waiting.try_wait(), None)
    clock.advance(1)
    try waiting.wait() catch {
      @voice.VoiceError::JoinTimeout => ()
      error => fail("unexpected wait_ready error: \{Repr(error)}")
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
      user_id="100",
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
      error => fail("unexpected wait_ready error: \{Repr(error)}")
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
  clock~ : @netruntime.VirtualClock = @netruntime.VirtualClock(),
) -> @voice.VoiceConnection {
  let connection = @voice.VoiceConnection::start(
    group,
    connection_credentials(),
    user_id="100",
    channel_id=7UL,
    leave=() => (),
    rejoin=() => connection_credentials(),
    connector=_ => (transport : &@voice.VoiceTransport),
    udp_opener=(_, _) => (udp : &@voice.VoiceUdp),
    clock~,
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
  ssrc : UInt32,
  sequence : Int32,
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
  ssrc : UInt32,
  sequence : Int32,
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
async test "voice subscriptions receive only their own user's audio" {
  if !@voice.shim_available() {
    return
  }
  let transport = ConnectionTestTransport::new()
  let udp = ConnectionTestUdp::new()
  @async.with_task_group(group => {
    let connection = ready_receive_connection(group, transport, udp)
    map_connection_speaker(connection, transport, "200", 77U, 3)
    map_connection_speaker(connection, transport, "300", 88U, 4)
    let stream = connection.subscribe(user_id="200")
    let audio : &@voice.AudioSource = stream
    udp.incoming.put(connection_opus_datagram(77U, 1, b"target-one"))
    udp.incoming.put(connection_opus_datagram(88U, 1, b"other"))
    udp.incoming.put(connection_opus_datagram(77U, 2, b"target-two"))
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
  let clock = @netruntime.VirtualClock()
  @async.with_task_group(group => {
    let connection = ready_receive_connection(group, transport, udp, clock~)
    map_connection_speaker(connection, transport, "200", 77U, 3)
    let stream = connection.subscribe(
      user_id="200",
      end_after_silence_ms=Some(20),
    )
    let audio : &@voice.AudioSource = stream
    udp.incoming.put(connection_opus_datagram(77U, 1, b"first"))
    assert_eq(audio.next_frame(), Some(b"first"))
    let reader = group.spawn(no_wait=true, () => audio.next_frame())
    clock.settle(until=() => clock.pending().contains(20))
    clock.advance(19)
    assert_eq(reader.try_wait(), None)
    clock.advance(1)
    assert_eq(reader.wait(), None)
    udp.incoming.put(connection_opus_datagram(77U, 2, b"too-late"))
    assert_eq(audio.next_frame(), None)
    connection.disconnect()
  })
}

///|
async test "closing a voice subscription wakes a blocked reader" {
  let transport = ConnectionTestTransport::new()
  let clock = @netruntime.VirtualClock()
  @async.with_task_group(group => {
    let connection = @voice.VoiceConnection::start(
      group,
      connection_credentials(),
      user_id="100",
      channel_id=7UL,
      leave=() => (),
      rejoin=() => connection_credentials(),
      connector=_ => (transport : &@voice.VoiceTransport),
      receive=false,
      clock~,
    )
    let stream = connection.subscribe(user_id="target")
    let audio : &@voice.AudioSource = stream
    let entered = Ref(false)
    let blocked = group.spawn(() => {
      entered.val = true
      audio.next_frame()
    })
    clock.settle(until=() => entered.val)
    assert_eq(blocked.try_wait(), None)
    stream.close()
    assert_eq(blocked.wait(), None)
    connection.disconnect()
  })
}

///|
async test "disconnect ends every voice subscription" {
  let transport = ConnectionTestTransport::new()
  let clock = @netruntime.VirtualClock()
  @async.with_task_group(group => {
    let connection = @voice.VoiceConnection::start(
      group,
      connection_credentials(),
      user_id="100",
      channel_id=7UL,
      leave=() => (),
      rejoin=() => connection_credentials(),
      connector=_ => (transport : &@voice.VoiceTransport),
      receive=false,
      clock~,
    )
    let first : &@voice.AudioSource = connection.subscribe(user_id="one")
    let second : &@voice.AudioSource = connection.subscribe(user_id="two")
    let entered = Ref(0)
    let first_read = group.spawn(() => {
      entered.val += 1
      first.next_frame()
    })
    let second_read = group.spawn(() => {
      entered.val += 1
      second.next_frame()
    })
    clock.settle(until=() => entered.val == 2)
    assert_eq(first_read.try_wait(), None)
    assert_eq(second_read.try_wait(), None)
    connection.disconnect()
    assert_eq(first_read.wait(), None)
    assert_eq(second_read.wait(), None)
  })
}

///|
async test "manual voice subscription waits across a long gap" {
  if !@voice.shim_available() {
    return
  }
  let transport = ConnectionTestTransport::new()
  let udp = ConnectionTestUdp::new()
  let clock = @netruntime.VirtualClock()
  @async.with_task_group(group => {
    let connection = ready_receive_connection(group, transport, udp, clock~)
    map_connection_speaker(connection, transport, "200", 77U, 3)
    let stream = connection.subscribe(user_id="200", end_after_silence_ms=None)
    let audio : &@voice.AudioSource = stream
    let blocked = group.spawn(() => audio.next_frame())
    // half a minute of silence (six keepalive ticks) does not end it
    for _ in 0..<6 {
      clock.settle(until=() => clock.pending().contains(5000))
      clock.advance(5000)
      udp.outgoing.get() |> ignore
    }
    assert_eq(blocked.try_wait(), None)
    udp.incoming.put(connection_opus_datagram(77U, 1, b"after-gap"))
    assert_eq(blocked.wait(), Some(b"after-gap"))
    stream.close()
    connection.disconnect()
  })
}

///|
async test "voice keepalive cadence runs on the clock" {
  let transport = ConnectionTestTransport::new()
  let udp = ConnectionTestUdp::new()
  let clock = @netruntime.VirtualClock()
  @async.with_task_group(group => {
    let connection = @voice.VoiceConnection::start(
      group,
      connection_credentials(),
      user_id="100",
      channel_id=7UL,
      leave=() => (),
      rejoin=() => connection_credentials(),
      connector=_ => (transport : &@voice.VoiceTransport),
      udp_opener=(_, _) => (udp : &@voice.VoiceUdp),
      receive=false,
      clock~,
    )
    clock.settle(until=() => clock.pending() == [5000])
    assert_eq(clock.pending(), [5000])
    // tick 1 elapses before the UDP socket exists: nothing is sent
    clock.advance(5000)
    clock.settle(until=() => clock.pending() == [5000])
    assert_eq(clock.pending(), [5000])
    // bring the socket up (the gateway heartbeat joins), then tick 2 sends
    // the 8-byte counter
    connection_finish_protocol_selection(transport, udp)
    clock.settle(until=() => clock.pending() == [5000, 60000])
    assert_eq(clock.pending(), [5000, 60000])
    clock.advance(4999)
    assert_eq(udp.outgoing.try_get(), None)
    clock.advance(1)
    assert_eq(udp.outgoing.get(), b"\x00\x00\x00\x00\x00\x00\x00\x00")
    // tick 3, 5000ms later: the counter increments little-endian
    clock.settle(until=() => clock.pending() == [5000, 60000])
    clock.advance(4999)
    assert_eq(udp.outgoing.try_get(), None)
    clock.advance(1)
    assert_eq(udp.outgoing.get(), b"\x01\x00\x00\x00\x00\x00\x00\x00")
    connection.disconnect()
  })
}

///|
async test "voice playback paces frames and the closing silence on the clock" {
  if !@voice.shim_available() {
    return
  }
  let transport = ConnectionTestTransport::new()
  let udp = ConnectionTestUdp::new()
  let clock = @netruntime.VirtualClock()
  let cipher = @voice.TransportCipher::new(AeadAes256GcmRtpsize, Bytes::new(32))
  // the next packet, decrypted, as (sequence, timestamp, payload)
  let next_packet = () => {
    let rtp = @voice.parse_rtp_packet(
      cipher.open(udp.outgoing.get(), header_len=12),
    )
    (rtp.sequence, rtp.timestamp, rtp.payload)
  }
  @async.with_task_group(group => {
    let connection = ready_receive_connection(group, transport, udp, clock~)
    let source : &@voice.AudioSource = ThreeFrameSource::{
      frames: [b"frame-1", b"frame-2"],
      cursor: 0,
    }
    connection.play(source)
    guard! transport.outgoing_text.get()
      is { "op": Number(5, ..), "d": { "speaking": Number(1, ..), .. }, .. }
    // the first frame goes out at once, then every 20ms slot carries one
    assert_eq(next_packet(), (0, 0, b"frame-1"))
    clock.settle(until=() => clock.pending() == [20, 5000, 60000])
    assert_eq(clock.pending(), [20, 5000, 60000])
    clock.advance(19)
    assert_eq(udp.outgoing.try_get(), None)
    clock.advance(1)
    assert_eq(next_packet(), (1, 960, b"frame-2"))
    // five silence frames flush the decoder, one per slot
    for index in 0..<5 {
      clock.settle(until=() => clock.pending().contains(20))
      clock.advance(19)
      assert_eq(udp.outgoing.try_get(), None)
      clock.advance(1)
      let sequence = (index + 2).to_uint16()
      let timestamp = (index + 2).reinterpret_as_uint() * 960U
      assert_eq(next_packet(), (sequence, timestamp, @voice.SILENCE_FRAME))
    }
    // the speaking flag clears once the last silence slot has elapsed
    clock.settle(until=() => clock.pending().contains(20))
    clock.advance(19)
    assert_eq(transport.outgoing_text.try_get(), None)
    clock.advance(1)
    guard! transport.outgoing_text.get()
      is { "op": Number(5, ..), "d": { "speaking": Number(0, ..), .. }, .. }
    assert_eq(clock.pending(), [5000, 60000])
    connection.disconnect()
  })
}

///|
/// An endless source that counts the frames it hands out.
struct EndlessSource {
  mut served : Int32
}

///|
impl @voice.AudioSource for EndlessSource with fn next_frame(self) {
  self.served += 1
  Some(b"frame-\{self.served}")
}

///|
async test "stopping voice playback flushes paced silence before it returns" {
  if !@voice.shim_available() {
    return
  }
  let transport = ConnectionTestTransport::new()
  let udp = ConnectionTestUdp::new()
  let clock = @netruntime.VirtualClock()
  let cipher = @voice.TransportCipher::new(AeadAes256GcmRtpsize, Bytes::new(32))
  let next_payload = () => {
    @voice.parse_rtp_packet(cipher.open(udp.outgoing.get(), header_len=12)).payload
  }
  @async.with_task_group(group => {
    let connection = ready_receive_connection(group, transport, udp, clock~)
    let source = EndlessSource::{ served: 0, }
    connection.play(source)
    guard! transport.outgoing_text.get()
      is { "op": Number(5, ..), "d": { "speaking": Number(1, ..), .. }, .. }
    assert_eq(next_payload(), b"frame-1")
    let stopping = group.spawn(no_wait=true, () => connection.stop())
    // the sender sees the request when its current slot ends: no more source
    // frames, then five silence frames, one per 20ms slot
    for _ in 0..<5 {
      clock.settle(until=() => clock.pending().contains(20))
      clock.advance(20)
      assert_eq(next_payload(), @voice.SILENCE_FRAME)
      assert_eq(stopping.try_wait(), None)
    }
    clock.settle(until=() => clock.pending().contains(20))
    clock.advance(20)
    guard! transport.outgoing_text.get()
      is { "op": Number(5, ..), "d": { "speaking": Number(0, ..), .. }, .. }
    stopping.wait()
    assert_eq(source.served, 1)
    assert_eq(udp.outgoing.try_get(), None)
    connection.disconnect()
  })
}

///|
async test "closing a voice subscription ends a read waiting out its silence" {
  if !@voice.shim_available() {
    return
  }
  let transport = ConnectionTestTransport::new()
  let udp = ConnectionTestUdp::new()
  let clock = @netruntime.VirtualClock()
  @async.with_task_group(group => {
    let connection = ready_receive_connection(group, transport, udp, clock~)
    map_connection_speaker(connection, transport, "200", 77U, 3)
    let stream = connection.subscribe(
      user_id="200",
      end_after_silence_ms=Some(20),
    )
    udp.incoming.put(connection_opus_datagram(77U, 1, b"first"))
    guard! stream.next_packet() is Some(Opus(sequence=1, ..))
    let reader = group.spawn(no_wait=true, () => stream.next_packet())
    clock.settle(until=() => clock.pending() == [20, 5000, 60000])
    assert_eq(clock.pending(), [20, 5000, 60000])
    stream.close()
    // the read ends at once, and its silence timer goes with it
    assert_eq(reader.wait(), None)
    clock.settle(until=() => clock.pending() == [5000, 60000])
    assert_eq(clock.pending(), [5000, 60000])
    connection.disconnect()
  })
}

///|
/// A live source with nothing to send yet: a read waits for the next frame
/// handed to `frames`, and `reading` says whether one is waiting.
struct WaitingSource {
  frames : @aqueue.Queue[Bytes]
  reading : Ref[Bool]
}

///|
impl @voice.AudioSource for WaitingSource with fn next_frame(self) {
  self.reading.val = true
  defer {
    self.reading.val = false
  }
  Some(self.frames.get())
}

///|
async test "no background task outlives its voice connection" {
  if !@voice.shim_available() {
    return
  }
  let transport = ConnectionTestTransport::new()
  let udp = ConnectionTestUdp::new()
  let clock = @netruntime.VirtualClock()
  @async.with_task_group(group => {
    let connection = ready_receive_connection(group, transport, udp, clock~)
    let source = WaitingSource::{
      frames: Queue(kind=Unbounded),
      reading: Ref(false),
    }
    connection.play(source)
    clock.settle(until=() => {
      source.reading.val && clock.pending() == [5000, 60000]
    })
    assert_true(source.reading.val)
    assert_eq(clock.pending(), [5000, 60000])
    connection.disconnect()
    clock.settle(until=() => !source.reading.val && clock.pending().is_empty())
    // The playback waiting on its source and the keepalive waiting for its
    // next tick end with the connection instead of holding it.
    assert_false(source.reading.val)
    assert_eq(clock.pending(), [])
  })
}
