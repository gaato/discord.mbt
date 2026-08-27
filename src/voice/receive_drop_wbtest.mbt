///|
test "receive pipeline tracks membership without touching any cipher" {
  let telemetry : Array[VoiceTelemetry] = []
  let pipeline = ReceivePipeline::new(event => telemetry.push(event))
  assert_eq(
    pipeline.handle_gateway_message(Speaking(ssrc=5U, user_id="alice", flags=1)),
    [SpeakingChanged(user_id="alice", ssrc=5U, flags=1)],
  )
  assert_eq(
    pipeline.handle_gateway_message(ClientsConnect(user_ids=["alice", "bob"])),
    [UserConnected(user_id="alice"), UserConnected(user_id="bob")],
  )
  // Disconnecting a user releases every SSRC mapped to them.
  assert_eq(pipeline.users_by_ssrc.length(), 1)
  assert_eq(
    pipeline.handle_gateway_message(ClientDisconnect(user_id="alice")),
    [UserDisconnected(user_id="alice")],
  )
  assert_eq(pipeline.users_by_ssrc.length(), 0)
  // Non-membership messages produce no receive events.
  assert_eq(pipeline.handle_gateway_message(Hello(heartbeat_interval=1000)), [])
  assert_eq(telemetry, [])
}

///|
test "receive pipeline drops undecodable datagrams with telemetry" {
  if !shim_available() {
    return
  }
  let telemetry : Array[VoiceTelemetry] = []
  let pipeline = ReceivePipeline::new(event => telemetry.push(event))
  let cipher = TransportCipher::new(AeadAes256GcmRtpsize, Bytes::new(32))

  // Looks like RTP by its first byte but is too short to be a packet.
  assert_eq(
    pipeline.process_udp_packet(
      b"\x80\x00\x00\x00\x00\x00",
      cipher,
      None,
      arrival_ms=0L,
    ),
    [],
  )
  guard telemetry is [PacketDropped(reason=first_reason)] else {
    fail("expected a dropped-packet telemetry event")
  }
  assert_true(first_reason.contains("RTP"))

  // A valid RTP header whose payload fails authentication.
  let header = build_rtp_header(sequence=1, timestamp=960U, ssrc=9U)
  let tampered = header + Bytes::new(24)
  assert_eq(
    pipeline.process_udp_packet(tampered, cipher, None, arrival_ms=1L),
    [],
  )
  assert_eq(telemetry.length(), 2)
  guard telemetry[1] is PacketDropped(reason=second_reason) else {
    fail("expected a decrypt-failure drop")
  }
  assert_true(second_reason.contains("decrypt"))
}

///|
test "transport cipher rejects impossible packet geometry" {
  if !shim_available() {
    return
  }
  let cipher = TransportCipher::new(AeadAes256GcmRtpsize, Bytes::new(32))
  try cipher.open(Bytes::new(30), header_len=-1) catch {
    InvalidEncryptedPacket(reason~) =>
      assert_eq(reason, "invalid RTP header length")
    _ => fail("unexpected crypto error")
  } noraise {
    _ => fail("expected a header length error")
  }
  try cipher.open(Bytes::new(30), header_len=12) catch {
    InvalidEncryptedPacket(reason~) =>
      assert_eq(
        reason, "packet is shorter than authentication tag and nonce suffix",
      )
    _ => fail("unexpected crypto error")
  } noraise {
    _ => fail("expected a short packet error")
  }
}
