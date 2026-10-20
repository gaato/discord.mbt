///|
suberror GatewayTestFailure {
  GatewayTestFailure
}

///|
async test "typed commands and latest presence survive re-identify" {
  let first = @gatewaysim.FakeTransport()
  let second = @gatewaysim.FakeTransport()
  let pending = [second, first]
  let initial = @model.UpdatePresence(status=Idle, activities=[
    @model.BotActivity::custom("initial"),
  ])
  let initial_json = initial.to_json()
  let latest = @model.UpdatePresence(status=Invisible, activities=[
    @model.BotActivity::custom("busy"),
  ])
  let clock = @simclock.VirtualClock()
  @async.with_timeout(5000, () => {
    @async.with_task_group(group => {
      let shard = @gateway.Shard::start(
        group,
        rand=seeded_rand(),
        token="tok",
        intents=@model.Intents::none(),
        presence=initial,
        connector=_ => {
          match pending.pop() {
            Some(t) => (t : &@gateway.GatewayTransport)
            None =>
              raise @gateway.TransportClosed(code=None, reason="no transport")
          }
        },
        clock~,
      )
      initial.activities.clear()
      initial.activities.push(@model.BotActivity::custom("changed after start"))
      first.put(HELLO)
      // Ignore the heartbeat if jitter schedules it ahead of Identify.
      for ;; {
        if first.outgoing.get()
          is { "op": Number(2, ..), "d": { "presence": presence, .. }, .. } {
          assert_eq(presence, initial_json)
          break
        }
      }
      first.put(ready_frame())
      guard! shard.next() is Connected(resumed=false)
      guard! shard.next() is Dispatch(Ready(_))
      shard.update_presence(latest)
      let sent_presence = latest.to_json()
      latest.activities.clear()
      latest.activities.push(@model.BotActivity::custom("changed after send"))
      shard.request_guild_members({
        guild_id: Id(1UL),
        select: All,
        presences: false,
        nonce: None,
      })
      shard.request_soundboard_sounds({ guild_ids: [Id(1UL)], })
      shard.request_channel_info({
        guild_id: Id(1UL),
        fields: [Status, VoiceStartTime],
      })
      for opcode in [3, 8, 31, 43] {
        for ;; {
          let frame = first.outgoing.get()
          if frame is { "op": Number(1, ..), .. } {
            continue
          }
          guard frame is { "op": Number(op, ..), .. } else {
            fail("missing opcode")
          }
          assert_eq(op.to_int(), opcode)
          break
        }
      }
      first.put("{\"op\":9,\"d\":false}")
      guard! shard.next() is Disconnected(..)
      // the documented 1-5 s wait before identifying again
      clock.advance(5000)
      second.put(HELLO)
      for ;; {
        if second.outgoing.get()
          is { "op": Number(2, ..), "d": { "presence": presence, .. }, .. } {
          assert_eq(presence, sent_presence)
          break
        }
      }
      shard.close()
    })
  })
}

///|
async test "inflater factory failure is fatal before connecting" {
  let calls = Ref(0)
  let telemetry : Array[@telemetry.TelemetryEvent] = []
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      rand=seeded_rand(),
      token="tok",
      intents=@model.Intents::none(),
      compress=true,
      inflater_factory=() => raise GatewayTestFailure,
      connector=_ => {
        calls.val += 1
        (@gatewaysim.FakeTransport() : &@gateway.GatewayTransport)
      },
      telemetry=event => telemetry.push(event),
    )
    guard! shard.next() is FatallyClosed(code=0)
    assert_eq(shard.state(), FatallyClosed(code=0))
    assert_eq(calls.val, 0)
    assert_true(
      telemetry.last()
      is Some(ShardDisconnected(shard_id=0, code=None, will_resume=false)),
    )
  })
}

///|
async test "a message size limit below 1 is fatal before connecting" {
  for limit in [0, -1] {
    let calls = Ref(0)
    @async.with_task_group(group => {
      let shard = @gateway.Shard::start(
        group,
        rand=seeded_rand(),
        token="tok",
        intents=@model.Intents::none(),
        max_message_bytes=limit,
        connector=_ => {
          calls.val += 1
          (@gatewaysim.FakeTransport() : &@gateway.GatewayTransport)
        },
      )
      guard! shard.next() is FatallyClosed(code=0)
      assert_eq(shard.state(), FatallyClosed(code=0))
      assert_eq(calls.val, 0)
    })
  }
  try
    @gateway.connect_websocket("ws://127.0.0.1:1", max_message_bytes=0)
    |> ignore
  catch {
    @gateway.InvalidMaxMessageBytes(value=0) => ()
    error => fail("unexpected \{Repr(error)}")
  } noraise {
    _ => fail("connect_websocket accepted a limit of 0")
  }
}

