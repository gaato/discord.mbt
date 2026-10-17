///|
async test "command limiter waits out the sliding window when full" {
  let clock = @simclock.VirtualClock(start_ms=0)
  let limiter = CommandLimiter(limit=1, clock~)
  @async.with_task_group(group => {
    limiter.acquire()
    clock.advance(1000)
    let second = group.spawn(() => limiter.acquire())
    clock.settle()
    // the oldest send leaves the 60 s window at 60000, plus the 1 ms nudge
    assert_eq(clock.pending(), [59001])
    clock.advance(59001)
    second.wait()
    // the expired slot was pruned and the new send took its place
    assert_eq(limiter.timestamps, [60001L])
  })
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
  let clock = @simclock.VirtualClock()
  @async.with_task_group(group => {
    let shard = Shard::start(
      group,
      token="test-token",
      intents=@model.Intents::none(),
      clock~,
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
        written_at.val = clock.now_unix_ms()
      },
    }
    shard.transport = Some(transport)
    // Hold the writer gate so a presence waiting to write cannot record a slot.
    shard.send_gate.acquire()
    let update = group.spawn(no_wait=true, () => {
      shard.update_presence(@model.UpdatePresence(status=Online))
    })
    clock.settle()
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
  let clock = @simclock.VirtualClock(start_ms=0)
  @async.with_task_group(group => {
    let shard = Shard::start(
      group,
      token="test-token",
      intents=@model.Intents::none(),
      presence=@model.UpdatePresence(status=Idle),
      clock~,
      connector=_ => {
        @async.sleep(3600000)
        raise TransportClosed(code=None, reason="test ended")
      },
    )
    let transport = PresenceTestTransport::{ sent: [], before_send: () => (), }
    shard.transport = Some(transport)
    for _ in 0..<5 {
      shard.update_presence(@model.UpdatePresence(status=Online))
    }
    let sixth = group.spawn(() => {
      shard.update_presence(@model.UpdatePresence(status=Idle))
    })
    clock.settle()
    assert_eq(clock.pending(), [20001])
    assert_eq(transport.sent.length(), 5)
    clock.advance(20001)
    sixth.wait()
    assert_eq(transport.sent.length(), 6)
    assert_eq(shard.command_limiter.timestamps.length(), 6)
    assert_eq(shard.presence_limiter.timestamps.length(), 1)
    shard.close()
  })
}

///|
async test "concurrent presence updates wait for general slots before presence slots" {
  let clock = @simclock.VirtualClock(start_ms=0)
  @async.with_task_group(group => {
    let shard = Shard::start(
      group,
      token="test-token",
      intents=@model.Intents::none(),
      clock~,
      connector=_ => {
        @async.sleep(3600000)
        raise TransportClosed(code=None, reason="test ended")
      },
    )
    let transport = PresenceTestTransport::{ sent: [], before_send: () => (), }
    shard.transport = Some(transport)
    for _ in 0..<115 {
      shard.command_limiter.acquire()
    }
    let updates = Array::makei(6, _ => {
      group.spawn(() => {
        shard.update_presence(@model.UpdatePresence(status=Online))
      })
    })
    clock.settle()
    // one update waits for a general slot without holding a presence slot
    assert_eq(clock.pending(), [60001])
    assert_eq(shard.presence_limiter.timestamps.length(), 0)
    clock.advance(60001)
    // five went out; the sixth holds a general slot and waits for presence
    assert_eq(clock.pending(), [20001])
    assert_eq(shard.command_limiter.timestamps.length(), 6)
    assert_eq(shard.presence_limiter.timestamps.length(), 5)
    clock.advance(20001)
    for update in updates {
      update.wait()
    }
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
