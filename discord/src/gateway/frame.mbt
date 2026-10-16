///|
/// A decoded Gateway payload after Hello, reduced to what the read loop acts
/// on. Malformed and unhandled payloads decode to `Ignored`.
priv enum Frame {
  Dispatch(t~ : String, seq~ : Int64?, d~ : Json)
  HeartbeatRequest
  Reconnect
  InvalidSession(resumable~ : Bool)
  HeartbeatAck
  Ignored
}

///|
/// The heartbeat interval from opcode 10 Hello, or `None` for any other
/// payload.
fn decode_hello(frame : Json) -> Int32? {
  guard frame
    is {
      "op": Number(10, ..),
      "d": { "heartbeat_interval": Number(interval, ..), .. },
      ..
    } else {
    return None
  }
  Some(interval.to_int())
}

///|
fn decode_frame(frame : Json) -> Frame {
  guard frame is { "op": Number(op, ..), .. } else { return Ignored }
  match op.to_int() {
    0 => {
      guard frame is { "t": String(t), "s": s, "d": d, .. } else {
        return Ignored
      }
      let seq = if s is Number(seq, ..) { Some(seq.to_int64()) } else { None }
      Dispatch(t~, seq~, d~)
    }
    1 => HeartbeatRequest
    7 => Reconnect
    9 => InvalidSession(resumable=frame is { "d": True, .. })
    11 => HeartbeatAck
    _ => Ignored
  }
}

///|
/// The session READY opens; a READY without a sequence starts at 0.
fn ready_session(d : Json, seq : Int64?) -> Session? {
  guard d
    is {
      "session_id": String(session_id),
      "resume_gateway_url": String(resume_url),
      ..
    } else {
    return None
  }
  Some({ id: session_id, resume_url, sequence: seq.unwrap_or(0L), })
}

///|
/// Opcode 2 Identify. Capabilities are sent only when opted in.
fn identify_payload(
  token~ : String,
  intents~ : @model.Intents,
  shard_id~ : Int32,
  shard_count~ : Int32,
  capabilities~ : @model.GatewayCapabilities,
  presence~ : @model.UpdatePresence?,
) -> Json {
  let data : Map[String, Json] = {
    "token": Json::string(token),
    "intents": intents.to_json(),
    "shard": [
      Json::number(shard_id.to_double()),
      Json::number(shard_count.to_double()),
    ],
    "properties": {
      "os": Json::string(identify_os()),
      "browser": "discord.mbt",
      "device": "discord.mbt",
    },
  }
  if capabilities != @model.GatewayCapabilities::none() {
    data["capabilities"] = capabilities.to_json()
  }
  if presence is Some(presence) {
    data["presence"] = presence.to_json()
  }
  { "op": 2, "d": Json::object(data) }
}

///|
/// Opcode 6 Resume.
fn resume_payload(token~ : String, session : Session) -> Json {
  {
    "op": 6,
    "d": {
      "token": Json::string(token),
      "session_id": Json::string(session.id),
      "seq": Json::number(session.sequence.to_double()),
    },
  }
}
