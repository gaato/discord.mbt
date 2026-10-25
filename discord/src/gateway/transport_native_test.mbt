///|
/// Serve one WebSocket connection on a loopback port: `serve` runs with the
/// server side, `run` with the client URL.
async fn with_loopback_websocket(
  serve : async (@asyncws.Conn) -> Unit,
  run : async (String) -> Unit,
) -> Unit {
  @async.with_task_group(group => {
    let server = @ahttp.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let ws = @asyncws.Conn::from_http_server(conn.read_request(), conn)
      defer ws.close()
      serve(ws)
    })
    run("ws://127.0.0.1:\{server.addr.port()}")
  })
}

///|
async test "the WebSocket transport closes an oversized message with 1009" {
  let peer_saw : Ref[String] = Ref("")
  with_loopback_websocket(
    ws => {
      ws.send_text("hello")
      ws.send_binary(b"bin")
      ws.send_binary(Bytes::make(1001, b'x'))
      try ws.recv() |> ignore catch {
        error => peer_saw.val = "\{error}"
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
    },
  )
  assert_true(peer_saw.val.contains("MessageTooBig"), msg=peer_saw.val)
}

///|
async test "a shard without a connector dials the Gateway URL over WebSocket" {
  let failures : @async.Queue[Unit] = @async.Queue(kind=Unbounded)
  let clock = @netruntime.VirtualClock()
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      token="tok",
      intents=@model.Intents::none(),
      // Nothing listens on port 1, so the default connector fails to dial.
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
async test "the WebSocket transport reports the peer's close code" {
  // `send_close` raises once the handshake completes; only the client matters.
  with_loopback_websocket(
    ws => ws.send_close(code=Other(4004)) catch { _ => () },
    url => {
      let transport = @gateway.connect_websocket(url)
      try transport.recv() |> ignore catch {
        @gateway.TransportClosed(code=Some(4004), ..) => ()
        error => fail("unexpected \{Repr(error)}")
      } noraise {
        _ => fail("a closed connection delivered a message")
      }
      // Closing after the peer did raises, which callers ignore; a second
      // close does nothing.
      transport.close(code=1000) catch {
        _ => ()
      }
      transport.close(code=1000)
    },
  )
}
