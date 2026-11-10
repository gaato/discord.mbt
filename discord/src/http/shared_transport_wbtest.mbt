///|
struct SharedClientTransport {
  requests : Array[@ghttp.Request]
}

///|
impl @ghttp.Backend for SharedClientTransport with fn send(
  self,
  request,
  _options,
) {
  self.requests.push(request)
  @ghttp.Response::new(
    200,
    body=Bytes(@utf8.encode("{\"url\":\"wss://gateway.example\"}")),
  )
}

///|
async test "client sends through supplied shared transport" {
  let shared = SharedClientTransport::{ requests: [], }
  let client = Client("test-token", backend=shared)
  inspect(client.get_gateway(), content="wss://gateway.example")
  assert_eq(shared.requests.length(), 1)
  assert_eq(shared.requests[0].meth.to_string(), "GET")
  assert_eq(shared.requests[0].url, "https://discord.com/api/v10/gateway")
  client.close()
  // Closing a Client cannot close the caller's transport. The trait has no
  // close method; the same transport remains usable independently.
  ignore(
    @ghttp.Backend::send(
      shared,
      @ghttp.Request::get("https://example.test/other"),
      @ghttp.SendOptions::default(),
    ),
  )
  assert_eq(shared.requests.length(), 2)
}
