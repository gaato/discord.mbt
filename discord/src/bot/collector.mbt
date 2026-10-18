///|
/// A pending typed gateway-event observation. The raw event is retained only
/// until delivery; `matches` performs the descriptor projection and predicate
/// without exposing type erasure to callers.
priv struct EventWaiter {
  kind : @model.EventKind
  matches : (@model.Event) -> Bool
  queue : @aqueue.Queue[@model.Event]
  persistent : Bool
}

///|
/// The gateway-local registry shared by `Bot` and every `GatewayCtx` it
/// creates. This is intentionally separate from Framework's component waiter:
/// collectors observe gateway events without consuming handler dispatch,
/// while component waiters route interactions (including HTTP interactions)
/// and return response-capable contexts.
priv struct EventCollector {
  waiters : Array[EventWaiter]
  // The Bot's clock, which times waits.
  clock : Ref[&@hclock.Clock]
}

///|
/// One expected gateway event, from `GatewayCtx::expect_event`. It is
/// registered when created, separately from waiting, so a caller can install
/// it before sending the command that makes Discord dispatch the event.
pub struct PendingEvent[T] {
  priv collector : EventCollector
  priv waiter : EventWaiter
  priv event_type : EventType[T]
}

///|
fn EventCollector::EventCollector(
  clock~ : Ref[&@hclock.Clock] = Ref(@transport.AsyncClock::new()),
) -> EventCollector {
  { waiters: [], clock, }
}

///|
fn EventCollector::remove(self : EventCollector, waiter : EventWaiter) -> Unit {
  for index, pending in self.waiters {
    if physical_equal(pending, waiter) {
      self.waiters.remove(index) |> ignore
      return
    }
  }
}

///|
/// Resolve every matching waiter. A gateway event is observational here: one
/// event may satisfy multiple concurrent collectors and still reaches normal
/// typed/raw handlers.
async fn EventCollector::dispatch(
  self : EventCollector,
  event : @model.Event,
) -> Unit {
  let kind = event_kind(event)
  let matched : Array[EventWaiter] = []
  for waiter in self.waiters {
    if waiter.kind == kind && (waiter.matches)(event) {
      matched.push(waiter)
    }
  }
  for waiter in matched {
    if !waiter.persistent {
      self.remove(waiter)
    }
    waiter.queue.put(event)
  }
}

///|
fn EventCollector::waits_for(
  self : EventCollector,
  kind : @model.EventKind,
) -> Bool {
  self.waiters.any(waiter => waiter.kind == kind)
}

///|
fn[T] EventCollector::register(
  self : EventCollector,
  event_type : EventType[T],
  predicate : (T) -> Bool,
  persistent~ : Bool = false,
) -> PendingEvent[T] {
  let waiter = EventWaiter::{
    kind: event_type.kind(),
    matches: event => event_type.project(event).map(predicate).unwrap_or(false),
    queue: Queue(kind=Unbounded),
    persistent,
  }
  self.waiters.push(waiter)
  { collector: self, waiter, event_type, }
}

///|
/// Stop expecting the event. `wait` also cancels when it returns, so this is
/// for an expectation that is abandoned without waiting.
pub fn[T] PendingEvent::cancel(self : PendingEvent[T]) -> Unit {
  self.collector.remove(self.waiter)
}

///|
/// Wait for the expected event. Returns `None` on timeout. An event that
/// arrived after the expectation was created and before this call is
/// returned at once.
pub async fn[T] PendingEvent::wait(
  self : PendingEvent[T],
  timeout_ms? : Int32,
) -> T? {
  defer self.cancel()
  let raw = match timeout_ms {
    Some(ms) =>
      @transport.with_timeout_opt(self.collector.clock.val, ms, () => {
        self.waiter.queue.get()
      })
    None => Some(self.waiter.queue.get())
  }
  raw.bind(raw_event => self.event_type.project(raw_event))
}
