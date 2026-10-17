///|
fn parsed_label(parsed : Result[Request, String]) -> String {
  let request = match parsed {
    Ok(request) => request
    Err(message) => return "error: \{message}"
  }
  match request {
    Ping => "ping"
    CooldownAcquire(key~, window_ms~) =>
      "cooldown acquire \{key}, window_ms=\{window_ms}"
    IdentifyAcquire(shard_id~) => "identify acquire, shard_id=\{shard_id}"
    HttpAcquire(bucket~, global_exempt~) =>
      "http acquire \{bucket}, global_exempt=\{global_exempt}"
    HttpRelease(bucket~, lease~, status~, headers~) => {
      let headers = headers
        .iter()
        .map(header => "\{header.0.to_lower()}: \{header.1}")
        .collect()
      "http release \{bucket}, lease=\{lease}, status=\{status}, headers=[\{headers.join(", ")}]"
    }
  }
}

///|
test "parse_request validates each op" {
  let rows : Array[(Json, String)] = [
    ({ "key": "global" }, "error: missing string op"),
    ({ "op": 1 }, "error: missing string op"),
    ({ "op": "ping" }, "ping"),
    (
      { "op": "cooldown_acquire", "key": "global", "window_ms": "1500" },
      "cooldown acquire global, window_ms=1500",
    ),
    (
      { "op": "cooldown_acquire", "key": "global", "window_ms": 1500 },
      "error: cooldown_acquire requires key and non-negative decimal string window_ms",
    ),
    (
      { "op": "cooldown_acquire", "key": "global", "window_ms": "-1" },
      "error: cooldown_acquire requires key and non-negative decimal string window_ms",
    ),
    (
      { "op": "identify_acquire", "shard_id": 3 },
      "identify acquire, shard_id=3",
    ),
    (
      { "op": "identify_acquire", "shard_id": 1.5 },
      "error: identify_acquire requires a non-negative integer shard_id",
    ),
    (
      { "op": "identify_acquire", "shard_id": -1 },
      "error: identify_acquire requires a non-negative integer shard_id",
    ),
    (
      { "op": "http_acquire", "bucket": "b", "global_exempt": true },
      "http acquire b, global_exempt=true",
    ),
    (
      { "op": "http_acquire", "bucket": "b", "global_exempt": "true" },
      "error: http_acquire requires bucket and boolean global_exempt",
    ),
    (
      { "op": "http_release", "bucket": "b", "lease": 1, "status": 200 },
      "error: http_release requires bucket, lease, non-negative integer status, and headers object",
    ),
    (
      {
        "op": "http_release",
        "bucket": "b",
        "lease": 1,
        "status": 200,
        "headers": { "X-RateLimit-Remaining": "0" },
      },
      "http release b, lease=1, status=200, headers=[x-ratelimit-remaining: 0]",
    ),
    ({ "op": "shutdown" }, "error: unknown op: shutdown"),
  ]
  for row in rows {
    let (request, expected) = row
    assert_eq(
      parsed_label(parse_request(request)),
      expected,
      msg=request.stringify(),
    )
  }
  let bad_header = parse_request({
    "op": "http_release",
    "bucket": "b",
    "lease": 1,
    "status": 200,
    "headers": { "Retry-After": 1 },
  })
  assert_eq(
    parsed_label(bad_header),
    "error: invalid headers: gaato/discord/coordinator.CoordinatorError.InvalidResponse",
  )
}

///|
test "decode_response returns ok responses and raises the rest" {
  json_inspect(decode_response("{\"ok\":true,\"lease\":3}"), content={
    "ok": true,
    "lease": 3,
  })
  let failures = [
    "{\"ok\":false,\"error\":\"unknown op: x\"}", "{\"ok\":false}", "not json", "{\"ok\":1}",
  ]
  let errors = failures.map(line => {
    try decode_response(line) catch {
      error => Repr(error).to_string()
    } noraise {
      _ => "no error"
    }
  })
  debug_inspect(
    errors,
    content=(
      #|[
      #|  "Remote(message=\"unknown op: x\")",
      #|  "InvalidResponse(message=\"expected an ok response\")",
      #|  "InvalidResponse(message=\"invalid JSON: Invalid character 'o' at line 1, column 1\")",
      #|  "InvalidResponse(message=\"expected an ok response\")",
      #|]
    ),
  )
}

///|
test "decode_cooldown inverts cooldown_response" {
  for
    decision in [
      @cooldown.CooldownDecision::Acquired,
      Active(retry_after_ms=1L),
      Active(retry_after_ms=9_223_372_036_854_775_807L),
    ] {
    assert_eq(decode_cooldown(cooldown_response(decision)), decision)
  }
  let invalid : Array[Json] = [
    { "ok": true },
    { "ok": true, "retry_after_ms": "-1" },
  ]
  for response in invalid {
    try decode_cooldown(response) catch {
      InvalidResponse(message~) =>
        assert_eq(message, "missing non-negative decimal string retry_after_ms")
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected InvalidResponse for \{response.stringify()}")
    }
  }
}
