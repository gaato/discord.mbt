///|
/// An offline client for whitebox tests whose handler sees each logical call
/// the way the wire would carry it before encoding: the route, the full API
/// path, the headers a `test-token` client sends (base headers, then the
/// caller's and middleware's), the JSON body, and the files.
///
/// Install the fake in the returned cell before the first call; a test may
/// replace it between calls. Everything above the rate limiter runs as it does
/// online — validation, middleware, status mapping, decoding — so these tests
/// pin the wire shape of each endpoint without a network or a send loop.
fn offline_test_client() -> (
  Client,
  Ref[
    (async (Route, String, Map[String, String], Json?, Array[FileUpload]?) -> HttpResponse)?,
  ],
) {
  let fake : Ref[
    (async (Route, String, Map[String, String], Json?, Array[FileUpload]?) -> HttpResponse)?,
  ] = Ref(None)
  let client = Client::offline(request => {
    guard fake.val is Some(answer) else { fail("no fake response installed") }
    let headers = base_headers(
      "test-token",
      request.route,
      request.audit_reason,
    )
    headers.merge_in_place(request.headers)
    answer(
      request.route,
      "/api/v10" + request.route.path(),
      headers,
      request.body,
      request.files,
    )
  })
  // The base URL a default client has, for helpers that build absolute URLs.
  ({ ..client, base_url: "https://discord.com", }, fake)
}

///|
/// A `gaato/http` transport for whitebox tests of the send loop. Each wire
/// request is decoded into its path under the host, its lowercase headers,
/// and its JSON body (a body that is not JSON, such as a multipart upload,
/// arrives as a JSON string of its text); `answer`'s logical response is
/// encoded back onto the wire, a JSON string body as its raw text, the way
/// `decode_response` reads a body that is not JSON. Everything between the middleware and the wire — the rate limiter,
/// the per-attempt timeout, 429 retries, telemetry — runs for real.
priv struct FakeWire {
  answer : async (String, Map[String, String], Json?) -> HttpResponse
}

///|
impl @ghttp.Transport for FakeWire with fn send(self, request) {
  let url = request.url
  let path = match url.find("/api/") {
    Some(index) => url[index:].to_owned()
    None => url
  }
  let headers : Map[String, String] = Map([])
  for pair in request.headers.iter() {
    headers[pair.0.to_lower()] = pair.1
  }
  let body : Json? = if request.body.is_empty() {
    None
  } else {
    Some(@json.parse(@utf8.decode_lossy(request.body))) catch {
      _ => Some(Json::string(@utf8.decode_lossy(request.body)))
    }
  }
  let response = (self.answer)(path, headers, body) catch {
    error => raise @ghttp.HttpError::Protocol(@debug.to_string(error))
  }
  let wire_headers = @ghttp.Headers::new()
  for name, value in response.headers {
    wire_headers.set(name, value)
  }
  {
    status: response.status,
    headers: wire_headers,
    body: match response.body {
      _ if response.status == 204 => b""
      String(text) => @utf8.encode(text)
      json => @utf8.encode(json.stringify())
    },
  }
}

///|
impl @ghttp.Transport for FakeWire with fn send_stream(_self, _request) {
  raise @ghttp.HttpError::Protocol("FakeWire does not stream")
}

///|
/// A `test-token` client whose wire is `answer`.
fn wire_test_client(
  answer : async (String, Map[String, String], Json?) -> HttpResponse,
  limiter? : &@runtime.RateLimiter,
  max_retries? : Int = 4,
  request_timeout_ms? : Int = 30000,
) -> Client {
  Client(
    "test-token",
    transport=FakeWire::{ answer, },
    limiter?,
    max_retries~,
    request_timeout_ms~,
  )
}

///|
/// Rate-limit headers as a lowercase map, for comparing releases.
fn header_map(headers : @ghttp.Headers) -> Map[String, String] {
  let map : Map[String, String] = Map([])
  for pair in headers.iter() {
    map[pair.0] = pair.1
  }
  map
}
