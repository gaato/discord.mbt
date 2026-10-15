///|
/// Sliding-window log limiter for gateway commands: Discord allows 120 sends
/// per 60 seconds per connection; a few slots are reserved for heartbeats
/// (which bypass this limiter), so user commands default to 115.
pub struct CommandLimiter {
  priv timestamps : Array[Int64]
  priv limit : Int32
  priv window_ms : Int64
  priv sleeper_ : async (Int32) -> Unit
}

///|
/// Create a limiter allowing `limit` sends per sliding window (60 seconds by default).
pub fn CommandLimiter::CommandLimiter(
  limit~ : Int32 = 115,
  window_ms~ : Int32 = 60000,
  sleeper~ : async (Int32) -> Unit = ms => @async.sleep(ms),
) -> CommandLimiter {
  { timestamps: [], limit, window_ms: window_ms.to_int64(), sleeper_: sleeper, }
}

///|
/// Wait until a send slot is available within the window, then consume it.
pub async fn CommandLimiter::acquire(self : CommandLimiter) -> Unit {
  self.wait_for_slot()
  self.record()
}

///|
// Callers must serialize waiting, sending, and recording to avoid oversubscription.
async fn CommandLimiter::wait_for_slot(self : CommandLimiter) -> Unit {
  for ;; {
    let now = @clock.now_ms()
    while self.timestamps.length() > 0 &&
          now - self.timestamps[0] >= self.window_ms {
      self.timestamps.remove(0) |> ignore
    }
    if self.timestamps.length() < self.limit {
      break
    }
    let wait = self.timestamps[0] + self.window_ms - now
    (self.sleeper_)(wait.to_int() + 1)
  }
}

///|
fn CommandLimiter::record(self : CommandLimiter) -> Unit {
  self.timestamps.push(@clock.now_ms())
}
