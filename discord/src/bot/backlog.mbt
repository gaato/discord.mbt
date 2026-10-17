///|
/// Event handler backlog accounting. `dropping` stays set from the first
/// dropped event until handlers have drained the backlog, so one overload
/// produces one warning.
priv struct Backlog {
  mut queued : Int32
  mut dropping : Bool
}

///|
fn Backlog::new() -> Backlog {
  { queued: 0, dropping: false, }
}

///|
/// An event was queued for the handlers.
fn Backlog::queued(self : Backlog) -> Unit {
  self.queued += 1
}

///|
/// The handlers took a queued event.
fn Backlog::taken(self : Backlog) -> Unit {
  self.queued -= 1
  if self.queued == 0 {
    self.dropping = false
  }
}

///|
/// An event was dropped because the backlog is full. Returns `true` for the
/// first drop of an overload, which is the one to warn about.
fn Backlog::dropped(self : Backlog) -> Bool {
  if self.dropping {
    false
  } else {
    self.dropping = true
    true
  }
}
