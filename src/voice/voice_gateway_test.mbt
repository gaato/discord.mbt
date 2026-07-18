///|
/// In-memory voice transport used by all gateway-driver tests.
struct FakeVoiceTransport {
  incoming : @aqueue.Queue[@voice.VoiceFrame]
  outgoing_text : @aqueue.Queue[Json]
  outgoing_binary : @aqueue.Queue[Bytes]
}

///|
fn FakeVoiceTransport::FakeVoiceTransport() -> FakeVoiceTransport {
  {
    incoming: Queue(kind=Unbounded),
    outgoing_text: Queue(kind=Unbounded),
    outgoing_binary: Queue(kind=Unbounded),
  }
}

///|
fn FakeVoiceTransport::server_close(
  self : FakeVoiceTransport,
  code : Int?,
) -> Unit {
  self.incoming.close(
    error=@voice.VoiceTransportClosed(code~, reason="server closed"),
  )
}

///|
impl @voice.VoiceTransport for FakeVoiceTransport with fn recv(self) {
  self.incoming.get()
}

///|
impl @voice.VoiceTransport for FakeVoiceTransport with fn send_text(self, text) {
  self.outgoing_text.put(@json.parse(text))
}

///|
impl @voice.VoiceTransport for FakeVoiceTransport with fn send_binary(
  self,
  bytes,
) {
  self.outgoing_binary.put(bytes)
}

///|
impl @voice.VoiceTransport for FakeVoiceTransport with fn close(self, code~) {
  self.incoming.close(
    error=@voice.VoiceTransportClosed(code=Some(code), reason="client closed"),
  )
}

///|
fn hello_frame(interval : Int) -> @voice.VoiceFrame {
  Text("{\"op\":8,\"d\":{\"heartbeat_interval\":\{interval}}}")
}

///|
fn ready_frame(seq : Int) -> @voice.VoiceFrame {
  Text(
    "{\"op\":2,\"seq\":\{seq},\"d\":{\"ssrc\":42,\"ip\":\"198.51.100.1\",\"port\":5000,\"modes\":[\"aead_aes256_gcm_rtpsize\",\"aead_xchacha20_poly1305_rtpsize\"]}}",
  )
}

///|
fn session_description_frame(seq : Int) -> @voice.VoiceFrame {
  Text(
    "{\"op\":4,\"seq\":\{seq},\"d\":{\"mode\":\"aead_aes256_gcm_rtpsize\",\"secret_key\":[1,2,3,4],\"dave_protocol_version\":1}}",
  )
}

///|
async fn finish_handshake(
  gateway : @voice.VoiceGateway,
  transport : FakeVoiceTransport,
  heartbeat_interval? : Int = 60000,
) -> Unit {
  transport.incoming.put(hello_frame(heartbeat_interval))
  guard transport.outgoing_text.get()
    is {
      "op": Number(0, ..),
      "d": { "max_dave_protocol_version": Number(1, ..), .. },
      ..
    }
  transport.incoming.put(ready_frame(1))
  guard gateway.next() is ReadyReceived
  guard transport.outgoing_text.get()
    is { "op": Number(1, ..), "d": { "protocol": String("udp"), .. }, .. }
  transport.incoming.put(session_description_frame(2))
  guard gateway.next()
    is SessionEstablished(
      mode="aead_aes256_gcm_rtpsize",
      secret_key=b"\x01\x02\x03\x04",
      dave_protocol_version=1
    )
  guard gateway.next() is Connected(resumed=false)
}

///|
async fn captured_gateway_url(endpoint : String) -> String {
  let transport = FakeVoiceTransport()
  let connected_urls : @aqueue.Queue[String] = Queue(kind=Unbounded)
  @async.with_task_group(group => {
    let gateway = @voice.VoiceGateway::start(
      group,
      server_id="guild",
      user_id="user",
      session_id="session",
      token="token",
      endpoint~,
      select_protocol=(_, _, _, _) => {
        ("203.0.113.8", 62000, "aead_aes256_gcm_rtpsize")
      },
      connector=url => {
        connected_urls.put(url)
        (transport : &@voice.VoiceTransport)
      },
    )
    let url = connected_urls.get()
    transport.server_close(None)
    guard gateway.next() is NeedsRejoin(code=None)
    url
  })
}

