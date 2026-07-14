///|
/// Gateway-only services passed to event and service handlers after READY.
pub struct GatewayCtx {
  priv app_ : @app.AppCtx
  priv mut ready_ : @model.Ready
  priv shard_ : @gateway.Shard
  priv framework_ : @framework.Framework
  priv mut shutdown_requested_ : Bool
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
/// Wait for the next component interaction with an exact custom id.
pub async fn GatewayCtx::wait_for_component(
  self : GatewayCtx,
  custom_id~ : String,
  timeout_ms? : Int,
) -> @framework.ComponentCtx? {
  self.framework_.wait_for_component(custom_id~, timeout_ms?)
}

///|
/// Request a graceful stop. Closing the shard wakes the run loop; the task
/// group then waits for already-started handlers before returning normally.
pub async fn GatewayCtx::shutdown(self : GatewayCtx) -> Unit {
  self.shutdown_requested_ = true
  self.shard_.close()
}
