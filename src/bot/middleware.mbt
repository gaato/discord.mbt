///|
/// Runs once per decoded gateway event, around the handler fan-out.
/// `next(event)` spawns the typed and raw handlers for (a possibly
/// transformed) event and returns once they are spawned, not completed.
/// Not calling `next` drops the event for handlers only: cache updates,
/// decode-error observation, collectors, and interaction routing are
/// wire-level machinery that runs before this chain.
pub type EventMiddleware = async (
  GatewayCtx,
  @model.Event,
  async (@model.Event) -> Unit,
) -> Unit

///|
/// Install gateway event middleware. The first installed middleware is
/// outermost. The chain runs serially in the shard dispatch loop, so
/// middleware must return promptly. A dropped event emits no EventDispatched
/// telemetry. Middleware cannot widen intents or the gateway event filter.
pub fn Bot::middleware(self : Bot, middleware : EventMiddleware) -> Unit {
  self.event_middleware_.push(middleware)
}

///|
async fn Bot::run_event_middleware(
  self : Bot,
  spawner : @app.Spawner,
  ctx : GatewayCtx,
  index : Int,
  event : @model.Event,
) -> Unit {
  if index < self.event_middleware_.length() {
    self.event_middleware_[index](ctx, event, next_event => {
      self.run_event_middleware(spawner, ctx, index + 1, next_event)
    })
  } else {
    self.spawn_event_handlers(spawner, ctx, event)
  }
}

///|
async fn Bot::dispatch_event(
  self : Bot,
  spawner : @app.Spawner,
  ctx : GatewayCtx,
  event : @model.Event,
) -> Unit {
  self.run_event_middleware(spawner, ctx, 0, event) catch {
    error if @async.is_being_cancelled() => raise error
    error => self.app_.warn("event middleware failed: \{Repr(error)}")
  }
}
