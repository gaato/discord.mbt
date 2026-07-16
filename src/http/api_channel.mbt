///|
/// Fetch a channel by snowflake.
pub async fn Client::get_channel(
  self : Client,
  channel_id : @model.ChannelId,
) -> @model.Channel raise DiscordHttpError {
  decode(self.request(GetChannel(channel_id~)))
}

///|
/// Modify common channel settings.
pub async fn Client::modify_channel(
  self : Client,
  channel_id : @model.ChannelId,
  name? : String,
  topic? : String,
  clear_topic? : Bool = false,
  nsfw? : Bool,
  parent_id? : @model.ChannelId,
  clear_parent_id? : Bool = false,
  rate_limit_per_user? : Int,
  position? : Int,
  audit_reason? : String,
) -> @model.Channel raise DiscordHttpError {
  if name is Some(value) && (value.length() < 1 || value.length() > 100) {
    raise Validation(
      message="channel name must be between 1 and 100 characters",
    )
  }
  if topic is Some(value) && value.length() > 4096 {
    raise Validation(message="channel topic exceeds 4096 characters")
  }
  if rate_limit_per_user is Some(value) && (value < 0 || value > 21600) {
    raise Validation(message="rate_limit_per_user must be between 0 and 21600")
  }
  let body = @model.ObjBuilder()
    .opt("name", name)
    .und("topic", patch_nullable("topic", topic, clear_topic))
    .opt("nsfw", nsfw)
    .und("parent_id", patch_nullable("parent_id", parent_id, clear_parent_id))
    .opt("rate_limit_per_user", rate_limit_per_user)
    .opt("position", position)
    .build()
  decode(self.request(ModifyChannel(channel_id~), body~, audit_reason?))
}

///|
/// Delete or close a channel.
pub async fn Client::delete_channel(
  self : Client,
  channel_id : @model.ChannelId,
  audit_reason? : String,
) -> @model.Channel raise DiscordHttpError {
  decode(self.request(DeleteChannel(channel_id~), audit_reason?))
}

///|
/// Trigger the typing indicator for a channel.
pub async fn Client::trigger_typing(
  self : Client,
  channel_id : @model.ChannelId,
) -> Unit raise DiscordHttpError {
  self.request(TriggerTypingIndicator(channel_id~)) |> ignore
}

///|
/// Pin a message in a channel.
pub async fn Client::pin_message(
  self : Client,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
  audit_reason? : String,
) -> Unit raise DiscordHttpError {
  self.request(PinMessage(channel_id~, message_id~), audit_reason?) |> ignore
}

///|
/// Remove a message pin from a channel.
pub async fn Client::unpin_message(
  self : Client,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
  audit_reason? : String,
) -> Unit raise DiscordHttpError {
  self.request(UnpinMessage(channel_id~, message_id~), audit_reason?) |> ignore
}

///|
/// List every pinned message in a channel.
pub async fn Client::get_pinned_messages(
  self : Client,
  channel_id : @model.ChannelId,
) -> Array[@model.Message] raise DiscordHttpError {
  decode(self.request(GetPinnedMessages(channel_id~)))
}

///|
/// Create or replace a channel permission overwrite.
pub async fn Client::edit_channel_permissions(
  self : Client,
  channel_id : @model.ChannelId,
  overwrite_id : @model.GenericId,
  allow : @model.Permissions,
  deny : @model.Permissions,
  typ : Int,
  audit_reason? : String,
) -> Unit raise DiscordHttpError {
  let body = @model.ObjBuilder()
    .field("allow", allow)
    .field("deny", deny)
    .field("type", typ)
    .build()
  self.request(
    EditChannelPermissions(channel_id~, overwrite_id~),
    body~,
    audit_reason?,
  )
  |> ignore
}

///|
/// Delete a channel permission overwrite.
pub async fn Client::delete_channel_permission(
  self : Client,
  channel_id : @model.ChannelId,
  overwrite_id : @model.GenericId,
  audit_reason? : String,
) -> Unit raise DiscordHttpError {
  self.request(
    DeleteChannelPermission(channel_id~, overwrite_id~),
    audit_reason?,
  )
  |> ignore
}

