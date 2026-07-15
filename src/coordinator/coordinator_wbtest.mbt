///|
async test "coordinator serializes identify and HTTP limits across clients" {
  @async.with_task_group(group => {
    let coordinator = Coordinator::serve(
      group,
      addr="127.0.0.1:0",
      identify_spacing_ms=40,
    )
    let first = RemoteIdentifyQueue::connect(coordinator.addr())
    let second = RemoteIdentifyQueue::connect(coordinator.addr())
    let remote_limiter = RemoteRateLimiter::connect(coordinator.addr())
    defer first.close()
    defer second.close()
    defer remote_limiter.close()
    first.ping()
    remote_limiter.ping()

    first.wait_for_identify(0)
    let first_admitted_at = @clock.now_ms()
    second.wait_for_identify(1)
    let second_admitted_at = @clock.now_ms()
    assert_true(second_admitted_at - first_admitted_at >= 25L)

    remote_limiter.acquire("POST:/channels/1/messages", global_exempt=false)
    remote_limiter.release("POST:/channels/1/messages", status=200, headers={
      "x-ratelimit-remaining": "0",
      "x-ratelimit-reset-after": "0.04",
    })
    let rate_wait_started = @clock.now_ms()
    remote_limiter.acquire("POST:/channels/1/messages", global_exempt=false)
    let rate_wait = @clock.now_ms() - rate_wait_started
    remote_limiter.release("POST:/channels/1/messages", status=200, headers={
      "x-ratelimit-remaining": "1",
    })
    assert_true(rate_wait >= 25L)

    let concurrent_bucket = "POST:/channels/2/messages"
    remote_limiter.acquire(concurrent_bucket, global_exempt=false)
    let blocked_acquire = group.spawn(() => {
      let started = @clock.now_ms()
      remote_limiter.acquire(concurrent_bucket, global_exempt=false)
      let waited = @clock.now_ms() - started
      remote_limiter.release(concurrent_bucket, status=200, headers={
        "x-ratelimit-remaining": "1",
      })
      waited
    })
    @async.sleep(10)
    remote_limiter.release(concurrent_bucket, status=200, headers={
      "x-ratelimit-remaining": "1",
    })
    assert_true(blocked_acquire.wait() >= 8L)

    let raw = CoordinatorClient::connect(coordinator.addr())
    defer raw.close()
    try raw.request({ "op": "not_a_real_operation" }) catch {
      CoordinatorError::Remote(message~) =>
        assert_true(message.contains("unknown op"))
      error => fail("unexpected error: \{error}")
    } noraise {
      _ => fail("unknown op should fail")
    }
    raw.request({ "op": "ping" })

    coordinator.close()
    @async.sleep(10)
    try first.ping() catch {
      CoordinatorError::Disconnected | CoordinatorError::Transport(..) => ()
      error => fail("unexpected disconnect error: \{error}")
    } noraise {
      _ => fail("expected ping after shutdown to fail")
    }
  })
}
