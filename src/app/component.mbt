///|
/// Initial response returned by an immediate component handler.
pub(all) enum ComponentReply {
  UpdateMessage(MessageUpdate)
  Message(InitialResponse)
  ShowModal(ModalHandle)
}

///|
/// Execution strategy for a component route.
pub(all) enum ComponentHandler[A] {
  Immediate(async (ComponentImmediateCtx, A) -> ComponentReply)
  DeferredUpdate(async (ComponentDeferredCtx, A) -> Unit)
  DeferredMessage(ephemeral~ : Bool, async (ComponentDeferredCtx, A) -> Unit)
  Raw(async (@framework.ComponentCtx) -> Unit)
}

///|
fn[A] ComponentHandler::ack_plan(self : ComponentHandler[A]) -> AckPlan {
  match self {
    DeferredUpdate(_) => DeferUpdate
    DeferredMessage(ephemeral~, _) => DeferMessage(ephemeral~)
    Immediate(_) | Raw(_) => Respond
  }
}

///|
/// Read-only component context for handlers returning their initial callback.
pub struct ComponentImmediateCtx {
  priv raw_ : @framework.ComponentCtx
  priv bot_ : AppCtx
}

///|
/// Component context available after a deferred callback.
pub struct ComponentDeferredCtx {
  priv raw_ : @framework.ComponentCtx
  priv bot_ : AppCtx
  priv waiter_ : ComponentWaiter?
  priv warn_ : (AppWarning) -> Unit
}

///|
/// Reply by editing the message that hosts the component. Omitted fields keep
/// their current value; `clear_content` removes the text, and
/// `keep_attachments` lists the existing attachments to retain alongside new
/// `files` (see `MessageUpdate`).
pub fn ComponentReply::update_message(
  content? : String,
  clear_content? : Bool = false,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  allowed_mentions? : @model.AllowedMentions,
  files? : Array[@dhttp.FileUpload],
  keep_attachments? : Array[@model.AttachmentRequest],
  poll? : @model.PollCreateRequest,
) -> ComponentReply {
  UpdateMessage(
    MessageUpdate(
      content?,
      clear_content~,
      embeds?,
      components?,
      allowed_mentions?,
      files?,
      keep_attachments?,
      poll?,
    ),
  )
}

///|
/// Reply with a new message; set `ephemeral=true` to show it only to
/// the invoking user.
pub fn ComponentReply::message(
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[@dhttp.FileUpload],
  allowed_mentions? : @model.AllowedMentions,
  poll? : @model.PollCreateRequest,
  ephemeral? : Bool = false,
) -> ComponentReply {
  Message(
    InitialResponse::message(
      content?,
      embeds?,
      components?,
      files?,
      allowed_mentions?,
      poll?,
      ephemeral~,
    ),
  )
}

///|
async fn InitialResponse::send_component(
  self : InitialResponse,
  ctx : @framework.ComponentCtx,
) -> Unit {
  ctx.respond(
    content?=self.content_,
    embeds?=self.embeds_,
    components?=self.components_,
    files?=self.files_,
    allowed_mentions?=self.allowed_mentions_,
    poll?=self.poll_,
    ephemeral=self.ephemeral_,
  )
}

///|
async fn ComponentReply::send(
  self : ComponentReply,
  ctx : @framework.ComponentCtx,
) -> Unit {
  match self {
    UpdateMessage(update) => update.send_component(ctx)
    Message(response) => response.send_component(ctx)
    ShowModal(handle) => handle.send_component(ctx)
  }
}

///|
fn component_values(raw : @framework.ComponentCtx) -> Array[String] {
  raw.data.values.map(values => values.copy()).unwrap_or([])
}

///|
fn selected_users(raw : @framework.ComponentCtx) -> Array[@model.User] {
  let result = []
  guard raw.data.resolved is Some(resolved) && resolved.users is Some(users) else {
    return result
  }
  for id in component_values(raw) {
    if users.get(id) is Some(user) {
      result.push(user)
    }
  }
  result
}

///|
fn selected_roles(raw : @framework.ComponentCtx) -> Array[@model.Role] {
  let result = []
  guard raw.data.resolved is Some(resolved) && resolved.roles is Some(roles) else {
    return result
  }
  for id in component_values(raw) {
    if roles.get(id) is Some(role) {
      result.push(role)
    }
  }
  result
}

