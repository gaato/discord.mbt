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
  assert_true(gate.responded())
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
      assert_false(gate.responded())
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
    rejected=_ => true,
  )
  try gate.send({ typ: ChannelMessageWithSource, data: None, }) catch {
    GateSinkError => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected sink failure")
  }
  assert_eq(gate.state(), Pending)
  assert_false(gate.responded())
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
  assert_true(gate.responded())
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
    GateSinkError => assert_true(gate.responded())
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
      @async.TaskCancelled => ()
      error => fail("unexpected cancellation error: \{Repr(error)}")
    } noraise {
      _ => fail("cancelled send unexpectedly completed")
    }
    assert_true(gate.responded())
    try gate.send({ typ: ChannelMessageWithSource, data: None, }) catch {
      @framework.ResponseGateError::AlreadyResponded => ()
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected AlreadyResponded")
    }
  })
}
