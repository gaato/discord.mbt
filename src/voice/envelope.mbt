///|
/// A decoded voice gateway v8 message.
pub(all) enum VoiceMessage {
  Ready(ssrc~ : UInt, ip~ : String, port~ : Int, modes~ : Array[String])
  Hello(heartbeat_interval~ : Int)
  SessionDescription(
    mode~ : String,
    secret_key~ : Bytes,
    dave_protocol_version~ : Int
  )
  HeartbeatAck(nonce~ : Int64)
  Speaking(ssrc~ : UInt, user_id~ : String, flags~ : Int)
  ClientsConnect(user_ids~ : Array[String])
  ClientDisconnect(user_id~ : String)
  Resumed
  DavePrepareTransition(transition_id~ : Int, protocol_version~ : Int)
  DaveExecuteTransition(transition_id~ : Int)
  DavePrepareEpoch(epoch~ : Int, protocol_version~ : Int)
  DaveMlsExternalSender(payload~ : Bytes)
  DaveMlsProposals(payload~ : Bytes)
  DaveMlsAnnounceCommitTransition(transition_id~ : Int, commit~ : Bytes)
  DaveMlsWelcome(transition_id~ : Int, welcome~ : Bytes)
  Unknown(op~ : Int)
} derive(Debug, Eq)

///|
/// A malformed JSON or binary voice gateway envelope.
pub(all) suberror VoiceEnvelopeError {
  InvalidTextFrame(reason~ : String)
  InvalidBinaryFrame(reason~ : String)
} derive(Debug, Eq)

///|
fn invalid_text(reason : String) -> VoiceEnvelopeError {
  InvalidTextFrame(reason~)
}

///|
fn int_field(value : Json, field : String) -> Int raise VoiceEnvelopeError {
  guard value is Number(number, ..) else {
    raise invalid_text("expected numeric field \{field}")
  }
  let integer = number.to_int()
  if integer.to_double() != number {
    raise invalid_text("expected integer field \{field}")
  }
  integer
}

///|
fn uint_field(value : Json, field : String) -> UInt raise VoiceEnvelopeError {
  guard value is Number(number, ..) && number >= 0.0 else {
    raise invalid_text("expected unsigned field \{field}")
  }
  let integer = number.to_uint()
  if integer.to_double() != number {
    raise invalid_text("expected unsigned integer field \{field}")
  }
  integer
}

///|
fn int64_field(value : Json, field : String) -> Int64 raise VoiceEnvelopeError {
  guard value is Number(number, ..) else {
    raise invalid_text("expected numeric field \{field}")
  }
  let integer = number.to_int64()
  if integer.to_double() != number {
    raise invalid_text("expected integer field \{field}")
  }
  integer
}

///|
fn string_array(
  value : Json,
  field : String,
) -> Array[String] raise VoiceEnvelopeError {
  guard value is Array(values) else {
    raise invalid_text("expected array field \{field}")
  }
  let result : Array[String] = []
  for value in values {
    guard value is String(item) else {
      raise invalid_text("expected string values in \{field}")
    }
    result.push(item)
  }
  result
}

///|
fn byte_array(value : Json, field : String) -> Bytes raise VoiceEnvelopeError {
  guard value is Array(values) else {
    raise invalid_text("expected array field \{field}")
  }
  let result : Array[Byte] = []
  for value in values {
    let item = int_field(value, field)
    if item < 0 || item > 255 {
      raise invalid_text("byte outside 0..255 in \{field}")
    }
    result.push(item.to_byte())
  }
  Bytes::from_array(result)
}

///|
/// Decode a JSON voice gateway message and return its optional top-level
/// buffered-resume sequence number.
pub fn parse_text_frame(
  text : String,
) -> (VoiceMessage, Int?) raise VoiceEnvelopeError {
  let root = @json.parse(text) catch {
    error => raise invalid_text("invalid JSON: \{error}")
  }
  guard root is { "op": op_value, "d": data, .. } else {
    raise invalid_text("expected top-level op and d")
  }
  let op = int_field(op_value, "op")
  let seq = match root {
    { "seq": value, .. } => Some(int_field(value, "seq"))
    _ => None
  }
  let message = match op {
    2 => {
      guard data
        is { "ssrc": ssrc, "ip": String(ip), "port": port, "modes": modes, .. } else {
        raise invalid_text("invalid Ready payload")
      }
      VoiceMessage::Ready(
        ssrc=uint_field(ssrc, "ssrc"),
        ip~,
        port=int_field(port, "port"),
        modes=string_array(modes, "modes"),
      )
    }
    4 => {
      guard data
        is {
          "mode": String(mode),
          "secret_key": secret_key,
          "dave_protocol_version": version,
          ..
        } else {
        raise invalid_text("invalid Session Description payload")
      }
      SessionDescription(
        mode~,
        secret_key=byte_array(secret_key, "secret_key"),
        dave_protocol_version=int_field(version, "dave_protocol_version"),
      )
    }
    5 => {
      guard data
        is { "ssrc": ssrc, "user_id": String(user_id), "speaking": flags, .. } else {
        raise invalid_text("invalid Speaking payload")
      }
      Speaking(
        ssrc=uint_field(ssrc, "ssrc"),
        user_id~,
        flags=int_field(flags, "speaking"),
      )
    }
    6 => {
      guard data is { "t": nonce, .. } else {
        raise invalid_text("invalid Heartbeat ACK payload")
      }
      HeartbeatAck(nonce=int64_field(nonce, "t"))
    }
    8 => {
      guard data is { "heartbeat_interval": interval, .. } else {
        raise invalid_text("invalid Hello payload")
      }
      Hello(heartbeat_interval=int_field(interval, "heartbeat_interval"))
    }
    9 => Resumed
    11 => {
      guard data is { "user_ids": user_ids, .. } else {
        raise invalid_text("invalid Clients Connect payload")
      }
      ClientsConnect(user_ids=string_array(user_ids, "user_ids"))
    }
    13 => {
      guard data is { "user_id": String(user_id), .. } else {
        raise invalid_text("invalid Client Disconnect payload")
      }
      ClientDisconnect(user_id~)
    }
    21 => {
      guard data
        is {
          "transition_id": transition_id,
          "protocol_version": protocol_version,
          ..
        } else {
        raise invalid_text("invalid DAVE Prepare Transition payload")
      }
      DavePrepareTransition(
        transition_id=int_field(transition_id, "transition_id"),
        protocol_version=int_field(protocol_version, "protocol_version"),
      )
    }
    22 => {
      guard data is { "transition_id": transition_id, .. } else {
        raise invalid_text("invalid DAVE Execute Transition payload")
      }
      DaveExecuteTransition(
        transition_id=int_field(transition_id, "transition_id"),
      )
    }
    24 => {
      guard data is { "epoch": epoch, "protocol_version": protocol_version, .. } else {
        raise invalid_text("invalid DAVE Prepare Epoch payload")
      }
      DavePrepareEpoch(
        epoch=int_field(epoch, "epoch"),
        protocol_version=int_field(protocol_version, "protocol_version"),
      )
    }
    other => Unknown(op=other)
  }
  (message, seq)
}

