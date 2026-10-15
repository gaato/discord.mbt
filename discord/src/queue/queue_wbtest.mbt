///|
async fn wait_until_identify_gate_is_held(queue : InMemoryQueue) -> Unit {
  let gate = queue.buckets[0].gate
  for _ in 0..<100 {
    if !gate.try_acquire() {
      return
    }
    gate.release()
    @async.sleep(1)
  }
  fail("identify waiter did not acquire its bucket gate")
}

///|
async test "a cancelled identify wait releases its bucket gate" {
  let queue = InMemoryQueue(max_concurrency=1, spacing_ms=60_000)
  let bucket = queue.buckets[0]
  bucket.last_identify_ms = @clock.now_ms()
  @async.with_task_group(group => {
    let waiting = group.spawn(no_wait=true, allow_failure=true, () => {
      IdentifyQueue::wait_for_identify(queue, 0)
    })
    wait_until_identify_gate_is_held(queue)
    waiting.cancel()
    try waiting.wait() catch {
      @async.WaitedTaskAlreadyCancelled => ()
      error => fail("unexpected cancellation error: \{Repr(error)}")
    } noraise {
      _ => fail("cancelled identify wait unexpectedly completed")
    }

    assert_true(bucket.gate.try_acquire())
    bucket.gate.release()
    bucket.last_identify_ms = 0
    @async.with_timeout(100, () => IdentifyQueue::wait_for_identify(queue, 0))
  })
}
