///|
test "voice transport errors preserve application codes and local size failures" {
  for code in [1000, 1001, 4000, 4006, 4014, 4015] {
    let error = @core_ws.WsError(
      kind=Closed({
        code: @ws.CloseCode::from_int(code),
        reason: "peer reason",
      }),
      detail="closed",
    )
    guard voice_transport_error(error)
      is VoiceTransportClosed(code=Some(actual), reason="peer reason") else {
      fail("lost close status or reason")
    }
    assert_eq(actual, code)
  }
  guard! voice_transport_error(
      @core_ws.WsError(kind=TooLarge(limit=1), detail="limit"),
    )
    is VoiceTransportClosed(code=Some(1009), reason="limit")
  for code in [@ws.CloseCode::Abnormal, @ws.CloseCode::NoStatus] {
    guard! voice_transport_error(
        @core_ws.WsError(kind=Closed({ code, reason: "", }), detail="closed"),
      )
      is VoiceTransportClosed(code=None, ..)
  }
  guard! voice_transport_error(
      @core_ws.WsError(kind=Protocol, detail="bad frame"),
    )
    is VoiceTransportClosed(code=None, ..)
}

///|
async test "cancelling voice recv stays cancellation and sends map peer Close" {
  let (conn, peer) = @sim.WebSocketStub::pair(
    @transport.RuntimeCoordination::new(),
  )
  defer peer.abort()
  let transport : &VoiceTransport = VoiceWsTransport::{
    conn,
    closed: Ref(false),
  }
  let entered : @async.Queue[Unit] = @async.Queue(kind=Unbounded)
  let converted = Ref(false)
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      entered.put(())
      (transport.recv() |> ignore) catch {
        VoiceTransportClosed(..) => converted.val = true
        error => raise error
      }
    })
    entered.get()
    task.cancel()
    task.wait() catch {
      @async.WaitedTaskAlreadyCancelled => ()
      error => raise error
    }
  })
  assert_false(converted.val)
  peer.send(Binary(b"\x00\xff"))
  assert_true(transport.recv() is Binary(b"\x00\xff"))
  peer.close({ code: Other(4006), reason: "session invalid", })
  for binary in [false, true] {
    try {
      if binary {
        transport.send_binary(b"closed")
      } else {
        transport.send_text("closed")
      }
    } catch {
      VoiceTransportClosed(code=Some(4006), reason="session invalid") => ()
      error => fail("unexpected \{Repr(error)}")
    } noraise {
      _ => fail("send after close succeeded")
    }
  }
  transport.close(code=1000)
  transport.close(code=1000)
}
