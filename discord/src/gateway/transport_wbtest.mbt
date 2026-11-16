///|
test "WebSocket failures retain application Close status and reason" {
  for code in 4000..<=4014 {
    let error = @core_ws.WsError(
      kind=Closed({
        code: @ws.CloseCode::from_int(code),
        reason: "peer reason",
      }),
      detail="closed",
    )
    guard transport_error(error)
      is TransportClosed(code=Some(actual), reason="peer reason") else {
      fail("lost close status or reason")
    }
    assert_eq(actual, code)
  }
  for code in [@ws.CloseCode::Abnormal, @ws.CloseCode::NoStatus] {
    guard! transport_error(
        @core_ws.WsError(kind=Closed({ code, reason: "", }), detail="closed"),
      )
      is TransportClosed(code=None, ..)
  }
  guard! transport_error(
      @core_ws.WsError(kind=TooLarge(limit=1), detail="limit"),
    )
    is TransportClosed(code=Some(1009), reason="limit")
  guard! transport_error(@core_ws.WsError(kind=Protocol, detail="bad frame"))
    is TransportClosed(code=None, ..)
}

///|
async test "cancelling Gateway recv stays cancellation and a later send maps Close" {
  let (conn, peer) = @sim.WebSocketStub::pair(
    @transport.RuntimeCoordination::new(),
  )
  defer peer.abort()
  let transport : &GatewayTransport = WsTransport::{ conn, closed: Ref(false), }
  let entered : @async.Queue[Unit] = @async.Queue(kind=Unbounded)
  let converted = Ref(false)
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      entered.put(())
      (transport.recv() |> ignore) catch {
        TransportClosed(..) => converted.val = true
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
  peer.send(Text("after cancellation"))
  assert_true(transport.recv() is Text("after cancellation"))
  peer.close({ code: Other(4004), reason: "authentication failed", })
  try transport.send("after close") catch {
    TransportClosed(code=Some(4004), reason="authentication failed") => ()
    error => fail("unexpected \{Repr(error)}")
  } noraise {
    _ => fail("send after close succeeded")
  }
  transport.close(code=1000)
  transport.close(code=1000)
}
