///|
/// A 429 as the runtime classifies it.
fn limited(
  headers : Array[(String, String)],
  body : String,
) -> @runtime.SdkError {
  @runtime.RateLimited(
    retry_after_ms=None,
    headers=@ghttp.Headers::from_array(headers),
    body=@utf8.encode(body),
  )
}

///|
/// An error status as the runtime classifies it.
fn status_error(status : Int32) -> @runtime.SdkError {
  @runtime.Status(status~, headers=@ghttp.Headers::new(), body=b"")
}

///|
/// `resend_decision` for `error` on a `verb` request after the failed
/// attempt `attempt`, with random 0.5 (the backoff's middle: 500 ms,
/// doubling per attempt).
fn decision(
  error : @runtime.SdkError,
  verb : String,
  attempt~ : Int32 = 0,
  max_retries~ : Int32 = 4,
  closed~ : Bool = false,
  replay_safe~ : Bool = false,
  remaining_ms? : Int64,
) -> @retry.Decision {
  let request = @ghttp.Request::new(
    verb, "https://discord.com/api/v10/channels/1/messages",
  )
  if replay_safe {
    request.headers.set(REPLAY_SAFE_HEADER, "1")
  }
  resend_decision(
    error,
    @runtime.RetryContext::new(request, attempt~, random=0.5, remaining_ms?),
    max_retries~,
    closed~,
  )
}

///|
test "a 429 is resent for any verb after the delay Discord asks for" {
  let discord = limited(
    [("x-ratelimit-scope", "user")],
    "{\"retry_after\":1.5}",
  )
  for verb in ["GET", "POST", "PATCH"] {
    assert_eq(decision(discord, verb), Wait(1501), msg=verb)
  }
  // The body's retry_after first, then Retry-After-Ms, then Retry-After,
  // then one second; the runtime's own retry_after_ms is not consulted.
  let cases : Array[(@runtime.SdkError, @retry.Decision)] = [
    (
      @runtime.RateLimited(
        retry_after_ms=Some(9),
        headers=@ghttp.Headers::from_array([
          ("x-ratelimit-scope", "user"),
          ("retry-after", "2"),
        ]),
        body=b"",
      ),
      Wait(2001),
    ),
    (
      limited(
        [
          ("x-ratelimit-scope", "user"),
          ("retry-after-ms", "250"),
          ("retry-after", "2"),
        ],
        "",
      ),
      Wait(251),
    ),
    (limited([("x-ratelimit-scope", "user")], ""), Wait(1001)),
    (limited([], "{\"retry_after\":0.25,\"global\":false}"), Wait(251)),
    // A long wait is followed, uncapped.
    (
      limited([("x-ratelimit-scope", "global")], "{\"retry_after\":3600}"),
      Wait(3600001),
    ),
  ]
  for case in cases {
    let (error, expected) = case
    assert_eq(decision(error, "POST"), expected, msg=Repr(error).to_string())
  }
  // ...but not past the call's deadline, nor past max_retries, nor once closed.
  assert_eq(decision(discord, "POST", remaining_ms=1000L), Stop(Budget(1501)))
  assert_eq(
    decision(discord, "POST", attempt=1, max_retries=1),
    Stop(Exhausted),
  )
  assert_eq(decision(discord, "POST", max_retries=0), Stop(Exhausted))
  assert_eq(decision(discord, "POST", closed=true), Stop(NotRetryable))
}

///|
test "a 429 without a JSON body or a Discord rate-limit header fails at once" {
  // Cloudflare's 429 in front of Discord: every retry counts against the
  // address's 10,000 invalid requests per ten minutes.
  for
    error in [
      limited([], ""),
      limited([("retry-after", "2")], ""),
      limited([("content-type", "text/html")], "<html>banned</html>"),
      limited([], "\"not an object\""),
    ] {
    assert_eq(
      decision(error, "GET"),
      Stop(NotRetryable),
      msg=Repr(error).to_string(),
    )
  }
  // Either Discord signal alone makes it Discord's.
  assert_eq(
    decision(limited([("x-ratelimit-global", "true")], ""), "GET"),
    Wait(1001),
  )
  assert_eq(
    decision(limited([("x-ratelimit-scope", "shared")], ""), "GET"),
    Wait(1001),
  )
  assert_eq(decision(limited([], "{}"), "GET"), Wait(1001))
}