///|
fn selected_channels(raw : @framework.ComponentCtx) -> Array[@model.Channel] {
  let result = []
  guard raw.data.resolved is Some(resolved) &&
    resolved.channels is Some(channels) else {
    return result
  }
  for id in component_values(raw) {
    if channels.get(id) is Some(channel) {
      result.push(channel)
    }
  }
  result
}

///|
/// The app-level services: the REST client and application id.
pub fn ComponentImmediateCtx::app(self : ComponentImmediateCtx) -> AppCtx {
  self.bot_
}

///|
/// The invoking user.
pub fn ComponentImmediateCtx::user(self : ComponentImmediateCtx) -> @model.User {
  self.raw_.user()
}

///|
/// Guild or DM invocation scope, carrying the invoking member or user.
pub fn ComponentImmediateCtx::scope(
  self : ComponentImmediateCtx,
) -> @framework.InvocationScope {
  self.raw_.scope()
}

///|
/// The validated guild invocation. In a DM this raises
/// `HandlerError::GuildOnly`, which the error policy renders normally.
pub fn ComponentImmediateCtx::guild_scope(
  self : ComponentImmediateCtx,
) -> @framework.GuildInvocation raise HandlerError {
  require_guild(self.raw_.guild_scope())
}

///|
/// The full interaction payload.
pub fn ComponentImmediateCtx::interaction(
  self : ComponentImmediateCtx,
) -> @model.Interaction {
  self.raw_.interaction
}

///|
/// The guild the interaction was invoked in, or `None` outside guilds. Use
/// `guild_scope()` for flows that require a guild; this accessor is for
/// maybe-guild flows where DMs are valid.
pub fn ComponentImmediateCtx::guild_id(
  self : ComponentImmediateCtx,
) -> @model.GuildId? {
  self.raw_.interaction.guild_id
}

///|
/// The full custom id of the component that fired.
pub fn ComponentImmediateCtx::custom_id(self : ComponentImmediateCtx) -> String {
  self.raw_.data.custom_id
}

///|
/// The raw string values selected in a select menu (empty for buttons).
pub fn ComponentImmediateCtx::values(
  self : ComponentImmediateCtx,
) -> Array[String] {
  component_values(self.raw_)
}

///|
/// Resolved user objects for a user or mentionable select.
pub fn ComponentImmediateCtx::selected_users(
  self : ComponentImmediateCtx,
) -> Array[@model.User] {
  selected_users(self.raw_)
}

///|
/// Resolved role objects for a role or mentionable select.
pub fn ComponentImmediateCtx::selected_roles(
  self : ComponentImmediateCtx,
) -> Array[@model.Role] {
  selected_roles(self.raw_)
}

///|
/// Resolved partial channel objects for a channel select.
pub fn ComponentImmediateCtx::selected_channels(
  self : ComponentImmediateCtx,
) -> Array[@model.Channel] {
  selected_channels(self.raw_)
}

///|
/// The message hosting the component.
pub fn ComponentImmediateCtx::message(
  self : ComponentImmediateCtx,
) -> @model.Message {
  self.raw_.message()
}

///|
/// Milliseconds left to return the initial response, or `None` when the
/// executor set no deadline.
pub fn ComponentImmediateCtx::remaining_ms(
  self : ComponentImmediateCtx,
) -> Int? {
  self.raw_.remaining_ms()
}

///|
/// Escape hatch to the underlying context. Its response methods bypass this
/// handler's discipline of returning its initial response: a callback sent
/// through it makes the returned reply fail with
/// `ResponseGateError::AlreadyResponded`, which reaches the error policy.
/// Prefer the read-only accessors on this context.
pub fn ComponentImmediateCtx::unchecked_raw(
  self : ComponentImmediateCtx,
) -> @framework.ComponentCtx {
  self.raw_
}

///|
/// The app-level services: the REST client and application id.
pub fn ComponentDeferredCtx::app(self : ComponentDeferredCtx) -> AppCtx {
  self.bot_
}

///|
/// The invoking user.
pub fn ComponentDeferredCtx::user(self : ComponentDeferredCtx) -> @model.User {
  self.raw_.user()
}

