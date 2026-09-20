///|
async test "REST gate only reopens for definitive rejection" {
  let cases : Array[(@dhttp.DiscordHttpError, Bool)] = [
    (Validation(message="invalid payload"), true),
    (
      Api(status=400, error={
        code: 50035,
        message: "invalid form",
        errors: None,
      }),
      true,
    ),
    (
      Api(status=401, error={ code: 0, message: "unauthorized", errors: None, }),
      true,
    ),
    (
      Api(status=499, error={ code: 0, message: "rejected", errors: None, }),
      true,
    ),
    (
      Api(status=400, error={
        code: 40060,
        message: "acknowledged",
        errors: None,
      }),
      false,
    ),
    (
      Api(status=429, error={ code: 0, message: "rate limited", errors: None, }),
      false,
    ),
    (
      Api(status=500, error={ code: 0, message: "server error", errors: None, }),
      false,
    ),
    (RateLimited(retry_after_ms=1000, global=false), false),
    (Transport(message="connection lost"), false),
    (Timeout(timeout_ms=100), false),
    (Deserialize(message="invalid response"), false),
  ]
  for (error, rejected) in cases {
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
    assert_eq(
      gate.state(),
      if rejected {
        Pending
      } else {
        Unconfirmed(ChannelMessageWithSource)
      },
    )
    assert_eq(gate.responded(), !rejected)
    if !rejected {
      gate.expire()
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
    rejected=_ => {
      classified.val = true
      true
    },
  )
  @async.with_task_group(group => {
    let task = group.spawn(no_wait=true, allow_failure=true, () => {
      gate.send({ typ: DeferredChannelMessageWithSource, data: None, })
    })
    started.get()
    task.cancel()
    try task.wait() catch {
      @async.TaskCancelled => ()
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected cancellation")
    }
  })
  assert_false(classified.val)
  assert_eq(gate.state(), Unconfirmed(DeferredChannelMessageWithSource))
}
