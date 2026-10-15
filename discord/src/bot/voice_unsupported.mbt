///|
/// Voice needs the native backend; this backend keeps no voice sessions.
priv struct VoiceSessions {
  unused : Unit
}

///|
fn VoiceSessions::new() -> VoiceSessions {
  let sessions : VoiceSessions = { unused: (), }
  let _ = sessions.unused
  sessions
}
