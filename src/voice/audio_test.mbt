///|
struct AudioTestTransport {
  incoming : @aqueue.Queue[@voice.VoiceFrame]
  outgoing : @aqueue.Queue[Json]
}

///|
fn AudioTestTransport::new() -> AudioTestTransport {
  { incoming: Queue(kind=Unbounded), outgoing: Queue(kind=Unbounded) }
}

///|
impl @voice.VoiceTransport for AudioTestTransport with fn recv(self) {
  self.incoming.get()
}

///|
impl @voice.VoiceTransport for AudioTestTransport with fn send_text(self, text) {
  self.outgoing.put(@json.parse(text))
}

///|
impl @voice.VoiceTransport for AudioTestTransport with fn send_binary(
  _self,
  _bytes,
) {

}

///|
impl @voice.VoiceTransport for AudioTestTransport with fn close(self, code~) {
  self.incoming.close(
    error=@voice.VoiceTransportClosed(code=Some(code), reason="closed"),
  )
}

///|
struct AudioTestUdp {
  outgoing : @aqueue.Queue[Bytes]
}

///|
fn AudioTestUdp::new() -> AudioTestUdp {
  { outgoing: Queue(kind=Unbounded) }
}

///|
impl @voice.VoiceUdp for AudioTestUdp with fn recv(_self, _buffer) {
  0
}

///|
impl @voice.VoiceUdp for AudioTestUdp with fn send(self, packet) {
  self.outgoing.put(packet)
}

///|
impl @voice.VoiceUdp for AudioTestUdp with fn close(_self) {

}

///|
struct ThreeFrameSource {
  frames : Array[Bytes]
  mut cursor : Int
}

///|
struct AudioTestDave {
  encrypted : Array[Bytes]
}

///|
impl @voice.DaveProvider for AudioTestDave with fn max_protocol_version(_self) {
  1
}

///|
impl @voice.DaveProvider for AudioTestDave with fn reinit(
  _self,
  protocol_version~,
) {
  ignore(protocol_version)
}

///|
impl @voice.DaveProvider for AudioTestDave with fn set_external_sender(
  _self,
  _payload,
) {

}

///|
impl @voice.DaveProvider for AudioTestDave with fn key_package(_self) {
  b"key-package"
}

///|
impl @voice.DaveProvider for AudioTestDave with fn process_proposals(
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
impl @voice.DaveProvider for AudioTestDave with fn process_commit(
  _self,
  _payload,
) {

}

///|
impl @voice.DaveProvider for AudioTestDave with fn process_welcome(
  _self,
  _payload,
) {

}

///|
impl @voice.DaveProvider for AudioTestDave with fn encrypt_frame(self, frame) {
  self.encrypted.push(frame)
  b"dave:" + frame
}

///|
impl @voice.DaveProvider for AudioTestDave with fn decrypt_frame(
  _self,
  user_id~,
  frame,
) {
  ignore(user_id)
  frame
}

///|
impl @voice.DaveProvider for AudioTestDave with fn status(_self) {
  2
}

///|
impl @voice.AudioSource for ThreeFrameSource with fn next_frame(self) {
  if self.cursor >= self.frames.length() {
    None
  } else {
    let frame = self.frames[self.cursor]
    self.cursor += 1
    Some(frame)
  }
}

///|
async test "send loop encrypts advancing RTP packets after voice handshake" {
  if !@voice.shim_available() {
    return
  }
  let transport = AudioTestTransport::new()
  let udp = AudioTestUdp::new()
  let secret_key = Bytes::new(32)
  let frames : Array[Bytes] = [b"frame-1", b"frame-2", b"frame-3"]
  @async.with_task_group(group => {
    let gateway = @voice.VoiceGateway::start(
      group,
      server_id="guild",
      user_id="user",
      session_id="session",
      token="token",
      endpoint="voice.example",
      select_protocol=(_, _, _, _) => {
        ("203.0.113.8", 62000, "aead_aes256_gcm_rtpsize")
      },
      connector=_ => (transport : &@voice.VoiceTransport),
    )
    transport.incoming.put(
      Text("{\"op\":8,\"d\":{\"heartbeat_interval\":60000}}"),
    )
    transport.outgoing.get() |> ignore
    transport.incoming.put(
      Text(
        "{\"op\":2,\"seq\":1,\"d\":{\"ssrc\":42,\"ip\":\"198.51.100.1\",\"port\":5000,\"modes\":[\"aead_aes256_gcm_rtpsize\"]}}",
      ),
    )
    guard gateway.next() is ReadyReceived
    transport.outgoing.get() |> ignore
    transport.incoming.put(
      Text(
        "{\"op\":4,\"seq\":2,\"d\":{\"mode\":\"aead_aes256_gcm_rtpsize\",\"secret_key\":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\"dave_protocol_version\":1}}",
      ),
    )
    guard gateway.next()
      is SessionEstablished(
        mode="aead_aes256_gcm_rtpsize",
        secret_key=session_key,
        ..
      )
    assert_eq(session_key, secret_key)
    guard gateway.next() is Connected(resumed=false)
    let cipher = @voice.TransportCipher::new(AeadAes256GcmRtpsize, session_key)
    let source : &@voice.AudioSource = ThreeFrameSource::{ frames, cursor: 0 }
    let dave_provider = AudioTestDave::{ encrypted: [] }
    let dave = @voice.DaveMachine::new(
      (dave_provider : &@voice.DaveProvider),
      self_user_id="100",
    )
    dave.handle(
      SessionDescription(
        mode="aead_aes256_gcm_rtpsize",
        secret_key=Bytes::new(32),
        dave_protocol_version=1,
      ),
    )
    |> ignore
    @voice.run_send_loop(
      source,
      cipher,
      (udp : &@voice.VoiceUdp),
      gateway,
      ssrc=42U,
      initial_sequence=65534,
      initial_timestamp=960U,
      frame_duration_ms=0,
      dave~,
    )
    guard transport.outgoing.get()
      is { "op": Number(5, ..), "d": { "speaking": Number(1, ..), .. }, .. }
    for index in 0..<8 {
      let encrypted = udp.outgoing.get()
      let plain = cipher.open(encrypted, header_len=12)
      let rtp = @voice.parse_rtp_packet(plain)
      assert_eq(rtp.sequence, (65534 + index).to_uint16())
      assert_eq(rtp.timestamp, 960U + index.reinterpret_as_uint() * 960U)
      if index < frames.length() {
        assert_eq(rtp.payload, b"dave:" + frames[index])
      } else {
        assert_eq(rtp.payload, b"dave:" + @voice.SILENCE_FRAME)
      }
    }
    assert_eq(
      dave_provider.encrypted,
      frames +
      [
        @voice.SILENCE_FRAME,
        @voice.SILENCE_FRAME,
        @voice.SILENCE_FRAME,
        @voice.SILENCE_FRAME,
        @voice.SILENCE_FRAME,
      ],
    )
    guard transport.outgoing.get()
      is { "op": Number(5, ..), "d": { "speaking": Number(0, ..), .. }, .. }
    gateway.close()
  })
}