///|
async test "shard rejects sends while connecting and cancels the connector" {
  let entered : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let pending : @aqueue.Queue[&@gateway.GatewayTransport] = Queue(
    kind=Unbounded,
  )
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      rand=seeded_rand(),
      token="tok",
      intents=@model.Intents::none(),
      connector=_ => {
        entered.put(())
        pending.get()
      },
    )
    entered.get()
    try shard.send({ "op": 3, "d": null }) catch {
      @gateway.TransportClosed(code~, reason~) => {
        assert_eq(code, None)
        assert_eq(reason, "shard is not connected")
      }
      error => fail("unexpected send error: \{Repr(error)}")
    } noraise {
      _ => fail("expected disconnected send to fail")
    }
    shard.close()
    shard.close()
    assert_eq(shard.state(), Disconnected(reconnect_attempts=0))
  })
}

///|
async test "shard suppresses connector failure after protected cancellation cleanup" {
  let entered : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let finish : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let telemetry : Array[@telemetry.TelemetryEvent] = []
  let attempts = Ref(0)
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      rand=seeded_rand(),
      token="tok",
      intents=@model.Intents::none(),
      connector=_ => {
        attempts.val += 1
        @async.protect_from_cancel(() => {
          entered.put(())
          finish.get()
          raise GatewayTestFailure
        })
      },
      telemetry=event => telemetry.push(event),
    )
    entered.get()
    let closing = group.spawn(no_wait=true, () => shard.close())
    @async.pause()
    finish.put(())
    closing.wait()
    assert_eq(attempts.val, 1)
    assert_eq(telemetry.length(), 2)
    assert_true(telemetry[0] is ShardConnecting(shard_id=0))
    assert_true(
      telemetry[1]
      is ShardDisconnected(shard_id=0, code=Some(1000), will_resume=false),
    )
    assert_eq(shard.state(), Disconnected(reconnect_attempts=0))
  })
}

///|
async test "shard connector failure reports telemetry and cancelled backoff stops retrying" {
  let clock = @simclock.VirtualClock()
  let attempts = Ref(0)
  let telemetry : Array[@telemetry.TelemetryEvent] = []
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      rand=seeded_rand(),
      token="tok",
      intents=@model.Intents::none(),
      connector=_ => {
        attempts.val += 1
        raise GatewayTestFailure
      },
      clock~,
      telemetry=event => telemetry.push(event),
    )
    clock.settle()
    guard clock.pending() is [delay] else { fail("expected one backoff") }
    assert_true(delay >= 250 && delay < 2250)
    assert_eq(shard.state(), Disconnected(reconnect_attempts=1))
    assert_true(telemetry[0] is ShardConnecting(shard_id=0))
    assert_true(
      telemetry[1]
      is ShardDisconnected(shard_id=0, code=None, will_resume=false),
    )
    shard.close()
    assert_eq(attempts.val, 1)
  })
}

///|
async test "shard rejects malformed Hello and preserves transport close codes" {
  for failure in 0..<3 {
    let transport = @gatewaysim.FakeTransport()
    @async.with_task_group(group => {
      let shard = @gateway.Shard::start(
        group,
        rand=seeded_rand(),
        token="tok",
        intents=@model.Intents::none(),
        connector=_ => (transport : &@gateway.GatewayTransport),
        clock=@simclock.VirtualClock(),
      )
      match failure {
        0 => transport.put("{\"op\":10,\"d\":{}}")
        1 => transport.server_close(Some(4004))
        _ => transport.incoming.close(error=GatewayTestFailure)
      }
      if failure == 1 {
        guard! shard.next() is FatallyClosed(code=4004)
        assert_eq(shard.state(), FatallyClosed(code=4004))
      } else {
        guard! shard.next() is Disconnected(code=None, resuming=false)
        assert_eq(shard.state(), Disconnected(reconnect_attempts=1))
      }
      assert_eq(transport.close_calls.val, 1)
      shard.close()
    })
  }
}

