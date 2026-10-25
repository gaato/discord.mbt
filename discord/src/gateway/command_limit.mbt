///|
/// Sliding-window log limiter for gateway commands: Discord allows 120 sends
/// per 60 seconds per connection; a few slots are reserved for heartbeats
/// (which bypass this limiter), so user commands default to 115.
pub struct CommandLimiter {
  priv timestamps : Array[Int64]
  priv limit : Int32
  priv window_ms : Int64
  priv clock_ : &@hclock.Clock
}

///|
/// Create a limiter allowing `limit` sends per sliding window (60 seconds by default).
pub fn CommandLimiter::CommandLimiter(
  limit~ : Int32 = 115,
  window_ms~ : Int32 = 60000,
  clock~ : &@hclock.Clock = @netruntime.AsyncClock::new(),
) -> CommandLimiter {
  { timestamps: [], limit, window_ms: window_ms.to_int64(), clock_: clock, }
}

///|
/// Wait until a send slot is available within the window, then consume it.
pub async fn CommandLimiter::acquire(self : CommandLimiter) -> Unit {
  self.wait_for_slot()
  self.record()
}

///|
/// Drop timestamps that left the window at `now`, then return how long to wait
/// for a free slot: `None` when one is free, otherwise until the oldest send
/// leaves the window, plus a 1 ms nudge.
fn CommandLimiter::slot_wait_ms(self : CommandLimiter, now : Int64) -> Int32? {
  while self.timestamps.length() > 0 &&
        now - self.timestamps[0] >= self.window_ms {
    self.timestamps.remove(0) |> ignore
  }
  if self.timestamps.length() < self.limit {
    None
  } else {
    Some((self.timestamps[0] + self.window_ms - now).to_int() + 1)
  }
}

///|
// Callers must serialize waiting, sending, and recording to avoid oversubscription.
async fn CommandLimiter::wait_for_slot(self : CommandLimiter) -> Unit {
  while self.slot_wait_ms(self.clock_.now_unix_ms()) is Some(ms) {
    self.clock_.sleep(ms)
  }
}

///|
fn CommandLimiter::record(self : CommandLimiter) -> Unit {
  self.timestamps.push(self.clock_.now_unix_ms())
}