///|
test "a 502 is resent for any verb, other 5xx only for idempotent ones" {
  for verb in ["GET", "HEAD", "PUT", "DELETE", "OPTIONS", "POST", "PATCH"] {
    assert_eq(decision(status_error(502), verb), Wait(500), msg=verb)
    assert_eq(
      decision(status_error(502), verb, attempt=2),
      Wait(2000),
      msg=verb,
    )
  }
  for status in [500, 503, 504, 520, 599] {
    for verb in ["GET", "HEAD", "PUT", "DELETE", "OPTIONS"] {
      assert_eq(
        decision(status_error(status), verb),
        Wait(500),
        msg="\{status} \{verb}",
      )
    }
    for verb in ["POST", "PATCH"] {
      assert_eq(
        decision(status_error(status), verb),
        Stop(MethodNotAllowed),
        msg="\{status} \{verb}",
      )
    }
  }
  assert_eq(decision(status_error(503), "GET", attempt=4), Stop(Exhausted))
}

///|
test "401, 403 and other answers are never resent" {
  for status in [400, 401, 403, 404, 405, 409, 413] {
    for verb in ["GET", "POST"] {
      assert_eq(
        decision(status_error(status), verb),
        Stop(NotRetryable),
        msg="\{status} \{verb}",
      )
    }
  }
  assert_eq(decision(@runtime.Config("limiter"), "GET"), Stop(NotRetryable))
}

///|
test "a transport failure is resent when nothing was sent, or for an idempotent call" {
  let unsent : Array[@ghttp.HttpError] = [
    Connect("refused"),
    Timeout(phase=Pool, ms=5),
    Timeout(phase=Dial, ms=5),
    Proxy(status=502, message="down"),
  ]
  for failure in unsent {
    for verb in ["GET", "POST"] {
      assert_eq(
        decision(@runtime.Transport(failure), verb),
        Wait(500),
        msg="\{Repr(failure)} \{verb}",
      )
    }
  }
  assert_eq(
    decision(@runtime.Transport(Connect("refused")), "POST", attempt=2),
    Wait(2000),
  )
  // Unsent but not transient: the proxy will refuse again.
  assert_eq(
    decision(@runtime.Transport(Proxy(status=407, message="auth")), "GET"),
    Stop(NotRetryable),
  )
  // May have reached Discord: only an idempotent call is sent again.
  let sent : Array[@ghttp.HttpError] = [
    Timeout(phase=Head, ms=5),
    Timeout(phase=Unknown, ms=5),
    Network(phase=Write, message="reset"),
  ]
  for failure in sent {
    assert_eq(
      decision(@runtime.Transport(failure), "GET"),
      Wait(500),
      msg=Repr(failure).to_string(),
    )
    assert_eq(
      decision(@runtime.Transport(failure), "POST"),
      Stop(MethodNotAllowed),
      msg=Repr(failure).to_string(),
    )
  }
  // A garbled answer is never resent.
  assert_eq(
    decision(@runtime.Transport(Protocol("garbled")), "GET"),
    Stop(NotRetryable),
  )
}

///|
test "a replay-safe message create is resent like an idempotent call" {
  let after_sending = @runtime.Transport(Timeout(phase=Head, ms=5))
  assert_eq(decision(after_sending, "POST"), Stop(MethodNotAllowed))
  assert_eq(decision(after_sending, "POST", replay_safe=true), Wait(500))
  assert_eq(decision(status_error(500), "POST", replay_safe=true), Wait(500))
  // Still never for an answer.
  assert_eq(
    decision(status_error(400), "POST", replay_safe=true),
    Stop(NotRetryable),
  )
}

