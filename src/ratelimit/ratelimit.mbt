///|
/// REST rate limiting strategy.
///
/// The design is requester-driven: `acquire` blocks (asynchronously) in the
/// calling task until the request may proceed, and `release` must be called
/// exactly once per successful `acquire`, with the response's rate-limit
/// headers when available. There is no background actor task, so a cancelled
/// caller cleans up naturally.
///
/// Implementations other than `InMemoryRateLimiter` (e.g. a cross-process
/// store) can be plugged into the HTTP client via this trait.
pub(open) trait RateLimiter {
  /// Wait until a request for `bucket_key` may be sent. `bucket_key` is the
  /// client's route-level bucket (method + path template + major parameter).
  /// `global_exempt` skips the global request-per-second limit (interaction
  /// and webhook endpoints are exempt per Discord's documentation).
  async fn acquire(Self, bucket_key : String, global_exempt~ : Bool) -> Unit

  /// Report the outcome of the request admitted by the matching `acquire`.
  /// `headers` must have lowercase header names; pass an empty map when the
  /// request failed before a response arrived (`status=0`).
  async fn release(
    Self,
    bucket_key : String,
    status~ : Int,
    headers~ : Map[String, String],
  ) -> Unit
}

///|
priv struct Bucket {
  /// Serializes requests within one bucket: held from admission until the
  /// response headers are reported. This keeps bucket accounting exact at the
  /// cost of per-bucket sequencing (different major parameters get different
  /// buckets, so cross-channel/guild parallelism is preserved).
  gate : @async.Semaphore
  mut known : Bool
  mut remaining : Int
  mut reset_at_ms : Int64
}

///|
/// In-process `RateLimiter`: per-bucket accounting learned from response
/// headers plus a global sliding-window limit (default 50 requests/second).
pub struct InMemoryRateLimiter {
  priv buckets : Map[String, Bucket]
  global_limit : Int
  mut global_window_start : Int64
  mut global_count : Int
  mut global_blocked_until : Int64
}

///|
/// Create a limiter with empty bucket accounting and a global window of
/// `global_limit` requests per second.
pub fn InMemoryRateLimiter::InMemoryRateLimiter(
  global_limit? : Int = 50,
) -> InMemoryRateLimiter {
  {
    buckets: Map([]),
    global_limit,
    global_window_start: 0,
    global_count: 0,
    global_blocked_until: 0,
  }
}

///|
async fn InMemoryRateLimiter::wait_for_global(
  self : InMemoryRateLimiter,
) -> Unit {
  for ;; {
    let now = @clock.now_ms()
    if now < self.global_blocked_until {
      @async.sleep((self.global_blocked_until - now).to_int() + 1)
      continue
    }
    if now - self.global_window_start >= 1000L {
      self.global_window_start = now
      self.global_count = 0
    }
    if self.global_count < self.global_limit {
      self.global_count += 1
      break
    }
    let wait = self.global_window_start + 1000L - now
    @async.sleep(wait.to_int() + 1)
  }
}

///|
/// Wait for bucket capacity — and the global window unless `global_exempt` —
/// before the request is sent.
pub impl RateLimiter for InMemoryRateLimiter with fn acquire(
  self,
  bucket_key,
  global_exempt~,
) {
  if !global_exempt {
    self.wait_for_global()
  }
  let bucket = match self.buckets.get(bucket_key) {
    Some(b) => b
    None => {
      let b : Bucket = {
        gate: Semaphore(1),
        known: false,
        remaining: 0,
        reset_at_ms: 0,
      }
      self.buckets[bucket_key] = b
      b
    }
  }
  bucket.gate.acquire()
  // From here on the gate is held; make sure a cancellation while waiting
  // for the bucket reset releases it.
  try {
    if bucket.known && bucket.remaining <= 0 {
      let wait = bucket.reset_at_ms - @clock.now_ms()
      if wait > 0 {
        @async.sleep(wait.to_int() + 1)
      }
      // optimistic: the window has reset; the next response corrects us
      bucket.remaining = 1
    }
  } catch {
    e => {
      bucket.gate.release()
      raise e
    }
  }
}

///|
/// Feed the response's `x-ratelimit-*` headers back into the bucket
/// accounting.
pub impl RateLimiter for InMemoryRateLimiter with fn release(
  self,
  bucket_key,
  status~,
  headers~,
) {
  guard self.buckets.get(bucket_key) is Some(bucket) else { return }
  if headers.get("x-ratelimit-remaining") is Some(remaining_s) {
    bucket.remaining = @string.parse_int(remaining_s) catch { _ => 0 }
    bucket.known = true
  }
  // Prefer the relative reset to be robust against wall-clock jumps.
  if headers.get("x-ratelimit-reset-after") is Some(after_s) {
    let after = @string.parse_double(after_s) catch { _ => 0.0 }
    bucket.reset_at_ms = @clock.now_ms() + (after * 1000.0).to_int64()
  }
  if status == 429 {
    let retry_after_ms = match headers.get("retry-after") {
      Some(s) => {
        let seconds = @string.parse_double(s) catch { _ => 1.0 }
        (seconds * 1000.0).to_int64()
      }
      None => 1000L
    }
    if headers.get("x-ratelimit-global") is Some(_) {
      self.global_blocked_until = @clock.now_ms() + retry_after_ms
    } else {
      bucket.known = true
      bucket.remaining = 0
      bucket.reset_at_ms = @clock.now_ms() + retry_after_ms
    }
  }
  bucket.gate.release()
}
