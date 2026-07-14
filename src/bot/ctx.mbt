///|
/// Transport-neutral services available to interaction handlers.
///
/// Values are constructed by the bot runtime; the public API intentionally
/// exposes read-only accessors only.
pub struct BotCtx {
  priv client_ : @dhttp.Client
  priv application_id_ : @model.ApplicationId
}

///|
/// The Discord REST client used by this bot.
pub fn BotCtx::http(self : BotCtx) -> @dhttp.Client {
  self.client_
}

///|
/// The application id learned during startup.
pub fn BotCtx::application_id(self : BotCtx) -> @model.ApplicationId {
  self.application_id_
}

///|
/// Gateway-only services passed to event and service handlers after READY.
/// GatewayCtx points to its transport-neutral BotCtx; BotCtx never points back.
pub struct GatewayCtx {
  priv bot_ : BotCtx
  priv mut ready_ : @model.Ready
  priv shard_ : @gateway.Shard
  priv framework_ : @framework.Framework
  priv mut shutdown_requested_ : Bool
}

///|
/// The transport-neutral bot context for REST access.
pub fn GatewayCtx::bot(self : GatewayCtx) -> BotCtx {
  self.bot_
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

///|
type ComponentWaiter = async (String, Int?) -> @framework.ComponentCtx?

///|
/// The response state when an interaction handler failed.
pub(all) enum ResponsePhase {
  BeforeInitial
  AfterDeferred
  AfterInitial
} derive(Debug, Eq)

///|
/// Read-only command context for handlers that return their initial response.
pub struct ImmediateCtx {
  priv raw_ : @framework.CommandCtx
  priv bot_ : BotCtx
}

///|
pub fn ImmediateCtx::bot(self : ImmediateCtx) -> BotCtx {
  self.bot_
}

///|
pub fn ImmediateCtx::user(self : ImmediateCtx) -> @model.User? {
  self.raw_.user()
}

///|
pub fn ImmediateCtx::interaction(self : ImmediateCtx) -> @model.Interaction {
  self.raw_.interaction
}

///|
pub fn ImmediateCtx::guild_id(self : ImmediateCtx) -> @model.GuildId? {
  self.raw_.interaction.guild_id
}

///|
/// Escape hatch for advanced read-only inspection. Calling response methods on
/// this raw value opts out of the immediate-handler response discipline.
pub fn ImmediateCtx::raw(self : ImmediateCtx) -> @framework.CommandCtx {
  self.raw_
}

///|
/// Command context made available after the initial deferred response.
pub struct DeferredCtx {
  priv raw_ : @framework.CommandCtx
  priv bot_ : BotCtx
  priv waiter_ : ComponentWaiter?
  priv warn_ : (String) -> Unit
}

///|
pub fn DeferredCtx::bot(self : DeferredCtx) -> BotCtx {
  self.bot_
}

///|
pub fn DeferredCtx::user(self : DeferredCtx) -> @model.User? {
  self.raw_.user()
}

///|
pub fn DeferredCtx::interaction(self : DeferredCtx) -> @model.Interaction {
  self.raw_.interaction
}

///|
pub fn DeferredCtx::guild_id(self : DeferredCtx) -> @model.GuildId? {
  self.raw_.interaction.guild_id
}

///|
pub fn DeferredCtx::raw(self : DeferredCtx) -> @framework.CommandCtx {
  self.raw_
}

///|
/// Edit the original response after deferring.
pub async fn DeferredCtx::edit_original(
  self : DeferredCtx,
  content? : @model.Undefinable[String] = Missing,
  embeds? : @model.Undefinable[Array[@model.Embed]] = Missing,
  components? : @model.Undefinable[Array[@model.Component]] = Missing,
  files? : Array[@dhttp.FileUpload],
) -> @model.Message {
  self.raw_.edit_response(content~, embeds~, components~, files?)
}

///|
/// Send a followup message after the initial deferred response.
pub async fn DeferredCtx::followup(
  self : DeferredCtx,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[@dhttp.FileUpload],
  ephemeral? : Bool = false,
) -> @model.Message {
  self.raw_.followup(content?, embeds?, components?, files?, ephemeral~)
}

///|
/// Wait for the next component interaction with an exact custom id.
pub async fn DeferredCtx::wait_for_component(
  self : DeferredCtx,
  custom_id~ : String,
  timeout_ms? : Int,
) -> @framework.ComponentCtx? {
  match self.waiter_ {
    Some(waiter) => waiter(custom_id, timeout_ms)
    None => {
      (self.warn_)(
        "component waiting is unavailable without a gateway connection",
      )
      None
    }
  }
}