///|
/// List invites created for a channel.
pub async fn Client::get_channel_invites(
  self : Client,
  channel_id : @model.ChannelId,
) -> Array[@model.Invite] raise DiscordHttpError {
  decode(self.request(GetChannelInvites(channel_id~)))
}

///|
/// Create an invite for a channel.
pub async fn Client::create_channel_invite(
  self : Client,
  channel_id : @model.ChannelId,
  max_age? : Int,
  max_uses? : Int,
  temporary? : Bool,
  unique? : Bool,
  audit_reason? : String,
) -> @model.Invite raise DiscordHttpError {
  let body = @model.ObjBuilder()
    .opt("max_age", max_age)
    .opt("max_uses", max_uses)
    .opt("temporary", temporary)
    .opt("unique", unique)
    .build()
  decode(self.request(CreateChannelInvite(channel_id~), body~, audit_reason?))
}

///|
/// Add a reaction. The emoji must already be URL-encoded; for custom emoji,
/// callers should pass forms such as name%3A123456789012345678.
pub async fn Client::create_reaction(
  self : Client,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
  emoji : String,
) -> Unit raise DiscordHttpError {
  self.request(CreateReaction(channel_id~, message_id~, emoji~)) |> ignore
}

///|
/// Delete the bot user's reaction. The emoji must already be URL-encoded.
pub async fn Client::delete_own_reaction(
  self : Client,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
  emoji : String,
) -> Unit raise DiscordHttpError {
  self.request(DeleteOwnReaction(channel_id~, message_id~, emoji~)) |> ignore
}

///|
/// Delete another user's reaction. The emoji must already be URL-encoded.
pub async fn Client::delete_user_reaction(
  self : Client,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
  emoji : String,
  user_id : @model.UserId,
) -> Unit raise DiscordHttpError {
  self.request(DeleteUserReaction(channel_id~, message_id~, emoji~, user_id~))
  |> ignore
}

///|
/// Delete every reaction from a message.
pub async fn Client::delete_all_reactions(
  self : Client,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
) -> Unit raise DiscordHttpError {
  self.request(DeleteAllReactions(channel_id~, message_id~)) |> ignore
}

///|
/// List users who reacted with a pre-encoded emoji.
pub async fn Client::get_reactions(
  self : Client,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
  emoji : String,
  limit? : Int,
  after? : @model.UserId,
) -> Array[@model.User] raise DiscordHttpError {
  if limit is Some(value) && (value < 1 || value > 100) {
    raise Validation(message="reaction limit must be 1 through 100")
  }
  let params : Array[String] = []
  if limit is Some(value) {
    params.push("limit=\{value}")
  }
  if after is Some(value) {
    params.push("after=\{value}")
  }
  let query = if params.length() == 0 { "" } else { "?" + params.join("&") }
  decode(self.request(GetReactions(channel_id~, message_id~, emoji~, query~)))
}

///|
/// Start a thread whose initial message is an existing channel message.
pub async fn Client::start_thread_from_message(
  self : Client,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
  name : String,
  auto_archive_duration? : @model.ThreadAutoArchiveDuration,
  rate_limit_per_user? : Int,
  audit_reason? : String,
) -> @model.Channel raise DiscordHttpError {
  if name.length() < 1 || name.length() > 100 {
    raise Validation(message="thread name must be between 1 and 100 characters")
  }
  if rate_limit_per_user is Some(value) && (value < 0 || value > 21600) {
    raise Validation(message="rate_limit_per_user must be between 0 and 21600")
  }
  let body = @model.ObjBuilder()
    .field("name", name)
    .opt("auto_archive_duration", auto_archive_duration)
    .opt("rate_limit_per_user", rate_limit_per_user)
    .build()
  decode(
    self.request(
      StartThreadFromMessage(channel_id~, message_id~),
      body~,
      audit_reason?,
    ),
  )
}

///|
/// Join the current user to a thread channel.
pub async fn Client::join_thread(
  self : Client,
  channel_id : @model.ChannelId,
) -> Unit raise DiscordHttpError {
  self.request(JoinThread(channel_id~)) |> ignore
}

///|
/// Remove the current user from a thread channel.
pub async fn Client::leave_thread(
  self : Client,
  channel_id : @model.ChannelId,
) -> Unit raise DiscordHttpError {
  self.request(LeaveThread(channel_id~)) |> ignore
}

