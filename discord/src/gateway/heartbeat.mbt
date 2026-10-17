///|
/// Heartbeat bookkeeping for one connection: the send time of the beat still
/// awaiting its ACK, if any. A second beat before the ACK restarts the clock.
priv struct Heartbeat {
  mut outstanding_since : Int64?
}

///|
fn Heartbeat::new() -> Heartbeat {
  { outstanding_since: None, }
}

///|
/// Whether the last beat is still unacknowledged. A beat that is due while
/// this holds means the connection is a zombie.
fn Heartbeat::awaiting_ack(self : Heartbeat) -> Bool {
  self.outstanding_since is Some(_)
}

///|
fn Heartbeat::beat(self : Heartbeat, now : Int64) -> Unit {
  self.outstanding_since = Some(now)
}

///|
/// Record an ACK and return the round-trip latency, or `None` when no beat
/// was outstanding (an unsolicited or duplicate ACK measures nothing).
fn Heartbeat::ack(self : Heartbeat, now : Int64) -> Int64? {
  guard self.outstanding_since is Some(sent_at) else { return None }
  self.outstanding_since = None
  Some(now - sent_at)
}