///|
async test "voice gateway URL always has a path before the v8 query" {
  assert_eq(captured_gateway_url("voice.example"), "wss://voice.example/?v=8")
  assert_eq(
    captured_gateway_url("voice.example:2096"),
    "wss://voice.example:2096/?v=8",
  )
  assert_eq(
    captured_gateway_url("wss://voice.example"),
    "wss://voice.example/?v=8",
  )
  assert_eq(
    captured_gateway_url("voice.example/socket"),
    "wss://voice.example/socket?v=8",
  )
  assert_eq(
    captured_gateway_url("voice.example?encoding=json"),
    "wss://voice.example/?encoding=json&v=8",
  )
}

///|
async test "voice gateway reports connector failures through telemetry and retries" {
  let attempts = Ref(0)
  let failures : Array[String] = []
  @async.with_task_group(group => {
    let gateway = @voice.VoiceGateway::start(
      group,
      server_id="guild",
      user_id="user",
      session_id="session",
      token="token",
      endpoint="voice.example",
      select_protocol=(_, _, _, _) => {
        ("203.0.113.8", 62000, "aead_aes256_gcm_rtpsize")
      },
      connector=_ => {
        attempts.val += 1
        raise @voice.VoiceTransportClosed(
          code=None,
          reason="connector attempt \{attempts.val}",
        )
      },
      telemetry=event => {
        match event {
          ConnectFailed(reason~) => failures.push(reason)
          _ => ()
        }
      },
    )
    @async.with_timeout(5000, () => {
      while failures.length() < 2 {
        @async.sleep(1)
      }
    })
    assert_true(@async.with_timeout_opt(10, () => gateway.next()) is None)
    gateway.close()
    assert_eq(attempts.val, 2)
    assert_eq(failures.length(), 2)
    assert_true(failures[0].contains("connector attempt 1"))
    assert_true(failures[1].contains("connector attempt 2"))
  })
}

///|
async test "missing heartbeat ACK closes with 4000 and reconnects" {
  let first = FakeVoiceTransport()
  let second = FakeVoiceTransport()
  let pending : Array[FakeVoiceTransport] = [second, first]
  @async.with_task_group(group => {
    let gateway = @voice.VoiceGateway::start(
      group,
      server_id="guild",
      user_id="user",
      session_id="session",
      token="token",
      endpoint="voice.example",
      select_protocol=(_, _, _, _) => {
        ("203.0.113.8", 62000, "aead_aes256_gcm_rtpsize")
      },
      connector=_ => {
        match pending.pop() {
          Some(transport) => (transport : &@voice.VoiceTransport)
          None => raise @voice.VoiceTransportClosed(code=None, reason="no more")
        }
      },
    )
    finish_handshake(gateway, first, heartbeat_interval=100)
    guard first.outgoing_text.get()
      is { "op": Number(3, ..), "d": { "seq_ack": Number(2, ..), .. }, .. }
    // Do not ACK: the following heartbeat deadline closes the fake with 4000.
    guard gateway.next() is Disconnected(code=Some(4000), resuming=true)
    second.incoming.put(hello_frame(60000))
    guard second.outgoing_text.get()
      is { "op": Number(7, ..), "d": { "seq_ack": Number(2, ..), .. }, .. }
    gateway.close()
  })
}

///|
async test "voice gateway completes identify and protocol selection" {
  let transport = FakeVoiceTransport()
  let connected_url = Ref("")
  let selected = Ref(false)
  @async.with_task_group(group => {
    let gateway = @voice.VoiceGateway::start(
      group,
      server_id="guild",
      user_id="user",
      session_id="session",
      token="token",
      endpoint="voice.example",
      select_protocol=(ssrc, ip, port, modes) => {
        assert_eq(ssrc, 42)
        assert_eq(ip, "198.51.100.1")
        assert_eq(port, 5000)
        assert_eq(modes.length(), 2)
        selected.val = true
        ("203.0.113.8", 62000, "aead_aes256_gcm_rtpsize")
      },
      connector=url => {
        connected_url.val = url
        (transport : &@voice.VoiceTransport)
      },
    )
    transport.incoming.put(hello_frame(60000))
    let identify = transport.outgoing_text.get()
    guard identify
      is {
        "op": Number(0, ..),
        "d": {
          "server_id": String("guild"),
          "user_id": String("user"),
          "session_id": String("session"),
          "token": String("token"),
          "max_dave_protocol_version": Number(1, ..),
          ..
        },
        ..
      } else {
      fail("unexpected identify: \{identify.stringify()}")
    }
    transport.incoming.put(ready_frame(10))
    guard gateway.next() is ReadyReceived
    let select = transport.outgoing_text.get()
    guard select
      is {
        "op": Number(1, ..),
        "d": {
          "protocol": String("udp"),
          "data": {
            "address": String("203.0.113.8"),
            "port": Number(62000, ..),
            "mode": String("aead_aes256_gcm_rtpsize"),
            ..
          },
          ..
        },
        ..
      } else {
      fail("unexpected Select Protocol: \{select.stringify()}")
    }
    assert_true(selected.val)
    transport.incoming.put(session_description_frame(11))
    guard gateway.next() is SessionEstablished(..)
    guard gateway.next() is Connected(resumed=false)
    assert_eq(gateway.state(), Active)
    assert_eq(connected_url.val, "wss://voice.example/?v=8")
    gateway.send_json(@voice.encode_speaking(ssrc=42, flags=1))
    guard transport.outgoing_text.get() is { "op": Number(5, ..), .. }
    gateway.send_binary(op=26, b"key")
    assert_eq(transport.outgoing_binary.get(), b"\x1akey")
    gateway.close()
  })
}

