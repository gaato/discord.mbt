///|
/// Read-only context passed to command checks before argument decoding and
/// handler execution.
pub struct CheckCtx {
  priv raw_ : @framework.CommandCtx
  priv bot_ : AppCtx
}

///|
/// The app-level services: the REST client and application id.
pub fn CheckCtx::app(self : CheckCtx) -> AppCtx {
  self.bot_
}

///|
/// Guild or DM invocation scope, carrying the invoking member or user.
pub fn CheckCtx::scope(self : CheckCtx) -> @framework.InvocationScope {
  self.raw_.scope()
}

///|
/// The validated guild invocation. In a DM this raises
/// `HandlerError::GuildOnly`, which the error policy renders normally.
pub fn CheckCtx::guild_scope(
  self : CheckCtx,
) -> @framework.GuildInvocation raise HandlerError {
  require_guild(self.raw_.guild_scope())
}

///|
/// The invoking user.
pub fn CheckCtx::user(self : CheckCtx) -> @model.User {
  self.raw_.user()
}

///|
/// The full interaction payload.
pub fn CheckCtx::interaction(self : CheckCtx) -> @model.Interaction {
  self.raw_.interaction
}

///|
/// The guild the interaction was invoked in, or `None` outside guilds. Use
/// `guild_scope()` for flows that require a guild; this accessor is for
/// maybe-guild flows where DMs are valid.
pub fn CheckCtx::guild_id(self : CheckCtx) -> @model.GuildId? {
  self.raw_.interaction.guild_id
}

///|
/// A command guard. Returning false produces `HandlerError::CheckFailed`; raise
/// a more specific `HandlerError` for an expected denial. Any other error
/// reaches the error policy unchanged.
pub type CommandCheck = async (CheckCtx) -> Bool

///|
/// Require a guild invocation.
pub fn guild_only() -> CommandCheck {
  ctx => {
    match ctx.scope() {
      Guild(_) => true
      Dm(_) => raise GuildOnly
    }
  }
}

///|
/// Require a direct-message invocation.
pub fn dm_only() -> CommandCheck {
  ctx => {
    match ctx.scope() {
      Dm(_) => true
      Guild(_) => raise DmOnly
    }
  }
}

///|
/// Require effective guild permissions supplied on the interaction member.
/// Discord does not provide member permissions for DM invocations.
pub fn required_permissions(required : @model.Permissions) -> CommandCheck {
  ctx => {
    let guild = ctx.guild_scope()
    guard guild.member.permissions is Some(actual) &&
      (
        actual.contains(@model.Permissions::administrator()) ||
        actual.contains(required)
      ) else {
      raise MissingPermission(required)
    }
    true
  }
}

///|
/// Identity used to share a fixed-window command cooldown.
pub(all) enum CooldownBucket {
  User
  Guild
  Global
} derive(Debug, Eq)

///|
priv struct CooldownConfig {
  seconds : Int
  bucket : CooldownBucket
}

///|
fn cooldown_key(
  config : CooldownConfig,
  ctx : CheckCtx,
) -> String raise HandlerError {
  match config.bucket {
    User => "user:\{ctx.user().id}"
    Guild =>
      match ctx.guild_id() {
        Some(guild_id) => "guild:\{guild_id}"
        None => raise GuildOnly
      }
    Global => "global"
  }
}

///|
async fn RegisteredCommand::run_checks_and_cooldown(
  self : RegisteredCommand,
  bot : AppCtx,
  raw : @framework.CommandCtx,
  now_ms : Int64,
) -> Unit {
  let ctx = CheckCtx::{ raw_: raw, bot_: bot, }
  for check in self.checks_ {
    if !check(ctx) {
      raise CheckFailed
    }
  }
  guard self.cooldown_ is Some(config) else { return }
  let key = cooldown_key(config, ctx)
  let duration_ms = config.seconds.to_int64() * 1000L
  if now_ms >= self.cooldown_cleanup_after_ {
    let expired : Array[String] = []
    for pending_key, expires_at in self.cooldowns_ {
      if expires_at <= now_ms {
        expired.push(pending_key)
      }
    }
    for pending_key in expired {
      self.cooldowns_.remove(pending_key) |> ignore
    }
    self.cooldown_cleanup_after_ = now_ms + duration_ms
  }
  match self.cooldowns_.get(key) {
    Some(expires_at) if expires_at > now_ms =>
      raise OnCooldown(retry_after_ms=expires_at - now_ms)
    _ => self.cooldowns_[key] = now_ms + duration_ms
  }
}
