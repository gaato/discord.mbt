///|
/// Proof that an interaction was invoked in a guild: the guild id and the
/// invoking member, both validated when the context was built.
pub(all) struct GuildInvocation {
  guild_id : @model.GuildId
  member : @model.GuildMember
} derive(Debug)

///|
/// The user who invoked this interaction.
pub fn GuildInvocation::user(self : GuildInvocation) -> @model.User {
  match self.member.user {
    Some(user) => user
    None => abort("validated guild invocation has no member user")
  }
}

///|
/// The context in which an interaction was invoked.
pub(all) enum InvocationScope {
  Guild(GuildInvocation)
  Dm(@model.User)
} derive(Debug)

///|
/// The interaction that opened a submitted modal.
pub(all) enum ModalOrigin {
  FromComponent(@model.Message)
  FromCommand
} derive(Debug)

///|
/// A malformed interaction that cannot satisfy the guarantees exposed by a
/// typed handler context.
pub(all) suberror InteractionContextError {
  MissingInvoker
  MissingGuildMemberUser
  MissingGuildId
  MissingComponentMessage
} derive(Debug)

///|
/// The resolved target of a USER context-menu command.
pub(all) struct TargetUser {
  user : @model.User
  member : @model.GuildMember?
}

///|
/// Prefer the guild member when both `member` and `user` are present: the
/// documented contract is exactly-one, but an interpretable payload should
/// never make the interaction unanswerable.
fn interaction_scope(
  interaction : @model.Interaction,
) -> InvocationScope raise InteractionContextError {
  match (interaction.guild_member, interaction.user) {
    (Some(guild_member), _) => {
      guard guild_member.user is Some(_) else { raise MissingGuildMemberUser }
      guard interaction.guild_id is Some(guild_id) else { raise MissingGuildId }
      Guild({ guild_id, member: guild_member, })
    }
    (None, Some(user)) => Dm(user)
    (None, None) => raise MissingInvoker
  }
}

///|
fn InvocationScope::invoking_user(self : InvocationScope) -> @model.User {
  match self {
    Guild(guild) => guild.user()
    Dm(user) => user
  }
}

///|
fn component_message(
  interaction : @model.Interaction,
) -> @model.Message raise InteractionContextError {
  match interaction.message {
    Some(message) => message
    None => raise MissingComponentMessage
  }
}

///|
fn modal_origin(interaction : @model.Interaction) -> ModalOrigin {
  match interaction.message {
    Some(message) => FromComponent(message)
    None => FromCommand
  }
}

///|
/// Context handed to a slash / context-menu command handler.
pub(all) struct CommandCtx {
  client : @dhttp.Client
  application_id : @model.ApplicationId
  interaction : @model.Interaction
  data : @model.CommandData
  options : @interaction.CommandOptions
  priv scope_ : InvocationScope
  priv gate : ResponseGate
}

///|
/// Whether the command was invoked in a guild or a DM.
pub fn CommandCtx::scope(self : CommandCtx) -> InvocationScope {
  self.scope_
}

///|
/// Milliseconds left before the initial-response window closes, or `None`
/// when the executor set no deadline.
pub fn CommandCtx::remaining_ms(self : CommandCtx) -> Int? {
  self.gate.remaining_ms()
}

///|
/// Milliseconds left before this interaction's token expires (15 minutes after
/// the executor received it). Followups and edits fail after that.
pub fn CommandCtx::token_remaining_ms(self : CommandCtx) -> Int {
  self.gate.token_remaining_ms()
}

///|
/// The current state of this interaction's initial callback.
pub fn CommandCtx::response_state(self : CommandCtx) -> ResponseState {
  self.gate.state()
}

///|
/// The validated guild invocation, or `None` when invoked in a DM.
pub fn CommandCtx::guild_scope(self : CommandCtx) -> GuildInvocation? {
  match self.scope_ {
    Guild(guild) => Some(guild)
    Dm(_) => None
  }
}

///|
/// The invoking user.
pub fn CommandCtx::user(self : CommandCtx) -> @model.User {
  self.scope_.invoking_user()
}

