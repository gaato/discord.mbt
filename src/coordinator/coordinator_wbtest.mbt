///|
extend RemoteIdentifyQueue with @queue.IdentifyQueue::{wait_for_identify}

///|
extend RemoteRateLimiter with @ratelimit.RateLimiter::{acquire, release}

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

///|
async test "remote client reconnects after coordinator restart" {
  let address : Ref[String?] = Ref(None)
  let remote : Ref[RemoteIdentifyQueue?] = Ref(None)
  @async.with_task_group(first_group => {
    let first = Coordinator::serve(
      first_group,
      addr="127.0.0.1:0",
      identify_spacing_ms=0,
    )
    defer first.close()
    let first_remote = RemoteIdentifyQueue::connect(first.addr())
    first_remote.ping()
    address.val = Some(first.addr())
    remote.val = Some(first_remote)
  })
  guard address.val is Some(address) && remote.val is Some(remote) else {
    fail("coordinator restart fixture did not initialize")
  }
  defer remote.close()
  @async.with_task_group(second_group => {
    let second = Coordinator::serve(
      second_group,
      addr=address,
      identify_spacing_ms=0,
    )
    defer second.close()
    remote.ping()
    try remote.client.request({ "op": "not_a_real_operation" }) catch {
      CoordinatorError::Remote(message~) =>
        assert_true(message.contains("unknown op"))
      error => fail("unexpected error: \{error}")
    } noraise {
      _ => fail("server error should be fatal")
    }
  })
}

///|
async test "coordinator EOF releases a held HTTP bucket" {
  @async.with_task_group(group => {
    let coordinator = Coordinator::serve(group, addr="127.0.0.1:0")
    defer coordinator.close()
    let first = RemoteRateLimiter::connect(coordinator.addr())
    let second = RemoteRateLimiter::connect(coordinator.addr())
    defer first.close()
    defer second.close()
    let bucket = "POST:/channels/9/messages"
    @ratelimit.RateLimiter::acquire(first, bucket, global_exempt=true)
    first.acquire_client.close()

    @async.with_timeout(1000, () => {
      @ratelimit.RateLimiter::acquire(second, bucket, global_exempt=true)
    })
    @ratelimit.RateLimiter::release(second, bucket, status=0, headers=Map([]))
  })
}

///|
priv suberror CoordinatorConnectTestError {
  SecondConnectionFailed
} derive(Debug)

///|
async test "remote rate limiter closes its first client when the second connection fails" {
  @async.with_task_group(group => {
    let coordinator = Coordinator::serve(group, addr="127.0.0.1:0")
    defer coordinator.close()
    let warmup = RemoteIdentifyQueue::connect(coordinator.addr())
    defer warmup.close()
    warmup.ping()
    let attempts = Ref(0)
    let first_client : Ref[CoordinatorClient?] = Ref(None)
    try
      RemoteRateLimiter::connect_with(coordinator.addr(), addr => {
        attempts.val += 1
        if attempts.val == 2 {
          raise CoordinatorConnectTestError::SecondConnectionFailed
        }
        let client = CoordinatorClient::connect(addr)
        first_client.val = Some(client)
        client
      })
    catch {
      CoordinatorConnectTestError::SecondConnectionFailed => ()
      error => fail("unexpected connection error: \{Repr(error)}")
    } noraise {
      _ => fail("second connection unexpectedly succeeded")
    }
    assert_eq(attempts.val, 2)
    guard first_client.val is Some(client) else {
      fail("first coordinator client was not captured")
    }
    assert_true(client.conn.val is None)
  })
}
