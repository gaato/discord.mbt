///|
/// Build the `data` object of a message-style interaction response.
fn message_response_data(
  content : String?,
  embeds : Array[@model.Embed]?,
  components : Array[@model.Component]?,
  files : Array[@dhttp.FileUpload]?,
  allowed_mentions : @model.AllowedMentions?,
  ephemeral : Bool,
) -> Json raise @dhttp.DiscordHttpError {
  let flags = @dhttp.message_flags_with_components_v2(
    if ephemeral {
      Some(@model.MessageFlags::ephemeral())
    } else {
      None
    },
    content,
    embeds,
    components,
  )
  let builder = @model.ObjBuilder()
    .opt("content", content)
    .opt("embeds", embeds)
    .opt("components", components)
    .opt("allowed_mentions", allowed_mentions)
  if files is Some(fs) && fs.length() > 0 {
    builder.field("attachments", @dhttp.attachments_json(fs)) |> ignore
  }
  builder.opt("flags", flags) |> ignore
  builder.build()
}

///|
async fn respond_message(
  gate : ResponseGate,
  typ : @model.InteractionResponseType,
  content : String?,
  embeds : Array[@model.Embed]?,
  components : Array[@model.Component]?,
  files : Array[@dhttp.FileUpload]?,
  allowed_mentions : @model.AllowedMentions?,
  ephemeral : Bool,
) -> Unit {
  gate.send(
    {
      typ,
      data: Some(
        message_response_data(
          content, embeds, components, files, allowed_mentions, ephemeral,
        ),
      ),
    },
    files?,
  )
}

///|
async fn respond_modal(
  gate : ResponseGate,
  custom_id : String,
  title : String,
  components : Array[@model.Component],
) -> Unit {
  gate.send({
    typ: Modal,
    data: Some(
      @model.ObjBuilder()
      .field("custom_id", custom_id)
      .field("title", title)
      .field("components", components)
      .build(),
    ),
  })
}

///|
async fn interaction_original_response(
  client : @dhttp.Client,
  application_id : @model.ApplicationId,
  token : String,
) -> @model.Message {
  client.get_original_response(application_id, token)
}

///|
async fn delete_interaction_response(
  client : @dhttp.Client,
  application_id : @model.ApplicationId,
  token : String,
) -> Unit {
  client.delete_original_response(application_id, token)
}

///|
async fn interaction_followup(
  client : @dhttp.Client,
  application_id : @model.ApplicationId,
  token : String,
  message_id : @model.MessageId,
) -> @model.Message {
  client.get_followup(application_id, token, message_id)
}

