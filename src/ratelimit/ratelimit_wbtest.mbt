///|
async fn wait_until_rate_limit_gate_is_held(bucket : Bucket) -> Unit {
  for _ in 0..<100 {
    if !bucket.gate.try_acquire() {
      return
    }
    bucket.gate.release()
    @async.sleep(1)
  }
  fail("rate-limit waiter did not acquire its bucket gate")
}

///|
async test "a cancelled bucket reset wait releases its gate" {
  let limiter = InMemoryRateLimiter()
  let key = "POST:/channels/5/messages"
  RateLimiter::acquire(limiter, key, global_exempt=true)
  RateLimiter::release(limiter, key, status=200, headers={
    "x-ratelimit-remaining": "0",
    "x-ratelimit-reset-after": "60",
  })
  guard limiter.buckets.get(key) is Some(bucket) else {
    fail("rate-limit bucket was not created")
  }
  @async.with_task_group(group => {
    let waiting = group.spawn(no_wait=true, allow_failure=true, () => {
      RateLimiter::acquire(limiter, key, global_exempt=true)
    })
    wait_until_rate_limit_gate_is_held(bucket)
    waiting.cancel()
    try waiting.wait() catch {
      @async.TaskCancelled => ()
      error => fail("unexpected cancellation error: \{Repr(error)}")
    } noraise {
      _ => fail("cancelled rate-limit wait unexpectedly completed")
    }

    assert_eq(bucket.remaining, 0)
    assert_true(bucket.gate.try_acquire())
    bucket.gate.release()
    bucket.reset_at_ms = 0
    @async.with_timeout(100, () => {
      RateLimiter::acquire(limiter, key, global_exempt=true)
    })
    RateLimiter::release(limiter, key, status=200, headers=Map([]))
  })
}

///|
async test "a shorter global 429 never shortens an existing block" {
  let limiter = InMemoryRateLimiter()
  let key = "POST:/channels/global/messages"
  RateLimiter::acquire(limiter, key, global_exempt=true)
  RateLimiter::release(limiter, key, status=429, headers={
    "x-ratelimit-global": "true",
    "retry-after": "60",
  })
  let first_deadline = limiter.global_blocked_until
  guard limiter.buckets.get(key) is Some(bucket) else {
    fail("rate-limit bucket was not created")
  }
  bucket.gate.acquire()
  RateLimiter::release(limiter, key, status=429, headers={
    "x-ratelimit-global": "true",
    "retry-after": "1",
  })
  assert_true(limiter.global_blocked_until >= first_deadline)
}

///|
async test "a 429 without retry-after blocks its bucket for one second" {
  let limiter = InMemoryRateLimiter()
  let key = "POST:/channels/6/messages"
  RateLimiter::acquire(limiter, key, global_exempt=true)
  let before = @clock.now_ms()
  RateLimiter::release(limiter, key, status=429, headers=Map([]))
  guard limiter.buckets.get(key) is Some(bucket) else {
    fail("rate-limit bucket was not created")
  }
  assert_eq(bucket.remaining, 0)
  let reset_in = bucket.reset_at_ms - before
  assert_true(reset_in >= 1000L && reset_in <= 1100L)
}
