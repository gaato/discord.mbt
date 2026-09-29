///|
/// The operation whose handler failed.
pub(all) enum FailureOrigin {
  Command(name~ : String)
  Autocomplete(name~ : String)
  Component(custom_id~ : String)
  Modal(custom_id~ : String)
  Event(kind~ : @model.EventKind)
  Service(name~ : String)
} derive(Debug)

///|
/// The underlying interaction context for a failure.
///
/// Event, service, and autocomplete failures have no raw context. Responding
/// through these contexts without checking the response state may fail; prefer
/// `FailureCtx::respond_error()` for ordinary error responses.
pub(all) enum FailureRaw {
  RawCommand(@framework.CommandCtx)
  RawComponent(@framework.ComponentCtx)
  RawModal(@framework.ModalCtx)
}

///|
/// Context handed to the error policy when a handler fails.
pub struct FailureCtx {
  priv origin_ : FailureOrigin
  priv raw_ : FailureRaw?
  priv warn_ : (AppWarning) -> Unit
}

///|
/// The operation whose handler failed.
pub fn FailureCtx::origin(self : FailureCtx) -> FailureOrigin {
  self.origin_
}

///|
/// Read the gate's current state. Event, service, and autocomplete failures
/// have no raw context and return `None`.
pub fn FailureCtx::response_state(
  self : FailureCtx,
) -> @framework.ResponseState? {
  match self.raw_ {
    Some(RawCommand(ctx)) => Some(ctx.response_state())
    Some(RawComponent(ctx)) => Some(ctx.response_state())
    Some(RawModal(ctx)) => Some(ctx.response_state())
    None => None
  }
}

///|
/// Access the underlying interaction context. Event, service, and autocomplete failures
/// return `None`. Direct responses through this escape hatch may fail unless
/// the response state is checked first; normally use `respond_error()`.
pub fn FailureCtx::raw(self : FailureCtx) -> FailureRaw? {
  self.raw_
}

///|
/// The interaction payload associated with this failure. Event and service
/// failures return `None`.
pub fn FailureCtx::interaction(self : FailureCtx) -> @model.Interaction? {
  match self.raw_ {
    Some(RawCommand(ctx)) => Some(ctx.interaction)
    Some(RawComponent(ctx)) => Some(ctx.interaction)
    Some(RawModal(ctx)) => Some(ctx.interaction)
    None => None
  }
}

///|
/// The user who invoked the failed interaction. Event and service failures
/// return `None`.
pub fn FailureCtx::user(self : FailureCtx) -> @model.User? {
  guard self.interaction() is Some(interaction) else { return None }
  match interaction.guild_member {
    Some(guild_member) =>
      match guild_member.user {
        Some(user) => Some(user)
        None => interaction.user
      }
    None => interaction.user
  }
}

///|
fn error_response_summary(
  content : String?,
  embeds : Array[@model.Embed]?,
  components : Array[@model.Component]?,
  files : Array[@dhttp.FileUpload]?,
) -> String {
  guard content is None else { return content.unwrap() }
  let kinds : Array[String] = []
  if embeds is Some(_) {
    kinds.push("embeds")
  }
  if components is Some(_) {
    kinds.push("components")
  }
  if files is Some(_) {
    kinds.push("files")
  }
  match kinds {
    [] => "empty error response"
    [kind] => "\{kind}-only error response"
    _ => "\{kinds.join("+")} error response"
  }
}

///|
/// Send an error without violating Discord's one-initial-response rule.
/// A pending callback gets an initial response; a deferred message whose
/// loading placeholder is still showing is edited in place (keeping the
/// visibility chosen when deferring); any other sent or unconfirmed callback
/// gets a followup. Expired callbacks and failures without a raw context
/// send a payload summary to the warning hook.
pub async fn FailureCtx::respond_error(
  self : FailureCtx,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[@dhttp.FileUpload],
  allowed_mentions? : @model.AllowedMentions,
  ephemeral? : Bool = true,
) -> Unit {
  guard self.raw_ is Some(raw) else {
    (self.warn_)(
      ErrorResponseWithoutInteraction(
        summary=error_response_summary(content, embeds, components, files),
      ),
    )
    return
  }
  let replied = try {
    match raw {
      RawCommand(ctx) =>
        ctx.reply(
          content?,
          embeds?,
          components?,
          files?,
          allowed_mentions?,
          ephemeral~,
        )
      RawComponent(ctx) =>
        ctx.reply(
          content?,
          embeds?,
          components?,
          files?,
          allowed_mentions?,
          ephemeral~,
        )
      RawModal(ctx) =>
        ctx.reply(
          content?,
          embeds?,
          components?,
          files?,
          allowed_mentions?,
          ephemeral~,
        )
    }
    true
  } catch {
    @framework.ResponseGateError::Expired => false
    error => raise error
  }
  if !replied {
    (self.warn_)(
      ErrorResponseExpired(
        summary=error_response_summary(content, embeds, components, files),
      ),
    )
  }
}

///|
/// Policy invoked for interaction, event, and service failures.
pub type ErrorPolicy = async (FailureCtx, Error) -> Unit

///|
/// Tell the user an interaction failed without echoing internal details.
/// Event, service, and autocomplete failures have nobody to tell.
async fn respond_if_interactive(ctx : FailureCtx, message : String) -> Unit {
  if ctx.raw_ is Some(_) {
    ctx.respond_error(content=message)
  }
}

///|
fn default_error_policy(warn : (AppWarning) -> Unit) -> ErrorPolicy {
  (ctx, error) => {
    match error {
      HandlerError::UserMessage(message~, ephemeral~) =>
        ctx.respond_error(content=message, ephemeral~)
      HandlerError::GuildOnly =>
        ctx.respond_error(content="This command can only be used in a server.")
      HandlerError::DmOnly =>
        ctx.respond_error(
          content="This command can only be used in a direct message.",
        )
      HandlerError::CheckFailed =>
        ctx.respond_error(content="You cannot use this command.")
      HandlerError::MissingPermission(permissions) =>
        ctx.respond_error(
          content="Missing required permission: \{Repr(permissions)}",
        )
      HandlerError::OnCooldown(retry_after_ms~) =>
        ctx.respond_error(
          content="This command is on cooldown. Try again in \{retry_after_ms} ms.",
        )
      HandlerError::InvalidInput(name=Some(name), message~) =>
        ctx.respond_error(content="Invalid value for \{name}: \{message}")
      HandlerError::InvalidInput(name=None, message~) =>
        ctx.respond_error(content="Invalid input: \{message}")
      HandlerError::Busy =>
        ctx.respond_error(
          content="The bot is busy right now. Please try again in a moment.",
        )
      HandlerError::Malformed(reason~) => {
        warn(MalformedInteraction(origin=ctx.origin(), reason~))
        respond_if_interactive(
          ctx, "This interaction is out of date. Please try again.",
        )
      }
      _ => {
        warn(UnhandledFailure(origin=ctx.origin(), error~))
        respond_if_interactive(ctx, "Something went wrong.")
      }
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
    policy_error if @async.is_being_cancelled() => raise policy_error
    policy_error => (ctx.warn_)(ErrorPolicyFailed(error=policy_error))
  }
}
