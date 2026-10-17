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
  before_send : () -> Unit raise
}

///|
impl GatewayTransport for PresenceTestTransport with fn recv(_self) {
  @async.sleep(3600000)
  raise TransportClosed(code=None, reason="test ended")
}

///|
impl GatewayTransport for PresenceTestTransport with fn send(self, text) {
  (self.before_send)()
  self.sent.push(text)
}

///|
async test "presence records only after a successful write" {
  @async.with_task_group(group => {
    let shard = Shard::start(
      group,
      token="test-token",
      intents=@model.Intents::none(),
      connector=_ => {
        @async.sleep(3600000)
        raise TransportClosed(code=None, reason="test ended")
      },
    )
    let fail_write = Ref(false)
    let written_at = Ref(0L)
    let transport = PresenceTestTransport::{
      sent: [],
      before_send: () => {
        assert_eq(shard.presence_limiter.timestamps.length(), 0)
        if fail_write.val {
          raise TransportClosed(code=Some(4000), reason="write failed")
        }
        written_at.val = @clock.now_ms()
      },
    }
    shard.transport = Some(transport)
    // Hold the writer gate so a presence waiting to write cannot record a slot.
    shard.send_gate.acquire()
    let update = group.spawn(no_wait=true, () => {
      shard.update_presence(@model.UpdatePresence(status=Online))
    })
    @async.sleep(1)
    assert_eq(shard.presence_limiter.timestamps.length(), 0)
    shard.send_gate.release()
    update.wait()
    assert_eq(transport.sent.length(), 1)
    assert_eq(shard.presence_limiter.timestamps.length(), 1)
    assert_true(shard.presence_limiter.timestamps[0] >= written_at.val)
    shard.presence_limiter.timestamps.clear()
    fail_write.val = true
    try shard.update_presence(@model.UpdatePresence(status=Idle)) catch {
      TransportClosed(code=Some(4000), reason="write failed") => ()
      error => fail("unexpected error: \{error}")
    } noraise {
      _ => fail("expected write failure")
    }
    assert_eq(shard.presence_limiter.timestamps.length(), 0)
    assert_eq(transport.sent.length(), 1)
    // General command slots are still consumed even for failed writes.
    assert_eq(shard.command_limiter.timestamps.length(), 2)
    shard.close()
  })
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
    let transport = PresenceTestTransport::{ sent: [], before_send: () => (), }
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

///|
async test "concurrent presence updates wait for general slots before presence slots" {
  let general_waits = Ref(0)
  let presence_waits = Ref(0)
  let holder : Ref[Shard?] = Ref(None)
  @async.with_task_group(group => {
    let shard = Shard::start(
      group,
      token="test-token",
      intents=@model.Intents::none(),
      connector=_ => {
        @async.sleep(3600000)
        raise TransportClosed(code=None, reason="test ended")
      },
      sleeper=ms => {
        guard! holder.val is Some(shard)
        if ms > 20001 {
          general_waits.val += 1
          assert_eq(shard.presence_limiter.timestamps.length(), 0)
          // Let the other presence tasks contend for the presence gate.
          @async.sleep(1)
          assert_eq(shard.presence_limiter.timestamps.length(), 0)
          for index in 0..<shard.command_limiter.timestamps.length() {
            shard.command_limiter.timestamps[index] -= 60001L
          }
        } else {
          presence_waits.val += 1
          assert_eq(shard.command_limiter.timestamps.length(), 6)
          assert_eq(shard.presence_limiter.timestamps.length(), 5)
          for index in 0..<shard.presence_limiter.timestamps.length() {
            shard.presence_limiter.timestamps[index] -= 20001L
          }
        }
      },
    )
    holder.val = Some(shard)
    let transport = PresenceTestTransport::{ sent: [], before_send: () => (), }
    shard.transport = Some(transport)
    for _ in 0..<115 {
      shard.command_limiter.acquire()
    }
    @async.with_task_group(updates => {
      let tasks = []
      for _ in 0..<6 {
        tasks.push(
          updates.spawn(no_wait=true, () => {
            shard.update_presence(@model.UpdatePresence(status=Online))
          }),
        )
      }
      for task in tasks {
        task.wait()
      }
    })
    assert_eq(general_waits.val, 1)
    assert_eq(presence_waits.val, 1)
    assert_eq(transport.sent.length(), 6)
    shard.close()
  })
}

///|
test "slot_wait_ms prunes the window and waits for the oldest send" {
  let limiter = CommandLimiter(limit=2, window_ms=1000)
  assert_eq(limiter.slot_wait_ms(100), None)
  limiter.timestamps.append([0L, 50L])
  // full: the oldest send leaves the window at 1000, plus the 1 ms nudge
  assert_eq(limiter.slot_wait_ms(100), Some(901))
  // a send exactly one window old has left it
  assert_eq(limiter.slot_wait_ms(1000), None)
  assert_eq(limiter.timestamps, [50L])
  limiter.timestamps.push(1000L)
  assert_eq(limiter.slot_wait_ms(1049), Some(2))
  // partial prune: only the expired send goes
  assert_eq(limiter.slot_wait_ms(1050), None)
  assert_eq(limiter.timestamps, [1000L])
}
