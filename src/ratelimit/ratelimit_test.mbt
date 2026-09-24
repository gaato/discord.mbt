///|
async test "unknown bucket admits immediately" {
  let limiter = @ratelimit.InMemoryRateLimiter()
  let start = @clock.now_ms()
  limiter.acquire("GET:/channels/1/messages", global_exempt=false)
  limiter.release(
    "GET:/channels/1/messages",
    status=200,
    headers=@http.Headers::new(),
  )
  assert_true(@clock.now_ms() - start < 100L)
}

///|
async test "exhausted bucket waits for reset-after" {
  let limiter = @ratelimit.InMemoryRateLimiter()
  let key = "POST:/channels/1/messages"
  limiter.acquire(key, global_exempt=false)
  limiter.release(
    key,
    status=200,
    headers=@http.Headers::from_array([
      ("x-ratelimit-remaining", "0"),
      ("x-ratelimit-reset-after", "0.08"),
    ]),
  )
  let start = @clock.now_ms()
  limiter.acquire(key, global_exempt=false)
  let waited = @clock.now_ms() - start
  limiter.release(
    key,
    status=200,
    headers=@http.Headers::from_array([
      ("x-ratelimit-remaining", "4"),
      ("x-ratelimit-reset-after", "60"),
    ]),
  )
  assert_true(waited >= 60L)
}

///|
async test "remaining budget admits without waiting" {
  let limiter = @ratelimit.InMemoryRateLimiter()
  let key = "POST:/channels/2/messages"
  limiter.acquire(key, global_exempt=false)
  limiter.release(
    key,
    status=200,
    headers=@http.Headers::from_array([
      ("x-ratelimit-remaining", "3"),
      ("x-ratelimit-reset-after", "60"),
    ]),
  )
  let start = @clock.now_ms()
  limiter.acquire(key, global_exempt=false)
  limiter.release(key, status=200, headers=@http.Headers::new())
  assert_true(@clock.now_ms() - start < 100L)
}

///|
async test "global 429 blocks subsequent requests until retry-after" {
  let limiter = @ratelimit.InMemoryRateLimiter()
  let key = "GET:/users/@me"
  limiter.acquire(key, global_exempt=false)
  limiter.release(
    key,
    status=429,
    headers=@http.Headers::from_array([
      ("x-ratelimit-global", "true"),
      ("retry-after", "0.08"),
    ]),
  )
  let start = @clock.now_ms()
  limiter.acquire("GET:/gateway", global_exempt=false)
  let waited = @clock.now_ms() - start
  limiter.release("GET:/gateway", status=200, headers=@http.Headers::new())
  assert_true(waited >= 60L)
}

///|
async test "route 429 exhausts only its bucket" {
  let limiter = @ratelimit.InMemoryRateLimiter()
  let key = "POST:/channels/3/messages"
  limiter.acquire(key, global_exempt=false)
  limiter.release(
    key,
    status=429,
    headers=@http.Headers::from_array([("retry-after", "0.08")]),
  )
  // a different bucket is unaffected
  let start = @clock.now_ms()
  limiter.acquire("POST:/channels/4/messages", global_exempt=false)
  limiter.release(
    "POST:/channels/4/messages",
    status=200,
    headers=@http.Headers::new(),
  )
  assert_true(@clock.now_ms() - start < 100L)
  // the same bucket waits
  let start2 = @clock.now_ms()
  limiter.acquire(key, global_exempt=false)
  let waited = @clock.now_ms() - start2
  limiter.release(key, status=200, headers=@http.Headers::new())
  assert_true(waited >= 60L)
}
