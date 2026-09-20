///|
/// Transport-neutral services available to interaction handlers.
///
/// Executors construct these values; the public API exposes read-only
/// accessors.
pub struct AppCtx {
  priv client_ : @dhttp.Client
  priv application_id_ : @model.ApplicationId
  priv latency_ms_ : (() -> Int64?)?
}

///|
/// The Discord REST client used by this application.
pub fn AppCtx::http(self : AppCtx) -> @dhttp.Client {
  self.client_
}

///|
/// The application id learned during startup.
pub fn AppCtx::application_id(self : AppCtx) -> @model.ApplicationId {
  self.application_id_
}

///|
/// The latest gateway heartbeat round-trip time in milliseconds. For a
/// multi-shard bot, this is the arithmetic mean of shards that have measured
/// latency. HTTP interaction executors and gateway connections awaiting their
/// first heartbeat acknowledgement return `None`; use
/// `GatewayCtx::latency_ms()` when the exact value for one shard is required.
pub fn AppCtx::latency_ms(self : AppCtx) -> Int64? {
  match self.latency_ms_ {
    Some(provider) => provider()
    None => None
  }
}

///|
/// The current application bound to its Discord REST client.
pub fn AppCtx::application_ref(self : AppCtx) -> @dhttp.ApplicationRef {
  self.client_.application_ref(self.application_id_)
}

///|
/// Executor-provided lookup behind `wait_for_component`: resolves the
/// next component interaction matching a custom id, with an optional
/// timeout in milliseconds.
pub type ComponentWaiter = async (String, Int?) -> @framework.ComponentCtx?

///|
fn require_guild(
  scope : @framework.GuildInvocation?,
) -> @framework.GuildInvocation raise HandlerError {
  match scope {
    Some(guild) => guild
    None => raise GuildOnly
  }
}

///|
/// Read-only command context for handlers that return their initial response.
pub struct ImmediateCtx {
  priv raw_ : @framework.CommandCtx
  priv bot_ : AppCtx
}

///|
/// The app-level services: the REST client and application id.
pub fn ImmediateCtx::app(self : ImmediateCtx) -> AppCtx {
  self.bot_
}

///|
/// Guild or DM invocation scope, carrying the invoking member or user.
pub fn ImmediateCtx::scope(self : ImmediateCtx) -> @framework.InvocationScope {
  self.raw_.scope()
}

///|
/// The validated guild invocation. In a DM this raises
/// `HandlerError::GuildOnly`, which the error policy renders normally.
pub fn ImmediateCtx::guild_scope(
  self : ImmediateCtx,
) -> @framework.GuildInvocation raise HandlerError {
  require_guild(self.raw_.guild_scope())
}

///|
/// The invoking user.
pub fn ImmediateCtx::user(self : ImmediateCtx) -> @model.User {
  self.raw_.user()
}

///|
/// The full interaction payload.
pub fn ImmediateCtx::interaction(self : ImmediateCtx) -> @model.Interaction {
  self.raw_.interaction
}

///|
/// The guild the interaction was invoked in, or `None` outside guilds. Use
/// `guild_scope()` for flows that require a guild; this accessor is for
/// maybe-guild flows where DMs are valid.
pub fn ImmediateCtx::guild_id(self : ImmediateCtx) -> @model.GuildId? {
  self.raw_.interaction.guild_id
}

///|
/// Escape hatch for advanced read-only inspection. Calling response methods on
/// this raw value opts out of the immediate-handler response discipline.
/// Failure handling still follows the gate's real response state.
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
/// The app-level services: the REST client and application id.
pub fn DeferredCtx::app(self : DeferredCtx) -> AppCtx {
  self.bot_
}

///|
/// Guild or DM invocation scope, carrying the invoking member or user.
pub fn DeferredCtx::scope(self : DeferredCtx) -> @framework.InvocationScope {
  self.raw_.scope()
}

///|
/// The validated guild invocation. In a DM this raises
/// `HandlerError::GuildOnly`, which the error policy renders normally.
pub fn DeferredCtx::guild_scope(
  self : DeferredCtx,
) -> @framework.GuildInvocation raise HandlerError {
  require_guild(self.raw_.guild_scope())
}

///|
/// The invoking user.
pub fn DeferredCtx::user(self : DeferredCtx) -> @model.User {
  self.raw_.user()
}

///|
/// The full interaction payload.
pub fn DeferredCtx::interaction(self : DeferredCtx) -> @model.Interaction {
  self.raw_.interaction
}

///|
/// The guild the interaction was invoked in, or `None` outside guilds. Use
/// `guild_scope()` for flows that require a guild; this accessor is for
/// maybe-guild flows where DMs are valid.
pub fn DeferredCtx::guild_id(self : DeferredCtx) -> @model.GuildId? {
  self.raw_.interaction.guild_id
}

///|
/// Escape hatch for advanced inspection. Calling response methods on the
/// raw value opts out of this wrapper's response discipline.
/// Failure handling still follows the gate's real response state.
pub fn DeferredCtx::raw(self : DeferredCtx) -> @framework.CommandCtx {
  self.raw_
}

///|
/// Edit the original response after deferring.
pub async fn DeferredCtx::edit_original(
  self : DeferredCtx,
  content? : String,
  clear_content? : Bool = false,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  allowed_mentions? : @model.AllowedMentions,
  files? : Array[@dhttp.FileUpload],
) -> @model.Message {
  self.raw_.edit_response(
    content?,
    clear_content~,
    embeds?,
    components?,
    allowed_mentions?,
    files?,
  )
}

///|
/// Send a followup message after the initial deferred response.
pub async fn DeferredCtx::followup(
  self : DeferredCtx,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[@dhttp.FileUpload],
  allowed_mentions? : @model.AllowedMentions,
  ephemeral? : Bool = false,
) -> @model.Message {
  self.raw_.followup(
    content?,
    embeds?,
    components?,
    files?,
    allowed_mentions?,
    ephemeral~,
  )
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
