///|
test "invalid requests leave the count ten minutes later, in ten-second steps" {
  let window = InvalidRequests::new()
  assert_eq(window.count(0L), 0)
  window.record(0L)
  window.record(5_000L)
  window.record(599_999L)
  assert_eq(window.count(599_999L), 3)
  // The step of 0 to 9,999 ms has left the window.
  assert_eq(window.count(600_000L), 1)
  // The step of 599,999 ms leaves at 1,190,000 ms.
  assert_eq(window.count(1_189_999L), 1)
  assert_eq(window.count(1_190_000L), 0)
  // Nothing counts before it happened.
  assert_eq(window.count(-1L), 0)
}

///|
test "a slot is reused when its step comes round again" {
  let window = InvalidRequests::new()
  for _ in 0..<5 {
    window.record(1_000L)
  }
  // Ten minutes on, the same slot counts afresh.
  window.record(601_000L)
  assert_eq(window.count(601_000L), 1)
  // Every slot holds at most one step: the ring never grows.
  for step in 0..<1000 {
    window.record(step.to_int64() * 10_000L)
  }
  assert_eq(window.count(999L * 10_000L), 60)
  assert_eq(window.steps.length(), 60)
}

///|
test "negative times fall in the step below" {
  let window = InvalidRequests::new()
  window.record(-1L)
  assert_eq(invalid_step(-1L), -1L)
  assert_eq(invalid_slot(-1L), 59)
  assert_eq(window.count(-1L), 1)
  assert_eq(window.count(0L), 1)
  assert_eq(window.count(589_999L), 1)
  assert_eq(window.count(590_000L), 0)
}

///|
test "Discord counts 401, 403 and 429 as invalid, except a shared 429" {
  let headers = (pairs : Array[(String, String)]) => @ghttp.Headers::of(pairs)
  assert_true(is_invalid_request(401, headers([])))
  assert_true(is_invalid_request(403, headers([])))
  assert_true(is_invalid_request(429, headers([])))
  assert_true(is_invalid_request(429, headers([("x-ratelimit-scope", "user")])))
  assert_true(
    is_invalid_request(429, headers([("x-ratelimit-scope", "global")])),
  )
  assert_false(
    is_invalid_request(429, headers([("x-ratelimit-scope", "shared")])),
  )
  assert_false(
    is_invalid_request(429, headers([("x-ratelimit-scope", " Shared ")])),
  )
  for status in [0, 200, 204, 400, 404, 500, 502] {
    assert_false(
      is_invalid_request(status, headers([])),
      msg=status.to_string(),
    )
  }
}

///|
async test "a client counts the invalid answers of every attempt" {
  let clock = @netruntime.VirtualClock()
  let answers : Array[(Int32, Map[String, String], Json)] = [
    (401, Map([]), { "code": 0, "message": "401: Unauthorized" }),
    (403, Map([]), { "code": 50013, "message": "Missing Permissions" }),
    (
      429,
      { "x-ratelimit-scope": "shared", "content-type": "application/json" },
      { "retry_after": 0.5, "global": false, "message": "shared" },
    ),
    (
      429,
      { "x-ratelimit-scope": "user", "content-type": "application/json" },
      { "retry_after": 0.5, "global": false, "message": "slow down" },
    ),
    (404, Map([]), { "code": 10003, "message": "Unknown Channel" }),
  ]
  let client = Client(
    "test-token",
    transport=FakeWire::{
      answer: (path, _headers, _body) => {
        for index, answer in answers {
          if path == "/api/v10/channels/\{index}" {
            let (status, headers, body) = answer
            return { status, headers, body, }
          }
        }
        fail("unexpected path \{path}")
      },
    },
    limiter=@runtime.NoLimiter::new(),
    clock~,
  )
  defer client.close()
  for index in 0..<answers.length() {
    let route = Route::custom(request_method=Get, path="/channels/\{index}")
    ignore(
      on_virtual_time(clock, () => {
        client.request(route) catch {
          _ => Json::null()
        }
      }),
    )
  }
  // 401, 403, and the user 429 with its resends (four by default); the
  // shared 429 and its resends are not held against the bot.
  assert_eq(client.invalid_requests(), 7)
  clock.advance(600_000)
  assert_eq(client.invalid_requests(), 0)
}

///|
test "an offline client never counts" {
  let client = Client::offline(_ => {
    status: 401,
    headers: Map([]),
    body: Json::null(),
  })
  assert_eq(client.invalid_requests(), 0)
}
