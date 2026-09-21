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
    raw.request({ "op": "ping" }) |> ignore

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

///|
async test "a stale HTTP release lease cannot release the current owner" {
  let state = CoordinatorState::{
    identify: InMemoryQueue(max_concurrency=1, spacing_ms=0),
    limiter: InMemoryRateLimiter(global_limit=50),
    cooldown: @cooldown.InMemoryCooldownStore(),
    owners: Map([]),
    next_connection_id: Ref(2),
    next_lease_id: Ref(0),
  }
  let first = ConnectionState::{ id: 0, held_buckets: Ref(Map([])), }
  let second = ConnectionState::{ id: 1, held_buckets: Ref(Map([])), }
  let bucket = "POST:/channels/lease-test/messages"
  let acquired_first = dispatch_request(
    { "op": "http_acquire", "bucket": bucket, "global_exempt": false },
    state,
    first,
  )
  guard acquired_first is { "lease": first_lease_json, .. } &&
    json_nonnegative_int(first_lease_json) is Some(first_lease) else {
    fail("first acquire did not return a lease")
  }
  dispatch_request(
    {
      "op": "http_release",
      "bucket": bucket,
      "lease": first_lease,
      "status": 200,
      "headers": {},
    },
    state,
    first,
  )
  |> ignore
  let acquired_second = dispatch_request(
    { "op": "http_acquire", "bucket": bucket, "global_exempt": false },
    state,
    second,
  )
  guard acquired_second is { "lease": second_lease_json, .. } &&
    json_nonnegative_int(second_lease_json) is Some(second_lease) else {
    fail("second acquire did not return a lease")
  }
  dispatch_request(
    {
      "op": "http_release",
      "bucket": bucket,
      "lease": first_lease,
      "status": 200,
      "headers": {},
    },
    state,
    first,
  )
  |> ignore
  guard state.owners.get(bucket) is Some(owner) else {
    fail("stale release removed the current owner")
  }
  assert_eq(owner.lease, second_lease)
  dispatch_request(
    {
      "op": "http_release",
      "bucket": bucket,
      "lease": second_lease,
      "status": 200,
      "headers": {},
    },
    state,
    second,
  )
  |> ignore
}

///|
async test "a closed remote client never reconnects" {
  @async.with_task_group(group => {
    let coordinator = Coordinator::serve(group, addr="127.0.0.1:0")
    defer coordinator.close()
    let remote = RemoteIdentifyQueue::connect(coordinator.addr())
    remote.close()
    try remote.ping() catch {
      CoordinatorError::Disconnected => ()
      error => fail("unexpected close error: \{Repr(error)}")
    } noraise {
      _ => fail("closed client unexpectedly reconnected")
    }
  })
}

///|
async test "cooldown is shared across remote clients" {
  @async.with_task_group(group => {
    let coordinator = Coordinator::serve(group, addr="127.0.0.1:0")
    defer coordinator.close()
    let first = RemoteCooldownStore::connect(coordinator.addr())
    let second = RemoteCooldownStore::connect(coordinator.addr())
    defer first.close()
    defer second.close()
    first.ping()
    let key = "1:limited|user:1"
    assert_eq(first.try_acquire(key, window_ms=10_000L), Acquired)
    guard second.try_acquire(key, window_ms=10_000L) is Active(retry_after_ms~) else {
      fail("another client did not observe the cooldown")
    }
    assert_true(retry_after_ms > 0L && retry_after_ms <= 10_000L)
    first.close()
    let third = RemoteCooldownStore::connect(coordinator.addr())
    defer third.close()
    assert_true(third.try_acquire(key, window_ms=10_000L) is Active(..))
    assert_eq(second.try_acquire("1:other|user:1", window_ms=10_000L), Acquired)
  })
}

///|
async fn with_silent_coordinator(
  run : async (String, Ref[Int]) -> Unit,
) -> Unit {
  @async.with_task_group(group => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    let connections = Ref(0)
    group.spawn_bg(no_wait=true, () => {
      server.run_forever(allow_failure=true, (conn, _) => {
        connections.val += 1
        conn.read_until("\n") |> ignore
        @async.sleep(5_000)
      })
    })
    run(server.addr.to_string(), connections)
  })
}

///|
async test "unreachable coordinator fails open within the deadline" {
  with_silent_coordinator((addr, connections) => {
    let errors : Array[Error] = []
    let timeout_ms = 100
    let remote = RemoteCooldownStore::connect(addr, timeout_ms~, on_error=error => {
      errors.push(error)
    })
    defer remote.close()
    let started = @clock.now_ms()
    assert_eq(remote.try_acquire("global", window_ms=10_000L), Acquired)
    let elapsed = @clock.now_ms() - started
    assert_true(elapsed < (2 * timeout_ms).to_int64())
    assert_eq(errors.length(), 1)
    assert_true(errors[0] is @async.TimeoutError)
    assert_eq(connections.val, 1)
    assert_true(remote.client.conn.val is None)
  })
}

///|
async test "unreachable coordinator fails closed within the deadline" {
  with_silent_coordinator((addr, connections) => {
    let errors : Array[Error] = []
    let timeout_ms = 100
    let remote = RemoteCooldownStore::connect(
      addr,
      timeout_ms~,
      when_unreachable=FailClosed,
      on_error=error => errors.push(error),
    )
    defer remote.close()
    let started = @clock.now_ms()
    assert_eq(
      remote.try_acquire("global", window_ms=10_000L),
      Active(retry_after_ms=10_000L),
    )
    let elapsed = @clock.now_ms() - started
    assert_true(elapsed < (2 * timeout_ms).to_int64())
    assert_eq(errors.length(), 1)
    assert_true(errors[0] is @async.TimeoutError)
    assert_eq(connections.val, 1)
    assert_true(remote.client.conn.val is None)
  })
}

