///|
/// Whether an executor still starts handlers. An executor that stops
/// gracefully closes its intake: from then on no handler starts, and handlers
/// waiting for capacity give up at once; handlers already running are not
/// affected. Pass one to `App::spawner` and `App::attach`.
pub struct HandlerIntake {
  priv mut open : Bool
  priv closed : @cond_var.Cond
}

///|
/// An open intake.
pub fn HandlerIntake::HandlerIntake() -> HandlerIntake {
  { open: true, closed: @cond_var.Cond(), }
}

///|
/// Stop starting handlers, and wake the ones waiting for capacity so they
/// give up. Closing twice is harmless.
pub fn HandlerIntake::close(self : HandlerIntake) -> Unit {
  if self.open {
    self.open = false
    self.closed.broadcast()
  }
}

///|
/// Whether handlers may still start.
pub fn HandlerIntake::is_open(self : HandlerIntake) -> Bool {
  self.open
}

///|
/// Run `wait` unless or until the intake closes, cancelling it then.
async fn HandlerIntake::until_closed(
  self : HandlerIntake,
  wait : async () -> Unit,
) -> Unit {
  guard self.open else { return }
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, () => {
      while self.open {
        self.closed.wait()
      }
      group.return_immediately(())
    })
    wait()
  })
}

///|
/// Take a permit from `limiter` while the intake is open; `limit` bounds the
/// wait (it runs its argument, perhaps under a timeout). Returns whether a
/// permit is held. Judged by a flag, not by how the wait ended: a release can
/// hand the waiter a permit just as the timeout or the close cancels it, and
/// `acquire` then keeps the permit and returns.
async fn HandlerIntake::acquire(
  self : HandlerIntake,
  limiter : @async.Semaphore,
  limit~ : async (async () -> Unit) -> Unit = wait => wait(),
) -> Bool {
  guard self.open else { return false }
  if limiter.try_acquire() {
    return true
  }
  let acquired = Ref(false)
  self.until_closed(() => {
    limit(() => {
      limiter.acquire()
      acquired.val = true
    })
  })
  acquired.val
}
