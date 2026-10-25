///|
/// A wire that answers after `delay_ms` on `clock`, or fails with `fail_with`,
/// counting the exchanges it starts.
priv struct SlowWire {
  clock : @netruntime.VirtualClock
  delay_ms : Int32
  fail_with : @ghttp.TransportError?
  mut started : Int32
}

///|
impl @runtime.Backend for SlowWire with fn send(self, _request, _options) {
  self.started += 1
  self.clock.sleep(self.delay_ms)
  if self.fail_with is Some(error) {
    raise error
  }
  @ghttp.Response::new(204)
}

///|
/// One call of `route` through a client over a supplied `SlowWire` on virtual
/// time: its outcome as text, the virtual milliseconds it took, and how many
/// exchanges the wire started.
async fn timed_call(
  delay_ms : Int32,
  request_timeout_ms : Int32,
  fail_with? : @ghttp.TransportError,
  route~ : Route = GetGateway,
  max_retries~ : Int32 = 0,
) -> (String, Int64, Int32) {
  let clock = @netruntime.VirtualClock()
  let wire = SlowWire::{ clock, delay_ms, fail_with, started: 0, }
  let client = Client(
    "test-token",
    transport=wire,
    limiter=@runtime.NoLimiter::new(),
    request_timeout_ms~,
    max_retries~,
    clock~,
  )
  defer client.close()
  let started_at = clock.now_unix_ms()
  let completed_attempts = Ref(0)
  client.on_telemetry(event => {
    if event is HttpRequest(..) {
      completed_attempts.val += 1
    }
  })
  let outcome = @async.with_task_group(group => {
    let task = group.spawn(() => {
      try {
        ignore(client.request(route))
        "ok"
      } catch {
        error => @debug.to_string(error)
      }
    })
    for attempt in 0..<=max_retries {
      // An in-flight attempt owns its body-delay timer and deadline timer.
      // Nonpositive deadlines finish before starting either timer.
      clock.settle(until=() => {
        task_finished(task) || clock.pending().length() == 2
      })
      if task_finished(task) {
        break
      }
      assert_true(clock.advance_to_next())
      clock.settle(until=() => {
        task_finished(task) || completed_attempts.val > attempt
      })
      if task_finished(task) {
        break
      }
      clock.settle(until=() => {
        task_finished(task) ||
        (clock.pending() is [wait] && wait >= 400 && wait <= 9600)
      })
      if task_finished(task) {
        break
      }
      assert_true(clock.advance_to_next())
    }
    task.wait()
  })
  (outcome, clock.now_unix_ms() - started_at, wire.started)
}

///|
async test "request_timeout_ms bounds each attempt through a supplied transport" {
  // within the limit
  assert_eq(timed_call(100, 1000), ("ok", 100L, 1))
  // past it: the client cannot tell how far the transport got
  assert_eq(
    timed_call(60000, 1000),
    ("Timeout(phase=Unknown, timeout_ms=1000)", 1000L, 1),
  )
  // the transport's own failure passes through
  assert_eq(
    timed_call(10, 1000, fail_with=wire_connect("refused")),
    ("Transport(phase=Dial, message=\"could not connect: refused\")", 10L, 1),
  )
}

///|
async test "a nonpositive request timeout fails every attempt at once" {
  for timeout_ms in [0, -5] {
    assert_eq(
      timed_call(100, timeout_ms),
      ("Timeout(phase=Unknown, timeout_ms=\{timeout_ms})", 0L, 0),
    )
  }
}

///|
async test "a timed-out attempt is sent again only for an idempotent call" {
  // GET: the timed-out attempt and one resend after the 500 ms backoff.
  let (outcome, took, started) = timed_call(60000, 1000, max_retries=1)
  assert_eq(outcome, "Timeout(phase=Unknown, timeout_ms=1000)")
  assert_eq(started, 2)
  assert_true(took >= 2400L && took <= 2600L, msg=took.to_string())
  // POST: it may have reached Discord.
  assert_eq(
    timed_call(
      60000,
      1000,
      route=Route::custom(request_method=Post, path="/channels/1/messages"),
      max_retries=1,
    ),
    ("Timeout(phase=Unknown, timeout_ms=1000)", 1000L, 1),
  )
}

///|
async test "an offline client times its telemetry on its clock" {
  let clock = @netruntime.VirtualClock()
  let client = Client::offline(
    _ => {
      clock.sleep(250)
      { status: 200, headers: Map([]), body: { "url": "wss://x" }, }
    },
    clock~,
  )
  let events : Array[@telemetry.TelemetryEvent] = []
  client.on_telemetry(event => events.push(event))
  @async.with_task_group(group => {
    let task = group.spawn(() => client.get_gateway())
    clock.settle(until=() => clock.pending() == [250])
    assert_true(clock.advance_to_next())
    clock.settle(until=() => task_finished(task))
    assert_eq(task.wait(), "wss://x")
  })
  guard events is [HttpRequest(status=200, duration_ms=250L, ..)] else {
    fail("unexpected telemetry: \{Repr(events)}")
  }
}
