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
/// Add the current user's reaction. `emoji` must already be URL-encoded.
pub async fn MessageRef::react(
  self : MessageRef,
  emoji : String,
) -> Unit raise DiscordHttpError {
  self.client.create_reaction(self.channel_id, self.message_id, emoji)
}

///|
/// Delete every reaction from this message, regardless of emoji or user.
pub async fn MessageRef::delete_reactions(
  self : MessageRef,
) -> Unit raise DiscordHttpError {
  self.client.delete_all_reactions(self.channel_id, self.message_id)
}

///|
/// Crosspost this message from an announcement channel to its followers.
pub async fn MessageRef::crosspost(
  self : MessageRef,
) -> @model.Message raise DiscordHttpError {
  self.client.crosspost_message(self.channel_id, self.message_id)
}

///|
/// Delete the current user's reaction. `emoji` must already be URL-encoded.
pub async fn MessageRef::unreact(
  self : MessageRef,
  emoji : String,
) -> Unit raise DiscordHttpError {
  self.client.delete_own_reaction(self.channel_id, self.message_id, emoji)
}

///|
/// Delete a specific user's reaction. `emoji` must already be URL-encoded.
pub async fn MessageRef::delete_user_reaction(
  self : MessageRef,
  emoji : String,
  user_id : @model.UserId,
) -> Unit raise DiscordHttpError {
  self.client.delete_user_reaction(
    self.channel_id,
    self.message_id,
    emoji,
    user_id,
  )
}

///|
/// Delete every reaction for one emoji. `emoji` must already be URL-encoded.
pub async fn MessageRef::delete_reactions_for(
  self : MessageRef,
  emoji : String,
) -> Unit raise DiscordHttpError {
  self.client.delete_all_reactions_for_emoji(
    self.channel_id,
    self.message_id,
    emoji,
  )
}

///|
/// List users who reacted with `emoji`, which must already be URL-encoded.
pub async fn MessageRef::reactions(
  self : MessageRef,
  emoji : String,
  limit? : Int,
  after? : @model.UserId,
) -> Array[@model.User] raise DiscordHttpError {
  self.client.get_reactions(
    self.channel_id,
    self.message_id,
    emoji,
    limit?,
    after?,
  )
}

///|
/// Start a thread from this message.
pub async fn MessageRef::start_thread(
  self : MessageRef,
  name : String,
  auto_archive_duration? : @model.ThreadAutoArchiveDuration,
  rate_limit_per_user? : Int,
  reason? : String,
) -> @model.Channel raise DiscordHttpError {
  self.client.start_thread_from_message(
    self.channel_id,
    self.message_id,
    name,
    auto_archive_duration?,
    rate_limit_per_user?,
    audit_reason?=reason,
  )
}

///|
/// Immediately expire this message's poll.
pub async fn MessageRef::expire_poll(
  self : MessageRef,
) -> @model.Message raise DiscordHttpError {
  self.client.expire_poll(self.channel_id, self.message_id)
}

///|
/// Paginate users who selected one answer in this message's poll.
pub fn MessageRef::poll_answer_voters(
  self : MessageRef,
  answer_id : Int,
  after? : @model.UserId,
  page_size? : Int = 100,
) -> Paginator[@model.User] raise DiscordHttpError {
  self.client.paginate_poll_answer_voters(
    self.channel_id,
    self.message_id,
    answer_id,
    after?,
    page_size~,
  )
}
