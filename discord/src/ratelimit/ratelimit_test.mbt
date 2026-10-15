///|
async test "unknown bucket admits immediately" {
  let clock = @mock.FakeClock::new()
  let limiter = @ratelimit.rate_limiter(clock~)
  limiter.acquire("unknown", global_exempt=false)
  limiter.release("unknown", status=200, headers=@http.Headers::new())
  assert_eq(clock.slept(), [])
}

///|
async test "exhausted bucket waits 1500 ms for Discord reset-after" {
  let clock = @mock.FakeClock::new()
  let limiter = @ratelimit.rate_limiter(clock~)
  limiter.acquire("bucket", global_exempt=false)
  limiter.release(
    "bucket",
    status=200,
    headers=@http.Headers::from_array([
      ("x-ratelimit-remaining", "0"),
      ("x-ratelimit-reset-after", "1.5"),
    ]),
  )
  limiter.acquire("bucket", global_exempt=false)
  limiter.release("bucket", status=200, headers=@http.Headers::new())
  assert_eq(clock.slept(), [1500])
}

///|
async test "remaining budget admits without waiting" {
  let clock = @mock.FakeClock::new()
  let limiter = @ratelimit.rate_limiter(clock~)
  limiter.acquire("bucket", global_exempt=false)
  limiter.release(
    "bucket",
    status=200,
    headers=@http.Headers::from_array([
      ("x-ratelimit-remaining", "3"),
      ("x-ratelimit-reset-after", "60"),
    ]),
  )
  limiter.acquire("bucket", global_exempt=false)
  limiter.release("bucket", status=200, headers=@http.Headers::new())
  assert_eq(clock.slept(), [])
}

///|
async test "global 429 blocks another bucket but exempts interaction routes" {
  let clock = @mock.FakeClock::new()
  let limiter = @ratelimit.rate_limiter(clock~)
  limiter.acquire("bucket", global_exempt=false)
  limiter.release(
    "bucket",
    status=429,
    headers=@http.Headers::from_array([
      ("x-ratelimit-global", "true"),
      ("retry-after", "1.5"),
    ]),
  )
  limiter.acquire("interaction", global_exempt=true)
  limiter.release("interaction", status=200, headers=@http.Headers::new())
  assert_eq(clock.slept(), [])
  limiter.acquire("other", global_exempt=false)
  limiter.release("other", status=200, headers=@http.Headers::new())
  assert_eq(clock.slept(), [1500])
}

///|
async test "route 429 exhausts only its bucket" {
  let clock = @mock.FakeClock::new()
  let limiter = @ratelimit.rate_limiter(clock~)
  limiter.acquire("bucket", global_exempt=false)
  limiter.release(
    "bucket",
    status=429,
    headers=@http.Headers::from_array([("retry-after", "0.08")]),
  )
  limiter.acquire("other", global_exempt=false)
  limiter.release("other", status=200, headers=@http.Headers::new())
  assert_eq(clock.slept(), [])
  limiter.acquire("bucket", global_exempt=false)
  limiter.release("bucket", status=200, headers=@http.Headers::new())
  assert_eq(clock.slept(), [80])
}

///|
async test "a 429 without Retry-After waits one second on its bucket" {
  let clock = @mock.FakeClock::new()
  let limiter = @ratelimit.rate_limiter(clock~)
  limiter.acquire("bucket", global_exempt=true)
  limiter.release("bucket", status=429, headers=@http.Headers::new())
  limiter.acquire("bucket", global_exempt=true)
  limiter.release("bucket", status=200, headers=@http.Headers::new())
  assert_eq(clock.slept(), [1000])
}

///|
async test "the default global window delays the 51st non-exempt acquire" {
  let clock = @mock.FakeClock::new()
  let limiter = @ratelimit.rate_limiter(clock~)
  for _ in 0..<50 {
    limiter.acquire("bucket", global_exempt=false)
    limiter.release("bucket", status=200, headers=@http.Headers::new())
  }
  limiter.acquire("interaction", global_exempt=true)
  limiter.release("interaction", status=200, headers=@http.Headers::new())
  assert_eq(clock.slept(), [])
  limiter.acquire("bucket", global_exempt=false)
  limiter.release("bucket", status=200, headers=@http.Headers::new())
  assert_eq(clock.slept(), [1000])
}