///|
async test "shard ignores incomplete dispatches and reconnects from a zero sequence" {
  let first = @gatewaysim.FakeTransport()
  let second = @gatewaysim.FakeTransport()
  let transports = [second, first]
  let clock = @simclock.VirtualClock()
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      rand=seeded_rand(),
      token="tok",
      intents=@model.Intents::none(),
      connector=_ => (transports.pop().unwrap() : &@gateway.GatewayTransport),
      clock~,
    )
    first.put(HELLO)
    guard! first.outgoing.get() is { "op": Number(2, ..), .. }
    for
      frame in [
        "{}", "{\"op\":0}", "{\"op\":0,\"t\":\"READY\",\"s\":1,\"d\":{}}", "{\"op\":255}",
      ] {
      first.put(frame)
    }
    first.put("{\"op\":1,\"d\":null}")
    assert_eq(first.outgoing.get(), { "op": 1, "d": null })
    let ready = @json.parse(ready_frame())
    guard! ready is Object(fields)
    fields["s"] = Json::null()
    first.put(ready.stringify())
    guard! shard.next() is Connected(resumed=false)
    guard! shard.next() is Dispatch(Ready(_))
    first.put("{\"op\":7,\"d\":null}")
    guard! shard.next() is Disconnected(code=None, resuming=true)
    // a 1000 close would invalidate the session we are about to resume
    assert_eq(first.close_code.val, Some(4000))
    assert_true(clock.advance_to_next())
    second.put(HELLO)
    guard second.outgoing.get()
      is { "op": Number(6, ..), "d": { "seq": Number(0, ..), .. }, .. } else {
      fail("expected resume from sequence zero")
    }
    shard.close()
  })
}

///|
async test "shard malformed read frames disconnect and tolerate transport close failure" {
  let transport = @gatewaysim.FakeTransport()
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      rand=seeded_rand(),
      token="tok",
      intents=@model.Intents::none(),
      connector=_ => (transport : &@gateway.GatewayTransport),
      clock=@simclock.VirtualClock(),
    )
    transport.put(HELLO)
    transport.outgoing.get() |> ignore
    transport.fail_close.val = true
    transport.put("{")
    guard! shard.next() is Disconnected(code=None, resuming=false)
    assert_eq(transport.close_calls.val, 1)
    shard.close()
  })
}

///|
async test "shard rejects compression frame mismatches" {
  for compress in [false, true] {
    let transport = @gatewaysim.FakeTransport()
    let inflater = FakeInflater::{ messages: [], chunks: [], pending: [], }
    @async.with_task_group(group => {
      let shard = @gateway.Shard::start(
        group,
        rand=seeded_rand(),
        token="tok",
        intents=@model.Intents::none(),
        compress~,
        connector=_ => (transport : &@gateway.GatewayTransport),
        inflater_factory=() => (inflater : &@gateway.Inflater),
        clock=@simclock.VirtualClock(),
      )
      transport.incoming.put(
        if compress {
          Text(HELLO)
        } else {
          Binary(b"frame")
        },
      )
      guard! shard.next() is Disconnected(code=None, resuming=false)
      assert_eq(inflater.chunks.length(), 0)
      shard.close()
    })
  }
}

///|
async test "shard send failures release the writer gate" {
  let transport = @gatewaysim.FakeTransport()
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      rand=seeded_rand(),
      token="tok",
      intents=@model.Intents::none(),
      connector=_ => (transport : &@gateway.GatewayTransport),
      clock=@simclock.VirtualClock(),
    )
    transport.put(HELLO)
    transport.outgoing.get() |> ignore
    transport.outgoing.close(error=GatewayTestFailure)
    for _ in 0..<2 {
      try shard.send({ "op": 3, "d": null }) catch {
        GatewayTestFailure => ()
        error => fail("unexpected send error: \{Repr(error)}")
      } noraise {
        _ => fail("expected failed send")
      }
    }
    shard.close()
    assert_eq(transport.close_calls.val, 1)
  })
}

