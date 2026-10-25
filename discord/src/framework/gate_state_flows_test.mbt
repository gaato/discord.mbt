///|
async test "REST gate classifies callback failures four ways" {
  let cases : Array[(@dhttp.DiscordHttpError, @framework.DeliveryFailure)] = [
    (
      Api(status=404, error={
        code: 10062,
        message: "Unknown interaction",
        errors: None,
      }),
      Expired,
    ),
    (Validation(message="invalid payload"), Rejected),
    (
      Api(status=400, error={
        code: 50035,
        message: "invalid form",
        errors: None,
      }),
      Rejected,
    ),
    (
      Api(status=401, error={ code: 0, message: "unauthorized", errors: None, }),
      Rejected,
    ),
    (
      Api(status=499, error={ code: 0, message: "rejected", errors: None, }),
      Rejected,
    ),
    (
      Api(status=400, error={
        code: 40060,
        message: "acknowledged",
        errors: None,
      }),
      Uncertain,
    ),
    (
      Api(status=429, error={ code: 0, message: "rate limited", errors: None, }),
      Uncertain,
    ),
    (
      Api(status=500, error={ code: 0, message: "server error", errors: None, }),
      Uncertain,
    ),
    (RateLimited(retry_after_ms=1000, global=false), Uncertain),
    (Transport(phase=Pool, message="client is closed"), Unsent),
    (Transport(phase=Dial, message="refused"), Unsent),
    (Timeout(phase=Pool, timeout_ms=100), Unsent),
    (Timeout(phase=Dial, timeout_ms=100), Unsent),
    (Transport(phase=Write, message="connection lost"), Uncertain),
    (Transport(phase=Head, message="connection lost"), Uncertain),
    (Transport(phase=Body, message="connection lost"), Uncertain),
    (Transport(phase=Unknown, message="connection lost"), Uncertain),
    (Timeout(phase=Write, timeout_ms=100), Uncertain),
    (Timeout(phase=Head, timeout_ms=100), Uncertain),
    (Timeout(phase=Body, timeout_ms=100), Uncertain),
    (Timeout(phase=Unknown, timeout_ms=100), Uncertain),
    (Deserialize(message="invalid response"), Uncertain),
  ]
  for (error, expected) in cases {
    let client = @dhttp.Client("test-token")
    defer client.close()
    client.middleware((_, _) => {
      match error {
        Api(status~, error~) =>
          { status, headers: Map([]), body: error.to_json(), }
        error => raise error
      }
    })
    let gate = @framework.ResponseGate::rest(client, gate_interaction(2))
    try gate.send({ typ: ChannelMessageWithSource, data: None, }) catch {
      @dhttp.DiscordHttpError::Validation(..)
      | @dhttp.DiscordHttpError::Api(..)
      | @dhttp.DiscordHttpError::RateLimited(..)
      | @dhttp.DiscordHttpError::Transport(..)
      | @dhttp.DiscordHttpError::Timeout(..)
      | @dhttp.DiscordHttpError::Deserialize(..) => ()
      other => fail("unexpected error: \{Repr(other)}")
    } noraise {
      _ => fail("expected sink failure")
    }
    assert_eq(@framework.classify_rest_callback_failure(error), expected)
    // A transport failure is `Unsent` exactly when the error proves it.
    if error is (Transport(..) | Timeout(..)) {
      assert_eq(error.is_unsent(), expected == Unsent)
    }
    let state : @framework.ResponseState = match expected {
      Rejected | Unsent => Pending
      Expired => Expired
      Uncertain => Unconfirmed(ChannelMessageWithSource)
      @framework.DeliveryFailure::.. => fail("unexpected delivery failure")
    }
    assert_eq(gate.state(), state)
    assert_eq(gate.is_pending(), expected is (Rejected | Unsent))
    gate.expire()
    if expected == Uncertain {
      assert_eq(gate.state(), Unconfirmed(ChannelMessageWithSource))
    }
  }
}

///|
async test "cancellation bypasses the rejection classifier" {
  let started : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let classified = Ref(false)
  let gate = @framework.ResponseGate(
    ApplicationCommand,
    (_, _) => {
      started.put(())
      @async.sleep(60_000)
    },
    classify=_ => {
      classified.val = true
      Rejected
    },
  )
  @async.with_task_group(group => {
    let task = group.spawn(no_wait=true, allow_failure=true, () => {
      gate.send({ typ: DeferredChannelMessageWithSource, data: None, })
    })
    started.get()
    task.cancel()
    try task.wait() catch {
      @async.WaitedTaskAlreadyCancelled => ()
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected cancellation")
    }
  })
  assert_false(classified.val)
  assert_eq(gate.state(), Unconfirmed(DeferredChannelMessageWithSource))
}

///|
/// A wire on which every connection is refused, so no callback reaches
/// Discord.
struct RefusingTransport {
  mut attempts : Int32
}

///|
impl @runtime.Backend for RefusingTransport with fn send(
  self,
  _request,
  _options,
) {
  self.attempts += 1
  raise @ghttp.TransportError(kind=Connect, phase=Dial, detail="refused")
}

///|
async test "a callback that never reached Discord leaves the window open" {
  let transport = RefusingTransport::{ attempts: 0, }
  let client = @dhttp.Client("test-token", transport~, max_retries=0)
  defer client.close()
  let gate = @framework.ResponseGate::rest(client, gate_interaction(2))
  try gate.send({ typ: DeferredChannelMessageWithSource, data: None, }) catch {
    @dhttp.DiscordHttpError::Transport(phase=Dial, ..) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the refused connection")
  }
  assert_eq(transport.attempts, 1)
  assert_eq(gate.state(), Pending)
  assert_false(gate.placeholder_open())
}