///|
test "only a message create with a nonce and enforce_nonce is replay-safe" {
  let create = Route::CreateMessage(channel_id=Id(1UL))
  let cases : Array[(Route, Json?, Bool)] = [
    (
      create,
      Some({ "content": "x", "nonce": "n-1", "enforce_nonce": true }),
      true,
    ),
    (create, Some({ "nonce": 42, "enforce_nonce": true }), true),
    (create, Some({ "nonce": "n-1" }), false),
    (create, Some({ "nonce": "n-1", "enforce_nonce": false }), false),
    (create, Some({ "enforce_nonce": true }), false),
    (create, Some({ "nonce": Json::null(), "enforce_nonce": true }), false),
    (create, None, false),
    (
      Route::EditMessage(channel_id=Id(1UL), message_id=Id(2UL)),
      Some({ "nonce": "n-1", "enforce_nonce": true }),
      false,
    ),
  ]
  for index, case in cases {
    let (route, body, expected) = case
    assert_eq(is_replay_safe(route, body), expected, msg="case \{index}")
  }
}

///|
/// A wire that fails its first attempts with `failures`, in order, then
/// answers through `wire`.
priv struct FlakyWire {
  failures : Array[@ghttp.HttpError]
  wire : FakeWire
  mut failed : Int32
}

///|
impl @ghttp.Transport for FlakyWire with fn send(self, request) {
  if self.failed < self.failures.length() {
    self.failed += 1
    raise self.failures[self.failed - 1]
  }
  @ghttp.Transport::send(self.wire, request)
}

///|
impl @ghttp.Transport for FlakyWire with fn send_stream(_self, _request) {
  raise @ghttp.HttpError::Protocol("FlakyWire does not stream")
}

///|
/// A `test-token` client over a `FlakyWire` whose answers count in
/// `answered`, on a virtual clock.
fn flaky_client(
  failures : Array[@ghttp.HttpError],
  limiter : TimeoutTestLimiter,
  answered : Ref[Int32],
  clock~ : @simclock.VirtualClock = @simclock.VirtualClock(),
) -> (Client, FlakyWire) {
  let wire = FlakyWire::{
    failures,
    wire: FakeWire::{
      answer: (_path, _headers, _body) => {
        answered.val += 1
        { status: 200, headers: Map([]), body: { "ok": true }, }
      },
    },
    failed: 0,
  }
  (Client("test-token", transport=wire, limiter~, clock~), wire)
}

///|
async test "a POST that never reached Discord is sent again through the limiter" {
  let limiter = TimeoutTestLimiter(() => ())
  let answered = Ref(0)
  let clock = @simclock.VirtualClock()
  let (client, wire) = flaky_client(
    [@ghttp.HttpError::Connect("refused")],
    limiter,
    answered,
    clock~,
  )
  defer client.close()
  let events : Array[@telemetry.TelemetryEvent] = []
  client.on_telemetry(event => events.push(event))
  let route = Route::custom(request_method=Post, path="/channels/1/messages")
  let started_at = clock.now_unix_ms()
  @async.with_task_group(group => {
    let sending = group.spawn(() => {
      client.request(route, body={ "content": "once" })
    })
    clock.settle()
    // Refused once, now waiting out the backoff on the client's clock.
    assert_eq(wire.failed, 1)
    assert_eq(answered.val, 0)
    while sending.try_wait() is None {
      guard clock.advance_to_next() else { fail("nothing left to wait for") }
    }
    json_inspect(sending.wait(), content={ "ok": true })
  })
  // The runtime's default backoff: 500 ms with 20% jitter.
  let waited = clock.now_unix_ms() - started_at
  assert_true(waited >= 400L && waited <= 600L)
  assert_eq(wire.failed, 1)
  assert_eq(answered.val, 1)
  assert_eq(limiter.acquires, 2)
  assert_eq(limiter.releases, [
    (route.bucket(), 0, Map([])),
    (route.bucket(), 200, Map([])),
  ])
  guard events
    is [
      HttpRequest(status=0, retries=0, ..),
      HttpRequest(status=200, retries=1, ..),
    ] else {
    fail("unexpected telemetry: \{Repr(events)}")
  }
}

///|
async test "a POST that may have reached Discord is raised at once" {
  for
    failure in [
      @ghttp.HttpError::Network(phase=Write, message="reset"),
      @ghttp.HttpError::Network(phase=Head, message="eof"),
      @ghttp.HttpError::Timeout(phase=Head, ms=5),
      @ghttp.HttpError::Protocol("garbled"),
    ] {
    let limiter = TimeoutTestLimiter(() => ())
    let answered = Ref(0)
    let (client, wire) = flaky_client([failure], limiter, answered)
    defer client.close()
    let route = Route::custom(request_method=Post, path="/channels/1/messages")
    try client.request(route, body={ "content": "once" }) catch {
      error =>
        assert_eq(
          @debug.to_string(error),
          @debug.to_string(transport_failure(failure)),
        )
    } noraise {
      _ => fail("expected the failure to surface")
    }
    assert_eq(wire.failed, 1)
    assert_eq(answered.val, 0)
    assert_eq(limiter.acquires, 1)
  }
}

