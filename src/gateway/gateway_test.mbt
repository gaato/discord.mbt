///|
/// In-memory transport: `incoming` feeds `recv`, `outgoing` captures `send`.
struct FakeTransport {
  incoming : @aqueue.Queue[String]
  outgoing : @aqueue.Queue[Json]
}

///|
fn FakeTransport::FakeTransport() -> FakeTransport {
  { incoming: Queue(kind=Unbounded), outgoing: Queue(kind=Unbounded) }
}

///|
fn FakeTransport::server_close(self : FakeTransport, code : Int?) -> Unit {
  self.incoming.close(
    error=@gateway.TransportClosed(code~, reason="server closed"),
  )
}

///|
impl @gateway.GatewayTransport for FakeTransport with fn recv(self) {
  Text(self.incoming.get() catch { e => raise e })
}

///|
impl @gateway.GatewayTransport for FakeTransport with fn send(self, text) {
  self.outgoing.put(@json.parse(text) catch { _ => Json::null() })
}

///|
impl @gateway.GatewayTransport for FakeTransport with fn close(self, code~) {
  self.incoming.close(
    error=@gateway.TransportClosed(code=Some(code), reason="client closed"),
  )
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
  let inflater : FakeInflater = {
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
    guard shard.next() is Connected(resumed=false)
    guard shard.next() is Dispatch(Ready(_))
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
    guard shard.next() is Connected(resumed=false)
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
    guard shard.next() is Disconnected(code=Some(4000), resuming=true)
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
    guard shard.next() is Connected(resumed=true)
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
      fail("unexpected shard telemetry: \{to_repr(telemetry)}")
    }
    shard.close()
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
    guard shard.next() is Connected(resumed=false)
    guard shard.next() is Dispatch(Ready(_))
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
    guard shard.next() is Disconnected(..)
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
async test "command limiter admits under the limit immediately" {
  let limiter = @gateway.CommandLimiter(limit=5)
  let start = @clock.now_ms()
  for _ in 0..<5 {
    limiter.acquire()
  }
  assert_true(@clock.now_ms() - start < 100L)
}
