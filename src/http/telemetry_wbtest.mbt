///|
priv suberror TelemetryHookFailure derive(Debug)

///|
async test "429 retry_after longer than the request timeout retries with telemetry" {
  let limiter = TimeoutTestLimiter(() => ())
  let client = Client(
    "test-token",
    limiter~,
    max_retries=1,
    request_timeout_ms=10,
  )
  defer client.close()
  let calls = Ref(0)
  client.perform_override_.val = Some((_route, _path, _headers, _body, _files) => {
    calls.val += 1
    if calls.val == 1 {
      {
        status: 429,
        headers: { "x-ratelimit-global": "true", "retry-after": "0.06" },
        body: { "retry_after": 0.06 },
      }
    } else {
      { status: 200, headers: Map([]), body: { "ok": true }, }
    }
  })
  let events : Array[@telemetry.TelemetryEvent] = []
  client.on_telemetry(event => events.push(event))
  let response = client.request(GetGateway)
  guard response is { "ok": True, .. } else {
    fail("expected successful retry")
  }
  inspect(calls.val, content="2")
  assert_eq(limiter.acquires, 2)
  assert_eq(limiter.releases.map(release => release.1), [429, 200])
  guard events
    is [
      HttpRequest(status=429, retries=0, ..),
      HttpRateLimited(global=true, retry_after_ms=60L, ..),
      HttpRequest(status=200, retries=1, ..),
    ] else {
    fail("unexpected telemetry: \{Repr(events)}")
  }
}

///|
async test "a timed-out attempt releases its bucket and emits telemetry without retrying" {
  let limiter = TimeoutTestLimiter(() => ())
  let client = Client(
    "test-token",
    limiter~,
    request_timeout_ms=10,
    max_retries=3,
  )
  defer client.close()
  let attempts = Ref(0)
  let cancelled = Ref(false)
  let events : Array[@telemetry.TelemetryEvent] = []
  client.on_telemetry(event => events.push(event))
  client.perform_override_.val = Some((_route, _path, _headers, _body, _files) => {
    attempts.val += 1
    defer {
      cancelled.val = @async.is_being_cancelled()
    }
    @async.sleep(60000)
    { status: 200, headers: Map([]), body: { "late": true }, }
  })
  let route = Route::custom(request_method=Post, path="/channels/1/messages")
  try client.request(route, body={ "content": "send once" }) catch {
    Timeout(timeout_ms~) => inspect(timeout_ms, content="10")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected timeout")
  }
  assert_eq(attempts.val, 1)
  assert_true(cancelled.val)
  assert_eq(limiter.acquires, 1)
  assert_eq(limiter.releases, [(route.bucket(), 0, Map([]))])
  guard events is [HttpRequest(status=0, retries=0, ..)] else {
    fail("expected cancelled request telemetry: \{Repr(events)}")
  }
}

///|
async test "telemetry hook failures flow to client warnings" {
  let client = Client("test-token")
  defer client.close()
  client.perform_override_.val = Some((_route, _path, _headers, _body, _files) => {
    status: 200,
    headers: Map([]),
    body: Json::null(),
  })
  let warnings : Array[String] = []
  client.on_warn(message => warnings.push(message))
  client.on_telemetry(_ => raise TelemetryHookFailure)
  ignore(client.request(GetGateway))
  inspect(warnings.length(), content="1")
  assert_true(warnings[0].contains("telemetry hook failed"))
}
