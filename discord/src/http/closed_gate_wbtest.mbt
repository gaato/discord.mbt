///|
priv struct GateStream {
  mut closed : Bool
}

///|
impl @ghttp.BodyStream for GateStream with fn read_some(_self) {
  None
}

///|
impl @ghttp.BodyStream for GateStream with fn close(self) {
  self.closed = true
}

///|
async test "ClosedGate passes exchanges through until closed, then refuses them" {
  for streaming in [false, true] {
    let closed = Ref(false)
    let stream = GateStream::{ closed: false, }
    let calls = Ref(0)
    let gate = ClosedGate::{
      inner: @runtime.from_fn((_, _) => {
        calls.val += 1
        @ghttp.Response::new(
          200,
          body=if streaming {
            Stream(@ghttp.StreamBody::new(stream))
          } else {
            Bytes(b"ok")
          },
        )
      }),
      closed,
    }
    let request = @ghttp.Request::get("https://discord.com/api/v10/gateway")
    let response = @runtime.Backend::send(
      gate,
      request,
      @runtime.RequestOptions::default(),
    )
    response.close()
    assert_eq(stream.closed, streaming)
    assert_eq(calls.val, 1)
    closed.val = true
    try
      @runtime.Backend::send(gate, request, @runtime.RequestOptions::default())
    catch {
      @ghttp.TransportError(kind=Closed, phase=Pool, detail~) =>
        assert_eq(detail, CLOSED_MESSAGE)
      error => raise error
    } noraise {
      _ => fail("closed gate sent another request")
    }
    assert_eq(calls.val, 1)
  }
}
