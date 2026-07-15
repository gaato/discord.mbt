///|
test "text envelopes decode v8 voice and DAVE opcodes" {
  let (ready, seq) = @voice.parse_text_frame(
    (
      #|{"op":2,"seq":7,"d":{"ssrc":42,"ip":"127.0.0.1","port":5000,"modes":["aead_aes256_gcm_rtpsize","aead_xchacha20_poly1305_rtpsize"]}}
    ),
  )
  guard ready
    is Ready(
      ssrc=42,
      ip="127.0.0.1",
      port=5000,
      modes=["aead_aes256_gcm_rtpsize", ..]
    ) else {
    fail("unexpected Ready: \{to_repr(ready)}")
  }
  assert_eq(seq, Some(7))
  let cases : Array[(String, @voice.VoiceMessage)] = [
    (
      "{\"op\":8,\"d\":{\"heartbeat_interval\":45000}}",
      Hello(heartbeat_interval=45000),
    ),
    (
      "{\"op\":4,\"d\":{\"mode\":\"aead_aes256_gcm_rtpsize\",\"secret_key\":[0,1,254,255],\"dave_protocol_version\":1}}",
      SessionDescription(
        mode="aead_aes256_gcm_rtpsize",
        secret_key=b"\x00\x01\xfe\xff",
        dave_protocol_version=1,
      ),
    ),
    ("{\"op\":6,\"d\":{\"t\":123456789}}", HeartbeatAck(nonce=123456789L)),
    (
      "{\"op\":5,\"d\":{\"ssrc\":99,\"user_id\":\"123\",\"speaking\":3}}",
      Speaking(ssrc=99, user_id="123", flags=3),
    ),
    (
      "{\"op\":11,\"d\":{\"user_ids\":[\"1\",\"2\"]}}",
      ClientsConnect(user_ids=["1", "2"]),
    ),
    ("{\"op\":13,\"d\":{\"user_id\":\"2\"}}", ClientDisconnect(user_id="2")),
    ("{\"op\":9,\"d\":null}", Resumed),
    (
      "{\"op\":21,\"d\":{\"transition_id\":5,\"protocol_version\":1}}",
      DavePrepareTransition(transition_id=5, protocol_version=1),
    ),
    (
      "{\"op\":22,\"d\":{\"transition_id\":5}}",
      DaveExecuteTransition(transition_id=5),
    ),
    (
      "{\"op\":24,\"d\":{\"transition_id\":6,\"epoch\":2}}",
      DavePrepareEpoch(transition_id=6, epoch=2),
    ),
    ("{\"op\":99,\"d\":{}}", Unknown(op=99)),
  ]
  for case in cases {
    let (text, expected) = case
    let (actual, sequence) = @voice.parse_text_frame(text)
    assert_eq(actual, expected)
    assert_eq(sequence, None)
  }
}

///|
test "binary envelopes decode sequence and DAVE payload layouts" {
  let (external_sender, seq) = @voice.parse_binary_frame(
    b"\x00\x0A\x19external",
  )
  assert_eq(external_sender, DaveMlsExternalSender(payload=b"external"))
  assert_eq(seq, Some(10))
  let (proposals, _) = @voice.parse_binary_frame(b"\x00\x0B\x1Bprops")
  assert_eq(proposals, DaveMlsProposals(payload=b"props"))
  let (commit, _) = @voice.parse_binary_frame(b"\x00\x0C\x1D\x12\x34commit")
  assert_eq(
    commit,
    DaveMlsAnnounceCommitTransition(transition_id=0x1234, commit=b"commit"),
  )
  let (welcome, _) = @voice.parse_binary_frame(b"\x00\x0D\x1E\x00\x09welcome")
  assert_eq(welcome, DaveMlsWelcome(transition_id=9, welcome=b"welcome"))
  assert_eq(
    @voice.encode_binary_client_frame(26, b"key-package"),
    b"\x1Akey-package",
  )
}

///|
test "client JSON encoders produce the v8 wire shapes" {
  let identify = @voice.encode_identify(
    server_id="guild",
    user_id="user",
    session_id="session",
    token="token",
  )
  guard identify
    is {
      "op": Number(0, ..),
      "d": {
        "server_id": String("guild"),
        "user_id": String("user"),
        "session_id": String("session"),
        "token": String("token"),
        "max_dave_protocol_version": Number(1, ..),
        ..
      },
      ..
    }
  let heartbeat = @voice.encode_heartbeat(t=123L, seq_ack=-1)
  guard heartbeat
    is {
      "op": Number(3, ..),
      "d": { "t": Number(123, ..), "seq_ack": Number(-1, ..), .. },
      ..
    }
  let selected = @voice.encode_select_protocol(
    address="203.0.113.1",
    port=6000,
    mode="aead_xchacha20_poly1305_rtpsize",
  )
  guard selected
    is {
      "op": Number(1, ..),
      "d": {
        "protocol": String("udp"),
        "data": {
          "address": String("203.0.113.1"),
          "port": Number(6000, ..),
          "mode": String("aead_xchacha20_poly1305_rtpsize"),
          ..
        },
        ..
      },
      ..
    }
  guard @voice.encode_speaking(ssrc=42, flags=1)
    is {
      "op": Number(5, ..),
      "d": {
        "speaking": Number(1, ..),
        "delay": Number(0, ..),
        "ssrc": Number(42, ..),
        ..
      },
      ..
    }
  guard @voice.encode_resume(
      server_id="guild",
      session_id="session",
      token="token",
      seq_ack=12,
    )
    is { "op": Number(7, ..), "d": { "seq_ack": Number(12, ..), .. }, .. }
  guard @voice.encode_transition_ready(transition_id=9)
    is { "op": Number(23, ..), "d": { "transition_id": Number(9, ..), .. }, .. }
  guard @voice.encode_invalid_commit_welcome(transition_id=9)
    is { "op": Number(31, ..), "d": { "transition_id": Number(9, ..), .. }, .. }
  // Stringification and parsing preserve the complete public encoder value.
  assert_eq(@json.parse(identify.stringify()), identify)
  assert_eq(@json.parse(heartbeat.stringify()), heartbeat)
}
