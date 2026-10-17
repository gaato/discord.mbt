///|
/// How a connection ended. `InvalidSession` is opcode 9; everything else is a
/// close with its WebSocket code (`None` for an unclean end or a server
/// request to reconnect).
priv suberror ConnectionEnded {
  ConnectionEnded(code~ : Int32?, reason~ : String)
  InvalidSession(resumable~ : Bool)
} derive(Debug)

///|
/// The wait before the next connection attempt.
priv enum ReconnectDelay {
  /// Full-jitter exponential backoff under `cap_ms`, plus a 250 ms floor.
  Backoff(cap_ms~ : Int32)
  /// The 1-5 s Discord asks for before identifying after a non-resumable
  /// INVALID_SESSION.
  InvalidSession
}

///|
/// What the reconnect loop does after a connection ends.
priv enum AfterClose {
  /// The shard is closing.
  Stop(code~ : Int32?)
  /// Reconnecting cannot succeed.
  Fatal(code~ : Int32?)
  /// Connect again, resuming the session or identifying after clearing it.
  Reconnect(code~ : Int32?, resuming~ : Bool, clear_session~ : Bool)
}

///|
/// Reconnect bookkeeping across connections: consecutive attempts drive the
/// backoff, consecutive connector failures drive the stale-host fallback.
priv struct Reconnect {
  mut attempts : Int32
  mut connector_failures : Int32
  mut delay : ReconnectDelay?
}

///|
fn Reconnect::new() -> Reconnect {
  { attempts: 0, connector_failures: 0, delay: None, }
}

///|
/// The backoff ceiling: doubling from 1 s, capped at 30 s.
fn backoff_cap_ms(attempts : Int32) -> Int32 {
  let cap = 1000 * (1 << (if attempts > 5 { 5 } else { attempts }))
  if cap > 30000 {
    30000
  } else {
    cap
  }
}

///|
fn ReconnectDelay::sample_ms(
  self : ReconnectDelay,
  rand : @random.Rand,
) -> Int32 {
  match self {
    Backoff(cap_ms~) => rand.int(limit=cap_ms) + 250
    InvalidSession => 1000 + rand.int(limit=4000)
  }
}

///|
/// Record a failed connect. Returns `true` when the session's resume URL
/// should be dropped: a persisted one can point at a dead host, so three
/// consecutive failures fall back to the configured gateway URL.
fn Reconnect::on_connector_failure(
  self : Reconnect,
  has_session~ : Bool,
) -> Bool {
  self.attempts += 1
  self.connector_failures += 1
  self.delay = Some(Backoff(cap_ms=backoff_cap_ms(self.attempts)))
  self.connector_failures >= 3 && has_session
}

///|
fn Reconnect::on_connected(self : Reconnect) -> Unit {
  self.connector_failures = 0
}

///|
/// Classify a finished connection. `was_active` says it reached READY or
/// RESUMED, which starts the backoff over: only consecutive failures should
/// push the delay toward its cap.
fn Reconnect::after_close(
  self : Reconnect,
  ended : ConnectionEnded,
  closing~ : Bool,
  was_active~ : Bool,
  has_session~ : Bool,
) -> AfterClose {
  if was_active {
    self.attempts = 0
  }
  let (code, has_session, invalid_session) = match ended {
    ConnectionEnded(code~, ..) => (code, has_session, false)
    InvalidSession(resumable=true) => (None, has_session, false)
    InvalidSession(resumable=false) => (None, false, true)
  }
  if closing {
    return Stop(code~)
  }
  let policy = on_close(code, has_session)
  if policy is Fatal {
    return Fatal(code~)
  }
  self.attempts += 1
  self.delay = Some(
    if invalid_session {
      InvalidSession
    } else {
      Backoff(cap_ms=backoff_cap_ms(self.attempts))
    },
  )
  Reconnect(
    code~,
    resuming=policy is Resume,
    clear_session=policy is Reidentify,
  )
}
