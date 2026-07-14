///|
/// A channel id bound to the REST client that operates on it.
pub struct ChannelRef {
  priv client : Client
  priv channel_id : @model.ChannelId
}

///|
/// A message id and its channel id bound to the REST client that operates on
/// it.
pub struct MessageRef {
  priv client : Client
  priv channel_id : @model.ChannelId
  priv message_id : @model.MessageId
}

///|
/// A guild member identity bound to the REST client that operates on it.
pub struct MemberRef {
  priv client : Client
  priv guild_id : @model.GuildId
  priv user_id : @model.UserId
}

///|
/// A user id bound to the REST client that operates on it.
pub struct UserRef {
  priv client : Client
  priv user_id : @model.UserId
}

///|
/// Bind a channel id to this client.
pub fn Client::channel_ref(
  self : Client,
  channel_id : @model.ChannelId,
) -> ChannelRef {
  { client: self, channel_id }
}

///|
/// Bind a channel/message id pair to this client.
pub fn Client::message_ref(
  self : Client,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
) -> MessageRef {
  { client: self, channel_id, message_id }
}

///|
/// Bind a guild/user id pair to this client.
pub fn Client::member_ref(
  self : Client,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
) -> MemberRef {
  { client: self, guild_id, user_id }
}

///|
/// Bind a user id to this client.
pub fn Client::user_ref(self : Client, user_id : @model.UserId) -> UserRef {
  { client: self, user_id }
}

///|
/// Derive a client-bound message handle from a message model.
pub fn Client::ref_of_message(
  self : Client,
  message : @model.Message,
) -> MessageRef {
  self.message_ref(message.channel_id, message.id)
}

///|
/// Send a message to this channel.
pub async fn ChannelRef::send(
  self : ChannelRef,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  allowed_mentions? : @model.AllowedMentions,
  files? : Array[FileUpload],
  reply_to? : @model.MessageId,
) -> @model.Message raise DiscordHttpError {
  self.client.create_message(
    self.channel_id,
    content?,
    embeds?,
    components?,
    allowed_mentions?,
    files?,
    reply_to?,
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
/// Reply to this message.
pub async fn MessageRef::reply(
  self : MessageRef,
  content? : String,
  embeds? : Array[@model.Embed],
  components? : Array[@model.Component],
  allowed_mentions? : @model.AllowedMentions,
  files? : Array[FileUpload],
) -> @model.Message raise DiscordHttpError {
  self.client.create_message(
    self.channel_id,
    content?,
    embeds?,
    components?,
    allowed_mentions?,
    files?,
    reply_to=self.message_id,
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
) -> Unit raise DiscordHttpError {
  self.client.delete_message(self.channel_id, self.message_id)
}

///|
/// Pin this message.
pub async fn MessageRef::pin(self : MessageRef) -> Unit raise DiscordHttpError {
  self.client.pin_message(self.channel_id, self.message_id)
}

///|
/// Remove this message's pin.
pub async fn MessageRef::unpin(
  self : MessageRef,
) -> Unit raise DiscordHttpError {
  self.client.unpin_message(self.channel_id, self.message_id)
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

///|
/// Ban this member from the guild.
pub async fn MemberRef::ban(
  self : MemberRef,
  delete_message_seconds? : Int,
  reason? : String,
) -> Unit raise DiscordHttpError {
  self.client.create_guild_ban(
    self.guild_id,
    self.user_id,
    delete_message_seconds?,
    audit_reason?=reason,
  )
}

///|
/// Remove this member from the guild.
pub async fn MemberRef::kick(
  self : MemberRef,
  reason? : String,
) -> Unit raise DiscordHttpError {
  self.client.remove_guild_member(
    self.guild_id,
    self.user_id,
    audit_reason?=reason,
  )
}

///|
/// Add a role to this member.
pub async fn MemberRef::add_role(
  self : MemberRef,
  role_id : @model.RoleId,
  reason? : String,
) -> Unit raise DiscordHttpError {
  self.client.add_member_role(
    self.guild_id,
    self.user_id,
    role_id,
    audit_reason?=reason,
  )
}

///|
/// Remove a role from this member.
pub async fn MemberRef::remove_role(
  self : MemberRef,
  role_id : @model.RoleId,
  reason? : String,
) -> Unit raise DiscordHttpError {
  self.client.remove_member_role(
    self.guild_id,
    self.user_id,
    role_id,
    audit_reason?=reason,
  )
}

///|
/// Set this member's communication timeout, or clear it when `until` is
/// `None`.
pub async fn MemberRef::timeout(
  self : MemberRef,
  until : @model.Timestamp?,
  reason? : String,
) -> @model.GuildMember raise DiscordHttpError {
  self.client.modify_guild_member(
    self.guild_id,
    self.user_id,
    communication_disabled_until?=until,
    clear_communication_disabled_until=until is None,
    audit_reason?=reason,
  )
}

///|
/// Open or reuse a DM channel with this user and bind it to the client.
pub async fn UserRef::dm(self : UserRef) -> ChannelRef raise DiscordHttpError {
  let channel = self.client.create_dm(self.user_id)
  self.client.channel_ref(channel.id)
}
