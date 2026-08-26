///|
async test "command limiter waits out the sliding window when full" {
  let waits : Array[Int] = []
  let holder : Ref[CommandLimiter?] = Ref(None)
  let limiter = CommandLimiter(limit=1, sleeper=ms => {
    waits.push(ms)
    guard! holder.val is Some(limiter)
    // simulate the window passing while asleep
    limiter.timestamps[0] = limiter.timestamps[0] - 61000L
  })
  holder.val = Some(limiter)
  limiter.acquire()
  assert_eq(waits.length(), 0)
  limiter.acquire()
  assert_eq(waits.length(), 1)
  // wait = oldest timestamp + 60s window - now, plus the 1ms nudge
  assert_true(waits[0] >= 1 && waits[0] <= 60001)
  // the expired slot was pruned and the new send took its place
  assert_eq(limiter.timestamps.length(), 1)
}
