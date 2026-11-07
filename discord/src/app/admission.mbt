///|
/// How a routed handler acknowledges its interaction.
priv enum AckPlan {
  /// The handler (or the framework on its behalf) sends the initial response.
  Respond
  /// The framework defers with a loading message before the handler runs.
  DeferMessage(ephemeral~ : Bool)
  /// The framework defers a component update before the handler runs.
  DeferUpdate
}

///|
/// Budget left in the initial-response window when a deferring route's
/// watchdog acknowledges on the handler's behalf. With the default 2500 ms
/// deadline this fires 1500 ms after receipt.
const AUTO_DEFER_MARGIN_MS : Int32 = 1000

///|
/// The response-gate operations admission needs, independent of the
/// interaction kind.
priv struct AdmissionGate {
  remaining_ms : () -> Int32?
  /// Milliseconds before the interaction token expires, from receipt.
  token_remaining_ms : () -> Int32
  is_pending : () -> Bool
  defer_now : async (AckPlan) -> Unit
}

///|
fn command_admission(raw : @framework.CommandCtx) -> AdmissionGate {
  {
    remaining_ms: () => raw.remaining_ms(),
    token_remaining_ms: () => raw.token_remaining_ms(),
    is_pending: () => raw.response_state() is Pending,
    defer_now: plan => {
      match plan {
        DeferMessage(ephemeral~) => raw.defer_response(ephemeral~)
        Respond | DeferUpdate => ()
      }
    },
  }
}

///|
fn component_admission(raw : @framework.ComponentCtx) -> AdmissionGate {
  {
    remaining_ms: () => raw.remaining_ms(),
    token_remaining_ms: () => raw.token_remaining_ms(),
    is_pending: () => raw.response_state() is Pending,
    defer_now: plan => {
      match plan {
        DeferMessage(ephemeral~) => raw.defer_response(ephemeral~)
        DeferUpdate => raw.defer_update()
        Respond => ()
      }
    },
  }
}

///|
fn modal_admission(raw : @framework.ModalCtx) -> AdmissionGate {
  {
    remaining_ms: () => raw.remaining_ms(),
    token_remaining_ms: () => raw.token_remaining_ms(),
    is_pending: () => raw.response_state() is Pending,
    defer_now: plan => {
      match plan {
        DeferMessage(ephemeral~) => raw.defer_response(ephemeral~)
        DeferUpdate => raw.defer_update()
        Respond => ()
      }
    },
  }
}

///|
fn autocomplete_admission(raw : @framework.AutocompleteCtx) -> AdmissionGate {
  {
    remaining_ms: () => raw.remaining_ms(),
    token_remaining_ms: () => raw.token_remaining_ms(),
    is_pending: () => false,
    defer_now: _ => (),
  }
}

///|
/// Acknowledge a deferring route unless its watchdog (or middleware)
/// already answered.
async fn ensure_acknowledged(gate : AdmissionGate, plan : AckPlan) -> Unit {
  (gate.defer_now)(plan) catch {
    @framework.ResponseGateError::AlreadyResponded => ()
    error => raise error
  }
}

///|
/// One executor attachment's handler budget: the permits for running
/// handlers, and the deferred interactions waiting for one.
priv struct Admission {
  limiter : @async.Semaphore
  mut pending : Int32
  max_pending : Int32
  /// An upper bound on how long a deferred interaction may wait for a
  /// permit, on top of its token's remaining lifetime.
  wait_limit_ms : Int32
  /// The framework's clock, which also times the gates' windows.
  clock : &@hclock.Clock
  /// Set from the first refusal until a deferred interaction is admitted
  /// again, so one overload produces one warning.
  mut refusing : Bool
  /// Closed when the executor stops: no handler starts after that.
  intake : HandlerIntake
}

///|
/// A deferred interaction was refused because the waiting budget is full.
/// Returns `true` for the first refusal of an overload, the one to warn about.
fn Admission::refused(self : Admission) -> Bool {
  let first = !self.refusing
  self.refusing = true
  first
}

///|
/// Take a permit from `limiter`, waiting at most `wait_ms` (`None`: as long as
/// it takes), while `open` holds and `intake` is open. A permit that only
/// arrives once the window or the intake has closed is handed back: the
/// handler would do its work with no way to answer, or after the executor
/// stopped.
async fn acquire_while_open(
  clock : &@hclock.Clock,
  limiter : @async.Semaphore,
  intake : HandlerIntake,
  wait_ms : Int32?,
  open : () -> Bool,
) -> Bool {
  if !open() {
    return false
  }
  let acquired = intake.acquire(limiter, limit=wait => {
    match wait_ms {
      Some(wait_ms) =>
        @netruntime.with_timeout_opt(clock, wait_ms, wait) |> ignore
      None => wait()
    }
  })
  if !acquired {
    return false
  }
  if !open() || !intake.is_open() {
    limiter.release()
    return false
  }
  true
}

