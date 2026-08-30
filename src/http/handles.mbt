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
  { client: self, channel_id, }
}

///|
/// Bind a channel/message id pair to this client.
pub fn Client::message_ref(
  self : Client,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
) -> MessageRef {
  { client: self, channel_id, message_id, }
}

///|
/// Bind a guild/user id pair to this client.
pub fn Client::member_ref(
  self : Client,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
) -> MemberRef {
  { client: self, guild_id, user_id, }
}

///|
/// Bind a user id to this client.
pub fn Client::user_ref(self : Client, user_id : @model.UserId) -> UserRef {
  { client: self, user_id, }
}

///|
/// Derive a client-bound message handle from a message model.
pub fn Client::ref_of_message(
  self : Client,
  message : @model.Message,
) -> MessageRef {
  self.message_ref(message.channel_id, message.id)
}
