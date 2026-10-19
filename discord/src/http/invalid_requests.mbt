///|
/// The step `InvalidRequests` moves its window in.
const INVALID_SLOT_MS : Int64 = 10_000

///|
/// How many steps the window spans: ten minutes, Discord's window for
/// invalid requests.
const INVALID_SLOTS : Int32 = 60

///|
/// A rolling count of the invalid requests one client received, for
/// Discord's limit of 10,000 per ten minutes, past which Discord restricts
/// the address for a while. The window moves in ten-second steps, so a request
/// leaves the count between 590 and 600 seconds after it was answered.
///
/// It is a fixed ring of `INVALID_SLOTS` counters, each labelled with the
/// step it counts; a counter whose step has left the window is reset when
/// the ring comes back to it, so the memory never grows.
priv struct InvalidRequests {
  // The step (time / INVALID_SLOT_MS) each counter counts, or Int64 min for
  // none yet.
  steps : FixedArray[Int64]
  counts : FixedArray[Int32]
}

///|
fn InvalidRequests::new() -> InvalidRequests {
  {
    steps: FixedArray::make(INVALID_SLOTS, -9223372036854775808L),
    counts: FixedArray::make(INVALID_SLOTS, 0),
  }
}

///|
/// The step that `now_unix_ms` falls in, rounding down.
fn invalid_step(now_unix_ms : Int64) -> Int64 {
  let step = now_unix_ms / INVALID_SLOT_MS
  if now_unix_ms < 0L && step * INVALID_SLOT_MS != now_unix_ms {
    step - 1L
  } else {
    step
  }
}

///|
/// The ring index of `step`.
fn invalid_slot(step : Int64) -> Int32 {
  let slot = (step % INVALID_SLOTS.to_int64()).to_int()
  if slot < 0 {
    slot + INVALID_SLOTS
  } else {
    slot
  }
}

///|
/// Counts one invalid request answered at `now_unix_ms`.
fn InvalidRequests::record(self : InvalidRequests, now_unix_ms : Int64) -> Unit {
  let step = invalid_step(now_unix_ms)
  let slot = invalid_slot(step)
  if self.steps[slot] != step {
    self.steps[slot] = step
    self.counts[slot] = 0
  }
  self.counts[slot] += 1
}

///|
/// The invalid requests answered in the window that ends at `now_unix_ms`.
fn InvalidRequests::count(self : InvalidRequests, now_unix_ms : Int64) -> Int32 {
  let step = invalid_step(now_unix_ms)
  let oldest = step - INVALID_SLOTS.to_int64()
  let mut total = 0
  for slot in 0..<INVALID_SLOTS {
    let counted = self.steps[slot]
    if counted > oldest && counted <= step {
      total += self.counts[slot]
    }
  }
  total
}

///|
/// Whether Discord counts a response with `status` and `headers` as an
/// invalid request: a 401, a 403, or a 429 other than one with
/// `X-RateLimit-Scope: shared`, which Discord says it does not count.
fn is_invalid_request(status : Int32, headers : @ghttp.Headers) -> Bool {
  match status {
    401 | 403 => true
    429 =>
      headers.get("x-ratelimit-scope").map(value => value.trim().to_lower()) !=
      Some("shared")
    _ => false
  }
}