///|
/// The resolved target of a MESSAGE context-menu command, or `None` when this
/// is not a message command or its target is unavailable.
pub fn CommandCtx::target_message(self : CommandCtx) -> @model.Message? {
  guard self.data.typ is Message &&
    self.data.target_id is Some(target_id) &&
    self.data.resolved is Some(resolved) &&
    resolved.messages is Some(messages) else {
    return None
  }
  messages.get(target_id.to_string())
}

///|
/// The resolved target of a USER context-menu command, or `None` when this is
/// not a user command or its target is unavailable.
pub fn CommandCtx::target_user(self : CommandCtx) -> TargetUser? {
  guard self.data.typ is User &&
    self.data.target_id is Some(target_id) &&
    self.data.resolved is Some(resolved) &&
    resolved.users is Some(users) &&
    users.get(target_id.to_string()) is Some(user) else {
    return None
  }
  let target_member = match resolved.members {
    Some(members) => members.get(target_id.to_string())
    None => None
  }
  Some({ user, member: target_member, })
}

///|
/// Decode the submitted options into a typed `CommandModel`.
pub fn[T : @interaction.CommandModel] CommandCtx::model(
  self : CommandCtx,
) -> T raise {
  T::from_options(self.options)
}

///|
/// The operations this interaction's token allows.
fn CommandCtx::responder(self : CommandCtx) -> Responder {
  {
    gate: self.gate,
    client: self.client,
    application_id: self.application_id,
    token: self.interaction.token,
  }
}

///|
/// Send a message through whichever path the response state allows: the
/// initial response while pending, an edit of a still-loading deferred
/// placeholder, or a followup after any other callback. `ephemeral` cannot
/// change an existing message, so an edited placeholder keeps the
/// visibility chosen when deferring. Raises `ResponseGateError::Expired`
/// once the callback window has closed unused. Concurrent replies to one
/// interaction run one at a time, so only the first replaces the placeholder.
pub async fn CommandCtx::reply(
  self : CommandCtx,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[@dhttp.FileUpload],
  allowed_mentions? : @model.AllowedMentions,
  poll? : @model.PollCreateRequest,
  ephemeral? : Bool = false,
) -> Unit {
  self
  .responder()
  .reply(content, embeds, components, files, allowed_mentions, poll, ephemeral)
}