///|
async test "cooldown outage policies cover disconnection and initial refusal" {
  @async.with_task_group(group => {
    let coordinator = Coordinator::serve(group, addr="127.0.0.1:0")
    let errors = Ref(0)
    let first = RemoteCooldownStore::connect(
      coordinator.addr(),
      timeout_ms=100,
      on_error=_ => errors.val += 1,
    )
    let second = RemoteCooldownStore::connect(
      coordinator.addr(),
      timeout_ms=100,
      when_unreachable=FailClosed,
      on_error=_ => errors.val += 1,
    )
    defer first.close()
    defer second.close()
    coordinator.close()
    @async.sleep(10)
    assert_eq(first.try_acquire("global", window_ms=10_000L), Acquired)
    assert_eq(
      second.try_acquire("global", window_ms=10_000L),
      Active(retry_after_ms=10_000L),
    )
    assert_eq(errors.val, 2)
    let offline = RemoteCooldownStore::connect(
      coordinator.addr(),
      timeout_ms=100,
      on_error=_ => errors.val += 1,
    )
    defer offline.close()
    assert_eq(errors.val, 3)
    assert_eq(offline.try_acquire("global", window_ms=10_000L), Acquired)
    assert_eq(errors.val, 4)
  })
}

///|
async test "a blocked http_acquire does not delay cooldown_acquire" {
  @async.with_task_group(group => {
    let coordinator = Coordinator::serve(group, addr="127.0.0.1:0")
    defer coordinator.close()
    let limiter = RemoteRateLimiter::connect(coordinator.addr())
    let cooldown = RemoteCooldownStore::connect(
      coordinator.addr(),
      timeout_ms=100,
    )
    defer limiter.close()
    defer cooldown.close()
    let bucket = "POST:/channels/cooldown-test/messages"
    limiter.acquire(bucket, global_exempt=true)
    let acquired = Ref(false)
    let blocked = group.spawn(() => {
      limiter.acquire(bucket, global_exempt=true)
      acquired.val = true
    })
    @async.sleep(10)
    @async.with_timeout(100, () => {
      assert_eq(cooldown.try_acquire("global", window_ms=10_000L), Acquired)
      assert_true(
        cooldown.try_acquire("global", window_ms=10_000L) is Active(..),
      )
    })
    assert_false(acquired.val)
    limiter.release(bucket, status=200, headers=Map([]))
    blocked.wait()
    limiter.release(bucket, status=200, headers=Map([]))
  })
}

///|
async test "cooldown cancellation always propagates without reporting an outage" {
  for policy in [FailOpen, FailClosed] {
    with_silent_coordinator((addr, _) => {
      let errors = Ref(0)
      let returned = Ref(false)
      let remote = RemoteCooldownStore::connect(
        addr,
        timeout_ms=1000,
        when_unreachable=policy,
        on_error=_ => errors.val += 1,
      )
      defer remote.close()
      try
        @async.with_timeout(20, () => {
          remote.try_acquire("global", window_ms=10_000L) |> ignore
          returned.val = true
        })
      catch {
        @async.TimeoutError => ()
        error => fail("unexpected cancellation result: \{Repr(error)}")
      } noraise {
        _ => fail("cancelled acquisition unexpectedly returned")
      }
      assert_false(returned.val)
      assert_eq(errors.val, 0)
      assert_true(remote.client.conn.val is None)
    })
  }
}

///|
async test "cooldown deadline includes waiting for the connection gate" {
  @async.with_task_group(group => {
    let coordinator = Coordinator::serve(group, addr="127.0.0.1:0")
    defer coordinator.close()
    let errors = Ref(0)
    let remote = RemoteCooldownStore::connect(
      coordinator.addr(),
      timeout_ms=100,
      on_error=_ => errors.val += 1,
    )
    defer remote.close()
    remote.client.gate.acquire()
    let started = @clock.now_ms()
    assert_eq(remote.try_acquire("global", window_ms=10_000L), Acquired)
    assert_true(@clock.now_ms() - started < 200L)
    assert_eq(errors.val, 1)
    remote.client.gate.release()
    remote.ping()
    assert_eq(remote.try_acquire("global", window_ms=10_000L), Acquired)
  })
}

///|
test "cooldown wire values preserve Int64 precision" {
  let value = 9_007_199_254_740_993L
  let request = @json.parse(
    cooldown_acquire_request("global", value).stringify(),
  )
  guard request is { "window_ms": window, .. } else { fail("missing window") }
  assert_eq(json_nonnegative_int64(window), Some(value))
  let response = @json.parse(
    cooldown_response(Active(retry_after_ms=value)).stringify(),
  )
  guard response is { "retry_after_ms": retry, .. } else {
    fail("missing retry")
  }
  assert_eq(json_nonnegative_int64(retry), Some(value))
  assert_eq(
    json_nonnegative_int64("9223372036854775807"),
    Some(9_223_372_036_854_775_807L),
  )
  for invalid in [Json::number(1000.0), "-1", "1.5", "9223372036854775808"] {
    assert_eq(json_nonnegative_int64(invalid), None)
  }
}

///|
async test "remote cooldown store rejects a non-positive timeout" {
  try
    RemoteCooldownStore::connect("127.0.0.1:1", timeout_ms=0) |> ignore
  catch {
    CoordinatorError::InvalidConfig(message~) =>
      assert_eq(message, "timeout_ms must be positive")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected an invalid configuration error")
  }
}
