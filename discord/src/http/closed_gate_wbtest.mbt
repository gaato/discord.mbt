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
        ignore(@ghttp.Transport::send_stream(gate, request))
      } else {
        ignore(@ghttp.Transport::send(gate, request))
      }
      "sent"
    } catch {
      @ghttp.HttpError::Connect(message) => "refused: \{message}"
      error => "inner: \{@debug.to_string(error)}"
    }
  }
  assert_eq(outcome(false), "sent")
  assert_eq(outcome(true), "inner: Protocol(\"FakeWire does not stream\")")
  closed.val = true
  assert_eq(outcome(false), "refused: client is closed")
  assert_eq(outcome(true), "refused: client is closed")
}
