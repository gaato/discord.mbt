///|
/// Shard lifecycle state.
#derive(Eq, Debug)
pub(all) enum ShardState {
  Disconnected(reconnect_attempts~ : Int32)
  Connecting
  Identifying
  Resuming
  Active
  FatallyClosed(code~ : Int32)
}

///|
/// Action after a gateway close: resume the session, identify from scratch,
/// or give up because reconnecting cannot succeed.
#derive(Eq, Debug)
pub(all) enum ReconnectPolicy {
  Resume
  Reidentify
  Fatal
}

///|
/// Gateway session state retained across reconnects for RESUME. Persist it
/// (for example with `to_json`) and pass it to `Shard::start(session~)` after a
/// process restart. `sequence` serializes as a JSON string (core's `Int64`
/// encoding); `from_json` accepts that form.
#derive(Debug, ToJson, FromJson)
pub(all) struct Session {
  id : String
  resume_url : String
  mut sequence : Int64
}

///|
/// Classify a close code into the action to take, per the Discord docs.
///
/// - fatal: authentication failure or invalid shard/intent configuration —
///   reconnecting cannot succeed;
/// - re-identify: the session is gone (invalid seq, session timeout);
/// - resume: everything else (transient errors, unclean closes), provided a
///   session exists.
pub fn on_close(code : Int32?, has_session : Bool) -> ReconnectPolicy {
  let policy = match code {
    Some(4004)
    | Some(4010)
    | Some(4011)
    | Some(4012)
    | Some(4013)
    | Some(4014) => ReconnectPolicy::Fatal
    Some(4007) | Some(4009) => Reidentify
    // normal closure invalidates the session per Discord's resume rules
    Some(1000) | Some(1001) => Reidentify
    _ => Resume
  }
  if policy is Resume && !has_session {
    Reidentify
  } else {
    policy
  }
}
