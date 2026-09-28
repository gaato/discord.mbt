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
const AUTO_DEFER_MARGIN_MS : Int = 1000

///|
/// The response-gate operations admission needs, independent of the
/// interaction kind.
priv struct AdmissionGate {
  remaining_ms : () -> Int?
  is_pending : () -> Bool
  defer_now : async (AckPlan) -> Unit
}

///|
fn command_admission(raw : @framework.CommandCtx) -> AdmissionGate {
  {
    remaining_ms: () => raw.remaining_ms(),
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
/// Run one routed interaction handler under the executor's work budget.
///
/// Routing and component waiters never hold a permit, so a handler waiting
/// for a component cannot starve the interaction that would wake it. A
/// deferring route starts a watchdog that acknowledges once the remaining
/// budget drops to `AUTO_DEFER_MARGIN_MS`, then waits for a permit without a
/// deadline. Other routes wait for a permit only while the callback window
/// is open; when it closes first, the interaction is dropped with a warning.
async fn run_admitted(
  limiter : @async.Semaphore,
  gate : AdmissionGate,
  plan : AckPlan,
  warn : (AppWarning) -> Unit,
  label : String,
  body : async () -> Unit,
) -> Unit {
  @async.with_task_group(group => {
    if !(plan is Respond) {
      group.spawn_bg(no_wait=true, () => {
        if (gate.remaining_ms)() is Some(left) && left > AUTO_DEFER_MARGIN_MS {
          @async.sleep(left - AUTO_DEFER_MARGIN_MS)
        }
        if (gate.is_pending)() {
          ensure_acknowledged(gate, plan) catch {
            error if @async.is_being_cancelled() => raise error
            error => warn(AutoDeferFailed(target=label, error~))
          }
        }
      })
      limiter.acquire()
    } else {
      match (gate.remaining_ms)() {
        None => limiter.acquire()
        Some(left) => {
          // Judge by the flag, not the timeout's result: when a release hands
          // this waiter a permit just as the timeout fires, `acquire` keeps
          // the permit and returns while `with_timeout_opt` still reports
          // `None`.
          let acquired = Ref(false)
          @async.with_timeout_opt(left, () => {
            limiter.acquire()
            acquired.val = true
          })
          |> ignore
          if !acquired.val {
            warn(InteractionDropped(target=label))
            return
          }
        }
      }
    }
    defer limiter.release()
    body()
  })
}
