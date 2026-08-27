///|
struct ReceiveTestDave {
  decrypted_users : Array[UInt64]
  decrypted_frames : Array[Bytes]
  remote_users : Set[UInt64]
  mut active_version : Int
  reject_unmarked_frames : Bool
}

///|
impl DaveBackend for ReceiveTestDave with fn protocol_version(_self) {
  1
}

///|
impl DaveBackend for ReceiveTestDave with fn reinitialize(
  _self,
  protocol_version~,
) {
  ignore(protocol_version)
}

///|
impl DaveBackend for ReceiveTestDave with fn reset(_self) {

}

///|
impl DaveBackend for ReceiveTestDave with fn set_external_sender(
  _self,
  _payload,
) {

}

///|
impl DaveBackend for ReceiveTestDave with fn key_package(_self) {
  b"key"
}

///|
impl DaveBackend for ReceiveTestDave with fn process_proposals(
  _self,
  _payload,
  recognized_user_ids~,
) {
  ignore(recognized_user_ids)
  b"commit-and-welcome"
}

///|
impl DaveBackend for ReceiveTestDave with fn process_commit(_self, _payload) {
  CommitIgnored
}

///|
impl DaveBackend for ReceiveTestDave with fn process_welcome(
  _self,
  _payload,
  recognized_user_ids~,
) {
  ignore(recognized_user_ids)
  WelcomeApplied(changes=[])
}

///|
impl DaveBackend for ReceiveTestDave with fn prepare_remote_ratchet(
  self,
  user_id~,
  protocol_version~,
) {
  ignore(protocol_version)
  self.remote_users.add(user_id)
}

///|
impl DaveBackend for ReceiveTestDave with fn has_remote(self, user_id~) {
  self.remote_users.contains(user_id)
}

///|
impl DaveBackend for ReceiveTestDave with fn remove_remote(self, user_id~) {
  self.remote_users.remove(user_id)
}

///|
impl DaveBackend for ReceiveTestDave with fn activate_self_ratchet(
  self,
  protocol_version~,
) {
  self.active_version = protocol_version
}

///|
impl DaveBackend for ReceiveTestDave with fn active_protocol_version(self) {
  self.active_version
}

///|
impl DaveBackend for ReceiveTestDave with fn encrypt_opus(_self, ssrc~, frame) {
  ignore(ssrc)
  frame
}

///|
impl DaveBackend for ReceiveTestDave with fn decrypt_opus(self, user_id~, frame) {
  self.decrypted_users.push(user_id)
  self.decrypted_frames.push(frame)
  if self.reject_unmarked_frames && !has_dave_magic(frame) {
    raise DaveInvalid(reason="libdave rejected an unencrypted Opus frame")
  }
  b"decrypted-opus"
}

///|
fn ReceiveTestDave::new(
  active_version~ : Int,
  remote_users? : Array[UInt64] = [],
  reject_unmarked_frames? : Bool = false,
) -> ReceiveTestDave {
  {
    decrypted_users: [],
    decrypted_frames: [],
    remote_users: Set(remote_users),
    active_version,
    reject_unmarked_frames,
  }
}

///|
fn receive_test_machine(provider : ReceiveTestDave) -> DaveMachine {
  DaveMachine::new_with_backend((provider : &DaveBackend), self_user_id=100UL)
}

///|
test "receive pipeline strips RTP extensions and decrypts mapped DAVE frames" {
  if !shim_available() {
    return
  }
  let telemetry : Array[VoiceTelemetry] = []
  let pipeline = ReceivePipeline::new(event => telemetry.push(event))
  assert_eq(
    pipeline.handle_gateway_message(Speaking(ssrc=77U, user_id="200", flags=1)),
    [SpeakingChanged(user_id="200", ssrc=77U, flags=1)],
  )
  let provider = ReceiveTestDave::new(active_version=1, remote_users=[200UL])
  let machine = receive_test_machine(provider)
  let cipher = TransportCipher::new(AeadAes256GcmRtpsize, Bytes::new(32))
  let header = build_rtp_header(sequence=10, timestamp=960U, ssrc=77U)
  let encrypted_dave = cipher.seal(header~, b"encrypted\xFA\xFA")
  assert_eq(
    pipeline.process_udp_packet(
      encrypted_dave,
      cipher,
      Some(machine),
      arrival_ms=0L,
    ),
    [
      OpusReceived(
        user_id=Some("200"),
        ssrc=77U,
        sequence=10,
        timestamp=960U,
        opus=b"decrypted-opus",
      ),
    ],
  )
  assert_eq(provider.decrypted_users, [200UL])
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
    pipeline.process_udp_packet(datagram, cipher, None, arrival_ms=0L),
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
    pipeline.process_udp_packet(b"keepalive", cipher, None, arrival_ms=1L),
    [],
  )
}

