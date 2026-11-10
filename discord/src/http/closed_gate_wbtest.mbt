///|
async test "ClosedGate passes exchanges through until closed, then refuses them" {
  let closed = Ref(false)
  let gate = ClosedGate::{
    inner: FakeWire::{
      answer: (_path, _headers, _body) => {
        status: 204,
        headers: Map([]),
        body: Json::null(),
      },
    },
    closed,
  }
  let request = @ghttp.Request::get("https://discord.com/api/v10/gateway")
  let outcome = async fn(stream : Bool) -> String {
    try {
      if stream {
        ignore(
          @ghttp.Backend::send(gate, request, {
            timeout_ms: None,
            body: Stream(idle_ms=None),
          }),
        )
      } else {
        ignore(
          @ghttp.Backend::send(gate, request, @ghttp.SendOptions::default()),
        )
      }
      "sent"
    } catch {
      @ghttp.TransportError(kind=Closed, detail~, ..) => "refused: \{detail}"
      error => "inner: \{@debug.to_string(error)}"
    }
  }
  assert_eq(outcome(false), "sent")
  assert_eq(outcome(true), "sent")
  closed.val = true
  assert_eq(outcome(false), "refused: client is closed")
  assert_eq(outcome(true), "refused: client is closed")
}