///|
async test "cancelling a shard closes its transport exactly once" {
  let transport = @gatewaysim.FakeTransport()
  @async.with_task_group(group => {
    @gateway.Shard::start(
      group,
      token="tok",
      intents=@model.Intents::none(),
      rand=seeded_rand(),
      connector=_ => (transport : &@gateway.GatewayTransport),
    )
    |> ignore
    transport.put(HELLO)
    transport.outgoing.get() |> ignore
  })
  assert_eq(transport.close_calls.val, 1)
  assert_eq(transport.close_code.val, Some(1000))
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
async test "shard resumes from a saved session and exposes snapshots" {
  let transport = @gatewaysim.FakeTransport()
  let urls : Array[String] = []
  let saved : @gateway.Session = {
    id: "sess",
    resume_url: "wss://resume.example",
    sequence: 41L,
  }
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      rand=seeded_rand(),
      token="tok",
      intents=@model.Intents::none(),
      gateway_url="wss://gateway.example",
      session=saved,
      connector=url => {
        urls.push(url)
        (transport : &@gateway.GatewayTransport)
      },
    )
    saved.sequence = 99L
    transport.put(HELLO)
    guard transport.outgoing.get()
      is {
        "op": Number(6, ..),
        "d": { "session_id": String("sess"), "seq": Number(41, ..), .. },
        ..
      } else {
      fail("expected saved session resume")
    }
    assert_true(urls[0].has_prefix("wss://resume.example/?v=10"))
    transport.put("{\"op\":0,\"t\":\"RESUMED\",\"s\":42,\"d\":{}}")
    guard! shard.next() is Connected(resumed=true)
    guard shard.session() is Some(snapshot) else { fail("expected session") }
    assert_eq(snapshot.sequence, 42L)
    snapshot.sequence = 100L
    guard shard.session() is Some(again) else { fail("expected session") }
    assert_eq(again.sequence, 42L)
    shard.close()
    assert_true(shard.session() is None)
  })
}

///|
async test "stale resume url falls back to identify after three connector failures" {
  let transport = @gatewaysim.FakeTransport()
  let urls : Array[String] = []
  let connected : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let clock = @simclock.VirtualClock()
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      rand=seeded_rand(),
      token="tok",
      intents=@model.Intents::none(),
      gateway_url="wss://gateway.example",
      session={ id: "sess", resume_url: "wss://resume.example", sequence: 41L, },
      connector=url => {
        urls.push(url)
        if url.contains("resume.example") {
          raise GatewayTestFailure
        }
        connected.put(())
        (transport : &@gateway.GatewayTransport)
      },
      clock~,
    )
    clock.settle()
    while urls.length() < 4 {
      assert_true(clock.advance_to_next())
    }
    connected.get()
    assert_eq(urls.length(), 4)
    for i in 0..<3 {
      assert_true(urls[i].has_prefix("wss://resume.example/?v=10"))
    }
    assert_true(urls[3].has_prefix("wss://gateway.example/?v=10"))
    transport.put(HELLO)
    guard! transport.outgoing.get() is { "op": Number(2, ..), .. }
    shard.close()
  })
}

///|
async test "successful connector resets stale-host fallback failure count" {
  let first = @gatewaysim.FakeTransport()
  let fallback = @gatewaysim.FakeTransport()
  let urls : Array[String] = []
  let first_connected : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let fallback_connected : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let clock = @simclock.VirtualClock()
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      rand=seeded_rand(),
      token="tok",
      intents=@model.Intents::none(),
      gateway_url="wss://gateway.example",
      session={ id: "sess", resume_url: "wss://resume.example", sequence: 41L, },
      connector=url => {
        urls.push(url)
        match urls.length() {
          2 => {
            first_connected.put(())
            (first : &@gateway.GatewayTransport)
          }
          6 => {
            fallback_connected.put(())
            (fallback : &@gateway.GatewayTransport)
          }
          _ => raise GatewayTestFailure
        }
      },
      clock~,
    )
    assert_true(clock.advance_to_next())
    first_connected.get()
    first.put(HELLO)
    guard! first.outgoing.get() is { "op": Number(6, ..), .. }
    // a resumable drop: the stale-host count restarts, so the resume url gets
    // three more tries before the fallback
    first.server_close(Some(4000))
    clock.settle()
    while urls.length() < 6 {
      assert_true(clock.advance_to_next())
    }
    fallback_connected.get()
    assert_eq(urls.length(), 6)
    for i in 0..<5 {
      assert_true(urls[i].has_prefix("wss://resume.example/?v=10"))
    }
    assert_true(urls[5].has_prefix("wss://gateway.example/?v=10"))
    fallback.put(HELLO)
    guard! fallback.outgoing.get() is { "op": Number(2, ..), .. }
    shard.close()
  })
}

