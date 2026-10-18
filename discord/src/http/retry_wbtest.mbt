///|
test "resend_delay_ms resends a 429 and an unsent transient failure only" {
  let limited = @runtime.RateLimited(
    retry_after_ms=None,
    headers=@ghttp.Headers::new(),
    body=@utf8.encode("{\"retry_after\":1.5}"),
  )
  let unsent = @runtime.Transport(@ghttp.HttpError::Connect("refused"))
  // (error, attempt, max_retries, closed, delay); random is 0.5, so the
  // backoff is the runtime default's middle: 500 ms, doubling per attempt.
  let cases : Array[(@runtime.SdkError, Int32, Int32, Bool, Int32?)] = [
    (limited, 0, 1, false, Some(1501)),
    (limited, 1, 1, false, None),
    (limited, 0, 0, false, None),
    (limited, 0, 1, true, None),
    // the runtime's own retry_after_ms is not consulted
    (
      @runtime.RateLimited(
        retry_after_ms=Some(9),
        headers=@ghttp.Headers::from_array([("retry-after", "2")]),
        body=b"",
      ),
      0,
      1,
      false,
      Some(2001),
    ),
    // nothing was sent: resent with backoff, whatever the method
    (unsent, 0, 4, false, Some(500)),
    (unsent, 2, 4, false, Some(2000)),
    (unsent, 4, 4, false, None),
    (unsent, 0, 4, true, None),
    (
      @runtime.Transport(@ghttp.HttpError::Timeout(phase=Pool, ms=5)),
      0,
      4,
      false,
      Some(500),
    ),
    (
      @runtime.Transport(@ghttp.HttpError::Timeout(phase=Dial, ms=5)),
      0,
      4,
      false,
      Some(500),
    ),
    (
      @runtime.Transport(@ghttp.HttpError::Proxy(status=502, message="down")),
      0,
      4,
      false,
      Some(500),
    ),
    // unsent but not transient: the proxy will refuse again
    (
      @runtime.Transport(@ghttp.HttpError::Proxy(status=407, message="auth")),
      0,
      4,
      false,
      None,
    ),
    // may have reached Discord
    (
      @runtime.Transport(@ghttp.HttpError::Timeout(phase=Head, ms=5)),
      0,
      4,
      false,
      None,
    ),
    (
      @runtime.Transport(@ghttp.HttpError::Timeout(phase=Unknown, ms=5)),
      0,
      4,
      false,
      None,
    ),
    (
      @runtime.Transport(
        @ghttp.HttpError::Network(phase=Write, message="reset"),
      ),
      0,
      4,
      false,
      None,
    ),
    (
      @runtime.Transport(@ghttp.HttpError::Protocol("garbled")),
      0,
      4,
      false,
      None,
    ),
    // Discord's answer
    (
      @runtime.Status(status=503, headers=@ghttp.Headers::new(), body=b""),
      0,
      4,
      false,
      None,
    ),
    (@runtime.Config("limiter"), 0, 4, false, None),
  ]
  for case in cases {
    let (error, attempt, max_retries, closed, expected) = case
    assert_eq(
      resend_delay_ms(error, attempt~, max_retries~, closed~, random=0.5),
      expected,
    )
  }
}

///|
/// A wire that fails its first attempts with `failures`, in order, then
/// answers through `wire`.
priv struct FlakyWire {
  failures : Array[@ghttp.HttpError]
  wire : FakeWire
  mut failed : Int32
}

///|
impl @ghttp.Transport for FlakyWire with fn send(self, request) {
  if self.failed < self.failures.length() {
    self.failed += 1
    raise self.failures[self.failed - 1]
  }
  @ghttp.Transport::send(self.wire, request)
}

///|
impl @ghttp.Transport for FlakyWire with fn send_stream(_self, _request) {
  raise @ghttp.HttpError::Protocol("FlakyWire does not stream")
}

///|
/// A `test-token` client over a `FlakyWire` whose answers count in `answered`.
fn flaky_client(
  failures : Array[@ghttp.HttpError],
  limiter : TimeoutTestLimiter,
  answered : Ref[Int32],
) -> (Client, FlakyWire) {
  let wire = FlakyWire::{
    failures,
    wire: FakeWire::{
      answer: (_path, _headers, _body) => {
        answered.val += 1
        { status: 200, headers: Map([]), body: { "ok": true }, }
      },
    },
    failed: 0,
  }
  (Client("test-token", transport=wire, limiter~), wire)
}

///|
async test "a POST that never reached Discord is sent again through the limiter" {
  let limiter = TimeoutTestLimiter(() => ())
  let answered = Ref(0)
  let (client, wire) = flaky_client(
    [@ghttp.HttpError::Connect("refused")],
    limiter,
    answered,
  )
  defer client.close()
  let events : Array[@telemetry.TelemetryEvent] = []
  client.on_telemetry(event => events.push(event))
  let route = Route::custom(request_method=Post, path="/channels/1/messages")
  json_inspect(client.request(route, body={ "content": "once" }), content={
    "ok": true,
  })
  assert_eq(wire.failed, 1)
  assert_eq(answered.val, 1)
  assert_eq(limiter.acquires, 2)
  assert_eq(limiter.releases, [
    (route.bucket(), 0, Map([])),
    (route.bucket(), 200, Map([])),
  ])
  guard events
    is [
      HttpRequest(status=0, retries=0, ..),
      HttpRequest(status=200, retries=1, ..),
    ] else {
    fail("unexpected telemetry: \{Repr(events)}")
  }
}

///|
async test "a POST that may have reached Discord is raised at once" {
  for
    failure in [
      @ghttp.HttpError::Network(phase=Write, message="reset"),
      @ghttp.HttpError::Network(phase=Head, message="eof"),
      @ghttp.HttpError::Timeout(phase=Head, ms=5),
      @ghttp.HttpError::Protocol("garbled"),
    ] {
    let limiter = TimeoutTestLimiter(() => ())
    let answered = Ref(0)
    let (client, wire) = flaky_client([failure], limiter, answered)
    defer client.close()
    let route = Route::custom(request_method=Post, path="/channels/1/messages")
    try client.request(route, body={ "content": "once" }) catch {
      error =>
        assert_eq(
          @debug.to_string(error),
          @debug.to_string(transport_failure(failure)),
        )
    } noraise {
      _ => fail("expected the failure to surface")
    }
    assert_eq(wire.failed, 1)
    assert_eq(answered.val, 0)
    assert_eq(limiter.acquires, 1)
  }
}

///|
async test "a closed client does not resend a call that never reached Discord" {
  let limiter = TimeoutTestLimiter(() => ())
  let answered = Ref(0)
  let (client, wire) = flaky_client(
    [@ghttp.HttpError::Connect("refused")],
    limiter,
    answered,
  )
  // Telemetry for the failed attempt runs before the retry decision.
  client.on_telemetry(_ => client.close())
  try client.request(GetGateway) catch {
    Transport(phase=Dial, ..) as error => assert_true(error.is_unsent())
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the refused connection")
  }
  assert_eq(wire.failed, 1)
  assert_eq(answered.val, 0)
  assert_eq(limiter.acquires, 1)
}
