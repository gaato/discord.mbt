///|
/// In-memory transport: `incoming` feeds `recv`, `outgoing` captures `send`.
struct FakeTransport {
  incoming : @aqueue.Queue[String]
  outgoing : @aqueue.Queue[Json]
  block_next_send : Ref[Bool]
  send_started : @aqueue.Queue[Unit]
  send_in_flight : Ref[Bool]
  recv_in_flight : Ref[Bool]
  close_during_send : Ref[Bool]
  close_during_recv : Ref[Bool]
  close_calls : Ref[Int]
}

///|
fn FakeTransport::FakeTransport() -> FakeTransport {
  {
    incoming: Queue(kind=Unbounded),
    outgoing: Queue(kind=Unbounded),
    block_next_send: Ref(false),
    send_started: Queue(kind=Unbounded),
    send_in_flight: Ref(false),
    recv_in_flight: Ref(false),
    close_during_send: Ref(false),
    close_during_recv: Ref(false),
    close_calls: Ref(0),
  }
}

///|
fn FakeTransport::server_close(self : FakeTransport, code : Int?) -> Unit {
  self.incoming.close(
    error=@gateway.TransportClosed(code~, reason="server closed"),
  )
}

///|
impl @gateway.GatewayTransport for FakeTransport with fn recv(self) {
  self.recv_in_flight.val = true
  defer {
    self.recv_in_flight.val = false
  }
  Text(self.incoming.get())
}

///|
impl @gateway.GatewayTransport for FakeTransport with fn send(self, text) {
  self.send_in_flight.val = true
  defer {
    self.send_in_flight.val = false
  }
  if self.block_next_send.val {
    self.block_next_send.val = false
    self.send_started.put(())
    @async.sleep(3_600_000)
  }
  self.outgoing.put(@json.parse(text) catch { _ => Json::null() })
}

///|
impl @gateway.GatewayTransport for FakeTransport with fn close(self, code~) {
  if self.send_in_flight.val {
    self.close_during_send.val = true
  }
  if self.recv_in_flight.val {
    self.close_during_recv.val = true
  }
  if self.close_calls.val > 0 {
    return
  }
  self.close_calls.val += 1
  self.incoming.close(
    error=@gateway.TransportClosed(code=Some(code), reason="client closed"),
  )
}

///|
async test "cancelling a shard closes its transport exactly once" {
  let transport = FakeTransport()
  @async.with_task_group(group => {
    @gateway.Shard::start(group, token="tok", intents=@model.Intents::none(), connector=_ => {
      (transport : &@gateway.GatewayTransport)
    })
    |> ignore
    transport.incoming.put(HELLO)
    transport.outgoing.get() |> ignore
  })
  assert_eq(transport.close_calls.val, 1)
}

///|
const HELLO : String =
  #|{"op":10,"d":{"heartbeat_interval":60000}}

///|
fn ready_frame() -> String {
  (
    #|{"op":0,"s":1,"t":"READY","d":{"v":10,"user":{"id":"1","username":"bot","discriminator":"0","global_name":null,"avatar":null},"guilds":[],"session_id":"sess-1","resume_gateway_url":"wss://resume.example","application":{"id":"42"},"shard":[0,1]}}
  )
}

///|
struct FakeInflater {
  messages : Array[String]
  chunks : Array[Bytes]
  pending : Array[Byte]
}

///|
impl @gateway.Inflater for FakeInflater with fn push(self, bytes) {
  self.chunks.push(bytes)
  for byte in bytes {
    self.pending.push(byte)
  }
  let len = self.pending.length()
  if len >= 4 &&
    self.pending[len - 4] == 0x00 &&
    self.pending[len - 3] == 0x00 &&
    self.pending[len - 2] == 0xff &&
    self.pending[len - 1] == 0xff {
    self.pending.clear()
    self.messages.pop()
  } else {
    None
  }
}

///|
struct BinaryFakeTransport {
  incoming : @aqueue.Queue[@gateway.GatewayFrame]
  outgoing : @aqueue.Queue[Json]
}

///|
fn BinaryFakeTransport::BinaryFakeTransport() -> BinaryFakeTransport {
  { incoming: Queue(kind=Unbounded), outgoing: Queue(kind=Unbounded) }
}

///|
impl @gateway.GatewayTransport for BinaryFakeTransport with fn recv(self) {
  self.incoming.get()
}

///|
impl @gateway.GatewayTransport for BinaryFakeTransport with fn send(self, text) {
  self.outgoing.put(@json.parse(text))
}

