///|
/// A source of pre-encoded 20 ms Opus frames. `None` marks end of stream.
pub(open) trait AudioSource {
  async fn next_frame(Self) -> Bytes?
}

///|
/// Discord's canonical Opus silence frame.
pub const SILENCE_FRAME : Bytes = b"\xF8\xFF\xFE"

///|
async fn pace_until(deadline : Int64) -> Unit {
  let remaining = deadline - now_ms()
  if remaining > 0L {
    @async.sleep(remaining.to_int())
  }
}

///|
async fn send_opus_packet(
  cipher : TransportCipher,
  udp : &VoiceUdp,
  dave : DaveMachine?,
  sequence : UInt16,
  timestamp : UInt32,
  ssrc : UInt32,
  frame : Bytes,
  on_dave_error : (String) -> Unit,
) -> Bool {
  let header = build_rtp_header(sequence~, timestamp~, ssrc~)
  let encrypted_frame = match dave {
    Some(machine) =>
      Some(machine.encrypt_opus_frame(ssrc~, frame)) catch {
        DaveInvalid(reason~) => {
          on_dave_error(reason)
          None
        }
        DaveUnavailable(reason~) => {
          on_dave_error(reason)
          None
        }
        DaveInternal(reason~) => {
          on_dave_error(reason)
          None
        }
      }
    None => Some(frame)
  }
  guard encrypted_frame is Some(encrypted) else { return false }
  udp.send(cipher.seal(header~, encrypted))
  true
}

///|
/// RTP timestamp ticks per Opus frame: 20 ms at 48 kHz.
const RTP_TICKS_PER_FRAME : UInt32 = 960

///|
priv struct SendLoopState {
  sequence : UInt16
  timestamp : UInt32
  deadline : Int64
}

///|
/// Counters after one frame slot. The sequence number advances only for a
/// packet that went out; the timestamp and pacing deadline advance for every
/// slot, so receivers see the gap. Both RTP counters wrap.
fn SendLoopState::advance(
  self : SendLoopState,
  sent~ : Bool,
  pace_ms~ : Int32,
) -> SendLoopState {
  {
    sequence: if sent {
      self.sequence + 1
    } else {
      self.sequence
    },
    timestamp: self.timestamp + RTP_TICKS_PER_FRAME,
    deadline: self.deadline + pace_ms.to_int64(),
  }
}

///|
/// Internal paced sender used by the M4 connection driver.
/// `frame_duration_ms` is only the pacing interval between packets: every
/// `AudioSource` frame is 20 ms, so RTP timestamps always advance by 960.
#doc(hidden)
pub async fn run_send_loop(
  source : &AudioSource,
  cipher : TransportCipher,
  udp : &VoiceUdp,
  gateway : VoiceGateway,
  ssrc~ : UInt32,
  initial_sequence~ : UInt16 = 0,
  initial_timestamp~ : UInt32 = 0,
  stop? : Ref[Bool],
  frame_duration_ms~ : Int32 = 20,
  dave? : DaveMachine,
  on_dave_error~ : (String) -> Unit = _ => (),
) -> Unit {
  let mut state = SendLoopState::{
    sequence: initial_sequence,
    timestamp: initial_timestamp,
    deadline: now_ms(),
  }
  // Send one frame (counting it only if it went out), then wait out its slot.
  async fn send_paced(frame : Bytes) -> Unit {
    let sent = send_opus_packet(
      cipher,
      udp,
      dave,
      state.sequence,
      state.timestamp,
      ssrc,
      frame,
      on_dave_error,
    )
    state = state.advance(sent~, pace_ms=frame_duration_ms)
    pace_until(state.deadline)
  }

  gateway.send_json(encode_speaking(ssrc~, flags=1))
  for ;; {
    if stop is Some(flag) && flag.val {
      break
    }
    guard source.next_frame() is Some(frame) else { break }
    send_paced(frame)
  }
  // Discord recommends five silence frames to flush decoder state on stop.
  for _ in 0..<5 {
    send_paced(SILENCE_FRAME)
  }
  gateway.send_json(encode_speaking(ssrc~, flags=0))
}
