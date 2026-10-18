///|
/// A wire that answers after `delay_ms` on `clock`, or fails with `fail_with`.
priv struct SlowWire {
  clock : @simclock.VirtualClock
  delay_ms : Int32
  fail_with : @ghttp.HttpError?
}

///|
impl @ghttp.Transport for SlowWire with fn send(self, _request) {
  self.clock.sleep(self.delay_ms)
  if self.fail_with is Some(error) {
    raise error
  }
  { status: 204, headers: @ghttp.Headers::new(), body: b"", }
}

///|
impl @ghttp.Transport for SlowWire with fn send_stream(self, request) {
  ignore(@ghttp.Transport::send(self, request))
  raise @ghttp.HttpError::Protocol("SlowWire does not stream")
}

///|
/// The outcome of one exchange through an `AttemptDeadline` on virtual time,
/// as text, with the virtual milliseconds it took.
async fn deadline_outcome(
  delay_ms : Int32,
  timeout_ms : Int32,
  fail_with? : @ghttp.HttpError,
  streaming~ : Bool = false,
) -> (String, Int64) {
  let clock = @simclock.VirtualClock()
  let deadline = AttemptDeadline::{
    inner: SlowWire::{ clock, delay_ms, fail_with, },
    clock,
    timeout_ms,
  }
  let request = @ghttp.Request::get("https://discord.com/api/v10/gateway")
  let started_at = clock.now_unix_ms()
  let outcome = @async.with_task_group(group => {
    let task = group.spawn(() => {
      try {
        if streaming {
          ignore(@ghttp.Transport::send_stream(deadline, request))
        } else {
          ignore(@ghttp.Transport::send(deadline, request))
        }
        "ok"
      } catch {
        error => @debug.to_string(error)
      }
    })
    while task.try_wait() is None {
      guard clock.advance_to_next() else { break }
    }
    task.wait()
  })
  (outcome, clock.now_unix_ms() - started_at)
}

///|
async test "the attempt deadline runs on the client's clock" {
  // within the deadline
  assert_eq(deadline_outcome(100, 1000), ("ok", 100L))
  // past it: the deadline cannot tell the phase
  assert_eq(
    deadline_outcome(60000, 1000),
    ("Timeout(phase=Unknown, ms=1000)", 1000L),
  )
  assert_eq(
    deadline_outcome(60000, 1000, streaming=true),
    ("Timeout(phase=Unknown, ms=1000)", 1000L),
  )
  // a nonpositive deadline expires before the exchange starts
  assert_eq(deadline_outcome(100, 0), ("Timeout(phase=Unknown, ms=0)", 0L))
  // the inner transport's own failure passes through
  assert_eq(
    deadline_outcome(10, 1000, fail_with=Connect("refused")),
    ("Connect(\"refused\")", 10L),
  )
}

///|
async test "an offline client times its telemetry on its clock" {
  let clock = @simclock.VirtualClock()
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
    while task.try_wait() is None {
      guard clock.advance_to_next() else { fail("nothing left to wait for") }
    }
    assert_eq(task.wait(), "wss://x")
  })
  guard events is [HttpRequest(status=200, duration_ms=250L, ..)] else {
    fail("unexpected telemetry: \{Repr(events)}")
  }
}
