///|
/// Gateway opcodes (send and receive).
#non_exhaustive
pub(all) enum GatewayOpcode {
  Dispatch
  Heartbeat
  Identify
  PresenceUpdate
  VoiceStateUpdate
  Resume
  Reconnect
  RequestGuildMembers
  InvalidSession
  Hello
  HeartbeatAck
  RequestSoundboardSounds
  RequestChannelInfo
  Unknown(Int32)
} derive(Eq, Debug)

///|
pub fn GatewayOpcode::to_int(self : GatewayOpcode) -> Int32 {
  match self {
    Dispatch => 0
    Heartbeat => 1
    Identify => 2
    PresenceUpdate => 3
    VoiceStateUpdate => 4
    Resume => 6
    Reconnect => 7
    RequestGuildMembers => 8
    InvalidSession => 9
    Hello => 10
    HeartbeatAck => 11
    RequestSoundboardSounds => 31
    RequestChannelInfo => 43
    Unknown(v) => v
  }
}

///|
pub fn GatewayOpcode::from_int(value : Int32) -> GatewayOpcode {
  match value {
    0 => Dispatch
    1 => Heartbeat
    2 => Identify
    3 => PresenceUpdate
    4 => VoiceStateUpdate
    6 => Resume
    7 => Reconnect
    8 => RequestGuildMembers
    9 => InvalidSession
    10 => Hello
    11 => HeartbeatAck
    31 => RequestSoundboardSounds
    43 => RequestChannelInfo
    v => Unknown(v)
  }
}

///|
/// Payload of opcode 10 (Hello).
pub(all) struct Hello {
  heartbeat_interval : Int32
} derive(ToJson, FromJson, Debug)

///|
/// Partial application object included in READY.
pub(all) struct ReadyApplication {
  id : ApplicationId
  flags : ApplicationFlags?
  flags_new : ApplicationFlags?
} derive(ToJson, FromJson, Debug)

///|
/// Payload of the READY dispatch.
pub(all) struct Ready {
  v : Int32
  user : User
  guilds : Array[UnavailableGuild]
  session_id : String
  resume_gateway_url : String
  shard : Array[Int32]?
  application : ReadyApplication
} derive(ToJson, FromJson, Debug)

///|
/// Payload of opcode 4 (Update Voice State): join or move to `channel_id`
/// in `guild_id`, or leave the guild's voice channel with `channel_id = None`.
pub(all) struct UpdateVoiceState {
  guild_id : GuildId
  channel_id : ChannelId?
  self_mute : Bool
  self_deaf : Bool
} derive(Eq, Debug)

///|
/// Leaving is an explicit `"channel_id": null`, so a missing channel is
/// written as null rather than omitted.
pub impl ToJson for UpdateVoiceState with fn to_json(self) {
  let channel : Json = match self.channel_id {
    Some(id) => id.to_json()
    None => Json::null()
  }
  {
    "guild_id": self.guild_id.to_json(),
    "channel_id": channel,
    "self_mute": Json::boolean(self.self_mute),
    "self_deaf": Json::boolean(self.self_deaf),
  }
}
