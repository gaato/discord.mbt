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
fn EventCollector::new() -> EventCollector {
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
async fn[T] EventCollector::wait_for(
  self : EventCollector,
  event_type : EventType[T],
  predicate : (T) -> Bool,
  timeout_ms? : Int,
) -> T? {
  let waiter : EventWaiter = {
    kind: event_type.kind(),
    matches: event => event_type.project(event).map(predicate).unwrap_or(false),
    queue: @aqueue.Queue::new(kind=Unbounded),
  }
  self.waiters.push(waiter)
  // Runs on normal delivery, timeout, and structured-concurrency cancellation.
  defer self.remove(waiter)
  let raw = match timeout_ms {
    Some(ms) => @async.with_timeout_opt(ms, () => waiter.queue.get())
    None => Some(waiter.queue.get())
  }
  raw.bind(raw_event => event_type.project(raw_event))
}
