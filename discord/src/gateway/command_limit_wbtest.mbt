///|
async test "command limiter waits out the sliding window when full" {
  let waits : Array[Int32] = []
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

///|
struct PresenceTestTransport {
  sent : Array[String]
}

///|
impl GatewayTransport for PresenceTestTransport with fn recv(_self) {
  @async.sleep(3600000)
  raise TransportClosed(code=None, reason="test ended")
}

///|
impl GatewayTransport for PresenceTestTransport with fn send(self, text) {
  self.sent.push(text)
}

///|
impl GatewayTransport for PresenceTestTransport with fn close(_self, code~) {
  ignore(code)
}

///|
async test "presence allows five updates and waits on the sixth" {
  let waits : Array[Int32] = []
  let holder : Ref[Shard?] = Ref(None)
  @async.with_task_group(group => {
    let shard = Shard::start(
      group,
      token="test-token",
      intents=@model.Intents::none(),
      presence=@model.UpdatePresence(status=Idle),
      connector=_ => {
        @async.sleep(3600000)
        raise TransportClosed(code=None, reason="test ended")
      },
      sleeper=ms => {
        waits.push(ms)
        guard! holder.val is Some(shard)
        for index in 0..<shard.presence_limiter.timestamps.length() {
          shard.presence_limiter.timestamps[index] -= 20001L
        }
      },
    )
    holder.val = Some(shard)
    let transport = PresenceTestTransport::{ sent: [], }
    shard.transport = Some(transport)
    for _ in 0..<5 {
      shard.update_presence(@model.UpdatePresence(status=Online))
    }
    assert_eq(waits.length(), 0)
    shard.update_presence(@model.UpdatePresence(status=Idle))
    assert_eq(waits.length(), 1)
    assert_true(waits[0] >= 1 && waits[0] <= 20001)
    assert_eq(transport.sent.length(), 6)
    assert_eq(shard.command_limiter.timestamps.length(), 6)
    assert_eq(shard.presence_limiter.timestamps.length(), 1)
    shard.close()
  })
}
