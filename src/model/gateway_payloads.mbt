///|
/// Gateway opcodes (send and receive).
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
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn GatewayOpcode::to_int(self : GatewayOpcode) -> Int {
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
    Unknown(v) => v
  }
}

///|
pub fn GatewayOpcode::from_int(value : Int) -> GatewayOpcode {
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
    v => Unknown(v)
  }
}

///|
/// Payload of opcode 10 (Hello).
pub(all) struct Hello {
  heartbeat_interval : Int
} derive(ToJson, FromJson, Debug)

///|
/// Partial application object included in READY.
pub(all) struct ReadyApplication {
  id : ApplicationId
  flags : ApplicationFlags?
} derive(ToJson, FromJson, Debug)

///|
/// Payload of the READY dispatch.
pub(all) struct Ready {
  v : Int
  user : User
  guilds : Array[UnavailableGuild]
  session_id : String
  resume_gateway_url : String
  shard : Array[Int]?
  application : ReadyApplication
} derive(ToJson, FromJson, Debug)
