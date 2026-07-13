///|
fn validate_webhook_name(name : String) -> Unit raise DiscordHttpError {
  if name.length() < 1 || name.length() > 80 {
    raise DiscordHttpError::Validation(
      message="webhook name must be between 1 and 80 characters",
    )
  }
}

///|
fn validate_execute_webhook(
  content : String?,
  embeds : Array[@model.Embed]?,
  components : Array[@model.Component]?,
  files : Array[FileUpload]?,
) -> Unit raise DiscordHttpError {
  if content is Some(value) && value.length() > 4000 {
    raise DiscordHttpError::Validation(
      message="content exceeds 4000 UTF-16 units",
    )
  }
  if content is None && embeds is None && components is None && files is None {
    raise DiscordHttpError::Validation(
      message="one of content/embeds/components/files is required",
    )
  }
}

///|
/// Create an incoming webhook for a channel.
pub async fn Client::create_webhook(
  self : Client,
  channel_id : @model.ChannelId,
  name : String,
  avatar? : String,
  audit_reason? : String,
) -> @model.Webhook raise DiscordHttpError {
  validate_webhook_name(name)
  let body = @model.ObjBuilder::new()
    .field("name", name)
    .opt("avatar", avatar)
    .build()
  decode(self.request(Route::CreateWebhook(channel_id~), body~, audit_reason?))
}

///|
/// List the webhooks created for a channel.
pub async fn Client::get_channel_webhooks(
  self : Client,
  channel_id : @model.ChannelId,
) -> Array[@model.Webhook] raise DiscordHttpError {
  decode(self.request(Route::GetChannelWebhooks(channel_id~)))
}

///|
/// List the webhooks belonging to a guild.
pub async fn Client::get_guild_webhooks(
  self : Client,
  guild_id : @model.GuildId,
) -> Array[@model.Webhook] raise DiscordHttpError {
  decode(self.request(Route::GetGuildWebhooks(guild_id~)))
}

///|
/// Fetch a webhook using bot authentication.
pub async fn Client::get_webhook(
  self : Client,
  webhook_id : @model.WebhookId,
) -> @model.Webhook raise DiscordHttpError {
  decode(self.request(Route::GetWebhook(webhook_id~)))
}

///|
/// Modify a webhook using bot authentication.
pub async fn Client::modify_webhook(
  self : Client,
  webhook_id : @model.WebhookId,
  name? : @model.Undefinable[String] = Missing,
  avatar? : @model.Undefinable[String] = Missing,
  channel_id? : @model.Undefinable[@model.ChannelId] = Missing,
  audit_reason? : String,
) -> @model.Webhook raise DiscordHttpError {
  if name is Value(value) {
    validate_webhook_name(value)
  }
  let body = @model.ObjBuilder::new()
    .und("name", name)
    .und("avatar", avatar)
    .und("channel_id", channel_id)
    .build()
  decode(self.request(Route::ModifyWebhook(webhook_id~), body~, audit_reason?))
}

///|
/// Delete a webhook using bot authentication.
pub async fn Client::delete_webhook(
  self : Client,
  webhook_id : @model.WebhookId,
  audit_reason? : String,
) -> Unit raise DiscordHttpError {
  self.request(Route::DeleteWebhook(webhook_id~), audit_reason?) |> ignore
}

///|
/// Execute a webhook and wait for the created message. At least one of
/// `content`, `embeds`, `components`, or `files` must be provided.
pub async fn Client::execute_webhook(
  self : Client,
  webhook_id : @model.WebhookId,
  token : String,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[FileUpload],
  username? : String,
  avatar_url? : String,
  tts? : Bool,
) -> @model.Message raise DiscordHttpError {
  validate_execute_webhook(content, embeds, components, files)
  let builder = @model.ObjBuilder::new()
    .opt("content", content)
    .opt("embeds", embeds)
    .opt("components", components)
    .opt("username", username)
    .opt("avatar_url", avatar_url)
    .opt("tts", tts)
  if files is Some(fs) && fs.length() > 0 {
    builder.field("attachments", attachments_json(fs)) |> ignore
  }
  decode(
    self.request(
      Route::ExecuteWebhook(webhook_id~, token~, query="?wait=true"),
      body=builder.build(),
      files?,
    ),
  )
}

///|
/// Fetch a message previously created by a webhook.
pub async fn Client::get_webhook_message(
  self : Client,
  webhook_id : @model.WebhookId,
  token : String,
  message_id : @model.MessageId,
) -> @model.Message raise DiscordHttpError {
  decode(
    self.request(Route::GetWebhookMessage(webhook_id~, token~, message_id~)),
  )
}

///|
/// Edit a message previously created by a webhook. Uploaded files replace
/// the attachment list announced in the request.
pub async fn Client::edit_webhook_message(
  self : Client,
  webhook_id : @model.WebhookId,
  token : String,
  message_id : @model.MessageId,
  content? : @model.Undefinable[String] = Missing,
  embeds? : @model.Undefinable[Array[@model.Embed]] = Missing,
  components? : @model.Undefinable[Array[@model.Component]] = Missing,
  files? : Array[FileUpload],
) -> @model.Message raise DiscordHttpError {
  if content is Value(value) && value.length() > 4000 {
    raise DiscordHttpError::Validation(
      message="content exceeds 4000 UTF-16 units",
    )
  }
  let builder = @model.ObjBuilder::new()
    .und("content", content)
    .und("embeds", embeds)
    .und("components", components)
  if files is Some(fs) && fs.length() > 0 {
    builder.field("attachments", attachments_json(fs)) |> ignore
  }
  decode(
    self.request(
      Route::EditWebhookMessage(webhook_id~, token~, message_id~),
      body=builder.build(),
      files?,
    ),
  )
}

///|
/// Delete a message previously created by a webhook.
pub async fn Client::delete_webhook_message(
  self : Client,
  webhook_id : @model.WebhookId,
  token : String,
  message_id : @model.MessageId,
) -> Unit raise DiscordHttpError {
  self.request(Route::DeleteWebhookMessage(webhook_id~, token~, message_id~))
  |> ignore
}
