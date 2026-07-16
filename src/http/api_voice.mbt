///|
/// List the voice regions available to Discord.
///
/// https://discord.com/developers/docs/resources/voice#list-voice-regions
pub async fn Client::list_voice_regions(
  self : Client,
) -> Array[@model.VoiceRegion] raise DiscordHttpError {
  decode(self.request(ListVoiceRegions))
}

///|
/// Fetch the current user's voice state in a guild.
///
/// https://discord.com/developers/docs/resources/voice#get-current-user-voice-state
pub async fn Client::get_current_user_voice_state(
  self : Client,
  guild_id : @model.GuildId,
) -> @model.VoiceState raise DiscordHttpError {
  decode(self.request(GetCurrentUserVoiceState(guild_id~)))
}

///|
/// Fetch a user's voice state in a guild.
///
/// https://discord.com/developers/docs/resources/voice#get-user-voice-state
pub async fn Client::get_user_voice_state(
  self : Client,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
) -> @model.VoiceState raise DiscordHttpError {
  decode(self.request(GetUserVoiceState(guild_id~, user_id~)))
}

///|
fn modify_current_user_voice_state_body(
  channel_id : @model.ChannelId?,
  suppress : Bool?,
  request_to_speak_timestamp : @model.Timestamp?,
  clear_request_to_speak_timestamp : Bool,
) -> Json raise DiscordHttpError {
  @model.ObjBuilder()
  .opt("channel_id", channel_id)
  .opt("suppress", suppress)
  .und(
    "request_to_speak_timestamp",
    patch_nullable(
      "request_to_speak_timestamp", request_to_speak_timestamp, clear_request_to_speak_timestamp,
    ),
  )
  .build()
}

///|
/// Modify the current user's voice state in a guild. Use
/// `clear_request_to_speak_timestamp=true` to send JSON null rather than omit
/// the timestamp.
///
/// https://discord.com/developers/docs/resources/voice#modify-current-user-voice-state
pub async fn Client::modify_current_user_voice_state(
  self : Client,
  guild_id : @model.GuildId,
  channel_id? : @model.ChannelId,
  suppress? : Bool,
  request_to_speak_timestamp? : @model.Timestamp,
  clear_request_to_speak_timestamp? : Bool = false,
) -> Unit raise DiscordHttpError {
  let body = modify_current_user_voice_state_body(
    channel_id, suppress, request_to_speak_timestamp, clear_request_to_speak_timestamp,
  )
  self.request(ModifyCurrentUserVoiceState(guild_id~), body~) |> ignore
}

///|
fn modify_user_voice_state_body(
  channel_id : @model.ChannelId,
  suppress : Bool?,
) -> Json {
  @model.ObjBuilder()
  .field("channel_id", channel_id)
  .opt("suppress", suppress)
  .build()
}

///|
/// Modify a user's voice state in a guild.
///
/// https://discord.com/developers/docs/resources/voice#modify-user-voice-state
pub async fn Client::modify_user_voice_state(
  self : Client,
  guild_id : @model.GuildId,
  user_id : @model.UserId,
  channel_id : @model.ChannelId,
  suppress? : Bool,
) -> Unit raise DiscordHttpError {
  let body = modify_user_voice_state_body(channel_id, suppress)
  self.request(ModifyUserVoiceState(guild_id~, user_id~), body~) |> ignore
}
