///|
/// List users who voted for one poll answer.
pub async fn Client::get_poll_answer_voters(
  self : Client,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
  answer_id : Int,
  after? : @model.UserId,
  limit? : Int,
) -> @model.PollAnswerVoters raise DiscordHttpError {
  if limit is Some(value) && (value < 1 || value > 100) {
    raise DiscordHttpError::Validation(
      message="poll voter limit must be 1 through 100",
    )
  }
  let params : Array[String] = []
  if after is Some(value) {
    params.push("after=\{value}")
  }
  if limit is Some(value) {
    params.push("limit=\{value}")
  }
  let query = if params.length() == 0 { "" } else { "?" + params.join("&") }
  decode(
    self.request(
      Route::GetPollAnswerVoters(channel_id~, message_id~, answer_id~, query~),
    ),
  )
}

///|
/// Immediately expire a poll and return the updated message.
pub async fn Client::expire_poll(
  self : Client,
  channel_id : @model.ChannelId,
  message_id : @model.MessageId,
) -> @model.Message raise DiscordHttpError {
  decode(self.request(Route::ExpirePoll(channel_id~, message_id~)))
}
