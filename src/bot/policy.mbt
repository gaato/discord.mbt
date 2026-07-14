///|
/// The operation whose handler failed.
pub(all) enum FailureOrigin {
  Command(name~ : String)
  Event(kind~ : @model.EventKind)
  Service(name~ : String)
} derive(Debug)

///|
/// Error-policy context. A raw command context is present only while handling
/// an application command, so event and service failures cannot accidentally
/// send an interaction response.
pub struct FailureCtx {
  priv origin_ : FailureOrigin
  priv phase_ : ResponsePhase?
  priv raw_ : @framework.CommandCtx?
  priv warn_ : (String) -> Unit
}

///|
pub fn FailureCtx::origin(self : FailureCtx) -> FailureOrigin {
  self.origin_
}

///|
pub fn FailureCtx::phase(self : FailureCtx) -> ResponsePhase? {
  self.phase_
}

///|
/// Send an error without violating Discord's one-initial-response rule.
/// Event and service failures have no response target; those calls are sent to
/// the warning hook instead of guessing a channel.
pub async fn FailureCtx::respond_error(
  self : FailureCtx,
  message : String,
  ephemeral? : Bool = true,
) -> Unit {
  guard self.raw_ is Some(raw) else {
    (self.warn_)("cannot respond to a non-command failure: \{message}")
    return
  }
  match self.phase_ {
    Some(BeforeInitial) | None => raw.respond(content=message, ephemeral~)
    Some(AfterDeferred) | Some(AfterInitial) =>
      raw.followup(content=message, ephemeral~) |> ignore
  }
}

///|
/// Policy invoked for command, event, and service failures.
pub type ErrorPolicy = async (FailureCtx, Error) -> Unit

///|
fn default_error_policy(warn : (String) -> Unit) -> ErrorPolicy {
  (ctx, error) => {
    match error {
      HandlerError::UserMessage(message~, ephemeral~) =>
        ctx.respond_error(message, ephemeral~)
      HandlerError::GuildOnly =>
        ctx.respond_error("This command can only be used in a server.")
      HandlerError::MissingPermission(permissions) =>
        ctx.respond_error(
          "Missing required permission: \{to_repr(permissions)}",
        )
      HandlerError::InvalidArgument(message) =>
        ctx.respond_error("Invalid argument: \{message}")
      _ =>
        warn(
          "unhandled bot failure (\{to_repr(ctx.origin())}): \{to_repr(error)}",
        )
    }
  }
}

///|
async fn invoke_error_policy(
  policy : ErrorPolicy,
  ctx : FailureCtx,
  error : Error,
) -> Unit {
  policy(ctx, error) catch {
    policy_error if @async.is_being_cancelled() ||
      @async.is_cancellation_error(policy_error) => raise policy_error
    policy_error => (ctx.warn_)("error policy failed: \{to_repr(policy_error)}")
  }
}
