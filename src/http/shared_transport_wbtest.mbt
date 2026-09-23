///|
struct SharedClientTransport {
  requests : Array[@ghttp.Request]
}

///|
impl @ghttp.Transport for SharedClientTransport with fn send(self, request) {
  self.requests.push(request)
  {
    status: 200,
    headers: @ghttp.Headers::new(),
    body: @utf8.encode("{\"url\":\"wss://gateway.example\"}"),
  }
}

///|
impl @ghttp.Transport for SharedClientTransport with fn send_stream(
  _self,
  _request,
) {
  raise @ghttp.HttpError::Protocol("unexpected streaming request")
}

///|
async test "client sends through supplied shared transport" {
  let shared = SharedClientTransport::{ requests: [], }
  let client = Client("test-token", transport=shared)
  inspect(client.get_gateway(), content="wss://gateway.example")
  assert_eq(shared.requests.length(), 1)
  assert_eq(shared.requests[0].http_method, "GET")
  assert_eq(shared.requests[0].url, "https://discord.com/api/v10/gateway")
  client.close()
  // Closing a Client cannot close the caller's transport. The trait has no
  // close method; the same transport remains usable independently.
  ignore(
    @ghttp.Transport::send(
      shared,
      @ghttp.Request::get("https://example.test/other"),
    ),
  )
  assert_eq(shared.requests.length(), 2)
}
