///|
/// A real mttp HTTP server and upgrade, isolated on a loopback port. Join
/// the peer before stopping the server so handler assertion failures count.
async fn with_loopback_websocket(
  serve : async (&@ws.Session) -> Unit,
  run : async (String) -> Unit,
  connections~ : Int32 = 1,
  watchdog_ms~ : Int32 = 10000,
) -> Unit {
  @async.with_timeout(watchdog_ms, () => {
    @async.with_task_group(group => {
      let listening : @async.Queue[String] = @async.Queue(kind=Unbounded)
      let finished : @async.Queue[Unit] = @async.Queue(kind=Unbounded)
      let failures : Array[String] = []
      group.spawn_bg(no_wait=true, () => {
        @server.serve(
          request => {
            @ws.upgrade(request, handler=ws => {
              serve(ws) catch {
                error => failures.push("\{Repr(error)}")
              }
              finished.put(())
            })
          },
          addr="127.0.0.1:0",
          limits={ ..@h1server.ServerLimits::default(), drain_ms: 100, },
          on_listen=addr => try! (listening.try_put("ws://\{addr}") |> ignore),
          on_error=error => failures.push("\{Repr(error)}"),
        )
      })
      run(listening.get())
      for _ in 0..<connections {
        finished.get()
      }
      assert_eq(failures, [])
    })
  })
}

///|
async test "the WebSocket transport closes an oversized message with 1009" {
  let peer_saw = Ref(false)
  with_loopback_websocket(
    ws => {
      ws.send(Text("hello"))
      ws.send(Binary(b"bin"))
      ws.send(Binary(Bytes::make(1001, b'x')))
      try ws.recv() |> ignore catch {
        @core_ws.WsError(kind=Closed({ code: MessageTooBig, .. }), ..) =>
          peer_saw.val = true
        error => fail("unexpected \{Repr(error)}")
      } noraise {
        _ => fail("expected Close 1009")
      }
    },
    url => {
      let transport = @gateway.connect_websocket(url, max_message_bytes=1000)
      assert_true(transport.recv() is Text("hello"))
      assert_true(transport.recv() is Binary(b"bin"))
      try transport.recv() |> ignore catch {
        @gateway.TransportClosed(code=Some(1009), ..) => ()
        error => fail("unexpected \{Repr(error)}")
      } noraise {
        _ => fail("an oversized message was accepted")
      }
      transport.close(code=1000)
      transport.close(code=1000)
    },
  )
  assert_true(peer_saw.val)
}

///|
async test "a shard without a connector dials the Gateway URL over WebSocket" {
  let failures : @async.Queue[Unit] = @async.Queue(kind=Unbounded)
  let clock = @transport.VirtualClock()
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      token="tok",
      intents=@model.Intents::none(),
      gateway_url="ws://127.0.0.1:1",
      telemetry=event => {
        if event is ShardDisconnected(..) {
          (failures.try_put(()) |> ignore) catch {
            _ => ()
          }
        }
      },
      clock~,
    )
    guard @async.with_timeout_opt(5000, () => failures.get()) is Some(_) else {
      fail("the default connector never reported a failure")
    }
    assert_true(shard.state() is Disconnected(reconnect_attempts=1))
    shard.close()
  })
}

///|
async test "the WebSocket transport reports every Discord close code and reason" {
  for code in 4000..<=4014 {
    with_loopback_websocket(
      ws => {
        ws.close({
          code: @ws.CloseCode::from_int(code),
          reason: "Discord close \{code}",
        })
      },
      url => {
        let transport = @gateway.connect_websocket(url)
        try transport.recv() |> ignore catch {
          @gateway.TransportClosed(code=Some(actual), reason~) => {
            assert_eq(actual, code)
            assert_eq(reason, "Discord close \{code}")
          }
          error => fail("unexpected \{Repr(error)}")
        } noraise {
          _ => fail("a closed connection delivered a message")
        }
        transport.close(code=1000)
        transport.close(code=1000)
      },
    )
  }
}

///|
async test "mttp upgrade carries a complete Gateway sequence into reconnect policy" {
  for compress in [false, true] {
    let sent : @async.Queue[Unit] = @async.Queue(kind=Unbounded)
    with_loopback_websocket(
      ws => gateway_peer_sequence(ws, compress~, before_close=() => sent.get()),
      url => {
        exercise_gateway_sequence(url, compress~, after_send=() => sent.put(()))
      },
    )
  }
}

///|
/// Node has a client WebSocket API but no fetch upgrade API. The JS test
/// launches this native mttp fixture, and kills/joins it in its cleanup.
async test "Node WebSocket fixture" {
  if @env.get_env_var("DISCORD_GATEWAY_NODE_FIXTURE") != Some("1") {
    return
  }
  let resuming = @env.get_env_var("DISCORD_GATEWAY_NODE_MODE") == Some("resume")
  let resume_url = Ref("")
  let connections = Ref(0)
  with_loopback_websocket(
    ws => {
      if resuming {
        connections.val += 1
        gateway_resume_peer(ws, connections.val, resume_url.val)
      } else {
        gateway_peer_sequence(ws, compress=true, before_close=() => {
          let sent = @env.get_env_var("DISCORD_GATEWAY_NODE_READY").unwrap() +
            ".sent"
          while !@fs.exists(sent) {
            @async.sleep(1)
          }
        })
      }
    },
    url => {
      // Native stdout is buffered when moon captures a test's output. Publish
      // readiness through the per-test file instead of waiting for a flush.
      let ready = @env.get_env_var("DISCORD_GATEWAY_NODE_READY").unwrap()
      resume_url.val = url
      @fs.write_text(ready, url)
    },
    connections=if resuming { 2 } else { 1 },
    // Bound a hang, not response time: host load slows real I/O across processes.
    watchdog_ms=60000,
  )
}

