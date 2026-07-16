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
///
/// Message-shaped endpoints switch to multipart automatically when `files`
/// is present (see `FileUpload` and `attachments_json` for the wire format).
/// The same `files` argument is available on interaction responses,
/// followups, and edit methods. On edit, the supplied files replace the
/// attachment list sent in that request; preserve any attachments that
/// should remain.
///
/// ```mbt check
/// test "upload a file alongside message content" {
///   async fn send_report(
///     client : @http.Client,
///     channel_id : @model.ChannelId,
///     report : Bytes,
///   ) -> @model.Message {
///     let file = @http.FileUpload(
///       "report.csv",
///       report,
///       content_type="text/csv",
///       description="Daily report",
///     )
///     client.create_message(channel_id, content="Report attached", files=[file])
///   }
///
///   ignore(send_report)
/// }
/// ```
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
  validate_content(content)
  if content is None &&
    embeds is None &&
    components is None &&
    sticker_ids is None &&
    files is None {
    raise Validation(
      message="one of content/embeds/components/sticker_ids/files is required",
    )
  }
  let flags = message_flags_with_components_v2(
    flags,
    content,
    embeds,
    components,
    sticker_ids?,
  )
  let body = self
    .with_channel_allowed_mentions(
      @model.ObjBuilder()
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
  decode(self.request(CreateMessage(channel_id~), body=body.build(), files?))
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
      EditMessage(channel_id~, message_id~),
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
  self.request(DeleteMessage(channel_id~, message_id~), audit_reason?) |> ignore
}

