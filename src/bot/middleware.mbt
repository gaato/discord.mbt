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
/// outermost. The chain runs serially, in event order, in a dispatch task
/// separate from the shard loop: slow middleware delays later events, never
/// interaction routing. A dropped event emits no EventDispatched
/// telemetry. Middleware cannot widen intents or the gateway event filter.
fn BotCore::middleware(self : BotCore, middleware : EventMiddleware) -> Unit {
  self.event_middleware_.push(middleware)
}

///|
async fn BotCore::run_event_middleware(
  self : BotCore,
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
async fn BotCore::dispatch_event(
  self : BotCore,
  spawner : @app.Spawner,
  ctx : GatewayCtx,
  event : @model.Event,
) -> Unit {
  self.run_event_middleware(spawner, ctx, 0, event) catch {
    error if @async.is_being_cancelled() => raise error
    error =>
      self.app_.warn(
        @app.Executor(
          source="gateway",
          message="event middleware failed: \{Repr(error)}",
        ),
      )
  }
}
