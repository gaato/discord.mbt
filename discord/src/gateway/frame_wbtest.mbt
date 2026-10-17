///|
test "decode_hello reads the heartbeat interval from opcode 10 only" {
  assert_eq(
    decode_hello({ "op": 10, "d": { "heartbeat_interval": 41250 } }),
    Some(41250),
  )
  assert_eq(
    decode_hello({ "op": 11, "d": { "heartbeat_interval": 41250 } }),
    None,
  )
  assert_eq(decode_hello({ "op": 10, "d": {} }), None)
  assert_eq(decode_hello({ "op": 10 }), None)
}

///|
fn frame_label(frame : Frame) -> String {
  match frame {
    Dispatch(t~, seq~, d~) => {
      let seq = match seq {
        Some(seq) => seq.to_string()
        None => "none"
      }
      "dispatch \{t}, seq=\{seq}, d=\{d.stringify()}"
    }
    HeartbeatRequest => "heartbeat request"
    Reconnect => "reconnect"
    InvalidSession(resumable~) => "invalid session, resumable=\{resumable}"
    HeartbeatAck => "heartbeat ack"
    Ignored => "ignored"
  }
}

///|
test "decode_frame classifies opcodes" {
  let rows : Array[(Json, String)] = [
    (
      { "op": 0, "t": "MESSAGE_CREATE", "s": 42, "d": { "id": "1" } },
      "dispatch MESSAGE_CREATE, seq=42, d={\"id\":\"1\"}",
    ),
    (
      { "op": 0, "t": "MESSAGE_CREATE", "s": Json::null(), "d": {} },
      "dispatch MESSAGE_CREATE, seq=none, d={}",
    ),
    ({ "op": 0, "s": 42, "d": {} }, "ignored"),
    ({ "op": 0, "t": "MESSAGE_CREATE", "d": {} }, "ignored"),
    ({ "op": 0, "t": "MESSAGE_CREATE", "s": 42 }, "ignored"),
    ({ "op": 1, "d": Json::null() }, "heartbeat request"),
    ({ "op": 7, "d": Json::null() }, "reconnect"),
    ({ "op": 9, "d": true }, "invalid session, resumable=true"),
    ({ "op": 9, "d": false }, "invalid session, resumable=false"),
    ({ "op": 9, "d": Json::null() }, "invalid session, resumable=false"),
    ({ "op": 11 }, "heartbeat ack"),
    ({ "op": 10, "d": { "heartbeat_interval": 41250 } }, "ignored"),
    ({ "t": "READY", "d": {} }, "ignored"),
    ({ "op": "0", "t": "READY", "s": 1, "d": {} }, "ignored"),
  ]
  for row in rows {
    let (frame, expected) = row
    assert_eq(frame_label(decode_frame(frame)), expected, msg=frame.stringify())
  }
}

///|
test "ready_session opens a session from READY" {
  let ready : Json = {
    "session_id": "abc",
    "resume_gateway_url": "wss://resume.example",
  }
  debug_inspect(
    ready_session(ready, Some(7)),
    content=(
      #|Some({ id: "abc", resume_url: "wss://resume.example", sequence: 7 })
    ),
  )
  debug_inspect(
    ready_session(ready, None),
    content=(
      #|Some({ id: "abc", resume_url: "wss://resume.example", sequence: 0 })
    ),
  )
  debug_inspect(ready_session({ "session_id": "abc" }, Some(7)), content="None")
}

///|
test "identify_payload omits capabilities and carries the presence" {
  let payload = identify_payload(
    token="tok",
    intents=@model.Intents::none(),
    shard_id=1,
    shard_count=2,
    capabilities=@model.GatewayCapabilities::none(),
    presence=Some(@model.UpdatePresence(status=Idle)),
  )
  guard payload is { "op": Number(2, ..), "d": Object(data), .. } else {
    fail("unexpected identify: \{payload.stringify()}")
  }
  json_inspect(data.keys().collect(), content=[
    "token", "intents", "shard", "properties", "presence",
  ])
  json_inspect(data["shard"], content=[1, 2])
  json_inspect(data["presence"], content={
    "status": "idle",
    "activities": [],
    "afk": false,
    "since": null,
  })
}

///|
test "resume_payload carries the session id and sequence" {
  json_inspect(
    resume_payload(token="tok", {
      id: "abc",
      resume_url: "wss://r",
      sequence: 9,
    }),
    content={ "op": 6, "d": { "token": "tok", "session_id": "abc", "seq": 9 } },
  )
}
