///|
/// How long `run` waits after a requested shutdown for handlers that are
/// still running before it cancels them.
pub const DEFAULT_SHUTDOWN_GRACE_MS : Int32 = 10000

///|
/// Counts the handlers that have started and not yet ended (event middleware
/// runs, event handlers, and interaction tasks), so a shutdown can wait for
/// them within its grace period.
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
/// Run `body`, tracked while it runs.
async fn HandlerTracker::track(
  self : HandlerTracker,
  body : async () -> Unit,
) -> Unit {
  self.enter()
  defer self.leave()
  body()
}

///|
/// Wrap `spawner` so every task it starts is tracked while its body runs. A
/// task that never starts its body, as `App::spawner` does once its intake has
/// closed, is never tracked.
fn HandlerTracker::spawner(
  self : HandlerTracker,
  spawner : @app.Spawner,
) -> @app.Spawner {
  body => spawner(() => self.track(body))
}