///|
/// Guild or DM invocation scope, carrying the invoking member or user.
pub fn ComponentDeferredCtx::scope(
  self : ComponentDeferredCtx,
) -> @framework.InvocationScope {
  self.raw_.scope()
}

///|
/// The validated guild invocation. In a DM this raises
/// `HandlerError::GuildOnly`, which the error policy renders normally.
pub fn ComponentDeferredCtx::guild_scope(
  self : ComponentDeferredCtx,
) -> @framework.GuildInvocation raise HandlerError {
  require_guild(self.raw_.guild_scope())
}

///|
/// The full interaction payload.
pub fn ComponentDeferredCtx::interaction(
  self : ComponentDeferredCtx,
) -> @model.Interaction {
  self.raw_.interaction
}

///|
/// The guild the interaction was invoked in, or `None` outside guilds. Use
/// `guild_scope()` for flows that require a guild; this accessor is for
/// maybe-guild flows where DMs are valid.
pub fn ComponentDeferredCtx::guild_id(
  self : ComponentDeferredCtx,
) -> @model.GuildId? {
  self.raw_.interaction.guild_id
}

///|
/// The full custom id of the component that fired.
pub fn ComponentDeferredCtx::custom_id(self : ComponentDeferredCtx) -> String {
  self.raw_.data.custom_id
}

///|
/// The raw string values selected in a select menu (empty for buttons).
pub fn ComponentDeferredCtx::values(
  self : ComponentDeferredCtx,
) -> Array[String] {
  component_values(self.raw_)
}

///|
/// Resolved user objects for a user or mentionable select.
pub fn ComponentDeferredCtx::selected_users(
  self : ComponentDeferredCtx,
) -> Array[@model.User] {
  selected_users(self.raw_)
}

///|
/// Resolved role objects for a role or mentionable select.
pub fn ComponentDeferredCtx::selected_roles(
  self : ComponentDeferredCtx,
) -> Array[@model.Role] {
  selected_roles(self.raw_)
}

///|
/// Resolved partial channel objects for a channel select.
pub fn ComponentDeferredCtx::selected_channels(
  self : ComponentDeferredCtx,
) -> Array[@model.Channel] {
  selected_channels(self.raw_)
}

///|
/// The message hosting the component.
pub fn ComponentDeferredCtx::message(
  self : ComponentDeferredCtx,
) -> @model.Message {
  self.raw_.message()
}

///|
/// Escape hatch for advanced inspection. Calling response methods on the
/// raw value opts out of this wrapper's response discipline.
/// Failure handling still follows the gate's real response state.
pub fn ComponentDeferredCtx::raw(
  self : ComponentDeferredCtx,
) -> @framework.ComponentCtx {
  self.raw_
}

///|
/// Fetch the original response.
pub async fn ComponentDeferredCtx::original(
  self : ComponentDeferredCtx,
) -> @model.Message {
  self.raw_.original_response()
}

///|
/// Edit the original response after deferring. For `DeferredUpdate`
/// handlers this edits the component's host message. New `files` replace
/// the existing attachments unless `keep_attachments` lists the ones to retain;
/// `poll` can be added only here, while editing the deferred response.
pub async fn ComponentDeferredCtx::edit_original(
  self : ComponentDeferredCtx,
  content? : String,
  clear_content? : Bool = false,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  allowed_mentions? : @model.AllowedMentions,
  files? : Array[@dhttp.FileUpload],
  keep_attachments? : Array[@model.AttachmentRequest],
  poll? : @model.PollCreateRequest,
) -> @model.Message {
  self.raw_.edit_response(
    content?,
    clear_content~,
    embeds?,
    components?,
    allowed_mentions?,
    files?,
    keep_attachments?,
    poll?,
  )
}

///|
/// Delete the original response.
pub async fn ComponentDeferredCtx::delete_original(
  self : ComponentDeferredCtx,
) -> Unit {
  self.raw_.delete_response()
}

///|
/// Send a followup message after the initial deferred response.
pub async fn ComponentDeferredCtx::followup(
  self : ComponentDeferredCtx,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[@dhttp.FileUpload],
  allowed_mentions? : @model.AllowedMentions,
  poll? : @model.PollCreateRequest,
  ephemeral? : Bool = false,
) -> @model.Message {
  self.raw_.followup(
    content?,
    embeds?,
    components?,
    files?,
    allowed_mentions?,
    poll?,
    ephemeral~,
  )
}