///|
fn validate_bulk_delete_messages(
  messages : Array[@model.MessageId],
) -> Unit raise DiscordHttpError {
  if messages.length() < 2 || messages.length() > 100 {
    raise Validation(message="bulk delete requires between 2 and 100 messages")
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
  let body = @model.ObjBuilder().field("messages", messages).build()
  self.request(BulkDeleteMessages(channel_id~), body~, audit_reason?) |> ignore
}

///|
/// Fetch a single message.
pub async fn Client::get_message(
  self : Client,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
) -> @model.Message raise DiscordHttpError {
  decode(self.request(GetChannelMessage(channel_id~, message_id~)))
}

///|
/// Publish a message from an announcement channel to its followers.
pub async fn Client::crosspost_message(
  self : Client,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
) -> @model.Message raise DiscordHttpError {
  decode(self.request(CrosspostMessage(channel_id~, message_id~)))
}

///|
/// List messages in a channel. `around`/`before`/`after` are mutually
/// exclusive.
pub async fn Client::get_channel_messages(
  self : Client,
  channel_id : @model.ChannelId,
  limit? : Int,
  around? : @model.MessageId,
  before? : @model.MessageId,
  after? : @model.MessageId,
) -> Array[@model.Message] raise DiscordHttpError {
  validate_page_limit("message", limit, 100)
  let cursor_count = (if around is Some(_) { 1 } else { 0 }) +
    (if before is Some(_) { 1 } else { 0 }) +
    (if after is Some(_) { 1 } else { 0 })
  if cursor_count > 1 {
    raise Validation(
      message="message pagination accepts only one of around, before, or after",
    )
  }
  let params : Array[String] = []
  if limit is Some(n) {
    params.push("limit=\{n}")
  }
  if around is Some(id) {
    params.push("around=\{id}")
  }
  if before is Some(id) {
    params.push("before=\{id}")
  }
  if after is Some(id) {
    params.push("after=\{id}")
  }
  let query = if params.length() == 0 { "" } else { "?" + params.join("&") }
  decode(self.request(GetChannelMessages(channel_id~, query~)))
}

///|
fn percent_encode_query_text(value : String) -> String {
  let builder = StringBuilder(size_hint=value.length())
  for byte in @utf8.encode(value).iter() {
    let value = byte.to_int()
    let unreserved = (value >= 65 && value <= 90) ||
      (value >= 97 && value <= 122) ||
      (value >= 48 && value <= 57) ||
      value == 45 ||
      value == 46 ||
      value == 95 ||
      value == 126
    if unreserved {
      builder.write_char(byte.to_char())
    } else {
      builder.write_char('%')
      builder.write_string(byte.to_hex().to_upper())
    }
  }
  builder.to_string()
}

///|
fn validate_search_array_count(
  name : String,
  values_length : Int,
  maximum : Int,
) -> Unit raise DiscordHttpError {
  if values_length > maximum {
    raise Validation(message="\{name} exceeds \{maximum} entries")
  }
}

///|
fn search_guild_messages_query(
  limit? : Int,
  offset? : Int,
  slop? : Int,
  content? : String,
  mention_everyone? : Bool,
  pinned? : Bool,
  include_nsfw? : Bool,
  sort_by? : String,
  sort_order? : String,
  max_id? : @model.MessageId,
  min_id? : @model.MessageId,
  channel_id? : Array[@model.ChannelId],
  author_type? : Array[String],
  author_id? : Array[@model.UserId],
  mentions? : Array[@model.UserId],
  mentions_role_id? : Array[@model.RoleId],
  replied_to_user_id? : Array[@model.UserId],
  replied_to_message_id? : Array[@model.MessageId],
  has? : Array[String],
  embed_type? : Array[String],
  embed_provider? : Array[String],
  link_hostname? : Array[String],
  attachment_filename? : Array[String],
  attachment_extension? : Array[String],
) -> String raise DiscordHttpError {
  validate_range("search limit", limit, min=1, max=25)
  validate_range("search offset", offset, min=0, max=9975)
  validate_range("search slop", slop, min=0, max=100)
  validate_length("search content", content, max=1024)
  if channel_id is Some(values) {
    validate_search_array_count("channel_id", values.length(), 500)
  }
  if author_id is Some(values) {
    validate_search_array_count("author_id", values.length(), 100)
  }
  if mentions is Some(values) {
    validate_search_array_count("mentions", values.length(), 100)
  }
  if mentions_role_id is Some(values) {
    validate_search_array_count("mentions_role_id", values.length(), 100)
  }
  if replied_to_user_id is Some(values) {
    validate_search_array_count("replied_to_user_id", values.length(), 100)
  }
  if replied_to_message_id is Some(values) {
    validate_search_array_count("replied_to_message_id", values.length(), 100)
  }
  if embed_provider is Some(values) {
    validate_search_array_count("embed_provider", values.length(), 100)
  }
  if link_hostname is Some(values) {
    validate_search_array_count("link_hostname", values.length(), 100)
  }
  if attachment_filename is Some(values) {
    validate_search_array_count("attachment_filename", values.length(), 100)
  }
  if attachment_extension is Some(values) {
    validate_search_array_count("attachment_extension", values.length(), 100)
  }
  let params : Array[String] = []
  if limit is Some(value) {
    params.push("limit=\{value}")
  }
  if offset is Some(value) {
    params.push("offset=\{value}")
  }
  if slop is Some(value) {
    params.push("slop=\{value}")
  }
  if content is Some(value) {
    params.push("content=" + percent_encode_query_text(value))
  }
  if mention_everyone is Some(value) {
    params.push("mention_everyone=\{value}")
  }
  if pinned is Some(value) {
    params.push("pinned=\{value}")
  }
  if include_nsfw is Some(value) {
    params.push("include_nsfw=\{value}")
  }
  if sort_by is Some(value) {
    params.push("sort_by=" + value)
  }
  if sort_order is Some(value) {
    params.push("sort_order=" + value)
  }
  if max_id is Some(value) {
    params.push("max_id=\{value}")
  }
  if min_id is Some(value) {
    params.push("min_id=\{value}")
  }
  if channel_id is Some(values) {
    for value in values {
      params.push("channel_id=\{value}")
    }
  }
  if author_type is Some(values) {
    for value in values {
      params.push("author_type=" + value)
    }
  }
  if author_id is Some(values) {
    for value in values {
      params.push("author_id=\{value}")
    }
  }
  if mentions is Some(values) {
    for value in values {
      params.push("mentions=\{value}")
    }
  }
  if mentions_role_id is Some(values) {
    for value in values {
      params.push("mentions_role_id=\{value}")
    }
  }
  if replied_to_user_id is Some(values) {
    for value in values {
      params.push("replied_to_user_id=\{value}")
    }
  }
  if replied_to_message_id is Some(values) {
    for value in values {
      params.push("replied_to_message_id=\{value}")
    }
  }
  if has is Some(values) {
    for value in values {
      params.push("has=" + value)
    }
  }
  if embed_type is Some(values) {
    for value in values {
      params.push("embed_type=" + value)
    }
  }
  if embed_provider is Some(values) {
    for value in values {
      params.push("embed_provider=" + percent_encode_query_text(value))
    }
  }
  if link_hostname is Some(values) {
    for value in values {
      params.push("link_hostname=" + percent_encode_query_text(value))
    }
  }
  if attachment_filename is Some(values) {
    for value in values {
      params.push("attachment_filename=" + percent_encode_query_text(value))
    }
  }
  if attachment_extension is Some(values) {
    for value in values {
      params.push("attachment_extension=" + percent_encode_query_text(value))
    }
  }
  if params.length() == 0 {
    ""
  } else {
    "?" + params.join("&")
  }
}

///|
/// Search messages in a guild. Results that contain message content require
/// the MESSAGE_CONTENT privileged intent, and the caller must have the
/// READ_MESSAGE_HISTORY permission in the channels being searched.
pub async fn Client::search_guild_messages(
  self : Client,
  guild_id : @model.GuildId,
  limit? : Int,
  offset? : Int,
  slop? : Int,
  content? : String,
  mention_everyone? : Bool,
  pinned? : Bool,
  include_nsfw? : Bool,
  sort_by? : String,
  sort_order? : String,
  max_id? : @model.MessageId,
  min_id? : @model.MessageId,
  channel_id? : Array[@model.ChannelId],
  author_type? : Array[String],
  author_id? : Array[@model.UserId],
  mentions? : Array[@model.UserId],
  mentions_role_id? : Array[@model.RoleId],
  replied_to_user_id? : Array[@model.UserId],
  replied_to_message_id? : Array[@model.MessageId],
  has? : Array[String],
  embed_type? : Array[String],
  embed_provider? : Array[String],
  link_hostname? : Array[String],
  attachment_filename? : Array[String],
  attachment_extension? : Array[String],
) -> @model.GuildMessageSearchResults raise DiscordHttpError {
  let query = search_guild_messages_query(
    limit?,
    offset?,
    slop?,
    content?,
    mention_everyone?,
    pinned?,
    include_nsfw?,
    sort_by?,
    sort_order?,
    max_id?,
    min_id?,
    channel_id?,
    author_type?,
    author_id?,
    mentions?,
    mentions_role_id?,
    replied_to_user_id?,
    replied_to_message_id?,
    has?,
    embed_type?,
    embed_provider?,
    link_hostname?,
    attachment_filename?,
    attachment_extension?,
  )
  decode(self.request(SearchGuildMessages(guild_id~, query~)))
}