///|
impl @gateway.GatewayTransport for BinaryFakeTransport with fn close(
  self,
  code~,
) {
  self.incoming.close(
    error=@gateway.TransportClosed(code=Some(code), reason="client closed"),
  )
}

///|
async test "compressed shard buffers suffix fragments and decodes messages" {
  let transport = BinaryFakeTransport()
  let inflater = FakeInflater::{
    // pop() consumes from the end: Hello, Ready, then dispatch.
    messages: [
      (
        #|{"op":0,"s":2,"t":"MESSAGE_DELETE","d":{"id":"5","channel_id":"6"}}
      ),
      ready_frame(),
      HELLO,
    ],
    chunks: [],
    pending: [],
  }
  let connected_url = Ref("")
  let telemetry : Array[@telemetry.TelemetryEvent] = []
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      token="tok",
      intents=@model.Intents::guild_messages(),
      compress=true,
      connector=url => {
        connected_url.val = url
        (transport : &@gateway.GatewayTransport)
      },
      inflater_factory=() => (inflater : &@gateway.Inflater),
      telemetry=event => telemetry.push(event),
    )
    transport.incoming.put(Binary(b"\x78\x9c\x00\x00"))
    @async.sleep(1)
    assert_eq(inflater.chunks.length(), 1)
    assert_eq(inflater.messages.length(), 3)
    transport.incoming.put(Binary(b"\xff\xff"))
    guard transport.outgoing.get() is { "op": Number(2, ..), .. } else {
      fail("expected an uncompressed identify payload")
    }
    transport.incoming.put(Binary(b"\x01\x00\x00\xff\xff"))
    guard! shard.next() is Connected(resumed=false)
    guard! shard.next() is Dispatch(Ready(_))
    transport.incoming.put(Binary(b"\x02\x00\x00\xff\xff"))
    guard shard.next() is Dispatch(MessageDelete(deleted)) else {
      fail("expected decoded message delete")
    }
    inspect(deleted.id, content="5")
    assert_true(connected_url.val.has_suffix("&compress=zlib-stream"))
    assert_eq(inflater.chunks.length(), 4)
    let saw_compression = Ref(false)
    for event in telemetry {
      if event is ShardCompressionEnabled(shard_id=0) {
        saw_compression.val = true
      }
    }
    assert_true(saw_compression.val)
    shard.close()
  })
}

///|
test "on_close classifies discord codes" {
  debug_inspect(@gateway.on_close(Some(4004), true), content="Fatal")
  debug_inspect(@gateway.on_close(Some(4014), true), content="Fatal")
  debug_inspect(@gateway.on_close(Some(4009), true), content="Reidentify")
  debug_inspect(@gateway.on_close(Some(1000), true), content="Reidentify")
  debug_inspect(@gateway.on_close(Some(4000), true), content="Resume")
  debug_inspect(@gateway.on_close(None, true), content="Resume")
  // resume requires a session
  debug_inspect(@gateway.on_close(Some(4000), false), content="Reidentify")
}

