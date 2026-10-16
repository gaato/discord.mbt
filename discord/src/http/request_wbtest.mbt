///|
fn headers_of(pairs : Array[(String, String)]) -> @ghttp.Headers {
  @ghttp.Headers::from_array(pairs)
}

///|
test "rate_limit_from_json prefers the body, then the headers, then one second" {
  let cases : Array[(Array[(String, String)], Json, (Int64, Bool))] = [
    ([("retry-after", "2")], { "retry_after": 1.5 }, (1500L, false)),
    ([("retry-after", "0.02")], {}, (20L, false)),
    ([("retry-after-ms", "250")], {}, (250L, false)),
    ([("retry-after-ms", "250"), ("retry-after", "3")], {}, (250L, false)),
    ([], {}, (1000L, false)),
    ([], Json::string("<html>"), (1000L, false)),
    ([("retry-after", "3")], { "retry_after": "x" }, (3000L, false)),
    ([("x-ratelimit-global", "true")], { "retry_after": 1 }, (1000L, true)),
    // only the header marks a global limit
    ([], { "retry_after": 1, "global": true }, (1000L, false)),
  ]
  for case in cases {
    let (pairs, body, expected) = case
    assert_eq(rate_limit_from_json(headers_of(pairs), body), expected)
  }
}

///|
test "rate_limit_details reads a body that is not JSON as no body" {
  assert_eq(
    rate_limit_details(
      headers_of([("retry-after", "1")]),
      @utf8.encode("<html>"),
    ),
    (1000L, false),
  )
  assert_eq(
    rate_limit_details(headers_of([]), @utf8.encode("{\"retry_after\":0.25}")),
    (250L, false),
  )
}

///|
test "DiscordRetry resends only a 429, after its delay plus one millisecond" {
  let request = @ghttp.Request::new("GET", "https://discord.test/api")
  let limited = @runtime.RateLimited(
    retry_after_ms=None,
    headers=headers_of([]),
    body=@utf8.encode("{\"retry_after\":1.5}"),
  )
  let cases : Array[(Int32, @runtime.SdkError, Int32, Int32?)] = [
    (1, limited, 0, Some(1501)),
    (1, limited, 1, None),
    (0, limited, 0, None),
    // the runtime's own retry_after_ms is not consulted
    (
      1,
      @runtime.RateLimited(
        retry_after_ms=Some(9),
        headers=headers_of([("retry-after", "2")]),
        body=b"",
      ),
      0,
      Some(2001),
    ),
    (1, @runtime.Status(status=500, headers=headers_of([]), body=b""), 0, None),
    (1, @runtime.Transport(@ghttp.HttpError::Timeout(5)), 0, None),
  ]
  for case in cases {
    let (max_retries, error, attempt, expected) = case
    assert_eq(
      @runtime.RetryDecider::next_delay_ms(
        DiscordRetry::{ max_retries, },
        error,
        request,
        attempt,
        0.0,
      ),
      expected,
    )
  }
}