///|
/// Decode a server-to-client binary DAVE frame. Its first two bytes are the
/// big-endian v8 sequence number and the third byte is the opcode.
pub fn parse_binary_frame(
  bytes : Bytes,
) -> (VoiceMessage, Int?) raise VoiceEnvelopeError {
  if bytes.length() < 3 {
    raise InvalidBinaryFrame(reason="frame is shorter than sequence and opcode")
  }
  let seq = (bytes[0].to_int() << 8) | bytes[1].to_int()
  let op = bytes[2].to_int()
  let payload = bytes[3:].to_owned()
  let message = match op {
    25 => DaveMlsExternalSender(payload~)
    27 => DaveMlsProposals(payload~)
    29 | 30 => {
      if payload.length() < 2 {
        raise InvalidBinaryFrame(
          reason="opcode \{op} payload is missing transition_id",
        )
      }
      let transition_id = (payload[0].to_int() << 8) | payload[1].to_int()
      let mls_message = payload[2:].to_owned()
      if op == 29 {
        DaveMlsAnnounceCommitTransition(transition_id~, commit=mls_message)
      } else {
        DaveMlsWelcome(transition_id~, welcome=mls_message)
      }
    }
    other => Unknown(op=other)
  }
  (message, Some(seq))
}

///|
pub fn encode_identify(
  server_id~ : String,
  user_id~ : String,
  session_id~ : String,
  token~ : String,
) -> Json {
  {
    "op": 0,
    "d": {
      "server_id": Json::string(server_id),
      "user_id": Json::string(user_id),
      "session_id": Json::string(session_id),
      "token": Json::string(token),
      "max_dave_protocol_version": 1,
    },
  }
}

///|
pub fn encode_heartbeat(t~ : Int64, seq_ack~ : Int) -> Json {
  {
    "op": 3,
    "d": {
      "t": Json::number(t.to_double(), repr=t.to_string()),
      "seq_ack": seq_ack,
    },
  }
}

///|
pub fn encode_select_protocol(
  address~ : String,
  port~ : Int,
  mode~ : String,
) -> Json {
  {
    "op": 1,
    "d": {
      "protocol": "udp",
      "data": {
        "address": Json::string(address),
        "port": port,
        "mode": Json::string(mode),
      },
    },
  }
}

///|
pub fn encode_speaking(ssrc~ : UInt, flags~ : Int, delay? : Int = 0) -> Json {
  {
    "op": 5,
    "d": {
      "speaking": flags,
      "delay": delay,
      "ssrc": Json::number(ssrc.to_double()),
    },
  }
}

///|
pub fn encode_resume(
  server_id~ : String,
  session_id~ : String,
  token~ : String,
  seq_ack~ : Int,
) -> Json {
  {
    "op": 7,
    "d": {
      "server_id": Json::string(server_id),
      "session_id": Json::string(session_id),
      "token": Json::string(token),
      "seq_ack": seq_ack,
    },
  }
}

///|
pub fn encode_transition_ready(transition_id~ : Int) -> Json {
  { "op": 23, "d": { "transition_id": transition_id } }
}

///|
pub fn encode_invalid_commit_welcome(transition_id~ : Int) -> Json {
  { "op": 31, "d": { "transition_id": transition_id } }
}

///|
/// Prefix a client-to-server binary DAVE payload with its one-byte opcode.
pub fn encode_binary_client_frame(op : Int, payload : Bytes) -> Bytes {
  let bytes : Array[Byte] = [op.to_byte()]
  for byte in payload {
    bytes.push(byte)
  }
  Bytes::from_array(bytes)
}
