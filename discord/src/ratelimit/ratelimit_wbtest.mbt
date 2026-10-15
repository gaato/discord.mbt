///|
async test "Discord allows only one request in flight per bucket" {
  let limiter = rate_limiter()
  limiter.acquire("bucket", global_exempt=true)
  @async.with_task_group(group => {
    let started = @async.Semaphore(1, initial_value=0)
    let admitted = Ref(false)
    let waiting = group.spawn(no_wait=true, () => {
      started.release()
      limiter.acquire("bucket", global_exempt=true)
      admitted.val = true
      limiter.release("bucket", status=200, headers=@http.Headers::new())
    })
    started.acquire()
    @async.sleep(10)
    assert_false(admitted.val)
    // A different bucket still proceeds while the first exchange is in flight.
    limiter.acquire("other", global_exempt=true)
    limiter.release("other", status=200, headers=@http.Headers::new())
    assert_false(admitted.val)
    limiter.release("bucket", status=200, headers=@http.Headers::new())
    @async.with_timeout(1000, () => waiting.wait())
    assert_true(admitted.val)
  })
}
