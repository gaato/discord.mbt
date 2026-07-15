///|
/// Voice gateway lifecycle state.
pub(all) enum VoiceGatewayState {
  Disconnected(reconnect_attempts~ : Int)
  Connecting
  Identifying
  SelectingProtocol
  Active
  Resuming
  FatallyClosed(code~ : Int)
} derive(Debug, Eq)

///|
/// Action after a voice WebSocket close: resume the session, rejoin from
/// scratch, or give up because reconnecting cannot succeed.
pub(all) enum VoiceReconnectPolicy {
  Resume
  Rejoin
  Fatal
} derive(Debug, Eq)

///|
/// Classify a voice WebSocket close code. A resumable transport failure still
/// requires a fresh join when no established voice session exists.
pub fn voice_on_close(code : Int?, has_session : Bool) -> VoiceReconnectPolicy {
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
