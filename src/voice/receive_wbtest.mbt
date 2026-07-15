///|
struct ReceiveTestDave {
  decrypted_users : Array[String]
  decrypted_frames : Array[Bytes]
}

///|
impl DaveProvider for ReceiveTestDave with fn max_protocol_version(_self) {
  1
}

///|
impl DaveProvider for ReceiveTestDave with fn reinit(_self, protocol_version~) {
  ignore(protocol_version)
}

///|
impl DaveProvider for ReceiveTestDave with fn set_external_sender(
  _self,
  _payload,
) {

}

///|
impl DaveProvider for ReceiveTestDave with fn key_package(_self) {
  b"key"
}

///|
impl DaveProvider for ReceiveTestDave with fn process_proposals(
  _self,
  op_type~,
  _payload,
  recognized~,
) {
  ignore(op_type)
  ignore(recognized)
  (None, None)
}

///|
impl DaveProvider for ReceiveTestDave with fn process_commit(_self, _payload) {

}

///|
impl DaveProvider for ReceiveTestDave with fn process_welcome(_self, _payload) {

}

///|
impl DaveProvider for ReceiveTestDave with fn encrypt_frame(_self, frame) {
  frame
}

///|
impl DaveProvider for ReceiveTestDave with fn decrypt_frame(
  self,
  user_id~,
  frame,
) {
  self.decrypted_users.push(user_id)
  self.decrypted_frames.push(frame)
  b"decrypted-opus"
}

///|
impl DaveProvider for ReceiveTestDave with fn status(_self) {
  2
}

///|
test "receive pipeline strips RTP extensions and decrypts mapped DAVE frames" {
  if !shim_available() {
    return
  }
  let telemetry : Array[VoiceTelemetry] = []
  let pipeline = ReceivePipeline::new(event => telemetry.push(event))
  assert_eq(
    pipeline.handle_gateway_message(
      Speaking(ssrc=77U, user_id="speaker", flags=1),
    ),
    [SpeakingChanged(user_id="speaker", ssrc=77U, flags=1)],
  )
  let provider = ReceiveTestDave::{ decrypted_users: [], decrypted_frames: [] }
  let machine = DaveMachine::new(
    (provider : &DaveProvider),
    self_user_id="self",
  )
  machine.handle(
    SessionDescription(
      mode="aead_aes256_gcm_rtpsize",
      secret_key=Bytes::new(32),
      dave_protocol_version=1,
    ),
  )
  |> ignore
  let cipher = TransportCipher::new(AeadAes256GcmRtpsize, Bytes::new(32))
  let header = build_rtp_header(sequence=10, timestamp=960U, ssrc=77U)
  let encrypted_dave = cipher.seal(header~, b"encrypted\xFA\xFA")
  assert_eq(
    pipeline.process_udp_packet(
      encrypted_dave,
      cipher,
      Some(machine),
      dave_enabled=true,
      arrival_ms=0L,
    ),
    [
      OpusReceived(
        user_id=Some("speaker"),
        ssrc=77U,
        sequence=10,
        timestamp=960U,
        opus=b"decrypted-opus",
      ),
    ],
  )
  assert_eq(provider.decrypted_users, ["speaker"])
  assert_eq(provider.decrypted_frames, [b"encrypted\xFA\xFA"])

  let base = build_rtp_header(sequence=1, timestamp=1920U, ssrc=88U)
  let extension_header = b"\x90" + base[1:].to_owned() + b"\xBE\xDE\x00\x01"
  let encrypted_extension = cipher.seal(
    header=extension_header,
    b"\x12\x34\x56\x78opus-after-extension",
  )
  assert_eq(
    pipeline.process_udp_packet(
      encrypted_extension,
      cipher,
      None,
      dave_enabled=false,
      arrival_ms=1L,
    ),
    [
      OpusReceived(
        user_id=None,
        ssrc=88U,
        sequence=1,
        timestamp=1920U,
        opus=b"opus-after-extension",
      ),
    ],
  )
  assert_eq(telemetry, [])
}

///|
test "receive pipeline drops an unmapped encrypted DAVE sender with telemetry" {
  if !shim_available() {
    return
  }
  let telemetry : Array[VoiceTelemetry] = []
  let pipeline = ReceivePipeline::new(event => telemetry.push(event))
  let cipher = TransportCipher::new(AeadAes256GcmRtpsize, Bytes::new(32))
  let header = build_rtp_header(sequence=1, timestamp=960U, ssrc=99U)
  let datagram = cipher.seal(header~, b"encrypted\xFA\xFA")
  assert_eq(
    pipeline.process_udp_packet(
      datagram,
      cipher,
      None,
      dave_enabled=true,
      arrival_ms=0L,
    ),
    [],
  )
  assert_eq(telemetry, [
    DaveDecryptDropped(
      user_id=None,
      ssrc=99U,
      count=1,
      reason="DAVE frame has no mapped sender",
    ),
  ])
  assert_eq(
    pipeline.process_udp_packet(
      b"keepalive",
      cipher,
      None,
      dave_enabled=false,
      arrival_ms=1L,
    ),
    [],
  )
}
