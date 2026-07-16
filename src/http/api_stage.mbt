///|
fn validate_stage_topic(topic : String?) -> Unit raise DiscordHttpError {
  validate_length("stage topic", topic, min=1, max=120)
}

///|
/// Create a stage instance for a stage channel.
pub async fn Client::create_stage_instance(
  self : Client,
  channel_id : @model.ChannelId,
  topic : String,
  privacy_level? : @model.StagePrivacyLevel,
  send_start_notification? : Bool,
  guild_scheduled_event_id? : @model.ScheduledEventId,
  audit_reason? : String,
) -> @model.StageInstance raise DiscordHttpError {
  validate_stage_topic(Some(topic))
  let body = @model.ObjBuilder()
    .field("channel_id", channel_id)
    .field("topic", topic)
    .opt("privacy_level", privacy_level)
    .opt("send_start_notification", send_start_notification)
    .opt("guild_scheduled_event_id", guild_scheduled_event_id)
    .build()
  decode(self.request(CreateStageInstance, body~, audit_reason?))
}

///|
/// Fetch the stage instance associated with a channel.
pub async fn Client::get_stage_instance(
  self : Client,
  channel_id : @model.ChannelId,
) -> @model.StageInstance raise DiscordHttpError {
  decode(self.request(GetStageInstance(channel_id~)))
}

///|
/// Modify a stage instance.
pub async fn Client::modify_stage_instance(
  self : Client,
  channel_id : @model.ChannelId,
  topic? : String,
  privacy_level? : @model.StagePrivacyLevel,
  audit_reason? : String,
) -> @model.StageInstance raise DiscordHttpError {
  validate_stage_topic(topic)
  let body = @model.ObjBuilder()
    .opt("topic", topic)
    .opt("privacy_level", privacy_level)
    .build()
  decode(self.request(ModifyStageInstance(channel_id~), body~, audit_reason?))
}

///|
/// Delete a stage instance.
pub async fn Client::delete_stage_instance(
  self : Client,
  channel_id : @model.ChannelId,
  audit_reason? : String,
) -> Unit raise DiscordHttpError {
  self.request(DeleteStageInstance(channel_id~), audit_reason?) |> ignore
}