///|
async test "shard identifies, dispatches, and resumes across a drop" {
  let first = FakeTransport()
  let second = FakeTransport()
  let pending : Array[FakeTransport] = [second, first]
  let telemetry : Array[@telemetry.TelemetryEvent] = []
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      token="tok-123",
      intents=@model.Intents::guilds() | @model.Intents::guild_messages(),
      connector=_ => {
        match pending.pop() {
          Some(t) => (t : &@gateway.GatewayTransport)
          None => raise @gateway.TransportClosed(code=None, reason="no more")
        }
      },
      telemetry=event => telemetry.push(event),
    )
    // --- connection 1: identify ---
    first.incoming.put(HELLO)
    let identify = first.outgoing.get()
    guard identify
      is {
        "op": Number(2, ..),
        "d": {
          "token": String("tok-123"),
          "shard": [Number(0, ..), Number(1, ..)],
          ..
        },
        ..
      } else {
      fail("expected identify, got \{identify.stringify()}")
    }
    first.incoming.put(ready_frame())
    guard! shard.next() is Connected(resumed=false)
    debug_inspect(shard.state(), content="Active")
    guard shard.next() is Dispatch(Ready(ready)) else {
      fail("expected Ready dispatch")
    }
    inspect(ready.session_id, content="sess-1")
    // --- dispatch flows through ---
    first.incoming.put(
      (
        #|{"op":0,"s":2,"t":"MESSAGE_DELETE","d":{"id":"5","channel_id":"6"}}
      ),
    )
    guard shard.next() is Dispatch(MessageDelete(deleted)) else {
      fail("expected MessageDelete dispatch")
    }
    inspect(deleted.id, content="5")
    // --- unknown event types are surfaced, not dropped ---
    first.incoming.put(
      (
        #|{"op":0,"s":3,"t":"SOME_FUTURE_EVENT","d":{"x":1}}
      ),
    )
    guard shard.next() is Dispatch(Unknown(t~, ..)) else {
      fail("expected Unknown dispatch")
    }
    inspect(t, content="SOME_FUTURE_EVENT")
    // --- server drops the connection with a resumable code ---
    first.server_close(Some(4000))
    guard! shard.next() is Disconnected(code=Some(4000), resuming=true)
    // --- connection 2: resume with the stored session and sequence ---
    second.incoming.put(HELLO)
    let resume_payload = second.outgoing.get()
    guard resume_payload
      is {
        "op": Number(6, ..),
        "d": {
          "token": String("tok-123"),
          "session_id": String("sess-1"),
          "seq": Number(3, ..),
          ..
        },
        ..
      } else {
      fail("expected resume, got \{resume_payload.stringify()}")
    }
    second.incoming.put(
      (
        #|{"op":0,"s":4,"t":"RESUMED","d":null}
      ),
    )
    guard! shard.next() is Connected(resumed=true)
    debug_inspect(shard.state(), content="Active")
    guard telemetry
      is [
        ShardConnecting(shard_id=0),
        ShardIdentified(shard_id=0),
        ShardConnected(shard_id=0),
        ShardDisconnected(shard_id=0, code=Some(4000), will_resume=true),
        ShardConnecting(shard_id=0),
        ShardResumed(shard_id=0),
        ShardConnected(shard_id=0),
      ] else {
      fail("unexpected shard telemetry: \{Repr(telemetry)}")
    }
    shard.close()
  })
}

///|
async test "cancelled shard send releases the serialized send gate" {
  let transport = FakeTransport()
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      token="tok",
      intents=@model.Intents::none(),
      connector=_ => (transport : &@gateway.GatewayTransport),
    )
    transport.incoming.put(HELLO)
    guard transport.outgoing.get() is { "op": Number(2, ..), .. } else {
      fail("expected identify")
    }
    transport.incoming.put(ready_frame())
    guard shard.next() is Connected(resumed=false) else {
      fail("expected a fresh gateway connection")
    }
    guard shard.next() is Dispatch(Ready(_)) else {
      fail("expected the ready dispatch")
    }

    transport.block_next_send.val = true
    let blocked = group.spawn(no_wait=true, allow_failure=true, () => {
      shard.send({ "op": 3, "d": { "since": 0 } })
    })
    transport.send_started.get()
    blocked.cancel()
    try blocked.wait() catch {
      error if @async.is_cancellation_error(error) => ()
      error => fail("unexpected send error: \{Repr(error)}")
    } noraise {
      _ => fail("cancelled send unexpectedly completed")
    }

    @async.with_timeout(100, () => {
      shard.send({ "op": 4, "d": { "guild_id": "1" } })
    })
    guard transport.outgoing.get() is { "op": Number(4, ..), .. } else {
      fail("expected the send after cancellation")
    }
    shard.close()
  })
}

///|
async test "closing a shard drains an in-flight writer before transport close" {
  let transport = FakeTransport()
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      token="tok",
      intents=@model.Intents::none(),
      connector=_ => (transport : &@gateway.GatewayTransport),
    )
    transport.incoming.put(HELLO)
    transport.outgoing.get() |> ignore
    transport.incoming.put(ready_frame())
    guard! shard.next() is Connected(resumed=false)
    guard! shard.next() is Dispatch(Ready(_))
    @async.with_timeout(100, () => {
      while !transport.recv_in_flight.val {
        @async.pause()
      }
    })

    transport.block_next_send.val = true
    let blocked = group.spawn(no_wait=true, allow_failure=true, () => {
      shard.send({ "op": 3, "d": { "since": 0 } })
    })
    transport.send_started.get()
    let queued = group.spawn(no_wait=true, allow_failure=true, () => {
      shard.send({ "op": 4, "d": { "guild_id": "1" } })
    })
    let close_started : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
    let closing = group.spawn(no_wait=true, () => {
      close_started.try_put(()) |> ignore
      shard.close()
    })
    close_started.get()
    @async.with_timeout(100, () => {
      while transport.recv_in_flight.val {
        @async.pause()
      }
    })
    assert_eq(transport.close_calls.val, 0)
    let closed_early = @async.with_timeout_opt(10, () => closing.wait())
    assert_true(closed_early is None)

    blocked.cancel()
    try blocked.wait() catch {
      error if @async.is_cancellation_error(error) => ()
      error => fail("unexpected send error: \{Repr(error)}")
    } noraise {
      _ => fail("blocked send unexpectedly completed")
    }
    try queued.wait() catch {
      @gateway.TransportClosed(..) => ()
      error => fail("unexpected queued send error: \{Repr(error)}")
    } noraise {
      _ => fail("queued send crossed the closing boundary")
    }
    @async.with_timeout(100, () => closing.wait())
    assert_eq(transport.close_calls.val, 1)
    assert_false(transport.close_during_send.val)
    assert_false(transport.close_during_recv.val)
    guard! shard.next() is Disconnected(code=Some(1000), resuming=false)
  })
}