///|
test "receive pipeline delegates an old encrypted frame after downgrade" {
  if !shim_available() {
    return
  }
  let telemetry : Array[VoiceTelemetry] = []
  let pipeline = ReceivePipeline::new(event => telemetry.push(event))
  pipeline.handle_gateway_message(Speaking(ssrc=77U, user_id="200", flags=1))
  |> ignore
  let provider = ReceiveTestDave::new(active_version=0, remote_users=[200UL])
  let machine = receive_test_machine(provider)
  let cipher = TransportCipher::new(AeadAes256GcmRtpsize, Bytes::new(32))
  let header = build_rtp_header(sequence=1, timestamp=960U, ssrc=77U)
  let datagram = cipher.seal(header~, b"old-encrypted\xFA\xFA")
  assert_eq(
    pipeline.process_udp_packet(datagram, cipher, Some(machine), arrival_ms=0L),
    [
      OpusReceived(
        user_id=Some("200"),
        ssrc=77U,
        sequence=1,
        timestamp=960U,
        opus=b"decrypted-opus",
      ),
    ],
  )
  assert_eq(provider.decrypted_users, [200UL])
  assert_eq(provider.decrypted_frames, [b"old-encrypted\xFA\xFA"])
  assert_eq(telemetry, [])
}

///|
test "receive pipeline delegates plaintext-looking media during active DAVE" {
  if !shim_available() {
    return
  }
  let telemetry : Array[VoiceTelemetry] = []
  let pipeline = ReceivePipeline::new(event => telemetry.push(event))
  pipeline.handle_gateway_message(Speaking(ssrc=77U, user_id="200", flags=1))
  |> ignore
  let provider = ReceiveTestDave::new(
    active_version=1,
    remote_users=[200UL],
    reject_unmarked_frames=true,
  )
  let machine = receive_test_machine(provider)
  let cipher = TransportCipher::new(AeadAes256GcmRtpsize, Bytes::new(32))
  let header = build_rtp_header(sequence=1, timestamp=960U, ssrc=77U)
  let datagram = cipher.seal(header~, b"plaintext-opus")
  assert_eq(
    pipeline.process_udp_packet(datagram, cipher, Some(machine), arrival_ms=0L),
    [],
  )
  assert_eq(provider.decrypted_users, [200UL])
  assert_eq(provider.decrypted_frames, [b"plaintext-opus"])
  guard telemetry
    is [DaveDecryptDropped(user_id=Some("200"), ssrc=77U, count=1, reason~)] else {
    fail("expected one DAVE decryption drop")
  }
  assert_true(reason.contains("unencrypted Opus frame"))
}

///|
test "receive pipeline permits plaintext only while DAVE is disabled" {
  if !shim_available() {
    return
  }
  let telemetry : Array[VoiceTelemetry] = []
  let pipeline = ReceivePipeline::new(event => telemetry.push(event))
  pipeline.handle_gateway_message(Speaking(ssrc=77U, user_id="200", flags=1))
  |> ignore
  let provider = ReceiveTestDave::new(active_version=0)
  let machine = receive_test_machine(provider)
  let cipher = TransportCipher::new(AeadAes256GcmRtpsize, Bytes::new(32))
  let plain_header = build_rtp_header(sequence=1, timestamp=960U, ssrc=77U)
  let plain_datagram = cipher.seal(header=plain_header, b"plaintext-opus")
  assert_eq(
    pipeline.process_udp_packet(
      plain_datagram,
      cipher,
      Some(machine),
      arrival_ms=0L,
    ),
    [
      OpusReceived(
        user_id=Some("200"),
        ssrc=77U,
        sequence=1,
        timestamp=960U,
        opus=b"plaintext-opus",
      ),
    ],
  )

  provider.active_version = 1
  let active_header = build_rtp_header(sequence=2, timestamp=1920U, ssrc=77U)
  let active_plain = cipher.seal(header=active_header, b"plaintext-opus")
  assert_eq(
    pipeline.process_udp_packet(
      active_plain,
      cipher,
      Some(machine),
      arrival_ms=1L,
    ),
    [],
  )

  provider.active_version = 0
  let encrypted_header = build_rtp_header(sequence=3, timestamp=2880U, ssrc=77U)
  let missing_decryptor = cipher.seal(
    header=encrypted_header,
    b"encrypted\xFA\xFA",
  )
  assert_eq(
    pipeline.process_udp_packet(
      missing_decryptor,
      cipher,
      Some(machine),
      arrival_ms=2L,
    ),
    [],
  )
  assert_eq(telemetry, [
    DaveDecryptDropped(
      user_id=Some("200"),
      ssrc=77U,
      count=1,
      reason="DAVE media is active but sender has no decryptor",
    ),
    DaveDecryptDropped(
      user_id=Some("200"),
      ssrc=77U,
      count=2,
      reason="DAVE frame has no decryptor",
    ),
  ])
}
