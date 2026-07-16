///|
/// A webhook id bound to the REST client for bot-authenticated management.
/// Executing the webhook requires a token; use `WebhookRef::with_token`.
pub struct WebhookRef {
  priv client : Client
  priv webhook_id : @model.WebhookId
}

///|
/// A webhook id and URL token bound to the REST client. These operations use
/// token authentication without the bot token and do not support audit reasons.
pub struct WebhookTokenRef {
  priv client : Client
  priv webhook_id : @model.WebhookId
  priv token : String
}

///|
/// A webhook message id bound to its webhook URL token and REST client.
pub struct WebhookMessageRef {
  priv client : Client
  priv webhook_id : @model.WebhookId
  priv token : String
  priv message_id : @model.MessageId
}

///|
/// Bind a webhook id to this client for bot-authenticated management.
pub fn Client::webhook_ref(
  self : Client,
  webhook_id : @model.WebhookId,
) -> WebhookRef {
  { client: self, webhook_id }
}

///|
/// Bind a webhook id and URL token to this client.
pub fn Client::webhook_token_ref(
  self : Client,
  webhook_id : @model.WebhookId,
  token : String,
) -> WebhookTokenRef {
  { client: self, webhook_id, token }
}

///|
/// Bind a URL token to this webhook for token-authenticated operations.
pub fn WebhookRef::with_token(
  self : WebhookRef,
  token : String,
) -> WebhookTokenRef {
  { client: self.client, webhook_id: self.webhook_id, token }
}

///|
/// Bind a message id created by this webhook to the client.
pub fn WebhookTokenRef::message_ref(
  self : WebhookTokenRef,
  message_id : @model.MessageId,
) -> WebhookMessageRef {
  {
    client: self.client,
    webhook_id: self.webhook_id,
    token: self.token,
    message_id,
  }
}

///|
/// Fetch this webhook using bot authentication.
pub async fn WebhookRef::fetch(
  self : WebhookRef,
) -> @model.Webhook raise DiscordHttpError {
  self.client.get_webhook(self.webhook_id)
}

///|
/// Edit this webhook using bot authentication.
pub async fn WebhookRef::edit(
  self : WebhookRef,
  name? : String,
  avatar? : String,
  clear_avatar? : Bool = false,
  channel_id? : @model.ChannelId,
  reason? : String,
) -> @model.Webhook raise DiscordHttpError {
  self.client.modify_webhook(
    self.webhook_id,
    name?,
    avatar?,
    clear_avatar~,
    channel_id?,
    audit_reason?=reason,
  )
}

///|
/// Delete this webhook using bot authentication.
pub async fn WebhookRef::delete(
  self : WebhookRef,
  reason? : String,
) -> Unit raise DiscordHttpError {
  self.client.delete_webhook(self.webhook_id, audit_reason?=reason)
}

///|
/// Fetch this webhook using its URL token without bot authentication.
pub async fn WebhookTokenRef::fetch(
  self : WebhookTokenRef,
) -> @model.Webhook raise DiscordHttpError {
  self.client.get_webhook_with_token(self.webhook_id, self.token)
}

///|
/// Edit this webhook using its URL token without bot authentication.
pub async fn WebhookTokenRef::edit(
  self : WebhookTokenRef,
  name? : String,
  avatar? : String,
  clear_avatar? : Bool = false,
) -> @model.Webhook raise DiscordHttpError {
  self.client.modify_webhook_with_token(
    self.webhook_id,
    self.token,
    name?,
    avatar?,
    clear_avatar~,
  )
}

///|
/// Delete this webhook using its URL token without bot authentication.
pub async fn WebhookTokenRef::delete(
  self : WebhookTokenRef,
) -> Unit raise DiscordHttpError {
  self.client.delete_webhook_with_token(self.webhook_id, self.token)
}

///|
/// Execute this webhook using its URL token.
pub async fn WebhookTokenRef::send(
  self : WebhookTokenRef,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  files? : Array[FileUpload],
  username? : String,
  avatar_url? : String,
  tts? : Bool,
  allowed_mentions? : @model.AllowedMentions,
) -> @model.Message raise DiscordHttpError {
  self.client.execute_webhook(
    self.webhook_id,
    self.token,
    content?,
    embeds?,
    components?,
    files?,
    username?,
    avatar_url?,
    tts?,
    allowed_mentions?,
  )
}

///|
/// Execute a Slack-compatible payload using this webhook's URL token.
pub async fn WebhookTokenRef::send_slack(
  self : WebhookTokenRef,
  payload : Json,
  thread_id? : @model.ChannelId,
  wait? : Bool,
) -> Unit raise DiscordHttpError {
  self.client.execute_slack_compatible_webhook(
    self.webhook_id,
    self.token,
    payload,
    thread_id?,
    wait?,
  )
}

///|
/// Execute a GitHub-compatible payload using this webhook's URL token.
pub async fn WebhookTokenRef::send_github(
  self : WebhookTokenRef,
  payload : Json,
  github_event~ : String,
  thread_id? : @model.ChannelId,
  wait? : Bool,
) -> Unit raise DiscordHttpError {
  self.client.execute_github_compatible_webhook(
    self.webhook_id,
    self.token,
    payload,
    github_event~,
    thread_id?,
    wait?,
  )
}

///|
/// Fetch this webhook message using the webhook's URL token.
pub async fn WebhookMessageRef::fetch(
  self : WebhookMessageRef,
) -> @model.Message raise DiscordHttpError {
  self.client.get_webhook_message(self.webhook_id, self.token, self.message_id)
}

///|
/// Edit this webhook message using the webhook's URL token.
pub async fn WebhookMessageRef::edit(
  self : WebhookMessageRef,
  content? : String,
  clear_content? : Bool = false,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  allowed_mentions? : @model.AllowedMentions,
  files? : Array[FileUpload],
) -> @model.Message raise DiscordHttpError {
  self.client.edit_webhook_message(
    self.webhook_id,
    self.token,
    self.message_id,
    content?,
    clear_content~,
    embeds?,
    components?,
    allowed_mentions?,
    files?,
  )
}

///|
/// Delete this webhook message using the webhook's URL token.
pub async fn WebhookMessageRef::delete(
  self : WebhookMessageRef,
) -> Unit raise DiscordHttpError {
  self.client.delete_webhook_message(
    self.webhook_id,
    self.token,
    self.message_id,
  )
}
