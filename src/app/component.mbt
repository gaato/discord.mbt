///|
/// Initial response returned by an immediate component handler.
pub(all) enum ComponentReply {
  UpdateMessage(
    content~ : String?,
    embeds~ : Array[@model.Embed]?,
    components~ : Array[@model.Component]?,
    allowed_mentions~ : @model.AllowedMentions?
  )
  Message(InitialResponse)
  ShowModal(ModalHandle)
}

///|
/// Execution strategy for a component route.
pub(all) enum ComponentHandler {
  Immediate(async (ComponentImmediateCtx) -> ComponentReply)
  DeferredUpdate(async (ComponentDeferredCtx) -> Unit)
  DeferredMessage(ephemeral~ : Bool, async (ComponentDeferredCtx) -> Unit)
  Raw(async (@framework.ComponentCtx) -> Unit)
}

///|
/// Read-only component context for handlers returning their initial callback.
pub struct ComponentImmediateCtx {
  priv raw_ : @framework.ComponentCtx
  priv bot_ : AppCtx
  priv prefix_ : String
}

///|
/// Component context available after a deferred callback.
pub struct ComponentDeferredCtx {
  priv raw_ : @framework.ComponentCtx
  priv bot_ : AppCtx
  priv prefix_ : String
  priv waiter_ : ComponentWaiter?
  priv warn_ : (String) -> Unit
}

///|
/// Reply by editing the message that hosts the component.
pub fn ComponentReply::update_message(
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  allowed_mentions? : @model.AllowedMentions,
) -> ComponentReply {
  UpdateMessage(content~, embeds~, components~, allowed_mentions~)
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
  ephemeral? : Bool = false,
) -> ComponentReply {
  Message(
    InitialResponse::message(
      content?,
      embeds?,
      components?,
      files?,
      allowed_mentions?,
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
    ephemeral=self.ephemeral_,
  )
}

///|
async fn ComponentReply::send(
  self : ComponentReply,
  ctx : @framework.ComponentCtx,
) -> Unit {
  match self {
    UpdateMessage(content~, embeds~, components~, allowed_mentions~) =>
      ctx.update_message(content?, embeds?, components?, allowed_mentions?)
    Message(response) => response.send_component(ctx)
    ShowModal(handle) => handle.send_component(ctx)
  }
}

///|
fn component_suffix(custom_id : String, prefix : String) -> String {
  if !custom_id.has_prefix(prefix) {
    return custom_id
  }
  custom_id[prefix.length():].to_owned()
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
/// The custom id with this route's registered prefix stripped (the full
/// id when it does not start with the prefix).
pub fn ComponentImmediateCtx::suffix(self : ComponentImmediateCtx) -> String {
  component_suffix(self.raw_.data.custom_id, self.prefix_)
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
/// Escape hatch for advanced inspection. Calling response methods on the
/// raw value opts out of this wrapper's response discipline.
/// Failure handling still follows the gate's real response state.
pub fn ComponentImmediateCtx::raw(
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
/// The custom id with this route's registered prefix stripped (the full
/// id when it does not start with the prefix).
pub fn ComponentDeferredCtx::suffix(self : ComponentDeferredCtx) -> String {
  component_suffix(self.raw_.data.custom_id, self.prefix_)
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
/// Edit the original response after deferring. For `DeferredUpdate`
/// handlers this edits the component's host message.
pub async fn ComponentDeferredCtx::edit_original(
  self : ComponentDeferredCtx,
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
pub async fn ComponentDeferredCtx::followup(
  self : ComponentDeferredCtx,
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
/// Returns `None` on timeout, or immediately when running without a
/// gateway connection.
pub async fn ComponentDeferredCtx::wait_for_component(
  self : ComponentDeferredCtx,
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

///|
async fn dispatch_component_handler(
  prefix : String,
  handler : ComponentHandler,
  bot : AppCtx,
  waiter : ComponentWaiter?,
  warn : (String) -> Unit,
  raw : @framework.ComponentCtx,
) -> Unit {
  match handler {
    Immediate(run) => {
      let response = run({ raw_: raw, bot_: bot, prefix_: prefix, })
      response.send(raw)
    }
    DeferredUpdate(run) => {
      raw.defer_update()
      run({
        raw_: raw,
        bot_: bot,
        prefix_: prefix,
        waiter_: waiter,
        warn_: warn,
      })
    }
    DeferredMessage(ephemeral~, run) => {
      raw.defer_response(ephemeral~)
      run({
        raw_: raw,
        bot_: bot,
        prefix_: prefix,
        waiter_: waiter,
        warn_: warn,
      })
    }
    Raw(run) => run(raw)
  }
}
