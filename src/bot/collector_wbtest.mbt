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
  count : Int,
) -> Unit {
  for _ in 0..<50 {
    let mut found = 0
    for waiter in collector.waiters {
      if waiter.kind == kind {
        found += 1
      }
    }
    if found == count {
      return
    }
    @async.sleep(1)
  }
  fail("event collectors were not registered")
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
  let collector = EventCollector()
  assert_true(
    collector.wait_for(Events::message_delete(), _ => true, timeout_ms=10)
    is None,
  )
  assert_false(collector.waits_for(KMessageDelete))
  @async.with_task_group(group => {
    let pending = group.spawn(no_wait=true, allow_failure=true, () => {
      collector.wait_for(Events::message_delete(), _ => true)
    })
    wait_until_registered(collector, KMessageDelete, 1)
    pending.cancel()
    try pending.wait() catch {
      @async.TaskCancelled => ()
      error => fail("unexpected cancellation error: \{Repr(error)}")
    } noraise {
      _ => fail("cancelled collector unexpectedly completed")
    }
    assert_false(collector.waits_for(KMessageDelete))
  })
}
