///|
priv suberror TelemetryHookFailure derive(Debug)

///|
async test "http telemetry reports 429 and retry attempts" {
  let client = Client("test-token", max_retries=1, request_timeout_ms=1000)
  defer client.close()
  let calls = Ref(0)
  client.perform_override_.val = Some((_route, _path, _headers, _body, _files) => {
    calls.val += 1
    if calls.val == 1 {
      {
        status: 429,
        headers: { "x-ratelimit-global": "true", "retry-after": "0" },
        body: { "retry_after": 0.0 },
      }
    } else {
      { status: 200, headers: Map([]), body: { "ok": true } }
    }
  })
  let events : Array[@telemetry.TelemetryEvent] = []
  client.on_telemetry(event => events.push(event))
  let response = client.request(GetGateway)
  guard response is { "ok": True, .. } else {
    fail("expected successful retry")
  }
  inspect(calls.val, content="2")
  guard events
    is [
      HttpRequest(status=429, retries=0, ..),
      HttpRateLimited(global=true, retry_after_ms=0L, ..),
      HttpRequest(status=200, retries=1, ..),
    ] else {
    fail("unexpected telemetry: \{to_repr(events)}")
  }
}

///|
async test "whole request timeout cancels a delayed transport" {
  let client = Client("test-token", request_timeout_ms=10, max_retries=0)
  defer client.close()
  client.perform_override_.val = Some((_route, _path, _headers, _body, _files) => {
    @async.sleep(100)
    { status: 200, headers: Map([]), body: { "late": true } }
  })
  try client.request(GetGateway) catch {
    Timeout(timeout_ms~) => inspect(timeout_ms, content="10")
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected timeout")
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
