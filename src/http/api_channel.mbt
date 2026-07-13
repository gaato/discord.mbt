///|
/// Fetch a channel by snowflake.
pub async fn Client::get_channel(
  self : Client,
  channel_id : @model.ChannelId,
) -> @model.Channel raise DiscordHttpError {
  decode(self.request(Route::GetChannel(channel_id~)))
}

///|
/// Modify common channel settings.
pub async fn Client::modify_channel(
  self : Client,
  channel_id : @model.ChannelId,
  name? : String,
  topic? : @model.Undefinable[String] = Missing,
  nsfw? : Bool,
  parent_id? : @model.Undefinable[@model.ChannelId] = Missing,
  rate_limit_per_user? : @model.Undefinable[Int] = Missing,
  position? : Int,
  audit_reason? : String,
) -> @model.Channel raise DiscordHttpError {
  if name is Some(value) && (value.length() < 1 || value.length() > 100) {
    raise DiscordHttpError::Validation(
      message="channel name must be between 1 and 100 characters",
    )
  }
  if topic is Value(value) && value.length() > 4096 {
    raise DiscordHttpError::Validation(
      message="channel topic exceeds 4096 characters",
    )
  }
  if rate_limit_per_user is Value(value) && (value < 0 || value > 21600) {
    raise DiscordHttpError::Validation(
      message="rate_limit_per_user must be between 0 and 21600",
    )
  }
  let body = @model.ObjBuilder::new()
    .opt("name", name)
    .und("topic", topic)
    .opt("nsfw", nsfw)
    .und("parent_id", parent_id)
    .und("rate_limit_per_user", rate_limit_per_user)
    .opt("position", position)
    .build()
  decode(self.request(Route::ModifyChannel(channel_id~), body~, audit_reason?))
}

///|
/// Delete or close a channel.
pub async fn Client::delete_channel(
  self : Client,
  channel_id : @model.ChannelId,
  audit_reason? : String,
) -> @model.Channel raise DiscordHttpError {
  decode(self.request(Route::DeleteChannel(channel_id~), audit_reason?))
}

///|
/// Trigger the typing indicator for a channel.
pub async fn Client::trigger_typing(
  self : Client,
  channel_id : @model.ChannelId,
) -> Unit raise DiscordHttpError {
  self.request(Route::TriggerTypingIndicator(channel_id~)) |> ignore
}

///|
/// Pin a message in a channel.
pub async fn Client::pin_message(
  self : Client,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
  audit_reason? : String,
) -> Unit raise DiscordHttpError {
  self.request(Route::PinMessage(channel_id~, message_id~), audit_reason?)
  |> ignore
}

///|
/// Remove a message pin from a channel.
pub async fn Client::unpin_message(
  self : Client,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
  audit_reason? : String,
) -> Unit raise DiscordHttpError {
  self.request(Route::UnpinMessage(channel_id~, message_id~), audit_reason?)
  |> ignore
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
  self.request(Route::CreateReaction(channel_id~, message_id~, emoji~))
  |> ignore
}

///|
/// Delete the bot user's reaction. The emoji must already be URL-encoded.
pub async fn Client::delete_own_reaction(
  self : Client,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
  emoji : String,
) -> Unit raise DiscordHttpError {
  self.request(Route::DeleteOwnReaction(channel_id~, message_id~, emoji~))
  |> ignore
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
  self.request(
    Route::DeleteUserReaction(channel_id~, message_id~, emoji~, user_id~),
  )
  |> ignore
}

///|
/// Delete every reaction from a message.
pub async fn Client::delete_all_reactions(
  self : Client,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
) -> Unit raise DiscordHttpError {
  self.request(Route::DeleteAllReactions(channel_id~, message_id~)) |> ignore
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
    raise DiscordHttpError::Validation(
      message="reaction limit must be 1 through 100",
    )
  }
  let params : Array[String] = []
  if limit is Some(value) {
    params.push("limit=\{value}")
  }
  if after is Some(value) {
    params.push("after=\{value}")
  }
  let query = if params.length() == 0 { "" } else { "?" + params.join("&") }
  decode(
    self.request(Route::GetReactions(channel_id~, message_id~, emoji~, query~)),
  )
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
    raise DiscordHttpError::Validation(
      message="thread name must be between 1 and 100 characters",
    )
  }
  if rate_limit_per_user is Some(value) && (value < 0 || value > 21600) {
    raise DiscordHttpError::Validation(
      message="rate_limit_per_user must be between 0 and 21600",
    )
  }
  let body = @model.ObjBuilder::new()
    .field("name", name)
    .opt("auto_archive_duration", auto_archive_duration)
    .opt("rate_limit_per_user", rate_limit_per_user)
    .build()
  decode(
    self.request(
      Route::StartThreadFromMessage(channel_id~, message_id~),
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
  self.request(Route::JoinThread(channel_id~)) |> ignore
}

///|
/// Remove the current user from a thread channel.
pub async fn Client::leave_thread(
  self : Client,
  channel_id : @model.ChannelId,
) -> Unit raise DiscordHttpError {
  self.request(Route::LeaveThread(channel_id~)) |> ignore
}
