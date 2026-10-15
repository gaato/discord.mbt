///|
/// Membership and lifecycle events of a live voice connection. Received audio
/// is not an event: it is delivered per user through
/// `VoiceConnection::subscribe`.
#non_exhaustive
pub(all) enum VoiceEvent {
  SpeakingChanged(user_id~ : String, ssrc~ : UInt32, flags~ : Int32)
  UserConnected(user_id~ : String)
  UserDisconnected(user_id~ : String)
  ConnectionReady
  ConnectionResumed
} derive(Debug, Eq)

///|
/// One item of a user's received audio, in RTP sequence order.
pub(all) enum ReceivedAudio {
  /// An Opus frame as the sender encoded it.
  Opus(sequence~ : Int32, timestamp~ : UInt32, opus~ : Bytes)
  /// `count` frames that never arrived, or that were dropped because the
  /// stream's backlog was full, before the next item.
  Lost(count~ : Int32)
} derive(Debug, Eq)

///|
/// Non-fatal diagnostics from the connection's gateway and media paths.
#non_exhaustive
pub(all) enum VoiceTelemetry {
  GatewayEvent(VoiceGatewayEvent)
  /// A DAVE media context became active after its local key ratchet was
  /// installed successfully. Version zero denotes passthrough; positive
  /// versions encrypt outbound Opus frames through libdave.
  DaveMediaContextActivated(protocol_version~ : Int32)
  /// A binary DAVE control message was accepted by the voice transport.
  /// `payload_bytes` excludes the one-byte opcode prefix.
  DaveBinaryControlSent(opcode~ : Int32, payload_bytes~ : Int32)
  PacketDropped(reason~ : String)
  DaveEncryptDropped(reason~ : String)
  DaveDecryptDropped(
    user_id~ : String?,
    ssrc~ : UInt32,
    count~ : Int32,
    reason~ : String
  )
  /// `next_event` fell `backlog` events behind, so the oldest unread event
  /// was discarded.
  EventDropped(backlog~ : Int32)
  /// A receive stream for `user_id` held `backlog` unread items, so a newly
  /// received frame was discarded. The reader sees it as `Lost`.
  ReceiveDropped(user_id~ : String, backlog~ : Int32)
} derive(Debug, Eq)

///|
priv struct ReceivedOpus {
  sequence : Int32
  timestamp : UInt32
  opus : Bytes
}

///|
priv struct ReceivePipeline {
  users_by_ssrc : Map[UInt32, String]
  reorder_by_ssrc : Map[UInt32, ReorderBuffer[ReceivedOpus]]
  mut dave_drop_count : Int32
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
/// Forget the reorder windows of `user_id`'s SSRCs, so a new subscription
/// never receives packets buffered for an earlier one.
fn ReceivePipeline::reset_reorder(
  self : ReceivePipeline,
  user_id : String,
) -> Unit {
  let ssrcs : Array[UInt32] = []
  for ssrc, mapped_user_id in self.users_by_ssrc {
    if mapped_user_id == user_id {
      ssrcs.push(ssrc)
    }
  }
  for ssrc in ssrcs {
    self.reorder_by_ssrc.remove(ssrc)
  }
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
      let removed : Array[UInt32] = []
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
fn rtp_payload_without_extension(packet : RtpPacket) -> Bytes? {
  guard packet.header is [u2be(_), u1be(_), u1be(1), ..] else {
    return Some(packet.payload)
  }
  // The extension preamble (profile, word count) ends the rtpsize header.
  guard packet.header[packet.header_len - 4:] is [u16be(_), u16be(word_count)] else {
    return None
  }
  let extension_bytes = word_count.reinterpret_as_int() * 4
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
fn[T] ReceivePipeline::drop_packet(
  self : ReceivePipeline,
  reason : String,
) -> Array[T] {
  (self.telemetry)(PacketDropped(reason~))
  []
}

///|
fn[T] ReceivePipeline::drop_dave_packet(
  self : ReceivePipeline,
  user_id : String,
  ssrc : UInt32,
  reason : String,
) -> Array[T] {
  self.dave_drop_count += 1
  (self.telemetry)(
    DaveDecryptDropped(
      user_id=Some(user_id),
      ssrc~,
      count=self.dave_drop_count,
      reason~,
    ),
  )
  []
}

///|
/// Decrypt one media datagram for a subscribed sender and restore RTP order.
/// Packets from SSRCs that are unmapped or that `wants` declines are dropped
/// before decryption, and their reorder state is discarded so a later
/// subscription starts from a clean window.
fn ReceivePipeline::process_udp_packet(
  self : ReceivePipeline,
  datagram : Bytes,
  cipher : TransportCipher,
  dave : DaveMachine?,
  arrival_ms~ : Int64,
  wants~ : (String) -> Bool,
) -> Array[(String, ReceivedAudio)] {
  if datagram.length() == 0 ||
    (datagram[0] != b'\x80' && datagram[0] != b'\x90') {
    return []
  }
  let encrypted_rtp = parse_rtp_packet(datagram) catch {
    error => return self.drop_packet("invalid RTP packet: \{Repr(error)}")
  }
  guard self.users_by_ssrc.get(encrypted_rtp.ssrc) is Some(user_id) &&
    wants(user_id) else {
    self.reorder_by_ssrc.remove(encrypted_rtp.ssrc)
    return []
  }
  let decrypted = cipher.open(datagram, header_len=encrypted_rtp.header_len) catch {
    error => return self.drop_packet("RTP decryption failed: \{Repr(error)}")
  }
  let rtp = parse_rtp_packet(decrypted) catch {
    error =>
      return self.drop_packet("invalid decrypted RTP packet: \{Repr(error)}")
  }
  guard rtp_payload_without_extension(rtp) is Some(payload) else {
    return self.drop_packet("RTP extension data is truncated")
  }
  let dave_magic = has_dave_magic(payload)
  let opus = match dave {
    Some(machine) => {
      let has_decryptor = machine.has_remote_decryptor(user_id~) catch {
        error =>
          return self.drop_dave_packet(user_id, rtp.ssrc, "\{Repr(error)}")
      }
      if has_decryptor {
        machine.decrypt_opus_frame(user_id~, payload) catch {
          error =>
            return self.drop_dave_packet(user_id, rtp.ssrc, "\{Repr(error)}")
        }
      } else if machine.active_protocol_version() == 0 && !dave_magic {
        payload
      } else {
        let reason = if dave_magic {
          "DAVE frame has no decryptor"
        } else {
          "DAVE media is active but sender has no decryptor"
        }
        return self.drop_dave_packet(user_id, rtp.ssrc, reason)
      }
    }
    None =>
      if dave_magic {
        return self.drop_dave_packet(
          user_id,
          rtp.ssrc,
          "DAVE frame without a DAVE session",
        )
      } else {
        payload
      }
  }
  let packet = ReceivedOpus::{
    sequence: rtp.sequence.to_int(),
    timestamp: rtp.timestamp,
    opus,
  }
  let reorder = self.reorder_by_ssrc.get_or_init(rtp.ssrc, () => {
    ReorderBuffer::new()
  })
  reorder
  .push(seq=packet.sequence, arrival_ms~, packet)
  .map(output => {
    let audio : ReceivedAudio = match output {
      Deliver(delivered) =>
        Opus(
          sequence=delivered.sequence,
          timestamp=delivered.timestamp,
          opus=delivered.opus,
        )
      Lost(count~) => Lost(count~)
    }
    (user_id, audio)
  })
}