///|
test "session json round trip" {
  let session : @gateway.Session = {
    id: "sess",
    resume_url: "wss://r",
    sequence: 41L,
  }
  let encoded = session.to_json()
  let decoded : @gateway.Session = @json.from_json(encoded)
  assert_eq(decoded.id, session.id)
  assert_eq(decoded.resume_url, session.resume_url)
  assert_eq(decoded.sequence, session.sequence)
  inspect(
    encoded.stringify(),
    content="{\"id\":\"sess\",\"resume_url\":\"wss://r\",\"sequence\":\"41\"}",
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
async test "compressed shard buffers suffix fragments and decodes messages" {
  let transport = @gatewaysim.FakeTransport()
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
      rand=seeded_rand(),
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
async test "compression=ZstdStream requests zstd-stream over compress=true" {
  let transport = @gatewaysim.FakeTransport()
  let connected_url = Ref("")
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      rand=seeded_rand(),
      token="tok",
      intents=@model.Intents::guild_messages(),
      compress=true,
      compression=ZstdStream,
      connector=url => {
        connected_url.val = url
        (transport : &@gateway.GatewayTransport)
      },
    )
    @async.sleep(1)
    assert_true(connected_url.val.has_suffix("&compress=zstd-stream"))
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
  let first = @gatewaysim.FakeTransport()
  let second = @gatewaysim.FakeTransport()
  let pending : Array[@gatewaysim.FakeTransport] = [second, first]
  let telemetry : Array[@telemetry.TelemetryEvent] = []
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      rand=seeded_rand(),
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
    first.put(HELLO)
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
    first.put(ready_frame())
    guard! shard.next() is Connected(resumed=false)
    debug_inspect(shard.state(), content="Active")
    guard shard.next() is Dispatch(Ready(ready)) else {
      fail("expected Ready dispatch")
    }
    inspect(ready.session_id, content="sess-1")
    // --- dispatch flows through ---
    first.put(
      (
        #|{"op":0,"s":2,"t":"MESSAGE_DELETE","d":{"id":"5","channel_id":"6"}}
      ),
    )
    guard shard.next() is Dispatch(MessageDelete(deleted)) else {
      fail("expected MessageDelete dispatch")
    }
    inspect(deleted.id, content="5")
    // --- unknown event types are surfaced, not dropped ---
    first.put(
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
    second.put(HELLO)
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
    second.put(
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
  let transport = @gatewaysim.FakeTransport()
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      rand=seeded_rand(),
      token="tok",
      intents=@model.Intents::none(),
      connector=_ => (transport : &@gateway.GatewayTransport),
    )
    transport.put(HELLO)
    guard transport.outgoing.get() is { "op": Number(2, ..), .. } else {
      fail("expected identify")
    }
    transport.put(ready_frame())
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
      @async.WaitedTaskAlreadyCancelled => ()
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
  let transport = @gatewaysim.FakeTransport()
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      rand=seeded_rand(),
      token="tok",
      intents=@model.Intents::none(),
      connector=_ => (transport : &@gateway.GatewayTransport),
    )
    transport.put(HELLO)
    transport.outgoing.get() |> ignore
    transport.put(ready_frame())
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
      @async.WaitedTaskAlreadyCancelled => ()
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
  let first = @gatewaysim.FakeTransport()
  let second = @gatewaysim.FakeTransport()
  let pending : Array[@gatewaysim.FakeTransport] = [second, first]
  let latencies : Array[Int64] = []
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      rand=seeded_rand(),
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
    first.put(HELLO)
    first.outgoing.get() |> ignore // identify
    first.put(ready_frame())
    guard! shard.next() is Connected(resumed=false)
    guard! shard.next() is Dispatch(Ready(_))
    // op 1 from the server must be answered immediately with a heartbeat
    first.put(
      (
        #|{"op":1,"d":null}
      ),
    )
    let beat = first.outgoing.get()
    guard beat is { "op": Number(1, ..), "d": Number(1, ..), .. } else {
      fail("expected heartbeat with seq 1, got \{beat.stringify()}")
    }
    first.put("{\"op\":11,\"d\":null}")
    @async.sleep(1)
    guard latencies.get(0) is Some(latency) else {
      fail("expected heartbeat latency telemetry")
    }
    assert_true(latency >= 0L)
    // op 9 non-resumable clears the session -> next connection identifies
    first.put(
      (
        #|{"op":9,"d":false}
      ),
    )
    guard! shard.next() is Disconnected(..)
    second.put(HELLO)
    let second_payload = second.outgoing.get()
    guard second_payload is { "op": Number(2, ..), .. } else {
      fail("expected re-identify, got \{second_payload.stringify()}")
    }
    shard.close()
  })
}

