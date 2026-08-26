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
      error if @async.is_cancellation_error(error) => ()
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