///|
/// What admission does with one routed interaction.
priv enum AdmissionStep {
  /// The executor is stopping: drop the interaction without starting it.
  Stopping
  /// Too many deferred interactions already wait: refuse through `busy`.
  Refuse
  /// Acknowledge through the auto-defer watchdog unless already answered,
  /// and wait at most `wait_ms` for a permit.
  Deferred(wait_ms~ : Int32)
  /// Wait for a permit for at most `wait_ms` (`None`: as long as it takes).
  Direct(wait_ms~ : Int32?)
}

///|
/// How long the auto-defer watchdog waits before acknowledging: until
/// `AUTO_DEFER_MARGIN_MS` of the callback window is left, or not at all when
/// less remains or the gate has no deadline.
fn auto_defer_delay(remaining_ms : Int32?) -> Int32 {
  match remaining_ms {
    Some(left) if left > AUTO_DEFER_MARGIN_MS => left - AUTO_DEFER_MARGIN_MS
    _ => 0
  }
}

///|
fn admission_step(
  plan : AckPlan,
  stopping~ : Bool,
  pending~ : Int32,
  max_pending~ : Int32,
  wait_limit_ms~ : Int32,
  remaining_ms~ : Int32?,
  token_left_ms~ : Int32,
) -> AdmissionStep {
  if stopping {
    return Stopping
  }
  if plan is Respond {
    return Direct(wait_ms=remaining_ms)
  }
  if pending >= max_pending {
    return Refuse
  }
  // Past the token's lifetime (counted from receipt) the handler could not
  // answer anyway.
  let wait_ms = if token_left_ms < wait_limit_ms {
    token_left_ms
  } else {
    wait_limit_ms
  }
  Deferred(wait_ms~)
}

///|
/// The warning for an interaction whose wait for a permit ended without one:
/// the executor stopped, or its window (`deferred`: its token) ran out.
fn not_started_warning(
  label : String,
  stopping~ : Bool,
  deferred~ : Bool,
) -> AppWarning {
  if stopping {
    InteractionDroppedWhileStopping(target=label)
  } else if deferred {
    DeferredInteractionExpired(target=label)
  } else {
    InteractionDropped(target=label)
  }
}

///|
/// Run one routed interaction handler under the executor's work budget.
///
/// Routing and component waiters never hold a permit, so a handler waiting
/// for a component cannot starve the interaction that would wake it. A
/// deferring route starts a watchdog that acknowledges once the remaining
/// budget drops to `AUTO_DEFER_MARGIN_MS`, then waits for a permit for at
/// most the interaction token's lifetime; at most `max_pending` such routes
/// wait at once, and one more is refused through `busy` before anything is
/// acknowledged. Other routes wait for a permit only while the callback
/// window is open. Either way the window is checked again once the permit is
/// taken, so a handler never starts after its token (deferring routes) or its
/// callback window (other routes) has run out; such an interaction is dropped
/// with a warning. Nor does one start once the intake has closed: a waiting
/// interaction gives up as it closes.
async fn run_admitted(
  admission : Admission,
  gate : AdmissionGate,
  plan : AckPlan,
  warn : (AppWarning) -> Unit,
  label : String,
  busy : async () -> Unit,
  body : async () -> Unit,
) -> Unit {
  let limiter = admission.limiter
  @async.with_task_group(group => {
    let step = admission_step(
      plan,
      stopping=!admission.intake.is_open(),
      pending=admission.pending,
      max_pending=admission.max_pending,
      wait_limit_ms=admission.wait_limit_ms,
      remaining_ms=(gate.remaining_ms)(),
      token_left_ms=(gate.token_remaining_ms)(),
    )
    match step {
      Stopping => {
        warn(InteractionDroppedWhileStopping(target=label))
        return
      }
      Refuse => {
        if admission.refused() {
          warn(DeferredInteractionsRefused(max_pending=admission.max_pending))
        }
        // Still pending: the error policy can answer with a message.
        busy()
        return
      }
      Deferred(wait_ms~) => {
        admission.refusing = false
        admission.pending += 1
        let waiting = Ref(true)
        defer (if waiting.val { admission.pending -= 1 })
        group.spawn_bg(no_wait=true, () => {
          // Read the window when the task runs, so a late start still
          // leaves the margin.
          let delay = auto_defer_delay((gate.remaining_ms)())
          if delay > 0 {
            admission.clock.sleep(delay)
          }
          if (gate.is_pending)() {
            ensure_acknowledged(gate, plan) catch {
              error if @async.is_being_cancelled() => raise error
              error => warn(AutoDeferFailed(target=label, error~))
            }
          }
        })
        let acquired = acquire_while_open(
          admission.clock,
          limiter,
          admission.intake,
          Some(wait_ms),
          () => (gate.token_remaining_ms)() > 0,
        )
        waiting.val = false
        admission.pending -= 1
        if !acquired {
          warn(
            not_started_warning(
              label,
              stopping=!admission.intake.is_open(),
              deferred=true,
            ),
          )
          return
        }
      }
      Direct(wait_ms~) =>
        if !acquire_while_open(
            admission.clock,
            limiter,
            admission.intake,
            wait_ms,
            () => !((gate.remaining_ms)() is Some(0)),
          ) {
          warn(
            not_started_warning(
              label,
              stopping=!admission.intake.is_open(),
              deferred=false,
            ),
          )
          return
        }
    }
    defer limiter.release()
    body()
  })
}
