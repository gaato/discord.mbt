///|
/// REST rate limiting through sdk-runtime's requester-driven `RateLimiter`
/// contract. Each completed acquire is paired with a release carrying response
/// headers, or status 0 when no response arrived. `rate_limiter()` configures
/// `WindowLimiter` for Discord; `coordinator` offers the cross-process
/// `RemoteRateLimiter` through the same contract.
///
/// Discord's REST rate limiter: per-bucket accounting from
/// `x-ratelimit-remaining` / `x-ratelimit-reset-after`, one request in flight
/// per bucket, a global window of `global_limit` requests per second (skipped
/// for interaction/webhook routes), a 429 carrying `x-ratelimit-global`
/// blocking every bucket, and one second of backoff for a 429 without Retry-After.
pub fn rate_limiter(
  global_limit~ : Int32 = 50,
  clock? : &@clock.Clock,
) -> @runtime.WindowLimiter {
  let clock : &@clock.Clock = match clock {
    Some(clock) => clock
    None => @transport.AsyncClock::new()
  }
  @runtime.WindowLimiter::new(
    clock,
    @runtime.rate_limit_headers(
      remaining="x-ratelimit-remaining",
      reset_after_seconds="x-ratelimit-reset-after",
    ),
    gate=() => @transport.SemaphoreGate::new(),
    global={ limit: global_limit, window_ms: 1000, },
    global_block=headers => headers.get("x-ratelimit-global") is Some(_),
    default_retry_after_ms=1000,
  )
}
