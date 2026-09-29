///|
fn gate_interaction(kind : Int) -> @model.Interaction raise {
  @json.from_json(
    @json.parse(
      (
        #|{
        #|  "id": "500000000000000010",
        #|  "application_id": "400000000000000001",
        #|  "type": KIND,
        #|  "token": "interaction-token",
        #|  "version": 1
        #|}
      ).replace(old="KIND", new=kind.to_string()),
    ),
  )
}

///|
async test "response gate captures one valid callback" {
  let (gate, capture) = @framework.ResponseGate::capture(gate_interaction(2))
  let response = @model.InteractionResponse::{
    typ: ChannelMessageWithSource,
    data: Some({ "content": "hello" }),
  }
  gate.send(response)
  assert_false(gate.is_pending())
  let captured = capture.get()
  assert_true(captured.response.typ == ChannelMessageWithSource)
  assert_true(captured.files is None)
  inspect(
    captured.response.to_json().stringify(),
    content=(
      #|{"type":4,"data":{"content":"hello"}}
    ),
  )
}

///|
async test "response gate rejects a second callback" {
  let (gate, _) = @framework.ResponseGate::capture(gate_interaction(2))
  gate.send({ typ: ChannelMessageWithSource, data: None, })
  try gate.send({ typ: DeferredChannelMessageWithSource, data: None, }) catch {
    @framework.ResponseGateError::AlreadyResponded => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected AlreadyResponded")
  }
}