///|
async test "voice heartbeat tracks JSON and binary sequence numbers" {
  let transport = FakeVoiceTransport()
  @async.with_task_group(group => {
    let gateway = @voice.VoiceGateway::start(
      group,
      server_id="guild",
      user_id="user",
      session_id="session",
      token="token",
      endpoint="voice.example",
      select_protocol=(_, _, _, _) => {
        ("203.0.113.8", 62000, "aead_aes256_gcm_rtpsize")
      },
      connector=_ => (transport : &@voice.VoiceTransport),
    )
    transport.incoming.put(hello_frame(40))
    transport.outgoing_text.get() |> ignore // identify
    let first_beat = transport.outgoing_text.get()
    guard first_beat
      is {
        "op": Number(3, ..),
        "d": { "t": Number(first_nonce, ..), "seq_ack": Number(-1, ..), .. },
        ..
      } else {
      fail("expected initial heartbeat, got \{first_beat.stringify()}")
    }
    transport.incoming.put(
      Text("{\"op\":6,\"d\":{\"t\":\{first_nonce.to_int64()}}}"),
    )
    transport.incoming.put(
      Text(
        (
          #|{"op":5,"seq":7,"d":{"ssrc":42,"user_id":"user","speaking":1}}
        ),
      ),
    )
    guard gateway.next() is Message(Speaking(..))
    let second_beat = transport.outgoing_text.get()
    guard second_beat
      is {
        "op": Number(3, ..),
        "d": { "t": Number(second_nonce, ..), "seq_ack": Number(7, ..), .. },
        ..
      } else {
      fail("expected JSON seq heartbeat, got \{second_beat.stringify()}")
    }
    transport.incoming.put(
      Text("{\"op\":6,\"d\":{\"t\":\{second_nonce.to_int64()}}}"),
    )
    transport.incoming.put(Binary(b"\x00\x0A\x19external"))
    guard gateway.next() is Message(DaveMlsExternalSender(payload=b"external"))
    let third_beat = transport.outgoing_text.get()
    guard third_beat
      is {
        "op": Number(3, ..),
        "d": { "t": Number(third_nonce, ..), "seq_ack": Number(10, ..), .. },
        ..
      } else {
      fail("expected binary seq heartbeat, got \{third_beat.stringify()}")
    }
    transport.incoming.put(
      Text("{\"op\":6,\"d\":{\"t\":\{third_nonce.to_int64()}}}"),
    )
    @async.sleep(1)
    guard gateway.latency_ms() is Some(latency) else {
      fail("expected matched ACK latency")
    }
    assert_true(latency >= 0L)
    gateway.close()
  })
}

///|
async test "4015 resumes with seq_ack and skips protocol selection" {
  let first = FakeVoiceTransport()
  let second = FakeVoiceTransport()
  let pending : Array[FakeVoiceTransport] = [second, first]
  let select_calls = Ref(0)
  @async.with_task_group(group => {
    let gateway = @voice.VoiceGateway::start(
      group,
      server_id="guild",
      user_id="user",
      session_id="session",
      token="token",
      endpoint="voice.example",
      select_protocol=(_, _, _, _) => {
        select_calls.val += 1
        ("203.0.113.8", 62000, "aead_aes256_gcm_rtpsize")
      },
      connector=_ => {
        match pending.pop() {
          Some(transport) => (transport : &@voice.VoiceTransport)
          None => raise @voice.VoiceTransportClosed(code=None, reason="no more")
        }
      },
    )
    finish_handshake(gateway, first)
    assert_eq(select_calls.val, 1)
    first.server_close(Some(4015))
    guard gateway.next() is Disconnected(code=Some(4015), resuming=true)
    second.incoming.put(hello_frame(60000))
    let resume_payload = second.outgoing_text.get()
    guard resume_payload
      is {
        "op": Number(7, ..),
        "d": {
          "server_id": String("guild"),
          "session_id": String("session"),
          "token": String("token"),
          "seq_ack": Number(2, ..),
          ..
        },
        ..
      } else {
      fail("unexpected Resume: \{resume_payload.stringify()}")
    }
    second.incoming.put(Text("{\"op\":9,\"seq\":3,\"d\":null}"))
    guard gateway.next() is Connected(resumed=true)
    assert_eq(select_calls.val, 1)
    assert_eq(gateway.state(), Active)
    gateway.close()
  })
}

