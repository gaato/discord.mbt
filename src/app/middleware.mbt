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
pub fn InteractionCtx::target(self : InteractionCtx) -> InteractionTarget {
  self.target_
}

///|
pub fn InteractionCtx::interaction(self : InteractionCtx) -> @model.Interaction {
  match self.raw_ {
    RawCommand(ctx) => ctx.interaction
    RawComponent(ctx) => ctx.interaction
    RawModal(ctx) => ctx.interaction
  }
}

///|
pub fn InteractionCtx::user(self : InteractionCtx) -> @model.User {
  match self.raw_ {
    RawCommand(ctx) => ctx.user()
    RawComponent(ctx) => ctx.user()
    RawModal(ctx) => ctx.user()
  }
}

///|
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
