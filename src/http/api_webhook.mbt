///|
fn validate_webhook_name(name : String) -> Unit raise DiscordHttpError {
  validate_length("webhook name", Some(name), min=1, max=80)
}

///|
fn validate_execute_webhook(
  content : String?,
  embeds : Array[@model.Embed]?,
  components : Array[@model.Component]?,
  files : Array[FileUpload]?,
) -> Unit raise DiscordHttpError {
  validate_content(content)
  if content is None && embeds is None && components is None && files is None {
    raise Validation(
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
  let body = @model.ObjBuilder()
    .field("name", name)
    .opt("avatar", avatar)
    .build()
  decode(self.request(CreateWebhook(channel_id~), body~, audit_reason?))
}

///|
/// List the webhooks created for a channel.
pub async fn Client::get_channel_webhooks(
  self : Client,
  channel_id : @model.ChannelId,
) -> Array[@model.Webhook] raise DiscordHttpError {
  decode(self.request(GetChannelWebhooks(channel_id~)))
}

///|
/// List the webhooks belonging to a guild.
pub async fn Client::get_guild_webhooks(
  self : Client,
  guild_id : @model.GuildId,
) -> Array[@model.Webhook] raise DiscordHttpError {
  decode(self.request(GetGuildWebhooks(guild_id~)))
}

///|
/// Fetch a webhook using bot authentication.
pub async fn Client::get_webhook(
  self : Client,
  webhook_id : @model.WebhookId,
) -> @model.Webhook raise DiscordHttpError {
  decode(self.request(GetWebhook(webhook_id~)))
}

///|
/// Modify a webhook using bot authentication.
pub async fn Client::modify_webhook(
  self : Client,
  webhook_id : @model.WebhookId,
  name? : String,
  avatar? : String,
  clear_avatar? : Bool = false,
  channel_id? : @model.ChannelId,
  audit_reason? : String,
) -> @model.Webhook raise DiscordHttpError {
  if name is Some(value) {
    validate_webhook_name(value)
  }
  let body = @model.ObjBuilder()
    .opt("name", name)
    .und("avatar", patch_nullable("avatar", avatar, clear_avatar))
    .opt("channel_id", channel_id)
    .build()
  decode(self.request(ModifyWebhook(webhook_id~), body~, audit_reason?))
}

///|
/// Delete a webhook using bot authentication.
pub async fn Client::delete_webhook(
  self : Client,
  webhook_id : @model.WebhookId,
  audit_reason? : String,
) -> Unit raise DiscordHttpError {
  self.request(DeleteWebhook(webhook_id~), audit_reason?) |> ignore
}

///|
fn modify_webhook_with_token_body(
  name : String?,
  avatar : String?,
  clear_avatar : Bool,
) -> Json raise DiscordHttpError {
  if name is Some(value) {
    validate_webhook_name(value)
  }
  @model.ObjBuilder()
  .opt("name", name)
  .und("avatar", patch_nullable("avatar", avatar, clear_avatar))
  .build()
}

///|
fn compatible_webhook_query(
  thread_id : @model.ChannelId?,
  wait : Bool?,
) -> String {
  let params : Array[String] = []
  if thread_id is Some(value) {
    params.push("thread_id=\{value}")
  }
  if wait is Some(value) {
    params.push("wait=\{value}")
  }
  if params.length() == 0 {
    ""
  } else {
    "?" + params.join("&")
  }
}

///|
/// Fetch a webhook using the webhook token embedded in the route.
pub async fn Client::get_webhook_with_token(
  self : Client,
  webhook_id : @model.WebhookId,
  token : String,
) -> @model.Webhook raise DiscordHttpError {
  decode(self.request(GetWebhookWithToken(webhook_id~, token~)))
}

///|
/// Modify a webhook using its token. This token-authenticated variant cannot
/// move the webhook to another channel.
pub async fn Client::modify_webhook_with_token(
  self : Client,
  webhook_id : @model.WebhookId,
  token : String,
  name? : String,
  avatar? : String,
  clear_avatar? : Bool = false,
) -> @model.Webhook raise DiscordHttpError {
  let body = modify_webhook_with_token_body(name, avatar, clear_avatar)
  decode(self.request(ModifyWebhookWithToken(webhook_id~, token~), body~))
}

///|
/// Delete a webhook using its token.
pub async fn Client::delete_webhook_with_token(
  self : Client,
  webhook_id : @model.WebhookId,
  token : String,
) -> Unit raise DiscordHttpError {
  self.request(DeleteWebhookWithToken(webhook_id~, token~)) |> ignore
}

///|
/// Execute a Slack-compatible webhook payload. `thread_id` targets a thread,
/// and `wait` asks Discord to wait for server confirmation.
pub async fn Client::execute_slack_compatible_webhook(
  self : Client,
  webhook_id : @model.WebhookId,
  token : String,
  payload : Json,
  thread_id? : @model.ChannelId,
  wait? : Bool,
) -> Unit raise DiscordHttpError {
  let query = compatible_webhook_query(thread_id, wait)
  self.request(
    ExecuteSlackCompatibleWebhook(webhook_id~, token~, query~),
    body=payload,
  )
  |> ignore
}

///|
/// Execute a GitHub-compatible webhook payload. Supported `github_event`
/// values are commit_comment, create, delete, fork, issue_comment, issues,
/// member, public, pull_request, pull_request_review,
/// pull_request_review_comment, push, release, watch, check_run, check_suite,
/// discussion, and discussion_comment.
pub async fn Client::execute_github_compatible_webhook(
  self : Client,
  webhook_id : @model.WebhookId,
  token : String,
  payload : Json,
  github_event~ : String,
  thread_id? : @model.ChannelId,
  wait? : Bool,
) -> Unit raise DiscordHttpError {
  let query = compatible_webhook_query(thread_id, wait)
  self.request(
    ExecuteGithubCompatibleWebhook(webhook_id~, token~, query~),
    body=payload,
    headers={ "x-github-event": github_event },
  )
  |> ignore
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
  allowed_mentions? : @model.AllowedMentions,
) -> @model.Message raise DiscordHttpError {
  validate_execute_webhook(content, embeds, components, files)
  let flags = message_flags_with_components_v2(
    None,
    content,
    embeds,
    components,
  )
  let builder = @model.ObjBuilder()
    .opt("content", content)
    .opt("embeds", embeds)
    .opt("components", components)
    .opt("flags", flags)
    .opt("username", username)
    .opt("avatar_url", avatar_url)
    .opt("tts", tts)
    .opt("allowed_mentions", allowed_mentions)
  if files is Some(fs) && fs.length() > 0 {
    builder.field("attachments", attachments_json(fs)) |> ignore
  }
  decode(
    self.request(
      ExecuteWebhook(webhook_id~, token~, query="?wait=true"),
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
  decode(self.request(GetWebhookMessage(webhook_id~, token~, message_id~)))
}

///|
/// Edit a message previously created by a webhook. Uploaded files replace
/// the attachment list announced in the request.
pub async fn Client::edit_webhook_message(
  self : Client,
  webhook_id : @model.WebhookId,
  token : String,
  message_id : @model.MessageId,
  content? : String,
  clear_content? : Bool = false,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  allowed_mentions? : @model.AllowedMentions,
  files? : Array[FileUpload],
) -> @model.Message raise DiscordHttpError {
  let builder = message_patch_builder(
    content,
    clear_content,
    embeds,
    components,
    None,
  ).opt("allowed_mentions", allowed_mentions)
  if files is Some(fs) && fs.length() > 0 {
    builder.field("attachments", attachments_json(fs)) |> ignore
  }
  decode(
    self.request(
      EditWebhookMessage(webhook_id~, token~, message_id~),
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
  self.request(DeleteWebhookMessage(webhook_id~, token~, message_id~)) |> ignore
}