///|
fn thread_members_query(
  with_member : Bool?,
  after : @model.UserId?,
  limit : Int?,
) -> String {
  let params : Array[String] = []
  if with_member is Some(value) {
    params.push("with_member=\{value}")
  }
  if after is Some(value) {
    params.push("after=\{value}")
  }
  if limit is Some(value) {
    params.push("limit=\{value}")
  }
  if params.length() == 0 {
    ""
  } else {
    "?" + params.join("&")
  }
}

///|
fn archived_threads_query(before : String?, limit : Int?) -> String {
  let params : Array[String] = []
  if before is Some(value) {
    // ISO8601 offsets contain `+`, which decodes to a space in query strings.
    params.push("before=" + value.replace(old="+", new="%2B"))
  }
  if limit is Some(value) {
    params.push("limit=\{value}")
  }
  if params.length() == 0 {
    ""
  } else {
    "?" + params.join("&")
  }
}

///|
/// List members of a thread channel.
pub async fn Client::list_thread_members(
  self : Client,
  channel_id : @model.ChannelId,
  with_member? : Bool,
  after? : @model.UserId,
  limit? : Int,
) -> Array[@model.ThreadMember] raise DiscordHttpError {
  if limit is Some(value) && (value < 1 || value > 100) {
    raise Validation(message="thread member limit must be 1 through 100")
  }
  let query = thread_members_query(with_member, after, limit)
  decode(self.request(ListThreadMembers(channel_id~, query~)))
}

///|
/// Fetch a user's membership record for a thread channel.
pub async fn Client::get_thread_member(
  self : Client,
  channel_id : @model.ChannelId,
  user_id : @model.UserId,
  with_member? : Bool,
) -> @model.ThreadMember raise DiscordHttpError {
  let query = thread_members_query(with_member, None, None)
  decode(self.request(GetThreadMember(channel_id~, user_id~, query~)))
}

///|
/// Add a user to a thread channel.
pub async fn Client::add_thread_member(
  self : Client,
  channel_id : @model.ChannelId,
  user_id : @model.UserId,
) -> Unit raise DiscordHttpError {
  self.request(AddThreadMember(channel_id~, user_id~)) |> ignore
}

///|
/// Remove a user from a thread channel.
pub async fn Client::remove_thread_member(
  self : Client,
  channel_id : @model.ChannelId,
  user_id : @model.UserId,
) -> Unit raise DiscordHttpError {
  self.request(RemoveThreadMember(channel_id~, user_id~)) |> ignore
}

///|
/// List public archived threads in a channel.
pub async fn Client::list_public_archived_threads(
  self : Client,
  channel_id : @model.ChannelId,
  before? : @model.Timestamp,
  limit? : Int,
) -> @model.ArchivedThreads raise DiscordHttpError {
  let before_string = match before {
    Some(value) => Some(value.to_string())
    None => None
  }
  let query = archived_threads_query(before_string, limit)
  decode(self.request(ListPublicArchivedThreads(channel_id~, query~)))
}

///|
/// List private archived threads in a channel.
pub async fn Client::list_private_archived_threads(
  self : Client,
  channel_id : @model.ChannelId,
  before? : @model.Timestamp,
  limit? : Int,
) -> @model.ArchivedThreads raise DiscordHttpError {
  let before_string = match before {
    Some(value) => Some(value.to_string())
    None => None
  }
  let query = archived_threads_query(before_string, limit)
  decode(self.request(ListPrivateArchivedThreads(channel_id~, query~)))
}

///|
/// List private archived threads joined by the current user.
pub async fn Client::list_joined_private_archived_threads(
  self : Client,
  channel_id : @model.ChannelId,
  before? : @model.ChannelId,
  limit? : Int,
) -> @model.ArchivedThreads raise DiscordHttpError {
  let before_string = match before {
    Some(value) => Some(value.to_string())
    None => None
  }
  let query = archived_threads_query(before_string, limit)
  decode(self.request(ListJoinedPrivateArchivedThreads(channel_id~, query~)))
}

///|
/// List every active thread in a guild.
pub async fn Client::list_active_guild_threads(
  self : Client,
  guild_id : @model.GuildId,
) -> @model.ActiveGuildThreads raise DiscordHttpError {
  decode(self.request(ListActiveGuildThreads(guild_id~)))
}
