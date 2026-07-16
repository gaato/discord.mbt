///|
/// Fetch this message.
pub async fn MessageRef::fetch(
  self : MessageRef,
) -> @model.Message raise DiscordHttpError {
  self.client.get_message(self.channel_id, self.message_id)
}

///|
/// Reply to this message.
pub async fn MessageRef::reply(
  self : MessageRef,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  sticker_ids? : Array[@model.StickerId],
  files? : Array[FileUpload],
  tts? : Bool,
  flags? : @model.MessageFlags,
  allowed_mentions? : @model.AllowedMentions,
  nonce? : @model.Nonce,
  enforce_nonce? : Bool,
) -> @model.Message raise DiscordHttpError {
  self.client.create_message(
    self.channel_id,
    content?,
    embeds?,
    components?,
    sticker_ids?,
    files?,
    reply_to=self.message_id,
    tts?,
    flags?,
    allowed_mentions?,
    nonce?,
    enforce_nonce?,
  )
}

///|
/// Edit this message.
pub async fn MessageRef::edit(
  self : MessageRef,
  content? : String,
  clear_content? : Bool = false,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  flags? : @model.MessageFlags,
  allowed_mentions? : @model.AllowedMentions,
  files? : Array[FileUpload],
) -> @model.Message raise DiscordHttpError {
  self.client.edit_message(
    self.channel_id,
    self.message_id,
    content?,
    clear_content~,
    embeds?,
    components?,
    flags?,
    allowed_mentions?,
    files?,
  )
}

///|
/// Delete this message.
pub async fn MessageRef::delete(
  self : MessageRef,
  reason? : String,
) -> Unit raise DiscordHttpError {
  self.client.delete_message(
    self.channel_id,
    self.message_id,
    audit_reason?=reason,
  )
}

///|
/// Pin this message.
pub async fn MessageRef::pin(
  self : MessageRef,
  reason? : String,
) -> Unit raise DiscordHttpError {
  self.client.pin_message(
    self.channel_id,
    self.message_id,
    audit_reason?=reason,
  )
}

///|
/// Remove this message's pin.
pub async fn MessageRef::unpin(
  self : MessageRef,
  reason? : String,
) -> Unit raise DiscordHttpError {
  self.client.unpin_message(
    self.channel_id,
    self.message_id,
    audit_reason?=reason,
  )
}

///|
/// Add a reaction. `emoji` follows the underlying REST wrapper and must
/// already be URL-encoded.
pub async fn MessageRef::react(
  self : MessageRef,
  emoji : String,
) -> Unit raise DiscordHttpError {
  self.client.create_reaction(self.channel_id, self.message_id, emoji)
}

///|
/// Delete every reaction from this message.
pub async fn MessageRef::delete_reactions(
  self : MessageRef,
) -> Unit raise DiscordHttpError {
  self.client.delete_all_reactions(self.channel_id, self.message_id)
}
