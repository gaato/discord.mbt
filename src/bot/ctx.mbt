///|
/// Gateway-only services passed to event and service handlers after READY.
pub struct GatewayCtx {
  priv app_ : @app.AppCtx
  priv mut ready_ : @model.Ready
  priv shard_ : @gateway.Shard
  priv shards_ : Array[@gateway.Shard]
  priv framework_ : @framework.Framework
  priv collector_ : EventCollector
  priv shutdown_requested_ : Ref[Bool]
}

///|
/// The transport-neutral application context for REST access.
pub fn GatewayCtx::app(self : GatewayCtx) -> @app.AppCtx {
  self.app_
}

///|
/// The latest READY payload for this gateway session.
pub fn GatewayCtx::ready(self : GatewayCtx) -> @model.Ready {
  self.ready_
}

///|
/// Access the underlying gateway shard.
pub fn GatewayCtx::shard_raw(self : GatewayCtx) -> @gateway.Shard {
  self.shard_
}

///|
/// Access the underlying interaction framework.
pub fn GatewayCtx::framework_raw(self : GatewayCtx) -> @framework.Framework {
  self.framework_
}

///|
/// Bind a message-create event's message to the gateway REST client.
pub fn GatewayCtx::message_ref(
  self : GatewayCtx,
  event : @model.MessageCreateEvent,
) -> @dhttp.MessageRef {
  self.app_.http().ref_of_message(event.message)
}

///|
/// Bind a message model to the gateway REST client.
pub fn GatewayCtx::ref_of_message(
  self : GatewayCtx,
  message : @model.Message,
) -> @dhttp.MessageRef {
  self.app_.http().ref_of_message(message)
}

///|
/// Wait for the next component interaction with an exact custom id.
pub async fn GatewayCtx::wait_for_component(
  self : GatewayCtx,
  custom_id~ : String,
  timeout_ms? : Int,
) -> @framework.ComponentCtx? {
  self.framework_.wait_for_component(custom_id~, timeout_ms?)
}

///|
/// Wait for the next gateway event of `event_type` that satisfies `predicate`.
/// The event remains visible to other collectors and registered handlers.
/// Returns `None` on timeout. The caller must enable an intent capable of
/// delivering the requested event when it is not already subscribed.
pub async fn[T] GatewayCtx::wait_for(
  self : GatewayCtx,
  event_type : EventType[T],
  predicate : (T) -> Bool,
  timeout_ms? : Int,
) -> T? {
  self.collector_.wait_for(event_type, predicate, timeout_ms?)
}

///|
/// Request a graceful stop. Closing every managed shard wakes the run loop;
/// the task group then waits for already-started handlers before returning.
pub async fn GatewayCtx::shutdown(self : GatewayCtx) -> Unit {
  self.shutdown_requested_.val = true
  close_shards(self.shards_)
}
