///|
/// The routed target of an interaction entering the middleware chain.
/// Autocomplete, gateway events, and services never pass through it.
pub(all) enum InteractionTarget {
  Command(name~ : String)
  Component(custom_id~ : String)
  Modal(custom_id~ : String)
} derive(Debug)

///|
/// Read-only context handed to interaction middleware, before any initial
/// response has been sent.
pub struct InteractionCtx {
  priv target_ : InteractionTarget
  priv raw_ : FailureRaw
}

///|
/// The routed command, component, or modal being invoked.
pub fn InteractionCtx::target(self : InteractionCtx) -> InteractionTarget {
  self.target_
}

///|
/// The full interaction payload.
pub fn InteractionCtx::interaction(self : InteractionCtx) -> @model.Interaction {
  match self.raw_ {
    RawCommand(ctx) => ctx.interaction
    RawComponent(ctx) => ctx.interaction
    RawModal(ctx) => ctx.interaction
  }
}

///|
/// The invoking user.
pub fn InteractionCtx::user(self : InteractionCtx) -> @model.User {
  match self.raw_ {
    RawCommand(ctx) => ctx.user()
    RawComponent(ctx) => ctx.user()
    RawModal(ctx) => ctx.user()
  }
}

///|
/// Guild or DM invocation scope, carrying the invoking member or user.
pub fn InteractionCtx::scope(
  self : InteractionCtx,
) -> @framework.InvocationScope {
  match self.raw_ {
    RawCommand(ctx) => ctx.scope()
    RawComponent(ctx) => ctx.scope()
    RawModal(ctx) => ctx.scope()
  }
}

///|
/// The validated guild invocation. In a DM this raises
/// `HandlerError::GuildOnly`, which the error policy renders normally.
pub fn InteractionCtx::guild_scope(
  self : InteractionCtx,
) -> @framework.GuildInvocation raise HandlerError {
  let scope = match self.raw_ {
    RawCommand(ctx) => ctx.guild_scope()
    RawComponent(ctx) => ctx.guild_scope()
    RawModal(ctx) => ctx.guild_scope()
  }
  require_guild(scope)
}

///|
/// The guild the interaction was invoked in, or `None` outside guilds. Use
/// `guild_scope()` for flows that require a guild; this accessor is for
/// maybe-guild flows where DMs are valid.
pub fn InteractionCtx::guild_id(self : InteractionCtx) -> @model.GuildId? {
  self.interaction().guild_id
}

///|
/// Send the initial response from middleware, short-circuiting the handler.
pub async fn InteractionCtx::respond(
  self : InteractionCtx,
  message : String,
  ephemeral? : Bool = true,
) -> Unit {
  match self.raw_ {
    RawCommand(ctx) => ctx.respond(content=message, ephemeral~)
    RawComponent(ctx) => ctx.respond(content=message, ephemeral~)
    RawModal(ctx) => ctx.respond(content=message, ephemeral~)
  }
}

///|
/// Middleware around interaction dispatch: receives the read-only
/// context and a `next` continuation. Call `next()` to continue the
/// chain; skip it (typically after `InteractionCtx::respond`) to
/// short-circuit the handler.
pub type InteractionMiddleware = async (InteractionCtx, async () -> Unit) -> Unit

///|
async fn App::run_middleware(
  self : App,
  ctx : InteractionCtx,
  index : Int,
  terminal : async () -> Unit,
) -> Unit {
  if index < self.middleware_.length() {
    self.middleware_[index](ctx, () => {
      self.run_middleware(ctx, index + 1, terminal)
    })
  } else {
    terminal()
  }
}