///|
/// Send the initial "channel message with source" response.
pub async fn CommandCtx::respond(
  self : CommandCtx,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[@dhttp.FileUpload],
  allowed_mentions? : @model.AllowedMentions,
  poll? : @model.PollCreateRequest,
  ephemeral? : Bool = false,
) -> Unit {
  self
  .responder()
  .respond(
    ChannelMessageWithSource,
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
/// Display a modal as the initial command response.
pub async fn CommandCtx::show_modal(
  self : CommandCtx,
  custom_id~ : String,
  title~ : String,
  components~ : Array[@model.Component],
) -> Unit {
  self.responder().show_modal(custom_id, title, components)
}

///|
/// Acknowledge now and reply later via `edit_response` / `followup`.
pub async fn CommandCtx::defer_response(
  self : CommandCtx,
  ephemeral? : Bool = false,
) -> Unit {
  self.responder().defer_message(ephemeral)
}

///|
/// Fetch the original response to this command interaction.
pub async fn CommandCtx::original_response(self : CommandCtx) -> @model.Message {
  self.responder().original()
}

///|
/// Delete the original response to this command interaction.
pub async fn CommandCtx::delete_response(self : CommandCtx) -> Unit {
  self.responder().delete_original()
}

///|
/// Edit the original response to this command interaction. `poll` may only
/// be added while editing a deferred response.
pub async fn CommandCtx::edit_response(
  self : CommandCtx,
  content? : String,
  clear_content? : Bool = false,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  allowed_mentions? : @model.AllowedMentions,
  files? : Array[@dhttp.FileUpload],
  keep_attachments? : Array[@model.AttachmentRequest],
  poll? : @model.PollCreateRequest,
) -> @model.Message {
  self
  .responder()
  .edit_original(
    content, clear_content, embeds, components, allowed_mentions, files, keep_attachments,
    poll,
  )
}

///|
/// Send a followup message for this command interaction.
pub async fn CommandCtx::followup(
  self : CommandCtx,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[@dhttp.FileUpload],
  allowed_mentions? : @model.AllowedMentions,
  poll? : @model.PollCreateRequest,
  ephemeral? : Bool = false,
) -> @model.Message {
  self
  .responder()
  .followup(
    content, embeds, components, files, allowed_mentions, poll, ephemeral,
  )
}

///|
/// Fetch a followup message for this command interaction.
pub async fn CommandCtx::get_followup(
  self : CommandCtx,
  message_id : @model.MessageId,
) -> @model.Message {
  self.responder().get_followup(message_id)
}

///|
/// Edit a followup message for this command interaction.
pub async fn CommandCtx::edit_followup(
  self : CommandCtx,
  message_id : @model.MessageId,
  content? : String,
  clear_content? : Bool = false,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  allowed_mentions? : @model.AllowedMentions,
  files? : Array[@dhttp.FileUpload],
  keep_attachments? : Array[@model.AttachmentRequest],
) -> @model.Message {
  self
  .responder()
  .edit_followup(
    message_id, content, clear_content, embeds, components, allowed_mentions, files,
    keep_attachments,
  )
}

///|
/// Delete a followup message for this command interaction.
pub async fn CommandCtx::delete_followup(
  self : CommandCtx,
  message_id : @model.MessageId,
) -> Unit {
  self.responder().delete_followup(message_id)
}

///|
/// Context handed to a message-component (button / select) handler.
pub(all) struct ComponentCtx {
  client : @dhttp.Client
  application_id : @model.ApplicationId
  interaction : @model.Interaction
  data : @model.ComponentData
  priv scope_ : InvocationScope
  priv message_ : @model.Message
  priv gate : ResponseGate
}

///|
/// Whether the component was invoked in a guild or a DM.
pub fn ComponentCtx::scope(self : ComponentCtx) -> InvocationScope {
  self.scope_
}

///|
/// Milliseconds left before the initial-response window closes, or `None`
/// when the executor set no deadline.
pub fn ComponentCtx::remaining_ms(self : ComponentCtx) -> Int? {
  self.gate.remaining_ms()
}

///|
/// Milliseconds left before this interaction's token expires (15 minutes after
/// the executor received it). Followups and edits fail after that.
pub fn ComponentCtx::token_remaining_ms(self : ComponentCtx) -> Int {
  self.gate.token_remaining_ms()
}

///|
/// The current state of this interaction's initial callback.
pub fn ComponentCtx::response_state(self : ComponentCtx) -> ResponseState {
  self.gate.state()
}

///|
/// The validated guild invocation, or `None` when invoked in a DM.
pub fn ComponentCtx::guild_scope(self : ComponentCtx) -> GuildInvocation? {
  match self.scope_ {
    Guild(guild) => Some(guild)
    Dm(_) => None
  }
}

///|
/// The invoking user.
pub fn ComponentCtx::user(self : ComponentCtx) -> @model.User {
  self.scope_.invoking_user()
}

///|
/// The message to which the component was attached.
pub fn ComponentCtx::message(self : ComponentCtx) -> @model.Message {
  self.message_
}

///|
/// The operations this interaction's token allows.
fn ComponentCtx::responder(self : ComponentCtx) -> Responder {
  {
    gate: self.gate,
    client: self.client,
    application_id: self.application_id,
    token: self.interaction.token,
  }
}

///|
/// Send a message through whichever path the response state allows: the
/// initial response while pending, an edit of a still-loading deferred
/// placeholder, or a followup after any other callback. `ephemeral` cannot
/// change an existing message, so an edited placeholder keeps the
/// visibility chosen when deferring. Raises `ResponseGateError::Expired`
/// once the callback window has closed unused. Concurrent replies to one
/// interaction run one at a time, so only the first replaces the placeholder.
pub async fn ComponentCtx::reply(
  self : ComponentCtx,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[@dhttp.FileUpload],
  allowed_mentions? : @model.AllowedMentions,
  poll? : @model.PollCreateRequest,
  ephemeral? : Bool = false,
) -> Unit {
  self
  .responder()
  .reply(content, embeds, components, files, allowed_mentions, poll, ephemeral)
}

///|
/// Send a new "channel message with source" response.
pub async fn ComponentCtx::respond(
  self : ComponentCtx,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[@dhttp.FileUpload],
  allowed_mentions? : @model.AllowedMentions,
  poll? : @model.PollCreateRequest,
  ephemeral? : Bool = false,
) -> Unit {
  self
  .responder()
  .respond(
    ChannelMessageWithSource,
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
/// Edit the message the component is attached to.
pub async fn ComponentCtx::update_message(
  self : ComponentCtx,
  content? : String,
  clear_content? : Bool = false,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  allowed_mentions? : @model.AllowedMentions,
  files? : Array[@dhttp.FileUpload],
  keep_attachments? : Array[@model.AttachmentRequest],
  poll? : @model.PollCreateRequest,
) -> Unit {
  self
  .responder()
  .respond(
    UpdateMessage,
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
/// Display a modal as the initial component response.
pub async fn ComponentCtx::show_modal(
  self : ComponentCtx,
  custom_id~ : String,
  title~ : String,
  components~ : Array[@model.Component],
) -> Unit {
  self.responder().show_modal(custom_id, title, components)
}

///|
/// Acknowledge now and send a message later through webhook methods.
pub async fn ComponentCtx::defer_response(
  self : ComponentCtx,
  ephemeral? : Bool = false,
) -> Unit {
  self.responder().defer_message(ephemeral)
}

///|
/// Acknowledge without any visible change (edit later if needed).
pub async fn ComponentCtx::defer_update(self : ComponentCtx) -> Unit {
  self.responder().defer_update()
}

///|
/// Fetch the original response to this component interaction.
pub async fn ComponentCtx::original_response(
  self : ComponentCtx,
) -> @model.Message {
  self.responder().original()
}

///|
/// Delete the original response to this component interaction.
pub async fn ComponentCtx::delete_response(self : ComponentCtx) -> Unit {
  self.responder().delete_original()
}

///|
/// Edit the original response to this component interaction. `poll` may only
/// be added while editing a deferred response.
pub async fn ComponentCtx::edit_response(
  self : ComponentCtx,
  content? : String,
  clear_content? : Bool = false,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  allowed_mentions? : @model.AllowedMentions,
  files? : Array[@dhttp.FileUpload],
  keep_attachments? : Array[@model.AttachmentRequest],
  poll? : @model.PollCreateRequest,
) -> @model.Message {
  self
  .responder()
  .edit_original(
    content, clear_content, embeds, components, allowed_mentions, files, keep_attachments,
    poll,
  )
}

///|
/// Send a followup message for this component interaction.
pub async fn ComponentCtx::followup(
  self : ComponentCtx,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[@dhttp.FileUpload],
  allowed_mentions? : @model.AllowedMentions,
  poll? : @model.PollCreateRequest,
  ephemeral? : Bool = false,
) -> @model.Message {
  self
  .responder()
  .followup(
    content, embeds, components, files, allowed_mentions, poll, ephemeral,
  )
}

///|
/// Fetch a followup message for this component interaction.
pub async fn ComponentCtx::get_followup(
  self : ComponentCtx,
  message_id : @model.MessageId,
) -> @model.Message {
  self.responder().get_followup(message_id)
}

///|
/// Edit a followup message for this component interaction.
pub async fn ComponentCtx::edit_followup(
  self : ComponentCtx,
  message_id : @model.MessageId,
  content? : String,
  clear_content? : Bool = false,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  allowed_mentions? : @model.AllowedMentions,
  files? : Array[@dhttp.FileUpload],
  keep_attachments? : Array[@model.AttachmentRequest],
) -> @model.Message {
  self
  .responder()
  .edit_followup(
    message_id, content, clear_content, embeds, components, allowed_mentions, files,
    keep_attachments,
  )
}

///|
/// Delete a followup message for this component interaction.
pub async fn ComponentCtx::delete_followup(
  self : ComponentCtx,
  message_id : @model.MessageId,
) -> Unit {
  self.responder().delete_followup(message_id)
}

///|
/// Context handed to a modal-submit handler.
pub(all) struct ModalCtx {
  client : @dhttp.Client
  application_id : @model.ApplicationId
  interaction : @model.Interaction
  data : @model.ModalData
  priv scope_ : InvocationScope
  priv origin_ : ModalOrigin
  priv gate : ResponseGate
}

///|
/// Whether the modal was submitted in a guild or a DM.
pub fn ModalCtx::scope(self : ModalCtx) -> InvocationScope {
  self.scope_
}

///|
/// Milliseconds left before the initial-response window closes, or `None`
/// when the executor set no deadline.
pub fn ModalCtx::remaining_ms(self : ModalCtx) -> Int? {
  self.gate.remaining_ms()
}

///|
/// Milliseconds left before this interaction's token expires (15 minutes after
/// the executor received it). Followups and edits fail after that.
pub fn ModalCtx::token_remaining_ms(self : ModalCtx) -> Int {
  self.gate.token_remaining_ms()
}

///|
/// The current state of this interaction's initial callback.
pub fn ModalCtx::response_state(self : ModalCtx) -> ResponseState {
  self.gate.state()
}

///|
/// The validated guild invocation, or `None` when invoked in a DM.
pub fn ModalCtx::guild_scope(self : ModalCtx) -> GuildInvocation? {
  match self.scope_ {
    Guild(guild) => Some(guild)
    Dm(_) => None
  }
}

///|
/// The invoking user.
pub fn ModalCtx::user(self : ModalCtx) -> @model.User {
  self.scope_.invoking_user()
}

///|
/// Whether the modal was opened from a component or from a command.
pub fn ModalCtx::origin(self : ModalCtx) -> ModalOrigin {
  self.origin_
}

///|
/// The submitted value of the text input with the given custom id.
pub fn ModalCtx::text_value(self : ModalCtx, custom_id : String) -> String? {
  fn walk(components : Array[@model.Component]) -> String? {
    for component in components {
      match component {
        ActionRow(row) =>
          if walk(row.components) is Some(value) {
            return Some(value)
          }
        Label(label) =>
          if walk([label.component]) is Some(value) {
            return Some(value)
          }
        TextInput(input) =>
          if input.custom_id == custom_id {
            return input.value
          }
        _ => ()
      }
    }
    None
  }

  walk(self.data.components)
}

///|
/// The operations this interaction's token allows.
fn ModalCtx::responder(self : ModalCtx) -> Responder {
  {
    gate: self.gate,
    client: self.client,
    application_id: self.application_id,
    token: self.interaction.token,
  }
}

///|
/// Send a message through whichever path the response state allows: the
/// initial response while pending, an edit of a still-loading deferred
/// placeholder, or a followup after any other callback. `ephemeral` cannot
/// change an existing message, so an edited placeholder keeps the
/// visibility chosen when deferring. Raises `ResponseGateError::Expired`
/// once the callback window has closed unused. Concurrent replies to one
/// interaction run one at a time, so only the first replaces the placeholder.
pub async fn ModalCtx::reply(
  self : ModalCtx,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[@dhttp.FileUpload],
  allowed_mentions? : @model.AllowedMentions,
  poll? : @model.PollCreateRequest,
  ephemeral? : Bool = false,
) -> Unit {
  self
  .responder()
  .reply(content, embeds, components, files, allowed_mentions, poll, ephemeral)
}

///|
/// Send a "channel message with source" response to the modal.
pub async fn ModalCtx::respond(
  self : ModalCtx,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[@dhttp.FileUpload],
  allowed_mentions? : @model.AllowedMentions,
  poll? : @model.PollCreateRequest,
  ephemeral? : Bool = false,
) -> Unit {
  self
  .responder()
  .respond(
    ChannelMessageWithSource,
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
/// Edit the message whose component opened this modal. A modal opened by
/// a command has no such message, so this raises
/// `ResponseGateError::InvalidCallback` without sending anything.
pub async fn ModalCtx::update_message(
  self : ModalCtx,
  content? : String,
  clear_content? : Bool = false,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  allowed_mentions? : @model.AllowedMentions,
  files? : Array[@dhttp.FileUpload],
  keep_attachments? : Array[@model.AttachmentRequest],
  poll? : @model.PollCreateRequest,
) -> Unit {
  guard self.origin() is FromComponent(_) else {
    raise ResponseGateError::InvalidCallback(
      kind=ModalSubmit,
      typ=UpdateMessage,
    )
  }
  self
  .responder()
  .respond(
    UpdateMessage,
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
/// Acknowledge now and reply later via a followup.
pub async fn ModalCtx::defer_response(
  self : ModalCtx,
  ephemeral? : Bool = false,
) -> Unit {
  self.responder().defer_message(ephemeral)
}

///|
/// Acknowledge without changing the message whose component opened this
/// modal (edit it later with `edit_response`). A modal opened by a command
/// has no such message, so this raises `ResponseGateError::InvalidCallback`.
pub async fn ModalCtx::defer_update(self : ModalCtx) -> Unit {
  guard self.origin() is FromComponent(_) else {
    raise ResponseGateError::InvalidCallback(
      kind=ModalSubmit,
      typ=DeferredUpdateMessage,
    )
  }
  self.responder().defer_update()
}

///|
/// Fetch the original response to this modal interaction.
pub async fn ModalCtx::original_response(self : ModalCtx) -> @model.Message {
  self.responder().original()
}

///|
/// Delete the original response to this modal interaction.
pub async fn ModalCtx::delete_response(self : ModalCtx) -> Unit {
  self.responder().delete_original()
}

///|
/// Edit the original response to this modal interaction. `poll` may only
/// be added while editing a deferred response.
pub async fn ModalCtx::edit_response(
  self : ModalCtx,
  content? : String,
  clear_content? : Bool = false,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  allowed_mentions? : @model.AllowedMentions,
  files? : Array[@dhttp.FileUpload],
  keep_attachments? : Array[@model.AttachmentRequest],
  poll? : @model.PollCreateRequest,
) -> @model.Message {
  self
  .responder()
  .edit_original(
    content, clear_content, embeds, components, allowed_mentions, files, keep_attachments,
    poll,
  )
}

///|
/// Send a followup message for this modal interaction.
pub async fn ModalCtx::followup(
  self : ModalCtx,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[@dhttp.FileUpload],
  allowed_mentions? : @model.AllowedMentions,
  poll? : @model.PollCreateRequest,
  ephemeral? : Bool = false,
) -> @model.Message {
  self
  .responder()
  .followup(
    content, embeds, components, files, allowed_mentions, poll, ephemeral,
  )
}

///|
/// Fetch a followup message for this modal interaction.
pub async fn ModalCtx::get_followup(
  self : ModalCtx,
  message_id : @model.MessageId,
) -> @model.Message {
  self.responder().get_followup(message_id)
}

///|
/// Edit a followup message for this modal interaction.
pub async fn ModalCtx::edit_followup(
  self : ModalCtx,
  message_id : @model.MessageId,
  content? : String,
  clear_content? : Bool = false,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  allowed_mentions? : @model.AllowedMentions,
  files? : Array[@dhttp.FileUpload],
  keep_attachments? : Array[@model.AttachmentRequest],
) -> @model.Message {
  self
  .responder()
  .edit_followup(
    message_id, content, clear_content, embeds, components, allowed_mentions, files,
    keep_attachments,
  )
}

///|
/// Delete a followup message for this modal interaction.
pub async fn ModalCtx::delete_followup(
  self : ModalCtx,
  message_id : @model.MessageId,
) -> Unit {
  self.responder().delete_followup(message_id)
}

///|
/// Context handed to an autocomplete handler.
pub(all) struct AutocompleteCtx {
  client : @dhttp.Client
  application_id : @model.ApplicationId
  interaction : @model.Interaction
  data : @model.CommandData
  options : @interaction.CommandOptions
  priv gate : ResponseGate
}

///|
/// Milliseconds left before the autocomplete response window closes, or
/// `None` when the executor set no deadline.
pub fn AutocompleteCtx::remaining_ms(self : AutocompleteCtx) -> Int? {
  self.gate.remaining_ms()
}

///|
/// Milliseconds left before this interaction's token expires (15 minutes after
/// the executor received it). Followups and edits fail after that.
pub fn AutocompleteCtx::token_remaining_ms(self : AutocompleteCtx) -> Int {
  self.gate.token_remaining_ms()
}

///|
/// Send autocomplete suggestions. Choices beyond the first 25 are truncated.
pub async fn AutocompleteCtx::suggest(
  self : AutocompleteCtx,
  choices : Array[@model.CommandOptionChoice],
) -> Unit {
  let choices = if choices.length() > 25 {
    choices[:25].to_owned()
  } else {
    choices
  }
  self.gate.send({
    typ: Autocomplete,
    data: Some(@model.ObjBuilder().field("choices", choices).build()),
  })
}