///|
async test "shard answers heartbeat requests and tracks op9" {
  let first = FakeTransport()
  let second = FakeTransport()
  let pending : Array[FakeTransport] = [second, first]
  let latencies : Array[Int64] = []
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      token="tok",
      intents=@model.Intents::none(),
      connector=_ => {
        match pending.pop() {
          Some(t) => (t : &@gateway.GatewayTransport)
          None => raise @gateway.TransportClosed(code=None, reason="no more")
        }
      },
      telemetry=event => {
        if event is ShardHeartbeatLatency(latency_ms~, ..) {
          latencies.push(latency_ms)
        }
      },
    )
    first.incoming.put(HELLO)
    first.outgoing.get() |> ignore // identify
    first.incoming.put(ready_frame())
    guard! shard.next() is Connected(resumed=false)
    guard! shard.next() is Dispatch(Ready(_))
    // op 1 from the server must be answered immediately with a heartbeat
    first.incoming.put(
      (
        #|{"op":1,"d":null}
      ),
    )
    let beat = first.outgoing.get()
    guard beat is { "op": Number(1, ..), "d": Number(1, ..), .. } else {
      fail("expected heartbeat with seq 1, got \{beat.stringify()}")
    }
    first.incoming.put("{\"op\":11,\"d\":null}")
    @async.sleep(1)
    guard latencies.get(0) is Some(latency) else {
      fail("expected heartbeat latency telemetry")
    }
    assert_true(latency >= 0L)
    // op 9 non-resumable clears the session -> next connection identifies
    first.incoming.put(
      (
        #|{"op":9,"d":false}
      ),
    )
    guard! shard.next() is Disconnected(..)
    second.incoming.put(HELLO)
    let second_payload = second.outgoing.get()
    guard second_payload is { "op": Number(2, ..), .. } else {
      fail("expected re-identify, got \{second_payload.stringify()}")
    }
    shard.close()
  })
}

///|
async test "identify queue spaces buckets" {
  let queue = @queue.InMemoryQueue(max_concurrency=1, spacing_ms=60)
  let start = @clock.now_ms()
  queue.wait_for_identify(0)
  queue.wait_for_identify(1)
  assert_true(@clock.now_ms() - start >= 50L)
}

///|
/// Hello with a 1ms heartbeat interval: the heartbeat task's sleeps are
/// always <= 1ms, so a test sleeper can tell them apart from reconnect
/// backoff (>= 250ms) and the op9 re-identify delay (>= 1000ms).
const HELLO_FAST : String =
  #|{"op":10,"d":{"heartbeat_interval":1}}