///|
async test "a closed client does not resend a call that never reached Discord" {
  let limiter = TimeoutTestLimiter(() => ())
  let answered = Ref(0)
  let (client, wire) = flaky_client(
    [@ghttp.HttpError::Connect("refused")],
    limiter,
    answered,
  )
  // Telemetry for the failed attempt runs before the retry decision.
  client.on_telemetry(_ => client.close())
  try client.request(GetGateway) catch {
    Transport(phase=Dial, ..) as error => assert_true(error.is_unsent())
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the refused connection")
  }
  assert_eq(wire.failed, 1)
  assert_eq(answered.val, 0)
  assert_eq(limiter.acquires, 1)
}

///|
async test "a client closed during the backoff does not send the resend" {
  let limiter = TimeoutTestLimiter(() => ())
  let answered = Ref(0)
  let clock = @simclock.VirtualClock()
  let (client, wire) = flaky_client(
    [@ghttp.HttpError::Connect("refused")],
    limiter,
    answered,
    clock~,
  )
  let route = Route::custom(request_method=Post, path="/channels/1/messages")
  @async.with_task_group(group => {
    let sending = group.spawn(() => {
      try client.request(route, body={ "content": "once" }) catch {
        error => Some(error)
      } noraise {
        _ => None
      }
    })
    clock.settle()
    assert_eq(wire.failed, 1, msg="refused once, now in the backoff")
    client.close()
    while sending.try_wait() is None {
      guard clock.advance_to_next() else { fail("nothing left to wait for") }
    }
    guard sending.wait() is Some(error) else { fail("the resend went out") }
    assert_true(error.is_unsent(), msg=@debug.to_string(error))
  })
  assert_eq(answered.val, 0, msg="the transport never got the resend")
}

///|
async test "a GET that may have reached Discord is sent again" {
  for
    failure in [
      @ghttp.HttpError::Network(phase=Write, message="reset"),
      @ghttp.HttpError::Network(phase=Head, message="eof"),
      @ghttp.HttpError::Timeout(phase=Head, ms=5),
    ] {
    let limiter = TimeoutTestLimiter(() => ())
    let answered = Ref(0)
    let clock = @simclock.VirtualClock()
    let (client, wire) = flaky_client([failure], limiter, answered, clock~)
    defer client.close()
    @async.with_task_group(group => {
      let sending = group.spawn(() => client.request(GetGateway))
      while sending.try_wait() is None {
        guard clock.advance_to_next() else { fail("nothing left to wait for") }
      }
      json_inspect(sending.wait(), content={ "ok": true })
    })
    assert_eq(wire.failed, 1)
    assert_eq(answered.val, 1)
    assert_eq(limiter.acquires, 2)
  }
}

///|
/// A wire that answers `statuses` in turn, then 200, counting its answers.
fn status_sequence_client(
  statuses : Array[(Int32, Map[String, String], Json)],
  answered : Ref[Int32],
  seen : Array[Map[String, String]],
  max_retries~ : Int32 = 4,
  clock~ : @simclock.VirtualClock = @simclock.VirtualClock(),
) -> Client {
  let wire = FakeWire::{
    answer: (_path, headers, _body) => {
      seen.push(headers)
      answered.val += 1
      if answered.val <= statuses.length() {
        let (status, headers, body) = statuses[answered.val - 1]
        { status, headers, body, }
      } else {
        {
          status: 200,
          headers: Map([]),
          body: {
            "id": "500",
            "channel_id": "1",
            "author": {
              "id": "200",
              "username": "nelly",
              "discriminator": "0",
              "avatar": null,
            },
            "content": "once",
            "timestamp": "2024-01-02T03:04:05.000000+00:00",
            "edited_timestamp": null,
            "tts": false,
            "mention_everyone": false,
            "mentions": [],
            "mention_roles": [],
            "attachments": [],
            "embeds": [],
            "pinned": false,
            "type": 0,
          },
        }
      }
    },
  }
  Client(
    "test-token",
    transport=wire,
    limiter=@runtime.NoLimiter::new(),
    max_retries~,
    clock~,
  )
}

