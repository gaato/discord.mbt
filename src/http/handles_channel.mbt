///|
/// Fetch this channel.
pub async fn ChannelRef::fetch(
  self : ChannelRef,
) -> @model.Channel raise DiscordHttpError {
  self.client.get_channel(self.channel_id)
}

///|
/// Send a message to this channel.
pub async fn ChannelRef::send(
  self : ChannelRef,
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
  self.client.create_message(
    self.channel_id,
    content?,
    embeds?,
    components?,
    sticker_ids?,
    files?,
    reply_to?,
    tts?,
    flags?,
    allowed_mentions?,
    nonce?,
    enforce_nonce?,
  )
}

///|
/// Paginate messages in this channel.
pub fn ChannelRef::messages(
  self : ChannelRef,
  before? : @model.MessageId,
  after? : @model.MessageId,
  around? : @model.MessageId,
  page_size? : Int = 100,
) -> Paginator[@model.Message] raise DiscordHttpError {
  self.client.paginate_messages(
    self.channel_id,
    before?,
    after?,
    around?,
    page_size~,
  )
}

///|
/// Trigger the typing indicator in this channel.
pub async fn ChannelRef::typing(
  self : ChannelRef,
) -> Unit raise DiscordHttpError {
  self.client.trigger_typing(self.channel_id)
}

///|
/// Bind a message id in this channel to the client.
pub fn ChannelRef::message_ref(
  self : ChannelRef,
  message_id : @model.MessageId,
) -> MessageRef {
  { client: self.client, channel_id: self.channel_id, message_id }
}