///|
/// Gated sleeper: every requested delay is observed on `requests` and only
/// completes when the test calls `release`.
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
async test "shard backoff, resume url switch, and op9 delay run through the sleeper" {
  let first = FakeTransport()
  let second = FakeTransport()
  let third = FakeTransport()
  let pending : Array[FakeTransport] = [third, second, first]
  let urls : Array[String] = []
  let gate = SleepGate()
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      token="tok-9",
      intents=@model.Intents::none(),
      connector=url => {
        urls.push(url)
        match pending.pop() {
          Some(t) => (t : &@gateway.GatewayTransport)
          None => raise @gateway.TransportClosed(code=None, reason="no more")
        }
      },
      sleeper=ms => {
        if ms <= 1 {
          // park the heartbeat task; cancelled with the connection group
          @async.sleep(3_600_000)
        } else {
          gate.sleep(ms)
        }
      },
    )
    // --- connection 1: identify, ready ---
    first.incoming.put(HELLO_FAST)
    guard first.outgoing.get() is { "op": Number(2, ..), .. } else {
      fail("expected identify")
    }
    first.incoming.put(ready_frame())
    guard! shard.next() is Connected(resumed=false)
    guard! shard.next() is Dispatch(Ready(_))
    // --- resumable drop: the reconnect is gated on the backoff sleep ---
    first.server_close(Some(4000))
    guard! shard.next() is Disconnected(code=Some(4000), resuming=true)
    let backoff1 = gate.requests.get()
    // attempts=1: full jitter over 2000ms plus the 250ms floor
    assert_true(backoff1 >= 250 && backoff1 < 2250)
    assert_eq(urls.length(), 1)
    gate.release()
    // --- connection 2: switches to the resume url and resumes ---
    second.incoming.put(HELLO_FAST)
    guard second.outgoing.get() is { "op": Number(6, ..), .. } else {
      fail("expected resume")
    }
    assert_eq(urls.length(), 2)
    assert_true(urls[1].has_prefix("wss://resume.example/"))
    // --- op9 non-resumable: documented 1-5s wait, then re-identify ---
    second.incoming.put(
      (
        #|{"op":9,"d":false}
      ),
    )
    let op9_wait = gate.requests.get()
    assert_true(op9_wait >= 1000 && op9_wait < 5000)
    gate.release()
    guard! shard.next() is Disconnected(code=None, resuming=false)
    let backoff2 = gate.requests.get()
    // attempts=2: full jitter over 4000ms plus the 250ms floor
    assert_true(backoff2 >= 250 && backoff2 < 4250)
    gate.release()
    // --- connection 3: session was cleared, back to the configured url ---
    third.incoming.put(HELLO_FAST)
    guard third.outgoing.get() is { "op": Number(2, ..), .. } else {
      fail("expected re-identify")
    }
    assert_eq(urls.length(), 3)
    assert_true(urls[2].has_prefix("wss://gateway.discord.gg/"))
    shard.close()
  })
}

///|
async test "shard heartbeat loop beats, tracks acks, and zombie-closes" {
  let first = FakeTransport()
  let second = FakeTransport()
  let pending : Array[FakeTransport] = [second, first]
  let latencies : Array[Int64] = []
  let gate = SleepGate()
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      token="tok",
      intents=@model.Intents::none(),
      connector=_ => {
        match pending.pop() {
          Some(t) => (t : &@gateway.GatewayTransport)
          None => raise @gateway.TransportClosed(code=None, reason="no more")
        }
      },
      telemetry=event => {
        if event is ShardHeartbeatLatency(latency_ms~, ..) {
          latencies.push(latency_ms)
        }
      },
      sleeper=ms => gate.sleep(ms),
    )
    first.incoming.put(HELLO)
    guard first.outgoing.get() is { "op": Number(2, ..), .. } else {
      fail("expected identify")
    }
    first.incoming.put(ready_frame())
    guard! shard.next() is Connected(resumed=false)
    guard! shard.next() is Dispatch(Ready(_))
    // the first beat waits out the documented jitter
    let jitter = gate.requests.get()
    assert_true(jitter >= 0 && jitter < 60000)
    gate.release()
    let beat = first.outgoing.get()
    guard beat is { "op": Number(1, ..), "d": Number(1, ..), .. } else {
      fail("expected heartbeat with seq 1, got \{beat.stringify()}")
    }
    first.incoming.put("{\"op\":11,\"d\":null}")
    @async.sleep(1) // let the read loop process the ack
    guard latencies.get(0) is Some(latency) else {
      fail("expected heartbeat latency telemetry")
    }
    assert_true(latency >= 0L)
    // acked: the steady-state interval elapses and the next beat goes out
    let steady = gate.requests.get()
    assert_eq(steady, 60000)
    gate.release()
    guard first.outgoing.get() is { "op": Number(1, ..), .. } else {
      fail("expected second heartbeat")
    }
    // not acked this time: the loop declares a zombie and closes with 4000
    let steady2 = gate.requests.get()
    assert_eq(steady2, 60000)
    gate.release()
    guard! shard.next() is Disconnected(code=Some(4000), resuming=true)
    // and the reconnect resumes after the gated backoff
    let backoff = gate.requests.get()
    assert_true(backoff >= 250 && backoff < 2250)
    gate.release()
    second.incoming.put(HELLO)
    guard second.outgoing.get() is { "op": Number(6, ..), .. } else {
      fail("expected resume after the zombie close")
    }
    shard.close()
  })
}

///|
async test "command limiter admits under the limit immediately" {
  let limiter = @gateway.CommandLimiter(limit=5)
  let start = @clock.now_ms()
  for _ in 0..<5 {
    limiter.acquire()
  }
  assert_true(@clock.now_ms() - start < 100L)
}