///|
async test "identify queue spaces buckets" {
  let clock = @simclock.VirtualClock()
  let queue = @queue.InMemoryQueue(max_concurrency=1, spacing_ms=60, clock~)
  @async.with_task_group(group => {
    queue.wait_for_identify(0)
    let second = group.spawn(() => queue.wait_for_identify(1))
    clock.settle()
    assert_eq(clock.pending(), [60])
    clock.advance(60)
    second.wait()
  })
}

///|
async test "shard backoff, resume url switch, and op9 delay run on the clock" {
  let first = @gatewaysim.FakeTransport()
  let second = @gatewaysim.FakeTransport()
  let third = @gatewaysim.FakeTransport()
  let pending : Array[@gatewaysim.FakeTransport] = [third, second, first]
  let urls : Array[String] = []
  let clock = @simclock.VirtualClock()
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      rand=seeded_rand(),
      token="tok-9",
      intents=@model.Intents::none(),
      connector=url => {
        urls.push(url)
        match pending.pop() {
          Some(t) => (t : &@gateway.GatewayTransport)
          None => raise @gateway.TransportClosed(code=None, reason="no more")
        }
      },
      clock~,
    )
    // --- connection 1: identify, ready ---
    first.put(HELLO)
    guard first.outgoing.get() is { "op": Number(2, ..), .. } else {
      fail("expected identify")
    }
    first.put(ready_frame())
    guard! shard.next() is Connected(resumed=false)
    guard! shard.next() is Dispatch(Ready(_))
    // --- resumable drop: the reconnect is gated on the backoff sleep ---
    first.server_close(Some(4000))
    guard! shard.next() is Disconnected(code=Some(4000), resuming=true)
    // the heartbeat timer went with the connection; only the backoff is left
    clock.settle()
    guard clock.pending() is [backoff1] else { fail("expected one backoff") }
    // attempts=1: full jitter over 2000ms plus the 250ms floor
    assert_true(backoff1 >= 250 && backoff1 < 2250)
    assert_eq(urls.length(), 1)
    assert_true(clock.advance_to_next())
    // --- connection 2: switches to the resume url and resumes ---
    second.put(HELLO)
    guard second.outgoing.get() is { "op": Number(6, ..), .. } else {
      fail("expected resume")
    }
    assert_eq(urls.length(), 2)
    assert_true(urls[1].has_prefix("wss://resume.example/"))
    // --- op9 non-resumable: the documented 1-5s wait replaces the backoff ---
    second.put(
      (
        #|{"op":9,"d":false}
      ),
    )
    guard! shard.next() is Disconnected(code=None, resuming=false)
    clock.settle()
    guard clock.pending() is [op9_wait] else { fail("expected one op9 wait") }
    assert_true(op9_wait >= 1000 && op9_wait < 5000)
    assert_true(clock.advance_to_next())
    // --- connection 3: session was cleared, back to the configured url ---
    third.put(HELLO)
    guard third.outgoing.get() is { "op": Number(2, ..), .. } else {
      fail("expected re-identify")
    }
    assert_eq(urls.length(), 3)
    assert_true(urls[2].has_prefix("wss://gateway.discord.gg/"))
    shard.close()
  })
}