///|
async test "response gate rejects modal callbacks for modal submits" {
  let (gate, _) = @framework.ResponseGate::capture(gate_interaction(5))
  try gate.send({ typ: Modal, data: None, }) catch {
    @framework.ResponseGateError::InvalidCallback(kind~, typ~) => {
      assert_true(kind == ModalSubmit)
      assert_true(typ == Modal)
      assert_true(gate.is_pending())
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected InvalidCallback")
  }
}

///|
priv suberror GateSinkError {
  GateSinkError
} derive(Debug)

///|
async test "state records the sent callback type" {
  let types : Array[@model.InteractionResponseType] = [
    ChannelMessageWithSource,
    DeferredChannelMessageWithSource,
    Modal,
  ]
  for typ in types {
    let (gate, capture) = @framework.ResponseGate::capture(gate_interaction(2))
    assert_eq(gate.state(), Pending)
    gate.send({ typ, data: None, })
    assert_eq(gate.state(), Sent(typ))
    assert_eq(capture.get().response.typ, typ)
  }
}

///|
async test "rejected sink error reopens the gate" {
  let calls = Ref(0)
  let gate = @framework.ResponseGate(
    ApplicationCommand,
    (_, _) => {
      calls.val += 1
      if calls.val == 1 {
        raise GateSinkError
      }
    },
    classify=_ => Rejected,
  )
  try gate.send({ typ: ChannelMessageWithSource, data: None, }) catch {
    GateSinkError => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected sink failure")
  }
  assert_eq(gate.state(), Pending)
  assert_true(gate.is_pending())
  gate.send({ typ: DeferredChannelMessageWithSource, data: None, })
  assert_eq(gate.state(), Sent(DeferredChannelMessageWithSource))
  assert_eq(calls.val, 2)
}

///|
async test "expire blocks later sends" {
  let (gate, capture) = @framework.ResponseGate::capture(gate_interaction(2))
  gate.expire()
  gate.expire()
  assert_eq(gate.state(), Expired)
  assert_false(gate.is_pending())
  try gate.send({ typ: ChannelMessageWithSource, data: None, }) catch {
    @framework.ResponseGateError::Expired => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected Expired")
  }
  assert_true(capture.try_get() is None)
}

///|
async test "expire after a sent callback is a no-op" {
  let (gate, capture) = @framework.ResponseGate::capture(gate_interaction(2))
  gate.send({ typ: Modal, data: None, })
  gate.expire()
  assert_eq(gate.state(), Sent(Modal))
  assert_eq(capture.get().response.typ, Modal)
}

///|
async test "response gate remains terminal after sink failure" {
  let gate = @framework.ResponseGate(ApplicationCommand, (_, _) => {
    raise GateSinkError
  })
  try gate.send({ typ: ChannelMessageWithSource, data: None, }) catch {
    GateSinkError => assert_false(gate.is_pending())
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected sink failure")
  }
  try gate.send({ typ: ChannelMessageWithSource, data: None, }) catch {
    @framework.ResponseGateError::AlreadyResponded => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected AlreadyResponded")
  }
}

///|
async test "response gate remains terminal after sink cancellation" {
  let sink_started : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let gate = @framework.ResponseGate(ApplicationCommand, (_, _) => {
    sink_started.put(())
    @async.sleep(3_600_000)
  })
  @async.with_task_group(group => {
    let send_task = group.spawn(no_wait=true, allow_failure=true, () => {
      gate.send({ typ: ChannelMessageWithSource, data: None, })
    })
    sink_started.get()
    send_task.cancel()
    try send_task.wait() catch {
      @async.WaitedTaskAlreadyCancelled => ()
      error => fail("unexpected cancellation error: \{Repr(error)}")
    } noraise {
      _ => fail("cancelled send unexpectedly completed")
    }
    assert_false(gate.is_pending())
    try gate.send({ typ: ChannelMessageWithSource, data: None, }) catch {
      @framework.ResponseGateError::AlreadyResponded => ()
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected AlreadyResponded")
    }
  })
}

///|
async test "a pending gate expires at its deadline" {
  let sent = Ref(0)
  let gate = @framework.ResponseGate(
    ApplicationCommand,
    (_, _) => sent.val += 1,
    deadline_ms=20,
  )
  assert_true(gate.remaining_ms() is Some(left) && left > 0 && left <= 20)
  assert_true(gate.is_pending())
  @async.sleep(40)
  assert_eq(gate.remaining_ms(), Some(0))
  assert_eq(gate.state(), Expired)
  try gate.send({ typ: ChannelMessageWithSource, data: None, }) catch {
    @framework.ResponseGateError::Expired => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected an expired gate")
  }
  assert_eq(sent.val, 0)
}

///|
async test "a gate without a deadline never expires on its own" {
  let gate = @framework.ResponseGate(ApplicationCommand, (_, _) => ())
  assert_eq(gate.remaining_ms(), None)
  assert_true(gate.is_pending())
}

///|
async test "only a deferred message opens the placeholder" {
  let deferred = @framework.ResponseGate(ApplicationCommand, (_, _) => ())
  deferred.send({ typ: DeferredChannelMessageWithSource, data: None, })
  assert_true(deferred.placeholder_open())
  deferred.close_placeholder()
  assert_false(deferred.placeholder_open())
  let message = @framework.ResponseGate(ApplicationCommand, (_, _) => ())
  message.send({ typ: ChannelMessageWithSource, data: None, })
  assert_false(message.placeholder_open())
  let rejected = @framework.ResponseGate(
    ApplicationCommand,
    (_, _) => raise GateSinkError,
    classify=_ => Rejected,
  )
  try
    rejected.send({ typ: DeferredChannelMessageWithSource, data: None, })
  catch {
    GateSinkError => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected sink failure")
  }
  assert_false(rejected.placeholder_open())
}

///|
async test "a concurrent send observes the in-flight callback's outcome" {
  let release : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let attempts = Ref(0)
  let gate = @framework.ResponseGate(
    ApplicationCommand,
    (_, _) => {
      attempts.val += 1
      if attempts.val == 1 {
        release.get()
        raise GateSinkError
      }
    },
    classify=_ => Rejected,
  )
  @async.with_task_group(group => {
    let first = group.spawn(allow_failure=true, () => {
      gate.send({ typ: DeferredChannelMessageWithSource, data: None, })
    })
    let second = group.spawn(() => {
      gate.send({ typ: ChannelMessageWithSource, data: None, })
    })
    release.put(())
    try first.wait() catch {
      GateSinkError => ()
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected the first delivery to fail")
    }
    second.wait()
  })
  // The rejected deferral reopened the window, so the waiting send went out.
  assert_eq(attempts.val, 2)
  assert_eq(gate.state(), Sent(ChannelMessageWithSource))
}

///|
async test "the token lifetime is counted from when the gate was built" {
  let interaction = @model.Interaction::{
    ..@json.from_json(
      @json.parse(
        (
          #|{"id":"500000000000000990","application_id":"400000000000000001","type":2,"token":"interaction-token","version":1,"data":{"id":"600000000000000100","name":"x","type":1}}
        ),
      ),
    ),
  }
  let (gate, _) = @framework.ResponseGate::capture(interaction)
  let fresh = gate.token_remaining_ms()
  assert_true(fresh <= @framework.INTERACTION_TOKEN_LIFETIME_MS)
  assert_true(fresh > @framework.INTERACTION_TOKEN_LIFETIME_MS - 1000)
  @async.sleep(30)
  assert_true(gate.token_remaining_ms() <= fresh - 30)
}