///|
async test "4006 requests a fresh voice join" {
  let transport = FakeVoiceTransport()
  @async.with_task_group(group => {
    let gateway = @voice.VoiceGateway::start(
      group,
      server_id="guild",
      user_id="user",
      session_id="session",
      token="token",
      endpoint="voice.example",
      select_protocol=(_, _, _, _) => {
        ("203.0.113.8", 62000, "aead_aes256_gcm_rtpsize")
      },
      connector=_ => (transport : &@voice.VoiceTransport),
    )
    finish_handshake(gateway, transport)
    transport.server_close(Some(4006))
    guard gateway.next() is NeedsRejoin(code=Some(4006))
    guard gateway.state() is Disconnected(reconnect_attempts=1)
  })
}

///|
async test "4014 is fatal" {
  let transport = FakeVoiceTransport()
  @async.with_task_group(group => {
    let gateway = @voice.VoiceGateway::start(
      group,
      server_id="guild",
      user_id="user",
      session_id="session",
      token="token",
      endpoint="voice.example",
      select_protocol=(_, _, _, _) => {
        ("203.0.113.8", 62000, "aead_aes256_gcm_rtpsize")
      },
      connector=_ => (transport : &@voice.VoiceTransport),
    )
    transport.incoming.put(hello_frame(60000))
    transport.outgoing_text.get() |> ignore
    transport.server_close(Some(4014))
    guard gateway.next() is FatallyClosed(code=4014)
    assert_eq(gateway.state(), FatallyClosed(code=4014))
  })
}

///|
/// Gated sleeper shared by the voice timing tests: each requested delay is
/// observed on `requests` and only completes when the test calls `release`.
struct SleepGate {
  requests : @aqueue.Queue[Int]
  releases : @aqueue.Queue[Unit]
}

///|
fn SleepGate::SleepGate() -> SleepGate {
  { requests: Queue(kind=Unbounded), releases: Queue(kind=Unbounded) }
}

///|
async fn SleepGate::sleep(self : SleepGate, ms : Int) -> Unit {
  self.requests.put(ms)
  self.releases.get()
}

///|
async fn SleepGate::release(self : SleepGate) -> Unit {
  self.releases.put(())
}

///|
async test "voice reconnect backoff runs through the injected sleeper" {
  let first = FakeVoiceTransport()
  let second = FakeVoiceTransport()
  let pending : Array[FakeVoiceTransport] = [second, first]
  let connects = Ref(0)
  let gate = SleepGate()
  @async.with_task_group(group => {
    let gateway = @voice.VoiceGateway::start(
      group,
      server_id="guild",
      user_id="user",
      session_id="session",
      token="token",
      endpoint="voice.example",
      select_protocol=(_, _, _, _) => {
        ("203.0.113.8", 62000, "aead_aes256_gcm_rtpsize")
      },
      connector=_ => {
        connects.val += 1
        match pending.pop() {
          Some(transport) => (transport : &@voice.VoiceTransport)
          None => raise @voice.VoiceTransportClosed(code=None, reason="no more")
        }
      },
      // 1ms heartbeat sleeps park; only the backoff (>= 250ms) hits the gate
      sleeper=ms => {
        if ms <= 1 {
          @async.sleep(3_600_000)
        } else {
          gate.sleep(ms)
        }
      },
    )
    finish_handshake(gateway, first, heartbeat_interval=1)
    first.server_close(Some(4000))
    guard gateway.next() is Disconnected(code=Some(4000), resuming=true)
    let backoff = gate.requests.get()
    // attempts=1: full jitter over 2000ms plus the 250ms floor
    assert_true(backoff >= 250 && backoff < 2250)
    // the reconnect is gated on the backoff sleep
    assert_eq(connects.val, 1)
    gate.release()
    second.incoming.put(hello_frame(1))
    guard second.outgoing_text.get()
      is { "op": Number(7, ..), "d": { "seq_ack": Number(2, ..), .. }, .. }
    assert_eq(connects.val, 2)
    gateway.close()
  })
}