///|
async test "connections that reach READY or RESUMED reset the reconnect backoff" {
  let transports = Array::makei(6, _ => @gatewaysim.FakeTransport())
  let pending = transports.copy()
  pending.rev_in_place()
  let clock = @simclock.VirtualClock()
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      rand=seeded_rand(),
      token="tok",
      intents=@model.Intents::none(),
      connector=_ => (pending.pop().unwrap() : &@gateway.GatewayTransport),
      clock~,
    )
    transports[0].put(HELLO)
    transports[0].outgoing.get() |> ignore
    transports[0].put(ready_frame())
    guard! shard.next() is Connected(resumed=false)
    guard! shard.next() is Dispatch(Ready(_))
    for i in 0..<5 {
      transports[i].server_close(Some(4000))
      guard! shard.next() is Disconnected(code=Some(4000), resuming=true)
      // every drop follows a healthy connection, so the backoff stays at
      // its first step (2000ms jitter plus the 250ms floor)
      clock.settle()
      guard clock.pending() is [backoff] else { fail("expected one backoff") }
      assert_true(backoff >= 250 && backoff < 2250)
      assert_true(clock.advance_to_next())
      let next = transports[i + 1]
      next.put(HELLO)
      guard! next.outgoing.get() is { "op": Number(6, ..), .. }
      next.put("{\"op\":0,\"t\":\"RESUMED\",\"s\":2,\"d\":{}}")
      guard! shard.next() is Connected(resumed=true)
      guard! shard.next() is Dispatch(_)
    }
    shard.close()
  })
}

///|
async test "shard heartbeat loop beats, tracks acks, and zombie-closes" {
  let first = @gatewaysim.FakeTransport()
  let second = @gatewaysim.FakeTransport()
  let pending : Array[@gatewaysim.FakeTransport] = [second, first]
  let latencies : Array[Int64] = []
  let clock = @simclock.VirtualClock()
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      rand=seeded_rand(),
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
      clock~,
    )
    first.put(HELLO)
    guard first.outgoing.get() is { "op": Number(2, ..), .. } else {
      fail("expected identify")
    }
    first.put(ready_frame())
    guard! shard.next() is Connected(resumed=false)
    guard! shard.next() is Dispatch(Ready(_))
    // the first beat waits out the documented jitter
    clock.settle()
    guard clock.pending() is [jitter] else { fail("expected the jitter wait") }
    assert_true(jitter >= 0 && jitter < 60000)
    assert_true(clock.advance_to_next())
    let beat = first.outgoing.get()
    guard beat is { "op": Number(1, ..), "d": Number(1, ..), .. } else {
      fail("expected heartbeat with seq 1, got \{beat.stringify()}")
    }
    first.put("{\"op\":11,\"d\":null}")
    clock.settle()
    // acked at the same virtual instant the beat went out
    assert_eq(latencies, [0L])
    // acked: the steady-state interval elapses and the next beat goes out
    assert_eq(clock.pending(), [60000])
    assert_true(clock.advance_to_next())
    guard first.outgoing.get() is { "op": Number(1, ..), .. } else {
      fail("expected second heartbeat")
    }
    // not acked this time: the loop declares a zombie and closes with 4000
    assert_eq(clock.pending(), [60000])
    assert_true(clock.advance_to_next())
    guard! shard.next() is Disconnected(code=Some(4000), resuming=true)
    assert_eq(first.close_code.val, Some(4000))
    // and the reconnect resumes after the gated backoff
    guard clock.pending() is [backoff] else { fail("expected one backoff") }
    assert_true(backoff >= 250 && backoff < 2250)
    assert_true(clock.advance_to_next())
    second.put(HELLO)
    guard second.outgoing.get() is { "op": Number(6, ..), .. } else {
      fail("expected resume after the zombie close")
    }
    shard.close()
    assert_eq(second.close_code.val, Some(1000))
  })
}

///|
async test "command limiter admits under the limit immediately" {
  let clock = @simclock.VirtualClock()
  let limiter = @gateway.CommandLimiter(limit=5, clock~)
  @async.with_task_group(group => {
    let sends = group.spawn(() => {
      for _ in 0..<5 {
        limiter.acquire()
      }
    })
    clock.settle()
    assert_eq(clock.pending(), [])
    sends.wait()
  })
}

///|
async test "identify queue lets a fresh bucket identify at once from time zero" {
  let clock = @simclock.VirtualClock(start_ms=0)
  let queue = @queue.InMemoryQueue(max_concurrency=1, spacing_ms=5250, clock~)
  @async.with_task_group(group => {
    let first = group.spawn(() => queue.wait_for_identify(0))
    clock.settle()
    assert_eq(clock.pending(), [])
    first.wait()
  })
}

///|
/// The shard's random source for tests: a fixed seed, so heartbeat jitter and
/// backoff are the same on every run. A zero first jitter would beat at once,
/// before IDENTIFY, with no timer registered.
fn seeded_rand() -> @random.Rand {
  @random.Rand::chacha8()
}
