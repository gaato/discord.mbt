///|
/// Sliding-window log limiter for gateway commands: Discord allows 120 sends
/// per 60 seconds per connection; a few slots are reserved for heartbeats
/// (which bypass this limiter), so user commands default to 115.
pub struct CommandLimiter {
  priv timestamps : Array[Int64]
  priv limit : Int
}

///|
pub fn CommandLimiter::new(limit? : Int = 115) -> CommandLimiter {
  { timestamps: [], limit }
}

///|
pub async fn CommandLimiter::acquire(self : CommandLimiter) -> Unit {
  for ;; {
    let now = @async.now()
    while self.timestamps.length() > 0 && now - self.timestamps[0] >= 60000L {
      self.timestamps.remove(0) |> ignore
    }
    if self.timestamps.length() < self.limit {
      self.timestamps.push(now)
      break
    }
    let wait = self.timestamps[0] + 60000L - now
    @async.sleep(wait.to_int() + 1)
  }
}
