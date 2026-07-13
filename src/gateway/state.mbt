///|
/// Shard lifecycle state.
pub(all) enum ShardState {
  Disconnected(reconnect_attempts~ : Int)
  Connecting
  Identifying
  Resuming
  Active
  FatallyClosed(code~ : Int)
} derive(Eq, Debug)

///|
pub(all) enum ReconnectPolicy {
  Resume
  Reidentify
  Fatal
} derive(Eq, Debug)

///|
/// Gateway session state retained across reconnects for RESUME.
pub(all) struct Session {
  id : String
  resume_url : String
  mut sequence : Int64
} derive(Debug)

///|
/// Classify a close code into the action to take, per the Discord docs.
///
/// - fatal: authentication failure or invalid shard/intent configuration —
///   reconnecting cannot succeed;
/// - re-identify: the session is gone (invalid seq, session timeout);
/// - resume: everything else (transient errors, unclean closes), provided a
///   session exists.
pub fn on_close(code : Int?, has_session : Bool) -> ReconnectPolicy {
  let policy = match code {
    Some(4004)
    | Some(4010)
    | Some(4011)
    | Some(4012)
    | Some(4013)
    | Some(4014) => ReconnectPolicy::Fatal
    Some(4007) | Some(4009) => ReconnectPolicy::Reidentify
    // normal closure invalidates the session per Discord's resume rules
    Some(1000) | Some(1001) => ReconnectPolicy::Reidentify
    _ => ReconnectPolicy::Resume
  }
  if policy is Resume && !has_session {
    ReconnectPolicy::Reidentify
  } else {
    policy
  }
}
