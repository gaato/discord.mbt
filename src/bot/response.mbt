///|
/// A declarative initial message response returned by an immediate handler.
pub struct InitialResponse {
  priv content_ : String?
  priv embeds_ : Array[@model.Embed]?
  priv components_ : Array[@model.Component]?
  priv files_ : Array[@dhttp.FileUpload]?
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
  ephemeral? : Bool = false,
) -> CommandReply {
  Message(
    InitialResponse::message(content?, embeds?, components?, files?, ephemeral~),
  )
}

///|
/// Construct an initial channel-message response.
pub fn InitialResponse::message(
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[@dhttp.FileUpload],
  ephemeral? : Bool = false,
) -> InitialResponse {
  {
    content_: content,
    embeds_: embeds,
    components_: components,
    files_: files,
    ephemeral_: ephemeral,
  }
}

///|
/// Build the same message data object used by `CommandCtx::respond`.
#warnings("-unused_value")
fn InitialResponse::message_data(self : InitialResponse) -> Json {
  let builder = @model.ObjBuilder::new()
    .opt("content", self.content_)
    .opt("embeds", self.embeds_)
    .opt("components", self.components_)
  if self.files_ is Some(files) && files.length() > 0 {
    builder.field("attachments", @dhttp.attachments_json(files)) |> ignore
  }
  if self.ephemeral_ {
    builder.field("flags", @model.MessageFlags::ephemeral()) |> ignore
  }
  builder.build()
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
