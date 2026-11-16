///|
async fn with_voice_websocket(
  serve : async (&@ws.Session) -> Unit,
  run : async (String) -> Unit,
) -> Unit {
  @async.with_timeout(10000, () => {
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
      finished.get()
      assert_eq(failures, [])
    })
  })
}

///|
async test "the voice WebSocket transport closes an oversized message with 1009" {
  with_voice_websocket(
    ws => {
      ws.send(Text("hello"))
      ws.send(Binary(b"bin"))
      // Session refuses an oversized frame at its header. Closing with
      // unread TCP input may reset this large writer before it sees Close.
      ws.send(Binary(Bytes::make(4 * 1024 * 1024 + 1, b'x'))) catch {
        @core_ws.WsError(kind=Transport(_), ..) => return
        error => raise error
      }
      try ws.recv() |> ignore catch {
        @core_ws.WsError(kind=Closed({ code: MessageTooBig, .. }), ..) => ()
        @core_ws.WsError(kind=Transport(_), ..) => ()
        error => fail("unexpected \{Repr(error)}")
      } noraise {
        _ => fail("expected Close 1009")
      }
    },
    url => {
      let transport = @voice.connect_voice_websocket(url)
      assert_eq(transport.recv(), Text("hello"))
      assert_eq(transport.recv(), Binary(b"bin"))
      try transport.recv() |> ignore catch {
        @voice.VoiceTransportClosed(code=Some(1009), ..) => ()
        error => fail("unexpected \{Repr(error)}")
      } noraise {
        _ => fail("an oversized message was accepted")
      }
      transport.close(code=1000)
    },
  )
}

///|
async test "the voice WebSocket transport reports the peer's close code" {
  with_voice_websocket(
    ws => ws.close({ code: Other(4006), reason: "session invalid", }),
    url => {
      let transport = @voice.connect_voice_websocket(url)
      try transport.recv() |> ignore catch {
        @voice.VoiceTransportClosed(code=Some(4006), reason="session invalid") =>
          ()
        error => fail("unexpected \{Repr(error)}")
      } noraise {
        _ => fail("a closed connection delivered a frame")
      }
      transport.close(code=1000)
      transport.close(code=1000)
    },
  )
}

///|
async test "the voice transport sends JSON and binary messages and a Discord Close" {
  with_voice_websocket(
    ws => {
      ws.send(Text("{\"op\":8,\"d\":{\"heartbeat_interval\":60000}}"))
      assert_eq(ws.recv(), Text("{\"op\":0,\"d\":{}}"))
      assert_eq(ws.recv(), Binary(b"\x00\xff\x01"))
      try ws.recv() |> ignore catch {
        @core_ws.WsError(kind=Closed({ code: Other(4000), .. }), ..) => ()
        error => fail("unexpected \{Repr(error)}")
      } noraise {
        _ => fail("expected client Close")
      }
    },
    url => {
      let transport = @voice.connect_voice_websocket(url)
      assert_true(transport.recv() is Text(_))
      transport.send_text("{\"op\":0,\"d\":{}}")
      transport.send_binary(b"\x00\xff\x01")
      transport.close(code=4000)
      transport.close(code=1000)
    },
  )
}

///|
async test "outgoing voice text and binary limits close both peers with 1009" {
  for binary in [false, true] {
    with_voice_websocket(
      ws => {
        try ws.recv() |> ignore catch {
          @core_ws.WsError(kind=Closed({ code: MessageTooBig, .. }), ..) => ()
          error => fail("unexpected \{Repr(error)}")
        } noraise {
          _ => fail("oversized outgoing data reached the peer")
        }
      },
      url => {
        let transport = @voice.connect_voice_websocket(url)
        try {
          if binary {
            transport.send_binary(Bytes::make(4_194_305, b'x'))
          } else {
            transport.send_text("x".repeat(4_194_305))
          }
        } catch {
          @voice.VoiceTransportClosed(code=Some(1009), ..) => ()
          error => fail("unexpected \{Repr(error)}")
        } noraise {
          _ => fail("oversized outgoing message was accepted")
        }
        transport.close(code=1000)
      },
    )
  }
}
