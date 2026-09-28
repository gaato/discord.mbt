///|
/// A declarative initial message response returned by an immediate handler.
pub struct InitialResponse {
  priv content_ : String?
  priv embeds_ : Array[@model.Embed]?
  priv components_ : Array[@model.Component]?
  priv files_ : Array[@dhttp.FileUpload]?
  priv allowed_mentions_ : @model.AllowedMentions?
  priv poll_ : @model.PollCreateRequest?
  priv ephemeral_ : Bool
}

///|
/// An initial response returned by an immediate command handler.
pub(all) enum CommandReply {
  Message(InitialResponse)
  ShowModal(ModalHandle)
}

///|
/// Construct an immediate message reply.
pub fn CommandReply::message(
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[@dhttp.FileUpload],
  allowed_mentions? : @model.AllowedMentions,
  poll? : @model.PollCreateRequest,
  ephemeral? : Bool = false,
) -> CommandReply {
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
/// Construct an initial channel-message response.
pub fn InitialResponse::message(
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[@dhttp.FileUpload],
  allowed_mentions? : @model.AllowedMentions,
  poll? : @model.PollCreateRequest,
  ephemeral? : Bool = false,
) -> InitialResponse {
  {
    content_: content,
    embeds_: embeds,
    components_: components,
    files_: files,
    allowed_mentions_: allowed_mentions,
    poll_: poll,
    ephemeral_: ephemeral,
  }
}

///|
/// Build the same message data object used by `CommandCtx::respond`.
#warnings("-unused_value")
fn InitialResponse::message_data(
  self : InitialResponse,
) -> Json raise @dhttp.DiscordHttpError {
  @dhttp.interaction_message_data(
    content?=self.content_,
    embeds?=self.embeds_,
    components?=self.components_,
    allowed_mentions?=self.allowed_mentions_,
    files?=self.files_,
    poll?=self.poll_,
    ephemeral=self.ephemeral_,
  )
}

///|
async fn InitialResponse::send(
  self : InitialResponse,
  ctx : @framework.CommandCtx,
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
async fn CommandReply::send(
  self : CommandReply,
  ctx : @framework.CommandCtx,
) -> Unit {
  match self {
    Message(response) => response.send(ctx)
    ShowModal(handle) => handle.send_command(ctx)
  }
}

///|
/// An `UPDATE_MESSAGE` callback: edits the message that hosts the component
/// (or, for a modal, the message whose component opened it). Omitted fields
/// keep their current value.
pub struct MessageUpdate {
  priv content_ : String?
  priv clear_content_ : Bool
  priv embeds_ : Array[@model.Embed]?
  priv components_ : Array[@model.Component]?
  priv allowed_mentions_ : @model.AllowedMentions?
  priv files_ : Array[@dhttp.FileUpload]?
  priv keep_attachments_ : Array[@model.AttachmentRequest]?
  priv poll_ : @model.PollCreateRequest?
}

///|
/// Describe an update of the host message. `clear_content` removes the text
/// (it cannot be combined with `content`). New `files` replace the existing
/// attachments unless `keep_attachments` lists the ones to retain; an empty
/// `keep_attachments` removes every existing attachment.
pub fn MessageUpdate::MessageUpdate(
  content? : String,
  clear_content? : Bool = false,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  allowed_mentions? : @model.AllowedMentions,
  files? : Array[@dhttp.FileUpload],
  keep_attachments? : Array[@model.AttachmentRequest],
  poll? : @model.PollCreateRequest,
) -> MessageUpdate {
  {
    content_: content,
    clear_content_: clear_content,
    embeds_: embeds,
    components_: components,
    allowed_mentions_: allowed_mentions,
    files_: files,
    keep_attachments_: keep_attachments,
    poll_: poll,
  }
}

///|
async fn MessageUpdate::send_component(
  self : MessageUpdate,
  ctx : @framework.ComponentCtx,
) -> Unit {
  ctx.update_message(
    content?=self.content_,
    clear_content=self.clear_content_,
    embeds?=self.embeds_,
    components?=self.components_,
    allowed_mentions?=self.allowed_mentions_,
    files?=self.files_,
    keep_attachments?=self.keep_attachments_,
    poll?=self.poll_,
  )
}