///|
async fn edit_interaction_followup(
  client : @dhttp.Client,
  application_id : @model.ApplicationId,
  token : String,
  message_id : @model.MessageId,
  content : String?,
  clear_content : Bool,
  embeds : Array[@model.Embed]?,
  components : Array[@model.Component]?,
  allowed_mentions : @model.AllowedMentions?,
  files : Array[@dhttp.FileUpload]?,
  keep_attachments : Array[@model.AttachmentRequest]?,
) -> @model.Message {
  client.edit_followup(
    application_id,
    token,
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
async fn delete_interaction_followup(
  client : @dhttp.Client,
  application_id : @model.ApplicationId,
  token : String,
  message_id : @model.MessageId,
) -> Unit {
  client.delete_followup(application_id, token, message_id)
}

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
      Guild({ guild_id, member: guild_member })
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
  Some({ user, member: target_member })
}

///|
/// Decode the submitted options into a typed `CommandModel`.
pub fn[T : @interaction.CommandModel] CommandCtx::model(
  self : CommandCtx,
) -> T raise {
  T::from_options(self.options)
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
  ephemeral? : Bool = false,
) -> Unit {
  respond_message(
    self.gate,
    ChannelMessageWithSource,
    content,
    embeds,
    components,
    files,
    allowed_mentions,
    ephemeral,
  )
}

///|
/// Acknowledge now and reply later via `edit_response` / `followup`.
pub async fn CommandCtx::defer_response(
  self : CommandCtx,
  ephemeral? : Bool = false,
) -> Unit {
  respond_message(
    self.gate,
    DeferredChannelMessageWithSource,
    None,
    None,
    None,
    None,
    None,
    ephemeral,
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
  respond_modal(self.gate, custom_id, title, components)
}

///|
/// Fetch the original response to this command interaction.
pub async fn CommandCtx::original_response(self : CommandCtx) -> @model.Message {
  interaction_original_response(
    self.client,
    self.application_id,
    self.interaction.token,
  )
}

///|
/// Delete the original response to this command interaction.
pub async fn CommandCtx::delete_response(self : CommandCtx) -> Unit {
  delete_interaction_response(
    self.client,
    self.application_id,
    self.interaction.token,
  )
}

///|
/// Edit the original response (typically after `defer`).
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
  self.client.edit_original_response(
    self.application_id,
    self.interaction.token,
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
/// Send a followup message after the initial response.
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
  self.client.create_followup(
    self.application_id,
    self.interaction.token,
    content?,
    embeds?,
    components?,
    files?,
    allowed_mentions?,
    poll?,
    flags=if ephemeral {
      @model.MessageFlags::ephemeral()
    } else {
      @model.MessageFlags::from_bits(0)
    },
  )
}

///|
/// Fetch a followup message for this command interaction.
pub async fn CommandCtx::get_followup(
  self : CommandCtx,
  message_id : @model.MessageId,
) -> @model.Message {
  interaction_followup(
    self.client,
    self.application_id,
    self.interaction.token,
    message_id,
  )
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
  edit_interaction_followup(
    self.client,
    self.application_id,
    self.interaction.token,
    message_id,
    content,
    clear_content,
    embeds,
    components,
    allowed_mentions,
    files,
    keep_attachments,
  )
}

///|
/// Delete a followup message for this command interaction.
pub async fn CommandCtx::delete_followup(
  self : CommandCtx,
  message_id : @model.MessageId,
) -> Unit {
  delete_interaction_followup(
    self.client,
    self.application_id,
    self.interaction.token,
    message_id,
  )
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
/// Send a new "channel message with source" response.
pub async fn ComponentCtx::respond(
  self : ComponentCtx,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[@dhttp.FileUpload],
  allowed_mentions? : @model.AllowedMentions,
  ephemeral? : Bool = false,
) -> Unit {
  respond_message(
    self.gate,
    ChannelMessageWithSource,
    content,
    embeds,
    components,
    files,
    allowed_mentions,
    ephemeral,
  )
}

///|
/// Edit the message the component is attached to.
pub async fn ComponentCtx::update_message(
  self : ComponentCtx,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  allowed_mentions? : @model.AllowedMentions,
) -> Unit {
  respond_message(
    self.gate,
    UpdateMessage,
    content,
    embeds,
    components,
    None,
    allowed_mentions,
    false,
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
  respond_modal(self.gate, custom_id, title, components)
}

///|
/// Acknowledge now and send a message later through webhook methods.
pub async fn ComponentCtx::defer_response(
  self : ComponentCtx,
  ephemeral? : Bool = false,
) -> Unit {
  respond_message(
    self.gate,
    DeferredChannelMessageWithSource,
    None,
    None,
    None,
    None,
    None,
    ephemeral,
  )
}

///|
/// Acknowledge without any visible change (edit later if needed).
pub async fn ComponentCtx::defer_update(self : ComponentCtx) -> Unit {
  self.gate.send({ typ: DeferredUpdateMessage, data: None })
}

///|
/// Fetch the original response to this component interaction.
pub async fn ComponentCtx::original_response(
  self : ComponentCtx,
) -> @model.Message {
  interaction_original_response(
    self.client,
    self.application_id,
    self.interaction.token,
  )
}

///|
/// Delete the original response to this component interaction.
pub async fn ComponentCtx::delete_response(self : ComponentCtx) -> Unit {
  delete_interaction_response(
    self.client,
    self.application_id,
    self.interaction.token,
  )
}

///|
/// Edit the original interaction response after deferring.
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
  self.client.edit_original_response(
    self.application_id,
    self.interaction.token,
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
/// Send a component-interaction followup message.
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
  self.client.create_followup(
    self.application_id,
    self.interaction.token,
    content?,
    embeds?,
    components?,
    files?,
    allowed_mentions?,
    poll?,
    flags=if ephemeral {
      @model.MessageFlags::ephemeral()
    } else {
      @model.MessageFlags::from_bits(0)
    },
  )
}

///|
/// Fetch a followup message for this component interaction.
pub async fn ComponentCtx::get_followup(
  self : ComponentCtx,
  message_id : @model.MessageId,
) -> @model.Message {
  interaction_followup(
    self.client,
    self.application_id,
    self.interaction.token,
    message_id,
  )
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
  edit_interaction_followup(
    self.client,
    self.application_id,
    self.interaction.token,
    message_id,
    content,
    clear_content,
    embeds,
    components,
    allowed_mentions,
    files,
    keep_attachments,
  )
}

///|
/// Delete a followup message for this component interaction.
pub async fn ComponentCtx::delete_followup(
  self : ComponentCtx,
  message_id : @model.MessageId,
) -> Unit {
  delete_interaction_followup(
    self.client,
    self.application_id,
    self.interaction.token,
    message_id,
  )
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
/// Send a "channel message with source" response to the modal.
pub async fn ModalCtx::respond(
  self : ModalCtx,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[@dhttp.FileUpload],
  allowed_mentions? : @model.AllowedMentions,
  ephemeral? : Bool = false,
) -> Unit {
  respond_message(
    self.gate,
    ChannelMessageWithSource,
    content,
    embeds,
    components,
    files,
    allowed_mentions,
    ephemeral,
  )
}

///|
/// Acknowledge now and reply later via a followup.
pub async fn ModalCtx::defer_response(
  self : ModalCtx,
  ephemeral? : Bool = false,
) -> Unit {
  respond_message(
    self.gate,
    DeferredChannelMessageWithSource,
    None,
    None,
    None,
    None,
    None,
    ephemeral,
  )
}

///|
/// Fetch the original response to this modal interaction.
pub async fn ModalCtx::original_response(self : ModalCtx) -> @model.Message {
  interaction_original_response(
    self.client,
    self.application_id,
    self.interaction.token,
  )
}

///|
/// Delete the original response to this modal interaction.
pub async fn ModalCtx::delete_response(self : ModalCtx) -> Unit {
  delete_interaction_response(
    self.client,
    self.application_id,
    self.interaction.token,
  )
}

///|
/// Edit the original modal interaction response after deferring.
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
  self.client.edit_original_response(
    self.application_id,
    self.interaction.token,
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
/// Send a modal-interaction followup message.
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
  self.client.create_followup(
    self.application_id,
    self.interaction.token,
    content?,
    embeds?,
    components?,
    files?,
    allowed_mentions?,
    poll?,
    flags=if ephemeral {
      @model.MessageFlags::ephemeral()
    } else {
      @model.MessageFlags::from_bits(0)
    },
  )
}

///|
/// Fetch a followup message for this modal interaction.
pub async fn ModalCtx::get_followup(
  self : ModalCtx,
  message_id : @model.MessageId,
) -> @model.Message {
  interaction_followup(
    self.client,
    self.application_id,
    self.interaction.token,
    message_id,
  )
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
  edit_interaction_followup(
    self.client,
    self.application_id,
    self.interaction.token,
    message_id,
    content,
    clear_content,
    embeds,
    components,
    allowed_mentions,
    files,
    keep_attachments,
  )
}

///|
/// Delete a followup message for this modal interaction.
pub async fn ModalCtx::delete_followup(
  self : ModalCtx,
  message_id : @model.MessageId,
) -> Unit {
  delete_interaction_followup(
    self.client,
    self.application_id,
    self.interaction.token,
    message_id,
  )
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
