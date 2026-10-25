///|
struct SharedClientTransport {
  requests : Array[@ghttp.Request]
  mut closes : Int32
}

///|
impl @runtime.Backend for SharedClientTransport with fn send(
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
impl @runtime.Backend for SharedClientTransport with fn close(self) {
  self.closes += 1
}

///|
async test "client sends through supplied shared transport" {
  let shared = SharedClientTransport::{ requests: [], closes: 0, }
  let client = Client("test-token", transport=shared)
  inspect(client.get_gateway(), content="wss://gateway.example")
  assert_eq(shared.requests.length(), 1)
  assert_eq(shared.requests[0].meth, @ghttp.Method::Get)
  assert_eq(shared.requests[0].url, "https://discord.com/api/v10/gateway")
  client.close()
  // A supplied backend belongs to the caller and remains independently usable.
  assert_eq(shared.closes, 0)
  ignore(
    @runtime.Backend::send(
      shared,
      @ghttp.Request::get("https://example.test/other"),
      @runtime.RequestOptions::default(),
    ),
  )
  assert_eq(shared.requests.length(), 2)
}
