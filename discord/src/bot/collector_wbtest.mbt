///|
/// `GatewayCtx::wait_for` without a context: register, then wait.
async fn[T] EventCollector::wait_for(
  self : EventCollector,
  event_type : EventType[T],
  predicate : (T) -> Bool,
  timeout_ms? : Int32,
) -> T? {
  self.register(event_type, predicate).wait(timeout_ms?)
}

///|
fn message_delete_event(id : String) -> @model.Event raise {
  MessageDelete({
    id: @model.Id::parse(id),
    channel_id: @model.Id::parse("20"),
    guild_id: Some(@model.Id::parse("30")),
  })
}

///|
async fn wait_until_registered(
  collector : EventCollector,
  kind : @model.EventKind,
  count : Int32,
) -> Unit {
  @netruntime.VirtualClock().settle(until=() => {
    collector.waiters.filter(waiter => waiter.kind == kind).length() == count
  })
  let mut found = 0
  for waiter in collector.waiters {
    if waiter.kind == kind {
      found += 1
    }
  }
  assert_eq(found, count, msg="event collectors were not registered")
}

///|
async test "event collector applies predicates and resolves concurrent waiters" {
  let collector = EventCollector()
  @async.with_task_group(group => {
    let first = group.spawn(no_wait=true, () => {
      collector.wait_for(
        Events::message_delete(),
        event => event.id.to_string() == "101",
        timeout_ms=500,
      )
    })
    let second = group.spawn(no_wait=true, () => {
      collector.wait_for(
        Events::message_delete(),
        event => event.channel_id.to_string() == "20",
        timeout_ms=500,
      )
    })
    wait_until_registered(collector, KMessageDelete, 2)
    collector.dispatch(message_delete_event("100"))
    // Only the broad predicate resolves on the first event.
    guard second.wait() is Some(broad) else {
      fail("expected broad collector result")
    }
    inspect(broad.id.to_string(), content="100")
    assert_true(collector.waits_for(KMessageDelete))
    collector.dispatch(message_delete_event("101"))
    guard first.wait() is Some(exact) else {
      fail("expected exact collector result")
    }
    inspect(exact.id.to_string(), content="101")
    assert_false(collector.waits_for(KMessageDelete))
  })
}

///|
async test "one gateway event resolves every matching collector" {
  let collector = EventCollector()
  @async.with_task_group(group => {
    let first = group.spawn(no_wait=true, () => {
      collector.wait_for(Events::message_delete(), _ => true, timeout_ms=500)
    })
    let second = group.spawn(no_wait=true, () => {
      collector.wait_for(Events::message_delete(), _ => true, timeout_ms=500)
    })
    wait_until_registered(collector, KMessageDelete, 2)
    collector.dispatch(message_delete_event("200"))
    assert_true(first.wait() is Some(_))
    assert_true(second.wait() is Some(_))
    assert_false(collector.waits_for(KMessageDelete))
  })
}

///|
async test "event collector timeout and cancellation remove registrations" {
  let clock = @netruntime.VirtualClock()
  let collector = EventCollector(clock=Ref(clock))
  @async.with_task_group(group => {
    let timing_out = group.spawn(() => {
      collector.wait_for(Events::message_delete(), _ => true, timeout_ms=10)
    })
    clock.settle(until=() => clock.pending() == [10])
    clock.advance(9)
    assert_true(collector.waits_for(KMessageDelete))
    clock.advance(1)
    assert_true(timing_out.wait() is None)
  })
  assert_false(collector.waits_for(KMessageDelete))
  @async.with_task_group(group => {
    let pending = group.spawn(no_wait=true, allow_failure=true, () => {
      collector.wait_for(Events::message_delete(), _ => true)
    })
    wait_until_registered(collector, KMessageDelete, 1)
    pending.cancel()
    try pending.wait() catch {
      @async.WaitedTaskAlreadyCancelled => ()
      error => fail("unexpected cancellation error: \{Repr(error)}")
    } noraise {
      _ => fail("cancelled collector unexpectedly completed")
    }
    assert_false(collector.waits_for(KMessageDelete))
  })
}

///|
/// A clock whose `tick` wakes every sleeper it makes due in one scheduler
/// round, in the order they went to sleep, so two timers can fire together.
priv struct TickClock {
  mut now : Int64
  due : @cond_var.Cond
}

///|
impl @hclock.Clock for TickClock with fn sleep(self, milliseconds) {
  let deadline = self.now + milliseconds.to_int64()
  while self.now < deadline {
    self.due.wait()
  }
}

///|
impl @hclock.Clock for TickClock with fn now_unix_ms(self) {
  self.now
}

///|
async test "an event dispatched as the wait times out is returned" {
  let clock = TickClock::{ now: 0L, due: @cond_var.Cond(), }
  let collector = EventCollector(clock=Ref(clock))
  @async.with_task_group(group => {
    let waiting = group.spawn(() => {
      collector.wait_for(Events::message_delete(), _ => true, timeout_ms=20)
    })
    // Wakes in the same round as the wait's timeout, right after it.
    group.spawn_bg(() => {
      (clock : &@hclock.Clock).sleep(20)
      collector.dispatch(message_delete_event("100"))
    })
    wait_until_registered(collector, KMessageDelete, 1)
    clock.now = 20L
    clock.due.broadcast()
    guard waiting.wait() is Some(event) else {
      fail("the wait lost an event dispatched to it")
    }
    assert_eq(event.id.to_string(), "100")
  })
}
