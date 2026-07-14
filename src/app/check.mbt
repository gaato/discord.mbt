///|
/// Read-only context passed to command checks before argument decoding and
/// handler execution.
pub struct CheckCtx {
  priv raw_ : @framework.CommandCtx
}

///|
pub fn CheckCtx::scope(self : CheckCtx) -> @framework.InvocationScope {
  self.raw_.scope()
}

///|
pub fn CheckCtx::user(self : CheckCtx) -> @model.User {
  self.raw_.user()
}

///|
pub fn CheckCtx::interaction(self : CheckCtx) -> @model.Interaction {
  self.raw_.interaction
}

///|
pub fn CheckCtx::guild_id(self : CheckCtx) -> @model.GuildId? {
  self.raw_.interaction.guild_id
}

///|
/// A command guard. Returning false produces `HandlerError::CheckFailed`;
/// expected denials can instead raise a more specific `HandlerError`.
pub type CommandCheck = (CheckCtx) -> Bool raise HandlerError

///|
/// Require a guild invocation.
pub fn guild_only() -> CommandCheck {
  ctx => {
    match ctx.scope() {
      Guild(_) => true
      Dm(_) => raise HandlerError::GuildOnly
    }
  }
}

///|
/// Require a direct-message invocation.
pub fn dm_only() -> CommandCheck {
  ctx => {
    match ctx.scope() {
      Dm(_) => true
      Guild(_) => raise HandlerError::DmOnly
    }
  }
}

///|
/// Require effective guild permissions supplied on the interaction member.
/// Discord does not provide member permissions for DM invocations.
pub fn required_permissions(required : @model.Permissions) -> CommandCheck {
  ctx => {
    match ctx.scope() {
      Guild(member) => {
        guard member.permissions is Some(actual) &&
          (
            actual.contains(@model.Permissions::administrator()) ||
            actual.contains(required)
          ) else {
          raise HandlerError::MissingPermission(required)
        }
        true
      }
      Dm(_) => raise HandlerError::GuildOnly
    }
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
        None => raise HandlerError::GuildOnly
      }
    Global => "global"
  }
}

///|
fn RegisteredCommand::run_checks_and_cooldown(
  self : RegisteredCommand,
  raw : @framework.CommandCtx,
  now_ms : Int64,
) -> Unit raise HandlerError {
  let ctx : CheckCtx = { raw_: raw }
  for check in self.checks_ {
    if !check(ctx) {
      raise HandlerError::CheckFailed
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
      raise HandlerError::OnCooldown(retry_after_ms=expires_at - now_ms)
    _ => self.cooldowns_[key] = now_ms + duration_ms
  }
}