///|
/// Fetch a followup message sent for this interaction.
pub async fn ComponentDeferredCtx::get_followup(
  self : ComponentDeferredCtx,
  message_id : @model.MessageId,
) -> @model.Message {
  self.raw_.get_followup(message_id)
}

///|
/// Edit a followup message sent for this interaction. New `files` replace
/// its attachments unless `keep_attachments` lists the ones to retain.
pub async fn ComponentDeferredCtx::edit_followup(
  self : ComponentDeferredCtx,
  message_id : @model.MessageId,
  content? : String,
  clear_content? : Bool = false,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  allowed_mentions? : @model.AllowedMentions,
  files? : Array[@dhttp.FileUpload],
  keep_attachments? : Array[@model.AttachmentRequest],
) -> @model.Message {
  self.raw_.edit_followup(
    message_id,
    content?,
    clear_content~,
    embeds?,
    components?,
    allowed_mentions?,
    files?,
    keep_attachments?,
  )
}

///|
/// Delete a followup message sent for this interaction.
pub async fn ComponentDeferredCtx::delete_followup(
  self : ComponentDeferredCtx,
  message_id : @model.MessageId,
) -> Unit {
  self.raw_.delete_followup(message_id)
}

///|
/// Wait for the next click on the component `route.custom_id(state)`
/// identifies — build the button with the same route and state. By default
/// only the invoking user may satisfy the wait; pass `from=Anyone` for a
/// public flow or `from=User(id)` for someone else. Returns `None` on
/// timeout, or at once without a gateway connection. Raises `CustomIdError`
/// when the state does not encode.
///
/// The returned context has not been answered, and the waited interaction does
/// not pass through admission or the automatic defer: respond to it (for
/// example `update_message` or `defer_update`) within three seconds.
pub async fn[A] ComponentDeferredCtx::wait_for_component(
  self : ComponentDeferredCtx,
  route : ComponentRoute[A],
  state : A,
  from? : WaitFrom = Invoker,
  timeout_ms? : Int,
) -> @framework.ComponentCtx? {
  wait_for_route(
    self.waiter_,
    self.warn_,
    route,
    state,
    from.user_filter(self.user().id),
    timeout_ms,
  )
}

///|
async fn[A] ComponentRoute::dispatch_typed(
  self : ComponentRoute[A],
  handler : ComponentHandler[A],
  bot : AppCtx,
  waiter : ComponentWaiter?,
  warn : (AppWarning) -> Unit,
  raw : @framework.ComponentCtx,
) -> Unit {
  match handler {
    Immediate(run) => {
      let value = self.decode(raw.data.custom_id)
      let response = run({ raw_: raw, bot_: bot, }, value)
      response.send(raw)
    }
    DeferredUpdate(run) => {
      let value = self.decode(raw.data.custom_id)
      ensure_acknowledged(component_admission(raw), DeferUpdate)
      run({ raw_: raw, bot_: bot, waiter_: waiter, warn_: warn, }, value)
    }
    DeferredMessage(ephemeral~, run) => {
      let value = self.decode(raw.data.custom_id)
      ensure_acknowledged(component_admission(raw), DeferMessage(ephemeral~))
      run({ raw_: raw, bot_: bot, waiter_: waiter, warn_: warn, }, value)
    }
    Raw(run) => run(raw)
  }
}

///|
priv struct RegisteredComponent {
  pattern : AppRoutePattern
  ack : AckPlan
  dispatch : async (
    AppCtx,
    ComponentWaiter?,
    (AppWarning) -> Unit,
    @framework.ComponentCtx,
  ) -> Unit
}

///|
fn[A] ComponentRoute::erase(
  self : ComponentRoute[A],
  handler : ComponentHandler[A],
) -> RegisteredComponent {
  {
    pattern: Id(self.id_),
    ack: handler.ack_plan(),
    dispatch: (bot, waiter, warn, raw) => {
      self.dispatch_typed(handler, bot, waiter, warn, raw)
    },
  }
}
