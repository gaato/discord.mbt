///|
fn Client::with_channel_allowed_mentions(
  self : Client,
  builder : @model.ObjBuilder,
  allowed_mentions : @model.AllowedMentions?,
) -> @model.ObjBuilder {
  builder.field(
    "allowed_mentions",
    allowed_mentions.unwrap_or(self.default_allowed_mentions),
  )
}

///|
/// Post a message to a channel. Labeled optional arguments replace the
/// builder pattern; at least one of `content`, `embeds`, `components`,
/// `sticker_ids`, or `files` must be provided.
pub async fn Client::create_message(
  self : Client,
  channel_id : @model.ChannelId,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  sticker_ids? : Array[@model.StickerId],
  files? : Array[FileUpload],
  reply_to? : @model.MessageId,
  tts? : Bool,
  flags? : @model.MessageFlags,
  allowed_mentions? : @model.AllowedMentions,
  nonce? : @model.Nonce,
  enforce_nonce? : Bool,
) -> @model.Message raise DiscordHttpError {
  if content is Some(c) && c.length() > 4000 {
    raise DiscordHttpError::Validation(
      message="content exceeds 4000 UTF-16 units",
    )
  }
  if content is None &&
    embeds is None &&
    components is None &&
    sticker_ids is None &&
    files is None {
    raise DiscordHttpError::Validation(
      message="one of content/embeds/components/sticker_ids/files is required",
    )
  }
  let body = self
    .with_channel_allowed_mentions(
      @model.ObjBuilder::new()
      .opt("content", content)
      .opt("embeds", embeds)
      .opt("components", components)
      .opt("sticker_ids", sticker_ids)
      .opt("tts", tts)
      .opt("flags", flags),
      allowed_mentions,
    )
    .opt("nonce", nonce)
    .opt("enforce_nonce", enforce_nonce)
  if reply_to is Some(message_id) {
    body.field("message_reference", {
      "message_id": Json::string(message_id.to_string()),
    })
    |> ignore
  }
  if files is Some(fs) && fs.length() > 0 {
    body.field("attachments", attachments_json(fs)) |> ignore
  }
  decode(
    self.request(Route::CreateMessage(channel_id~), body=body.build(), files?),
  )
}

///|
/// Edit a previously sent message. When `files` is given, the message's
/// attachments are replaced by the uploaded files (Discord keeps only the
/// attachments listed in the request).
pub async fn Client::edit_message(
  self : Client,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
  content? : String,
  clear_content? : Bool = false,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  flags? : @model.MessageFlags,
  allowed_mentions? : @model.AllowedMentions,
  files? : Array[FileUpload],
) -> @model.Message raise DiscordHttpError {
  let builder = self.with_channel_allowed_mentions(
    message_patch_builder(content, clear_content, embeds, components, flags),
    allowed_mentions,
  )
  if files is Some(fs) && fs.length() > 0 {
    builder.field("attachments", attachments_json(fs)) |> ignore
  }
  decode(
    self.request(
      Route::EditMessage(channel_id~, message_id~),
      body=builder.build(),
      files?,
    ),
  )
}

///|
/// Delete a message.
pub async fn Client::delete_message(
  self : Client,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
  audit_reason? : String,
) -> Unit raise DiscordHttpError {
  self.request(Route::DeleteMessage(channel_id~, message_id~), audit_reason?)
  |> ignore
}

///|
fn validate_bulk_delete_messages(
  messages : Array[@model.MessageId],
) -> Unit raise DiscordHttpError {
  if messages.length() < 2 || messages.length() > 100 {
    raise DiscordHttpError::Validation(
      message="bulk delete requires between 2 and 100 messages",
    )
  }
}

///|
/// Delete between 2 and 100 messages in one request.
pub async fn Client::bulk_delete_messages(
  self : Client,
  channel_id : @model.ChannelId,
  messages : Array[@model.MessageId],
  audit_reason? : String,
) -> Unit raise DiscordHttpError {
  validate_bulk_delete_messages(messages)
  let body = @model.ObjBuilder::new().field("messages", messages).build()
  self.request(Route::BulkDeleteMessages(channel_id~), body~, audit_reason?)
  |> ignore
}

///|
/// Fetch a single message.
pub async fn Client::get_message(
  self : Client,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
) -> @model.Message raise DiscordHttpError {
  decode(self.request(Route::GetChannelMessage(channel_id~, message_id~)))
}

///|
/// List messages in a channel. `around`/`before`/`after` are mutually
/// exclusive per the API; the first one provided wins here.
pub async fn Client::get_channel_messages(
  self : Client,
  channel_id : @model.ChannelId,
  limit? : Int,
  around? : @model.MessageId,
  before? : @model.MessageId,
  after? : @model.MessageId,
) -> Array[@model.Message] raise DiscordHttpError {
  let params : Array[String] = []
  if limit is Some(n) {
    params.push("limit=\{n}")
  }
  if around is Some(id) {
    params.push("around=\{id}")
  } else if before is Some(id) {
    params.push("before=\{id}")
  } else if after is Some(id) {
    params.push("after=\{id}")
  }
  let query = if params.length() == 0 { "" } else { "?" + params.join("&") }
  decode(self.request(Route::GetChannelMessages(channel_id~, query~)))
}
