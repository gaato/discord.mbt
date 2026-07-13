///|
/// Post a message to a channel. Labeled optional arguments replace the
/// builder pattern; at least one of `content`, `embeds`, `components`, or
/// `sticker_ids` must be provided.
pub async fn Client::create_message(
  self : Client,
  channel_id : @model.ChannelId,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  sticker_ids? : Array[@model.StickerId],
  reply_to? : @model.MessageId,
  tts? : Bool,
  flags? : @model.MessageFlags,
  allowed_mentions? : Json,
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
    sticker_ids is None {
    raise DiscordHttpError::Validation(
      message="one of content/embeds/components/sticker_ids is required",
    )
  }
  let body = @model.ObjBuilder::new()
    .opt("content", content)
    .opt("embeds", embeds)
    .opt("components", components)
    .opt("sticker_ids", sticker_ids)
    .opt("tts", tts)
    .opt("flags", flags)
    .opt("allowed_mentions", allowed_mentions)
    .opt("nonce", nonce)
    .opt("enforce_nonce", enforce_nonce)
  if reply_to is Some(message_id) {
    body.field("message_reference", {
      "message_id": Json::string(message_id.to_string()),
    })
    |> ignore
  }
  decode(self.request(Route::CreateMessage(channel_id~), body=body.build()))
}

///|
/// Edit a previously sent message.
pub async fn Client::edit_message(
  self : Client,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
  content? : @model.Undefinable[String] = Missing,
  embeds? : @model.Undefinable[Array[@model.Embed]] = Missing,
  components? : @model.Undefinable[Array[@model.Component]] = Missing,
  flags? : @model.Undefinable[@model.MessageFlags] = Missing,
) -> @model.Message raise DiscordHttpError {
  let body = @model.ObjBuilder::new()
    .und("content", content)
    .und("embeds", embeds)
    .und("components", components)
    .und("flags", flags)
    .build()
  decode(self.request(Route::EditMessage(channel_id~, message_id~), body~))
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
