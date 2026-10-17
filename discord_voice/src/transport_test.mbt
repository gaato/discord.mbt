///|
async test "the voice WebSocket transport closes an oversized message with 1009" {
  let peer_saw : Ref[String] = Ref("")
  @async.with_task_group(group => {
    let server = @ahttp.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let ws = @asyncws.Conn::from_http_server(conn.read_request(), conn)
      defer ws.close()
      ws.send_text("hello")
      ws.send_binary(b"bin")
      ws.send_binary(Bytes::make(4 * 1024 * 1024 + 1, b'x'))
      try ws.recv() |> ignore catch {
        error => peer_saw.val = "\{error}"
      }
    })
    let transport = @voice.connect_voice_websocket(
      "ws://127.0.0.1:\{server.addr.port()}",
    )
    assert_eq(transport.recv(), Text("hello"))
    assert_eq(transport.recv(), Binary(b"bin"))
    try transport.recv() |> ignore catch {
      @voice.VoiceTransportClosed(code=Some(1009), ..) => ()
      error => fail("unexpected \{Repr(error)}")
    } noraise {
      _ => fail("an oversized message was accepted")
    }
  })
  assert_true(peer_saw.val.contains("MessageTooBig"), msg=peer_saw.val)
}

///|
async test "the voice WebSocket transport reports the peer's close code" {
  @async.with_task_group(group => {
    let server = @ahttp.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let ws = @asyncws.Conn::from_http_server(conn.read_request(), conn)
      defer ws.close()
      // `send_close` raises once the handshake completes.
      ws.send_close(code=Other(4006)) catch {
        _ => ()
      }
    })
    let transport = @voice.connect_voice_websocket(
      "ws://127.0.0.1:\{server.addr.port()}",
    )
    try transport.recv() |> ignore catch {
      @voice.VoiceTransportClosed(code=Some(4006), ..) => ()
      error => fail("unexpected \{Repr(error)}")
    } noraise {
      _ => fail("a closed connection delivered a frame")
    }
    // Closing after the peer did raises, which callers ignore; a second
    // close does nothing.
    transport.close(code=1000) catch {
      _ => ()
    }
    transport.close(code=1000)
  })
}
