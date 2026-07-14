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
pub fn ComponentReply::update_message(
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  allowed_mentions? : @model.AllowedMentions,
) -> ComponentReply {
  UpdateMessage(content~, embeds~, components~, allowed_mentions~)
}

///|
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
pub fn ComponentImmediateCtx::app(self : ComponentImmediateCtx) -> AppCtx {
  self.bot_
}

///|
pub fn ComponentImmediateCtx::user(
  self : ComponentImmediateCtx,
) -> @model.User? {
  self.raw_.user()
}

///|
pub fn ComponentImmediateCtx::interaction(
  self : ComponentImmediateCtx,
) -> @model.Interaction {
  self.raw_.interaction
}

///|
pub fn ComponentImmediateCtx::guild_id(
  self : ComponentImmediateCtx,
) -> @model.GuildId? {
  self.raw_.interaction.guild_id
}

///|
pub fn ComponentImmediateCtx::custom_id(self : ComponentImmediateCtx) -> String {
  self.raw_.data.custom_id
}

///|
pub fn ComponentImmediateCtx::suffix(self : ComponentImmediateCtx) -> String {
  component_suffix(self.raw_.data.custom_id, self.prefix_)
}

///|
pub fn ComponentImmediateCtx::values(
  self : ComponentImmediateCtx,
) -> Array[String] {
  component_values(self.raw_)
}

///|
pub fn ComponentImmediateCtx::selected_users(
  self : ComponentImmediateCtx,
) -> Array[@model.User] {
  selected_users(self.raw_)
}

///|
pub fn ComponentImmediateCtx::selected_roles(
  self : ComponentImmediateCtx,
) -> Array[@model.Role] {
  selected_roles(self.raw_)
}

///|
pub fn ComponentImmediateCtx::selected_channels(
  self : ComponentImmediateCtx,
) -> Array[@model.Channel] {
  selected_channels(self.raw_)
}

///|
pub fn ComponentImmediateCtx::message(
  self : ComponentImmediateCtx,
) -> @model.Message? {
  self.raw_.interaction.message
}

///|
pub fn ComponentImmediateCtx::raw(
  self : ComponentImmediateCtx,
) -> @framework.ComponentCtx {
  self.raw_
}

///|
pub fn ComponentDeferredCtx::app(self : ComponentDeferredCtx) -> AppCtx {
  self.bot_
}

///|
pub fn ComponentDeferredCtx::user(self : ComponentDeferredCtx) -> @model.User? {
  self.raw_.user()
}

///|
pub fn ComponentDeferredCtx::interaction(
  self : ComponentDeferredCtx,
) -> @model.Interaction {
  self.raw_.interaction
}

///|
pub fn ComponentDeferredCtx::guild_id(
  self : ComponentDeferredCtx,
) -> @model.GuildId? {
  self.raw_.interaction.guild_id
}

///|
pub fn ComponentDeferredCtx::custom_id(self : ComponentDeferredCtx) -> String {
  self.raw_.data.custom_id
}

///|
pub fn ComponentDeferredCtx::suffix(self : ComponentDeferredCtx) -> String {
  component_suffix(self.raw_.data.custom_id, self.prefix_)
}

///|
pub fn ComponentDeferredCtx::values(
  self : ComponentDeferredCtx,
) -> Array[String] {
  component_values(self.raw_)
}

///|
pub fn ComponentDeferredCtx::selected_users(
  self : ComponentDeferredCtx,
) -> Array[@model.User] {
  selected_users(self.raw_)
}

///|
pub fn ComponentDeferredCtx::selected_roles(
  self : ComponentDeferredCtx,
) -> Array[@model.Role] {
  selected_roles(self.raw_)
}

///|
pub fn ComponentDeferredCtx::selected_channels(
  self : ComponentDeferredCtx,
) -> Array[@model.Channel] {
  selected_channels(self.raw_)
}

///|
pub fn ComponentDeferredCtx::message(
  self : ComponentDeferredCtx,
) -> @model.Message? {
  self.raw_.interaction.message
}

///|
pub fn ComponentDeferredCtx::raw(
  self : ComponentDeferredCtx,
) -> @framework.ComponentCtx {
  self.raw_
}

///|
pub async fn ComponentDeferredCtx::edit_original(
  self : ComponentDeferredCtx,
  content? : @model.Undefinable[String] = Missing,
  embeds? : @model.Undefinable[Array[@model.Embed]] = Missing,
  components? : @model.Undefinable[Array[@model.Component]] = Missing,
  allowed_mentions? : @model.AllowedMentions,
  files? : Array[@dhttp.FileUpload],
) -> @model.Message {
  self.raw_.edit_response(
    content~,
    embeds~,
    components~,
    allowed_mentions?,
    files?,
  )
}

///|
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
  let route = raw.data.custom_id
  match handler {
    Immediate(run) => {
      let response = run({ raw_: raw, bot_: bot, prefix_: prefix }) catch {
        source => raise_failure(route, BeforeInitial, source)
      }
      response.send(raw) catch {
        source => raise_failure(route, BeforeInitial, source)
      }
    }
    DeferredUpdate(run) => {
      raw.defer_update() catch {
        source => raise_failure(route, BeforeInitial, source)
      }
      run({
        raw_: raw,
        bot_: bot,
        prefix_: prefix,
        waiter_: waiter,
        warn_: warn,
      }) catch {
        source => raise_failure(route, AfterDeferred, source)
      }
    }
    DeferredMessage(ephemeral~, run) => {
      raw.defer_response(ephemeral~) catch {
        source => raise_failure(route, BeforeInitial, source)
      }
      run({
        raw_: raw,
        bot_: bot,
        prefix_: prefix,
        waiter_: waiter,
        warn_: warn,
      }) catch {
        source => raise_failure(route, AfterDeferred, source)
      }
    }
    Raw(run) =>
      run(raw) catch {
        source => raise_failure(route, BeforeInitial, source)
      }
  }
}
