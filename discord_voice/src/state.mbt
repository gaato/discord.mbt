///|
/// Voice gateway lifecycle state.
#doc(hidden)
pub(all) enum VoiceGatewayState {
  Disconnected(reconnect_attempts~ : Int32)
  Connecting
  Identifying
  SelectingProtocol
  Active
  Resuming
  FatallyClosed(code~ : Int32)
} derive(Debug, Eq)

///|
/// Action after a voice WebSocket close: resume the session, rejoin from
/// scratch, or give up because reconnecting cannot succeed.
#doc(hidden)
pub(all) enum VoiceReconnectPolicy {
  Resume
  Rejoin
  Fatal
} derive(Debug, Eq)

///|
/// Classify a voice WebSocket close code. A resumable transport failure still
/// requires a fresh join when no established voice session exists.
#doc(hidden)
pub fn voice_on_close(
  code : Int32?,
  has_session : Bool,
) -> VoiceReconnectPolicy {
  let policy = match code {
    // Unknown opcode: the client and server cannot speak the same protocol.
    Some(4001)
    // Failed payload decode: reconnecting would resend the same invalid data.
    | Some(4002)
    // Not authenticated: identify/resume credentials are invalid.
    | Some(4003)
    // Authentication failed: the voice token is invalid.
    | Some(4004)
    // Already authenticated: the client state machine is invalid.
    | Some(4005)
    // Server not found: the requested voice server is invalid.
    | Some(4011)
    // Unknown protocol: the selected transport protocol is unsupported.
    | Some(4012)
    // Disconnected: channel access or voice state is no longer valid.
    | Some(4014)
    // Unknown encryption mode: protocol selection cannot succeed unchanged.
    | Some(4016)
    // Bad request: the client sent a structurally invalid request.
    | Some(4020)
    // Disconnected rate limited: retrying this session cannot succeed safely.
    | Some(4021)
    // Call terminated: the server has ended this voice session.
    | Some(4022) => Fatal
    // Session no longer valid: the main gateway must issue a fresh voice join.
    Some(4006)
    // Session timed out: buffered resume state has expired.
    | Some(4009)
    // A normal/going-away close invalidates the current voice session.
    | Some(1000)
    | Some(1001) => Rejoin
    // Voice server crashed: Discord explicitly permits buffered resume.
    Some(4015) => Resume
    // Abnormal and unclassified failures are treated as transient.
    _ => Resume
  }
  if policy is Resume && !has_session {
    Rejoin
  } else {
    policy
  }
}

///|
/// Exclusive upper bound of the full-jitter delay before reconnect attempt
/// `attempts`: one second doubled per consecutive failure, capped at 30 s.
fn reconnect_delay_limit(attempts : Int32) -> Int32 {
  let exponent = if attempts > 5 { 5 } else { attempts }
  let max_delay = 1000 * (1 << exponent)
  if max_delay > 30000 {
    30000
  } else {
    max_delay
  }
}

///|
/// What the gateway loop does after a voice connection ends.
priv struct CloseOutcome {
  state : VoiceGatewayState
  event : VoiceGatewayEvent
  attempts : Int32
  stop : Bool
}

///|
/// Decide the next state, the event to surface, the consecutive-failure count,
/// and whether the loop stops after a connection ends with close `code`. A
/// local shutdown (`closing`) always stops with a non-resuming disconnect.
fn close_outcome(
  code : Int32?,
  closing~ : Bool,
  has_session~ : Bool,
  attempts~ : Int32,
) -> CloseOutcome {
  if closing {
    return {
      state: Disconnected(reconnect_attempts=0),
      event: Disconnected(code~, resuming=false),
      attempts,
      stop: true,
    }
  }
  match voice_on_close(code, has_session) {
    Fatal => {
      // Unreachable default: a missing close code never classifies as fatal.
      let code = code.unwrap_or(0)
      {
        state: FatallyClosed(code~),
        event: FatallyClosed(code~),
        attempts,
        stop: true,
      }
    }
    Rejoin => {
      let attempts = attempts + 1
      {
        state: Disconnected(reconnect_attempts=attempts),
        event: NeedsRejoin(code~),
        attempts,
        stop: true,
      }
    }
    Resume => {
      let attempts = attempts + 1
      {
        state: Disconnected(reconnect_attempts=attempts),
        event: Disconnected(code~, resuming=true),
        attempts,
        stop: false,
      }
    }
  }
}
