///|
async test "unknown bucket admits immediately" {
  let limiter = @ratelimit.InMemoryRateLimiter::new()
  let start = @async.now()
  limiter.acquire("GET:/channels/1/messages", global_exempt=false)
  limiter.release("GET:/channels/1/messages", status=200, headers={})
  assert_true(@async.now() - start < 100L)
}

///|
async test "exhausted bucket waits for reset-after" {
  let limiter = @ratelimit.InMemoryRateLimiter::new()
  let key = "POST:/channels/1/messages"
  limiter.acquire(key, global_exempt=false)
  limiter.release(key, status=200, headers={
    "x-ratelimit-remaining": "0",
    "x-ratelimit-reset-after": "0.08",
  })
  let start = @async.now()
  limiter.acquire(key, global_exempt=false)
  let waited = @async.now() - start
  limiter.release(key, status=200, headers={
    "x-ratelimit-remaining": "4",
    "x-ratelimit-reset-after": "60",
  })
  assert_true(waited >= 60L)
}

///|
async test "remaining budget admits without waiting" {
  let limiter = @ratelimit.InMemoryRateLimiter::new()
  let key = "POST:/channels/2/messages"
  limiter.acquire(key, global_exempt=false)
  limiter.release(key, status=200, headers={
    "x-ratelimit-remaining": "3",
    "x-ratelimit-reset-after": "60",
  })
  let start = @async.now()
  limiter.acquire(key, global_exempt=false)
  limiter.release(key, status=200, headers={})
  assert_true(@async.now() - start < 100L)
}

///|
async test "global 429 blocks subsequent requests until retry-after" {
  let limiter = @ratelimit.InMemoryRateLimiter::new()
  let key = "GET:/users/@me"
  limiter.acquire(key, global_exempt=false)
  limiter.release(key, status=429, headers={
    "x-ratelimit-global": "true",
    "retry-after": "0.08",
  })
  let start = @async.now()
  limiter.acquire("GET:/gateway", global_exempt=false)
  let waited = @async.now() - start
  limiter.release("GET:/gateway", status=200, headers={})
  assert_true(waited >= 60L)
}

///|
async test "route 429 exhausts only its bucket" {
  let limiter = @ratelimit.InMemoryRateLimiter::new()
  let key = "POST:/channels/3/messages"
  limiter.acquire(key, global_exempt=false)
  limiter.release(key, status=429, headers={ "retry-after": "0.08" })
  // a different bucket is unaffected
  let start = @async.now()
  limiter.acquire("POST:/channels/4/messages", global_exempt=false)
  limiter.release("POST:/channels/4/messages", status=200, headers={})
  assert_true(@async.now() - start < 100L)
  // the same bucket waits
  let start2 = @async.now()
  limiter.acquire(key, global_exempt=false)
  let waited = @async.now() - start2
  limiter.release(key, status=200, headers={})
  assert_true(waited >= 60L)
}
