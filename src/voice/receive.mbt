///|
/// Events emitted by a live voice connection.
pub(all) enum VoiceEvent {
  OpusReceived(
    user_id~ : String?,
    ssrc~ : UInt,
    sequence~ : Int,
    timestamp~ : UInt,
    opus~ : Bytes
  )
  PacketsLost(user_id~ : String?, ssrc~ : UInt, count~ : Int)
  SpeakingChanged(user_id~ : String, ssrc~ : UInt, flags~ : Int)
  UserConnected(user_id~ : String)
  UserDisconnected(user_id~ : String)
  ConnectionReady
  ConnectionResumed
} derive(Debug, Eq)

///|
/// Non-fatal diagnostics from the connection's gateway and media paths.
pub(all) enum VoiceTelemetry {
  GatewayEvent(VoiceGatewayEvent)
  PacketDropped(reason~ : String)
  DaveEncryptDropped(reason~ : String)
  DaveDecryptDropped(
    user_id~ : String?,
    ssrc~ : UInt,
    count~ : Int,
    reason~ : String
  )
} derive(Debug, Eq)

///|
priv struct ReceivedOpus {
  user_id : String?
  ssrc : UInt
  sequence : Int
  timestamp : UInt
  opus : Bytes
}

///|
priv struct ReceivePipeline {
  users_by_ssrc : Map[UInt, String]
  reorder_by_ssrc : Map[UInt, ReorderBuffer[ReceivedOpus]]
  mut dave_drop_count : Int
  telemetry : (VoiceTelemetry) -> Unit
}

///|
fn ReceivePipeline::new(
  telemetry : (VoiceTelemetry) -> Unit,
) -> ReceivePipeline {
  {
    users_by_ssrc: Map([]),
    reorder_by_ssrc: Map([]),
    dave_drop_count: 0,
    telemetry,
  }
}

///|
fn ReceivePipeline::reset_session(self : ReceivePipeline) -> Unit {
  self.users_by_ssrc.clear()
  self.reorder_by_ssrc.clear()
  self.dave_drop_count = 0
}

///|
fn ReceivePipeline::handle_gateway_message(
  self : ReceivePipeline,
  message : VoiceMessage,
) -> Array[VoiceEvent] {
  match message {
    Speaking(ssrc~, user_id~, flags~) => {
      self.users_by_ssrc[ssrc] = user_id
      [SpeakingChanged(user_id~, ssrc~, flags~)]
    }
    ClientsConnect(user_ids~) =>
      user_ids.map(user_id => UserConnected(user_id~))
    ClientDisconnect(user_id~) => {
      let removed : Array[UInt] = []
      for ssrc, mapped_user_id in self.users_by_ssrc {
        if mapped_user_id == user_id {
          removed.push(ssrc)
        }
      }
      for ssrc in removed {
        self.users_by_ssrc.remove(ssrc)
        self.reorder_by_ssrc.remove(ssrc)
      }
      [UserDisconnected(user_id~)]
    }
    _ => []
  }
}

///|
fn rtp_payload_without_extension(
  packet : RtpPacket,
  decrypted : Bytes,
) -> Bytes? {
  if (decrypted[0].to_int() & 0x10) == 0 {
    return Some(packet.payload)
  }
  let csrc_bytes = (decrypted[0].to_int() & 0x0f) * 4
  let extension_header = 12 + csrc_bytes
  if extension_header + 4 > decrypted.length() {
    return None
  }
  let word_count = (decrypted[extension_header + 2].to_int() << 8) |
    decrypted[extension_header + 3].to_int()
  let extension_bytes = word_count * 4
  if extension_bytes > packet.payload.length() {
    return None
  }
  Some(packet.payload[extension_bytes:].to_owned())
}

///|
fn has_dave_magic(frame : Bytes) -> Bool {
  frame.length() >= 2 &&
  frame[frame.length() - 2] == b'\xFA' &&
  frame[frame.length() - 1] == b'\xFA'
}

///|
fn ReceivePipeline::drop_packet(
  self : ReceivePipeline,
  reason : String,
) -> Array[VoiceEvent] {
  (self.telemetry)(PacketDropped(reason~))
  []
}

///|
fn ReceivePipeline::process_udp_packet(
  self : ReceivePipeline,
  datagram : Bytes,
  cipher : TransportCipher,
  dave : DaveMachine?,
  dave_enabled~ : Bool,
  arrival_ms~ : Int64,
) -> Array[VoiceEvent] {
  if datagram.length() == 0 ||
    (datagram[0] != b'\x80' && datagram[0] != b'\x90') {
    return []
  }
  let encrypted_rtp = parse_rtp_packet(datagram) catch {
    error => return self.drop_packet("invalid RTP packet: \{to_repr(error)}")
  }
  let decrypted = cipher.open(datagram, header_len=encrypted_rtp.header_len) catch {
    error => return self.drop_packet("RTP decryption failed: \{to_repr(error)}")
  }
  let rtp = parse_rtp_packet(decrypted) catch {
    error =>
      return self.drop_packet("invalid decrypted RTP packet: \{to_repr(error)}")
  }
  guard rtp_payload_without_extension(rtp, decrypted) is Some(payload) else {
    return self.drop_packet("RTP extension data is truncated")
  }
  let user_id = self.users_by_ssrc.get(rtp.ssrc)
  let opus = if dave_enabled && has_dave_magic(payload) {
    guard dave is Some(machine) && user_id is Some(sender) else {
      self.dave_drop_count += 1
      (self.telemetry)(
        DaveDecryptDropped(
          user_id~,
          ssrc=rtp.ssrc,
          count=self.dave_drop_count,
          reason="DAVE frame has no mapped sender",
        ),
      )
      return []
    }
    machine.decrypt_opus_frame(user_id=sender, payload) catch {
      error => {
        self.dave_drop_count += 1
        (self.telemetry)(
          DaveDecryptDropped(
            user_id~,
            ssrc=rtp.ssrc,
            count=self.dave_drop_count,
            reason="\{to_repr(error)}",
          ),
        )
        return []
      }
    }
  } else {
    payload
  }
  let packet : ReceivedOpus = {
    user_id,
    ssrc: rtp.ssrc,
    sequence: rtp.sequence.to_int(),
    timestamp: rtp.timestamp,
    opus,
  }
  let reorder = self.reorder_by_ssrc.get_or_init(rtp.ssrc, () => {
    ReorderBuffer::new()
  })
  let events : Array[VoiceEvent] = []
  for output in reorder.push(seq=packet.sequence, arrival_ms~, packet) {
    match output {
      Deliver(delivered) =>
        events.push(
          OpusReceived(
            user_id=delivered.user_id,
            ssrc=delivered.ssrc,
            sequence=delivered.sequence,
            timestamp=delivered.timestamp,
            opus=delivered.opus,
          ),
        )
      Lost(count~) => events.push(PacketsLost(user_id~, ssrc=rtp.ssrc, count~))
    }
  }
  events
}
