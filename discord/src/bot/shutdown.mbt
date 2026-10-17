///|
/// How long `run` waits after a requested shutdown for handlers that are
/// still running before it cancels them.
pub const DEFAULT_SHUTDOWN_GRACE_MS : Int32 = 10000

///|
/// Counts handlers that are running or spawned but not yet started, so a
/// shutdown can wait for them within its grace period.
priv struct HandlerTracker {
  mut active : Int32
  idle : @cond_var.Cond
}

///|
fn HandlerTracker::new() -> HandlerTracker {
  { active: 0, idle: @cond_var.Cond(), }
}

///|
fn HandlerTracker::enter(self : HandlerTracker) -> Unit {
  self.active += 1
}

///|
fn HandlerTracker::leave(self : HandlerTracker) -> Unit {
  self.active -= 1
  if self.active == 0 {
    self.idle.broadcast()
  }
}

///|
async fn HandlerTracker::wait_idle(self : HandlerTracker) -> Unit {
  while self.active > 0 {
    self.idle.wait()
  }
}

///|
/// Wrap `spawner` so every task it starts is tracked from the call until the
/// task ends. A call that fails before spawning, such as one cancelled while
/// waiting for capacity, leaves nothing tracked.
fn HandlerTracker::spawner(
  self : HandlerTracker,
  spawner : @app.Spawner,
) -> @app.Spawner {
  body => {
    self.enter()
    errdefer self.leave()
    spawner(() => {
      defer self.leave()
      body()
    })
  }
}
