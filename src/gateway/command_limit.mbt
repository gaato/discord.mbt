///|
/// Sliding-window log limiter for gateway commands: Discord allows 120 sends
/// per 60 seconds per connection; a few slots are reserved for heartbeats
/// (which bypass this limiter), so user commands default to 115.
pub struct CommandLimiter {
  priv timestamps : Array[Int64]
  priv limit : Int
  priv sleeper_ : async (Int) -> Unit
}

///|
/// Create a limiter allowing `limit` sends per 60-second sliding window.
pub fn CommandLimiter::CommandLimiter(
  limit? : Int = 115,
  sleeper? : async (Int) -> Unit = ms => @async.sleep(ms),
) -> CommandLimiter {
  { timestamps: [], limit, sleeper_: sleeper, }
}

///|
/// Wait until a send slot is available within the window, then consume it.
pub async fn CommandLimiter::acquire(self : CommandLimiter) -> Unit {
  for ;; {
    let now = @clock.now_ms()
    while self.timestamps.length() > 0 && now - self.timestamps[0] >= 60000L {
      self.timestamps.remove(0) |> ignore
    }
    if self.timestamps.length() < self.limit {
      self.timestamps.push(now)
      break
    }
    let wait = self.timestamps[0] + 60000L - now
    (self.sleeper_)(wait.to_int() + 1)
  }
}