///|
/// Runs `call` on `clock`'s virtual time until it finishes.
async fn[T] on_virtual_time(
  clock : @simclock.VirtualClock,
  call : async () -> T,
) -> T {
  @async.with_task_group(group => {
    let task = group.spawn(call)
    clock.settle()
    while task.try_wait() is None {
      guard clock.advance_to_next() else { fail("nothing left to wait for") }
    }
    task.wait()
  })
}

///|
async test "a 502 is sent again for a POST, another 5xx is not" {
  let clock = @simclock.VirtualClock()
  let answered = Ref(0)
  let client = status_sequence_client(
    [(502, Map([]), Json::string("<html>bad gateway</html>"))],
    answered,
    [],
    clock~,
  )
  let message = on_virtual_time(clock, () => {
    client.create_message(Id(1UL), content="once")
  })
  assert_eq(message.content, "once")
  assert_eq(answered.val, 2)
  for status in [500, 503, 504] {
    let answered = Ref(0)
    let client = status_sequence_client(
      [(status, Map([]), { "code": 0, "message": "oops" })],
      answered,
      [],
    )
    try client.create_message(Id(1UL), content="once") catch {
      Api(status=got, ..) => assert_eq(got, status)
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected the \{status} to surface")
    }
    assert_eq(answered.val, 1, msg=status.to_string())
  }
}

///|
async test "a message create with an enforced nonce is sent again and the mark stays home" {
  let clock = @simclock.VirtualClock()
  let answered = Ref(0)
  let seen : Array[Map[String, String]] = []
  let client = status_sequence_client(
    [(500, Map([]), { "code": 0, "message": "oops" })],
    answered,
    seen,
    clock~,
  )
  let message = on_virtual_time(clock, () => {
    client.create_message(
      Id(1UL),
      content="once",
      nonce=Str("n-1"),
      enforce_nonce=true,
    )
  })
  assert_eq(message.content, "once")
  assert_eq(answered.val, 2)
  for headers in seen {
    assert_false(headers.contains(REPLAY_SAFE_HEADER))
  }
  // Without enforce_nonce, Discord may create it twice: raised at once.
  let answered = Ref(0)
  let client = status_sequence_client(
    [(500, Map([]), { "code": 0, "message": "oops" })],
    answered,
    [],
  )
  try client.create_message(Id(1UL), content="once", nonce=Str("n-1")) catch {
    Api(status=500, ..) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the 500 to surface")
  }
  assert_eq(answered.val, 1)
  // A caller cannot set the mark itself.
  let answered = Ref(0)
  let client = status_sequence_client(
    [(500, Map([]), { "code": 0, "message": "oops" })],
    answered,
    [],
  )
  let route = Route::custom(request_method=Post, path="/channels/1/messages")
  try
    client.request(
      route,
      body={ "content": "once" },
      headers=Map([(REPLAY_SAFE_HEADER, "1")]),
    )
  catch {
    Api(status=500, ..) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the 500 to surface")
  }
  assert_eq(answered.val, 1)
}

///|
async test "a 429 that is not Discord's is raised without a resend" {
  let answered = Ref(0)
  let client = status_sequence_client(
    [
      (
        429,
        { "content-type": "text/html", "retry-after": "1" },
        Json::string("<html>Access denied</html>"),
      ),
    ],
    answered,
    [],
  )
  try client.get_gateway() catch {
    RateLimited(..) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the 429 to surface")
  }
  assert_eq(answered.val, 1)
  assert_eq(client.invalid_requests(), 1)
}

///|
async test "a 401 is raised without a resend and counted" {
  let answered = Ref(0)
  let client = status_sequence_client(
    [(401, Map([]), { "code": 0, "message": "401: Unauthorized" })],
    answered,
    [],
  )
  try client.get_gateway() catch {
    Api(status=401, ..) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the 401 to surface")
  }
  assert_eq(answered.val, 1)
  assert_eq(client.invalid_requests(), 1)
}
