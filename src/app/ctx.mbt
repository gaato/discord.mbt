///|
/// Transport-neutral services available to interaction handlers.
///
/// Values are constructed by the bot runtime; the public API intentionally
/// exposes read-only accessors only.
pub struct AppCtx {
  priv client_ : @dhttp.Client
  priv application_id_ : @model.ApplicationId
}

///|
/// The Discord REST client used by this bot.
pub fn AppCtx::http(self : AppCtx) -> @dhttp.Client {
  self.client_
}

///|
/// The application id learned during startup.
pub fn AppCtx::application_id(self : AppCtx) -> @model.ApplicationId {
  self.application_id_
}

///|
pub type ComponentWaiter = async (String, Int?) -> @framework.ComponentCtx?

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
  priv bot_ : AppCtx
}

///|
pub fn ImmediateCtx::app(self : ImmediateCtx) -> AppCtx {
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
  priv bot_ : AppCtx
  priv waiter_ : ComponentWaiter?
  priv warn_ : (String) -> Unit
}

///|
pub fn DeferredCtx::app(self : DeferredCtx) -> AppCtx {
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
