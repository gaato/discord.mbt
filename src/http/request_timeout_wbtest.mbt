///|
priv struct TimeoutTestLimiter {
  acquire_ : async () -> Unit
  mut acquires : Int
  releases : Array[(String, Int, Map[String, String])]
}

///|
fn TimeoutTestLimiter::TimeoutTestLimiter(
  acquire : async () -> Unit,
) -> TimeoutTestLimiter {
  { acquire_: acquire, acquires: 0, releases: [], }
}

///|
impl @runtime.RateLimiter for TimeoutTestLimiter with fn acquire(
  self,
  _bucket_key,
  global_exempt~,
) {
  ignore(global_exempt)
  self.acquires += 1
  (self.acquire_)()
}

///|
impl @runtime.RateLimiter for TimeoutTestLimiter with fn release(
  self,
  bucket_key,
  status~,
  headers~,
) {
  self.releases.push((bucket_key, status, header_map(headers)))
}

///|
async test "a rate-limit wait longer than the request timeout succeeds" {
  let limiter = TimeoutTestLimiter(() => @async.sleep(60))
  let attempts = Ref(0)
  let client = wire_test_client(
    (_path, _headers, _body) => {
      attempts.val += 1
      { status: 200, headers: Map([]), body: { "ok": true }, }
    },
    limiter~,
    request_timeout_ms=10,
  )
  defer client.close()
  json_inspect(client.request(GetGateway), content={ "ok": true })
  assert_eq(attempts.val, 1)
  assert_eq(limiter.acquires, 1)
  assert_eq(limiter.releases, [(GetGateway.bucket(), 200, Map([]))])
}

///|
async test "slow middleware before and after next is outside the request timeout" {
  let attempts = Ref(0)
  let client = wire_test_client(
    (_path, _headers, _body) => {
      attempts.val += 1
      { status: 200, headers: Map([]), body: { "ok": true }, }
    },
    request_timeout_ms=10,
  )
  defer client.close()
  client.middleware((request, next) => {
    @async.sleep(60)
    let response = next(request)
    @async.sleep(60)
    response
  })
  json_inspect(client.request(GetGateway), content={ "ok": true })
  assert_eq(attempts.val, 1)
}

///|
async test "cancelling a request waiting on the limiter propagates cancellation" {
  let started = @async.Semaphore(1, initial_value=0)
  let cancelled = Ref(false)
  let limiter = TimeoutTestLimiter(() => {
    defer {
      cancelled.val = @async.is_being_cancelled()
    }
    started.release()
    @async.sleep(60000)
  })
  let attempts = Ref(0)
  let client = wire_test_client(
    (_path, _headers, _body) => {
      attempts.val += 1
      { status: 200, headers: Map([]), body: Json::null(), }
    },
    limiter~,
    request_timeout_ms=10,
  )
  defer client.close()
  let events : Array[@telemetry.TelemetryEvent] = []
  client.on_telemetry(event => events.push(event))
  @async.with_task_group(group => {
    let waiting = group.spawn(allow_failure=true, () => {
      client.request(GetGateway)
    })
    @async.with_timeout(1000, () => started.acquire())
    waiting.cancel()
    try waiting.wait() catch {
      @async.WaitedTaskAlreadyCancelled => ()
      error => fail("unexpected cancellation error: \{Repr(error)}")
    } noraise {
      _ => fail("cancelled request unexpectedly completed")
    }
  })
  assert_true(cancelled.val)
  assert_eq(attempts.val, 0)
  assert_eq(limiter.acquires, 1)
  assert_eq(limiter.releases.length(), 0)
  assert_eq(events.length(), 0)
}

///|
async test "cancelling a network attempt releases its bucket without retrying" {
  let limiter = TimeoutTestLimiter(() => ())
  let started = @async.Semaphore(1, initial_value=0)
  let attempts = Ref(0)
  let client = wire_test_client(
    (_path, _headers, _body) => {
      attempts.val += 1
      started.release()
      @async.sleep(60000)
      { status: 200, headers: Map([]), body: Json::null(), }
    },
    limiter~,
    request_timeout_ms=60000,
  )
  defer client.close()
  let events : Array[@telemetry.TelemetryEvent] = []
  client.on_telemetry(event => events.push(event))
  @async.with_task_group(group => {
    let waiting = group.spawn(allow_failure=true, () => {
      client.request(GetGateway)
    })
    @async.with_timeout(1000, () => started.acquire())
    waiting.cancel()
    try waiting.wait() catch {
      @async.WaitedTaskAlreadyCancelled => ()
      error => fail("unexpected cancellation error: \{Repr(error)}")
    } noraise {
      _ => fail("cancelled request unexpectedly completed")
    }
  })
  assert_eq(attempts.val, 1)
  assert_eq(limiter.acquires, 1)
  assert_eq(limiter.releases, [(GetGateway.bucket(), 0, Map([]))])
  guard events is [HttpRequest(status=0, retries=0, ..)] else {
    fail("expected one cancelled attempt event: \{Repr(events)}")
  }
}

///|
async test "cancelling 429 back-off propagates cancellation without another attempt" {
  let limiter = TimeoutTestLimiter(() => ())
  let backing_off = @async.Semaphore(1, initial_value=0)
  let attempts = Ref(0)
  let client = wire_test_client(
    (_path, _headers, _body) => {
      attempts.val += 1
      { status: 429, headers: Map([]), body: { "retry_after": 60.0 }, }
    },
    limiter~,
    request_timeout_ms=10,
  )
  defer client.close()
  let events : Array[@telemetry.TelemetryEvent] = []
  client.on_telemetry(event => {
    events.push(event)
    if event is HttpRateLimited(..) {
      backing_off.release()
    }
  })
  @async.with_task_group(group => {
    let waiting = group.spawn(allow_failure=true, () => {
      client.request(GetGateway)
    })
    @async.with_timeout(1000, () => backing_off.acquire())
    waiting.cancel()
    try waiting.wait() catch {
      @async.WaitedTaskAlreadyCancelled => ()
      error => fail("unexpected cancellation error: \{Repr(error)}")
    } noraise {
      _ => fail("cancelled request unexpectedly completed")
    }
  })
  assert_eq(attempts.val, 1)
  assert_eq(limiter.acquires, 1)
  assert_eq(limiter.releases, [(GetGateway.bucket(), 429, Map([]))])
  guard events
    is [
      HttpRequest(status=429, retries=0, ..),
      HttpRateLimited(retry_after_ms=60000L, ..),
    ] else {
    fail("unexpected back-off telemetry: \{Repr(events)}")
  }
}

///|
async test "cancellation takes precedence over a middleware cleanup error" {
  let client = Client("test-token", request_timeout_ms=10)
  defer client.close()
  let started = @async.Semaphore(1, initial_value=0)
  client.middleware((_, _) => {
    started.release()
    ignore(@async.handle_cancellation(() => @async.sleep(60000)))
    raise MiddlewareFailure
  })
  @async.with_task_group(group => {
    let waiting = group.spawn(allow_failure=true, () => {
      client.request(GetGateway)
    })
    @async.with_timeout(1000, () => started.acquire())
    waiting.cancel()
    try waiting.wait() catch {
      @async.WaitedTaskAlreadyCancelled => ()
      error => fail("middleware masked cancellation: \{Repr(error)}")
    } noraise {
      _ => fail("cancelled request unexpectedly completed")
    }
  })
}
