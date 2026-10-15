///|
test "voice state decodes a full fixture" {
  let fixture =
    #|{
    #|  "guild_id": "81384788765712384",
    #|  "channel_id": "41771983423143937",
    #|  "user_id": "80351110224678912",
    #|  "member": {
    #|    "nick": "Nelly", "roles": [], "joined_at": null,
    #|    "deaf": false, "mute": false, "flags": 0
    #|  },
    #|  "session_id": "my-session",
    #|  "deaf": false, "mute": true,
    #|  "self_deaf": false, "self_mute": true,
    #|  "self_stream": true, "self_video": false,
    #|  "suppress": false,
    #|  "request_to_speak_timestamp": "2024-01-02T03:04:05.000000+00:00",
    #|  "brand_new_field_from_discord": true
    #|}
  let voice_state : @model.VoiceState = @json.from_json(@json.parse(fixture))
  debug_inspect(
    voice_state,
    content=(
      #|{
      #|  guild_id: Some(81384788765712384),
      #|  channel_id: Value(41771983423143937),
      #|  user_id: 80351110224678912,
      #|  guild_member: Some(
      #|    {
      #|      user: None,
      #|      nick: Some(Value("Nelly")),
      #|      avatar: None,
      #|      banner: None,
      #|      roles: [],
      #|      joined_at: Null,
      #|      premium_since: None,
      #|      deaf: Some(false),
      #|      mute: Some(false),
      #|      flags: Some(0),
      #|      pending: None,
      #|      permissions: None,
      #|      communication_disabled_until: None,
      #|      avatar_decoration_data: None,
      #|      collectibles: None,
      #|    },
      #|  ),
      #|  session_id: "my-session",
      #|  deaf: false,
      #|  mute: true,
      #|  self_deaf: false,
      #|  self_mute: true,
      #|  self_stream: Some(true),
      #|  self_video: Some(false),
      #|  suppress: false,
      #|  request_to_speak_timestamp: Value("2024-01-02T03:04:05.000000+00:00"),
      #|}
    ),
  )
}

///|
test "voice state decodes required fields only" {
  let fixture =
    #|{
    #|  "channel_id": null, "user_id": "1", "session_id": "session",
    #|  "deaf": false, "mute": false, "self_deaf": false,
    #|  "self_mute": false, "self_video": false, "suppress": false,
    #|  "request_to_speak_timestamp": null
    #|}
  let voice_state : @model.VoiceState = @json.from_json(@json.parse(fixture))
  debug_inspect(
    voice_state,
    content=(
      #|{
      #|  guild_id: None,
      #|  channel_id: Null,
      #|  user_id: 1,
      #|  guild_member: None,
      #|  session_id: "session",
      #|  deaf: false,
      #|  mute: false,
      #|  self_deaf: false,
      #|  self_mute: false,
      #|  self_stream: None,
      #|  self_video: Some(false),
      #|  suppress: false,
      #|  request_to_speak_timestamp: Null,
      #|}
    ),
  )
}

///|
test "voice state encode omits absent optional fields" {
  let voice_state = @model.VoiceState::{
    guild_id: None,
    channel_id: Null,
    user_id: Id(1UL),
    guild_member: None,
    session_id: "session",
    deaf: false,
    mute: false,
    self_deaf: false,
    self_mute: false,
    self_stream: None,
    self_video: Some(false),
    suppress: false,
    request_to_speak_timestamp: Null,
  }
  inspect(
    voice_state.to_json().stringify(),
    content=(
      #|{"channel_id":null,"user_id":"1","session_id":"session","deaf":false,"mute":false,"self_deaf":false,"self_mute":false,"self_video":false,"suppress":false,"request_to_speak_timestamp":null}
    ),
  )
}

///|
test "voice region round-trips" {
  let fixture =
    #|{"id":"us-west","name":"US West","optimal":true,"deprecated":false,"custom":false,"future":1}
  let region : @model.VoiceRegion = @json.from_json(@json.parse(fixture))
  inspect(
    region.to_json().stringify(),
    content=(
      #|{"id":"us-west","name":"US West","optimal":true,"deprecated":false,"custom":false}
    ),
  )
}
