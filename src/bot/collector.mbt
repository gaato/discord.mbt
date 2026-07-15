///|
/// A pending typed gateway-event observation. The raw event is retained only
/// until delivery; `matches` performs the descriptor projection and predicate
/// without exposing type erasure to callers.
priv struct EventWaiter {
  kind : @model.EventKind
  matches : (@model.Event) -> Bool
  queue : @aqueue.Queue[@model.Event]
}

///|
/// The gateway-local registry shared by `Bot` and every `GatewayCtx` it
/// creates. This is intentionally separate from Framework's component waiter:
/// collectors observe gateway events without consuming handler dispatch,
/// while component waiters route interactions (including HTTP interactions)
/// and return response-capable contexts.
priv struct EventCollector {
  waiters : Array[EventWaiter]
}

///|
/// A synchronously registered event observation. Registration is separate
/// from waiting so callers can install collectors before sending the command
/// that causes Discord to dispatch the matching event.
priv struct EventRegistration[T] {
  collector : EventCollector
  waiter : EventWaiter
  event_type : EventType[T]
}

///|
fn EventCollector::EventCollector() -> EventCollector {
  { waiters: [] }
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
    self.remove(waiter)
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
) -> EventRegistration[T] {
  let waiter : EventWaiter = {
    kind: event_type.kind(),
    matches: event => event_type.project(event).map(predicate).unwrap_or(false),
    queue: Queue(kind=Unbounded),
  }
  self.waiters.push(waiter)
  { collector: self, waiter, event_type }
}

///|
fn[T] EventRegistration::cancel(self : EventRegistration[T]) -> Unit {
  self.collector.remove(self.waiter)
}

///|
async fn[T] EventRegistration::wait(
  self : EventRegistration[T],
  timeout_ms? : Int,
) -> T? {
  defer self.cancel()
  let raw = match timeout_ms {
    Some(ms) => @async.with_timeout_opt(ms, () => self.waiter.queue.get())
    None => Some(self.waiter.queue.get())
  }
  raw.bind(raw_event => self.event_type.project(raw_event))
}

///|
async fn[T] EventCollector::wait_for(
  self : EventCollector,
  event_type : EventType[T],
  predicate : (T) -> Bool,
  timeout_ms? : Int,
) -> T? {
  self.register(event_type, predicate).wait(timeout_ms?)
}