///|
async fn gateway_resume_peer(
  ws : &@ws.Session,
  connection : Int32,
  url : String,
) -> Unit {
  ws.send(Text(HELLO))
  guard ws.recv() is Text(text) else { fail("expected JSON") }
  if connection == 1 {
    guard! @json.parse(text) is { "op": Number(2, ..), .. }
    let ready = @json.parse(ready_frame())
    guard ready is { "d": Object(data), .. } else { fail("bad READY fixture") }
    data["resume_gateway_url"] = Json::string(url)
    ws.send(Text(ready.stringify()))
    guard ws.recv() is Text(command) else {
      fail("expected interrupted command")
    }
    guard! @json.parse(command) is { "op": Number(3, ..), .. }
    try ws.recv() |> ignore catch {
      // Empty Close means the interruption cannot invalidate the session.
      @core_ws.WsError(kind=Closed({ code: NoStatus, .. }), ..) => ()
      error => fail("interrupted JS send lost resumability: \{Repr(error)}")
    } noraise {
      _ => fail("expected status-free abort")
    }
  } else {
    guard @json.parse(text)
      is {
        "op": Number(6, ..),
        "d": { "session_id": String("sess-1"), "seq": Number(1, ..), .. },
        ..
      } else {
      fail("expected Resume, not Identify: \{text}")
    }
    ws.send(Text("{\"op\":0,\"s\":2,\"t\":\"RESUMED\",\"d\":{}}"))
    try ws.recv() |> ignore catch {
      @core_ws.WsError(kind=Closed(_), ..) => ()
      error => fail("unexpected shutdown: \{Repr(error)}")
    } noraise {
      _ => fail("expected client shutdown")
    }
  }
}

///|
async fn gateway_peer_sequence(
  ws : &@ws.Session,
  compress~ : Bool,
  before_close~ : async () -> Unit = () => (),
) -> Unit {
  let encoder = @zlib.Encoder()
  let send_payload : async (String) -> Unit = text => {
    if compress {
      let bytes = wire_sync_flush(encoder, @utf8.encode(text))
      // A sync-flushed payload split across WebSocket binary messages must
      // still use the shard's one Discord inflater, not a WS extension.
      let middle = bytes.length() / 2
      ws.send(Binary(bytes[:middle].to_owned()))
      ws.send(Binary(bytes[middle:].to_owned()))
    } else {
      ws.send(Text(text))
    }
  }
  send_payload(HELLO)
  for ;; {
    guard ws.recv() is Text(text) else { fail("expected JSON Identify") }
    let frame = @json.parse(text)
    if frame is { "op": Number(1, ..), .. } {
      send_payload("{\"op\":11,\"d\":null}")
      continue
    }
    guard frame
      is { "op": Number(2, ..), "d": { "token": String("local-test"), .. }, .. } else {
      fail("expected Identify")
    }
    break
  }
  send_payload(ready_frame())
  // The client acknowledges dispatch processing before the fatal Close.
  guard ws.recv() is Text(text) else { fail("expected command") }
  assert_eq(@json.parse(text), { "op": 3, "d": null })
  // Wait until the client's send/drain has returned. Receiving its frame
  // alone can race that drain with the subsequent peer Close on JS.
  before_close()
  ws.close({ code: Other(4014), reason: "disallowed intents fixture", })
}

///|
fn wire_sync_flush(encoder : @zlib.Encoder, input : Bytes) -> Bytes {
  let bytes : Array[Byte] = []
  let out = FixedArray::make(256, b'\x00')
  for rest = input[:] {
    let status = encoder.step(rest, out.mut_view(), action=Flush)
    for byte in out[:encoder.last_produced()] {
      bytes.push(byte)
    }
    let rest = rest[encoder.last_consumed():]
    if status is NeedMoreInput && rest.is_empty() {
      break
    }
    continue rest
  }
  Bytes::from_array(bytes)
}

///|
async test "outgoing Gateway message limits close both peers with 1009" {
  with_loopback_websocket(
    ws => {
      try ws.recv() |> ignore catch {
        @core_ws.WsError(kind=Closed({ code: MessageTooBig, .. }), ..) => ()
        error => fail("unexpected \{Repr(error)}")
      } noraise {
        _ => fail("oversized outgoing data reached the peer")
      }
    },
    url => {
      let transport = @gateway.connect_websocket(url, max_message_bytes=1000)
      try transport.send("a".repeat(1001)) catch {
        @gateway.TransportClosed(code=Some(1009), ..) => ()
        error => fail("unexpected \{Repr(error)}")
      } noraise {
        _ => fail("oversized outgoing message was accepted")
      }
      transport.close(code=1000)
    },
  )
}
