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
  let remaining = deadline - @clock.now_ms()
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
  timestamp : UInt,
  ssrc : UInt,
  frame : Bytes,
  on_dave_error : (String) -> Unit,
) -> Bool {
  let header = build_rtp_header(sequence~, timestamp~, ssrc~)
  let encrypted_frame = match dave {
    Some(machine) =>
      Some(machine.encrypt_opus_frame(frame)) catch {
        DaveInvalid(reason~) => {
          on_dave_error(reason)
          None
        }
        DaveStale(reason~) => {
          on_dave_error(reason)
          None
        }
        DaveUnavailable(reason~) => {
          on_dave_error(reason)
          None
        }
        DaveInternal(status~, reason~) => {
          on_dave_error("DAVE status \{status}: \{reason}")
          None
        }
        error => raise error
      }
    None => Some(frame)
  }
  guard encrypted_frame is Some(encrypted) else { return false }
  udp.send(cipher.seal(header~, encrypted))
  true
}

///|
priv struct SendLoopState {
  mut sequence : UInt16
  mut timestamp : UInt
  mut deadline : Int64
}

///|
/// Internal paced sender used by the M4 connection driver.
pub async fn run_send_loop(
  source : &AudioSource,
  cipher : TransportCipher,
  udp : &VoiceUdp,
  gateway : VoiceGateway,
  ssrc~ : UInt,
  initial_sequence? : UInt16 = 0,
  initial_timestamp? : UInt = 0,
  stop? : Ref[Bool],
  frame_duration_ms? : Int = 20,
  dave? : DaveMachine,
  on_dave_error? : (String) -> Unit = _ => (),
) -> Unit {
  let state : SendLoopState = {
    sequence: initial_sequence,
    timestamp: initial_timestamp,
    deadline: @clock.now_ms(),
  }
  gateway.send_json(encode_speaking(ssrc~, flags=1))
  for ;; {
    if stop is Some(flag) && flag.val {
      break
    }
    guard source.next_frame() is Some(frame) else { break }
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
    if sent {
      state.sequence += 1
    }
    state.timestamp += 960
    state.deadline += frame_duration_ms.to_int64()
    pace_until(state.deadline)
  }
  // Discord recommends five silence frames to flush decoder state on stop.
  for _ in 0..<5 {
    let sent = send_opus_packet(
      cipher,
      udp,
      dave,
      state.sequence,
      state.timestamp,
      ssrc,
      SILENCE_FRAME,
      on_dave_error,
    )
    if sent {
      state.sequence += 1
    }
    state.timestamp += 960
    state.deadline += frame_duration_ms.to_int64()
    pace_until(state.deadline)
  }
  gateway.send_json(encode_speaking(ssrc~, flags=0))
}
