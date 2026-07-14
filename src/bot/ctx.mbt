///|
/// Runtime services available to typed bot handlers after READY.
///
/// Values are constructed by the bot runtime; the public API intentionally
/// exposes read-only accessors only.
pub struct BotCtx {
  priv client_ : @dhttp.Client
  priv application_id_ : @model.ApplicationId
  priv mut ready_ : @model.Ready
  priv shard_ : @gateway.Shard
  priv framework_ : @framework.Framework
  priv mut shutdown_requested_ : Bool
}

///|
/// Request a graceful stop. Closing the shard wakes the run loop; the task
/// group then waits for already-started handlers before returning normally.
pub async fn BotCtx::shutdown(self : BotCtx) -> Unit {
  self.shutdown_requested_ = true
  self.shard_.close()
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
/// The READY payload for this bot session.
pub fn BotCtx::ready(self : BotCtx) -> @model.Ready {
  self.ready_
}

///|
/// Access the underlying gateway shard.
pub fn BotCtx::shard_raw(self : BotCtx) -> @gateway.Shard {
  self.shard_
}

///|
/// Access the underlying interaction framework.
pub fn BotCtx::framework_raw(self : BotCtx) -> @framework.Framework {
  self.framework_
}

///|
/// Wait for the next component interaction with an exact custom id.
pub async fn BotCtx::wait_for_component(
  self : BotCtx,
  custom_id~ : String,
  timeout_ms? : Int,
) -> @framework.ComponentCtx? {
  self.framework_.wait_for_component(custom_id~, timeout_ms?)
}

///|
/// The response state when a command handler failed.
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
  self.bot_.wait_for_component(custom_id~, timeout_ms?)
}
