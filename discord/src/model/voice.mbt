///|
/// A user's connection state in a Discord voice channel.
pub(all) struct VoiceState {
  guild_id : GuildId?
  channel_id : Nullable[ChannelId]
  user_id : UserId
  guild_member : GuildMember?
  session_id : String
  deaf : Bool
  mute : Bool
  self_deaf : Bool
  self_mute : Bool
  self_stream : Bool?
  self_video : Bool?
  suppress : Bool
  request_to_speak_timestamp : Nullable[Timestamp]
} derive (
  ToJson(fields(guild_member(rename="member"))),
  FromJson(fields(guild_member(rename="member"))),
  Debug,
)

///|
/// A voice server region available to Discord clients.
pub(all) struct VoiceRegion {
  id : String
  name : String
  optimal : Bool
  deprecated : Bool
  custom : Bool
} derive(ToJson, FromJson, Debug)
