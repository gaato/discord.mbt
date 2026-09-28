///|
/// Everything one interaction can do with its messages: the single initial
/// callback through its response gate, and the webhook operations its token
/// allows afterwards. Command, component, and modal contexts expose the same
/// operations, so they all delegate here and cannot drift apart.
priv struct Responder {
  gate : ResponseGate
  client : @dhttp.Client
  application_id : @model.ApplicationId
  token : String
}

///|
/// Send a message-bearing initial callback of type `typ`.
async fn Responder::respond(
  self : Responder,
  typ : @model.InteractionResponseType,
  content? : String,
  clear_content? : Bool = false,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  allowed_mentions? : @model.AllowedMentions,
  files? : Array[@dhttp.FileUpload],
  keep_attachments? : Array[@model.AttachmentRequest],
  poll? : @model.PollCreateRequest,
  ephemeral? : Bool = false,
) -> Unit {
  let data = @dhttp.interaction_message_data(
    content?,
    clear_content~,
    embeds?,
    components?,
    allowed_mentions?,
    files?,
    keep_attachments?,
    poll?,
    ephemeral~,
  )
  self.gate.send({ typ, data: Some(data), }, files?)
}

///|
/// Acknowledge with a loading message to edit or follow up later.
async fn Responder::defer_message(self : Responder, ephemeral : Bool) -> Unit {
  self.respond(DeferredChannelMessageWithSource, ephemeral~)
}

///|
/// Acknowledge a component or modal without changing its message.
async fn Responder::defer_update(self : Responder) -> Unit {
  self.gate.send({ typ: DeferredUpdateMessage, data: None, })
}

///|
async fn Responder::show_modal(
  self : Responder,
  custom_id : String,
  title : String,
  components : Array[@model.Component],
) -> Unit {
  @dhttp.validate_modal_limits(title, components)
  self.gate.send({
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
/// Deliver a message through whichever path the gate's state allows:
/// the initial callback while pending, an edit of a still-loading deferred
/// placeholder, and a followup otherwise. Editing replaces the deprecated
/// behavior where the first followup after a deferral edits the original.
///
/// Verified live on 2026-09-28 with `src/examples/gate_probe`: the edit
/// replaces the loading message and keeps the defer's visibility; after an
/// edit or a `DeferredUpdateMessage` the reply is a separate followup; and
/// when an unconfirmed deferral's edit fails, the fallback followup still
/// replaces the loading message (Discord's deprecated followup-as-edit).
async fn Responder::reply(
  self : Responder,
  content : String?,
  embeds : Array[@model.Embed]?,
  components : Array[@model.Component]?,
  files : Array[@dhttp.FileUpload]?,
  allowed_mentions : @model.AllowedMentions?,
  poll : @model.PollCreateRequest?,
  ephemeral : Bool,
) -> Unit {
  let gate = self.gate
  gate.exclusive_reply(() => {
    gate.wait_settled()
    match gate.state() {
      Pending =>
        self.respond(
          ChannelMessageWithSource,
          content?,
          embeds?,
          components?,
          allowed_mentions?,
          files?,
          poll?,
          ephemeral~,
        )
      Expired => raise ResponseGateError::Expired
      Sent(DeferredChannelMessageWithSource)
      | Unconfirmed(DeferredChannelMessageWithSource) if gate.placeholder_open() => {
        let edited = try {
          self.client.edit_original_response(
            self.application_id,
            self.token,
            content?,
            embeds?,
            components?,
            allowed_mentions?,
            files?,
            poll?,
          )
          |> ignore
          true
        } catch {
          error if @async.is_being_cancelled() => raise error
          // An unconfirmed deferral may have no original message to edit.
          error if gate.state() is Unconfirmed(_) => {
            ignore(error)
            false
          }
          error => raise error
        }
        if !edited {
          self.send_followup(
            content, embeds, components, files, allowed_mentions, poll, ephemeral,
          )
          |> ignore
        }
        // Only a delivered reply replaces the placeholder; after a failure the
        // loading message may still be showing, so a later reply edits again.
        gate.close_placeholder()
      }
      Sent(_) | Unconfirmed(_) => {
        self.send_followup(
          content, embeds, components, files, allowed_mentions, poll, ephemeral,
        )
        |> ignore
        gate.close_placeholder()
      }
    }
  })
}

///|
async fn Responder::send_followup(
  self : Responder,
  content : String?,
  embeds : Array[@model.Embed]?,
  components : Array[@model.Component]?,
  files : Array[@dhttp.FileUpload]?,
  allowed_mentions : @model.AllowedMentions?,
  poll : @model.PollCreateRequest?,
  ephemeral : Bool,
) -> @model.Message {
  self.client.create_followup(
    self.application_id,
    self.token,
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
async fn Responder::followup(
  self : Responder,
  content : String?,
  embeds : Array[@model.Embed]?,
  components : Array[@model.Component]?,
  files : Array[@dhttp.FileUpload]?,
  allowed_mentions : @model.AllowedMentions?,
  poll : @model.PollCreateRequest?,
  ephemeral : Bool,
) -> @model.Message {
  let message = self.send_followup(
    content, embeds, components, files, allowed_mentions, poll, ephemeral,
  )
  self.gate.close_placeholder()
  message
}

///|
async fn Responder::original(self : Responder) -> @model.Message {
  self.client.get_original_response(self.application_id, self.token)
}

///|
async fn Responder::delete_original(self : Responder) -> Unit {
  self.client.delete_original_response(self.application_id, self.token)
  self.gate.close_placeholder()
}

///|
async fn Responder::edit_original(
  self : Responder,
  content : String?,
  clear_content : Bool,
  embeds : Array[@model.Embed]?,
  components : Array[@model.Component]?,
  allowed_mentions : @model.AllowedMentions?,
  files : Array[@dhttp.FileUpload]?,
  keep_attachments : Array[@model.AttachmentRequest]?,
  poll : @model.PollCreateRequest?,
) -> @model.Message {
  let message = self.client.edit_original_response(
    self.application_id,
    self.token,
    content?,
    clear_content~,
    embeds?,
    components?,
    allowed_mentions?,
    files?,
    keep_attachments?,
    poll?,
  )
  self.gate.close_placeholder()
  message
}

///|
async fn Responder::get_followup(
  self : Responder,
  message_id : @model.MessageId,
) -> @model.Message {
  self.client.get_followup(self.application_id, self.token, message_id)
}

///|
async fn Responder::edit_followup(
  self : Responder,
  message_id : @model.MessageId,
  content : String?,
  clear_content : Bool,
  embeds : Array[@model.Embed]?,
  components : Array[@model.Component]?,
  allowed_mentions : @model.AllowedMentions?,
  files : Array[@dhttp.FileUpload]?,
  keep_attachments : Array[@model.AttachmentRequest]?,
) -> @model.Message {
  self.client.edit_followup(
    self.application_id,
    self.token,
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
async fn Responder::delete_followup(
  self : Responder,
  message_id : @model.MessageId,
) -> Unit {
  self.client.delete_followup(self.application_id, self.token, message_id)
}
