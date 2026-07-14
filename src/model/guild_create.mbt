///|
/// The complete guild and gateway-only collections sent when it becomes
/// available to the client.
pub(all) struct AvailableGuildCreateEvent {
  guild : Guild
  joined_at : Timestamp
  large : Bool
  unavailable : Bool?
  member_count : Int
  voice_states : Array[VoiceState]
  members : Array[GuildMember]
  channels : Array[Channel]
  threads : Array[Channel]
  presences : Array[PresenceUpdateEvent]
  stage_instances : Array[StageInstance]
  guild_scheduled_events : Array[GuildScheduledEvent]
  soundboard_sounds : Array[SoundboardSound]
} derive(Debug)

///|
/// A guild-create dispatch is either a complete available guild or the small
/// unavailable-guild sentinel emitted while Discord is having an outage.
pub(all) enum GuildCreateEvent {
  Available(AvailableGuildCreateEvent)
  Unavailable(UnavailableGuild)
} derive(Debug)

///|
pub impl @json.FromJson for AvailableGuildCreateEvent with fn from_json(
  json,
  path,
) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError(
      (path, "expected available guild create event (object)"),
    )
  }
  {
    guild: @json.from_json(json, path~),
    joined_at: event_field(fields, "joined_at", path),
    large: event_field(fields, "large", path),
    unavailable: match fields.get("unavailable") {
      None => None
      Some(value) =>
        Some(@json.from_json(value, path=path.add_key("unavailable")))
    },
    member_count: event_field(fields, "member_count", path),
    voice_states: event_field(fields, "voice_states", path),
    members: event_field(fields, "members", path),
    channels: event_field(fields, "channels", path),
    threads: event_field(fields, "threads", path),
    presences: event_field(fields, "presences", path),
    stage_instances: event_field(fields, "stage_instances", path),
    guild_scheduled_events: event_field(fields, "guild_scheduled_events", path),
    soundboard_sounds: event_field(fields, "soundboard_sounds", path),
  }
}

///|
pub impl @json.FromJson for GuildCreateEvent with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "expected guild create event (object)"))
  }
  match fields.get("unavailable") {
    Some(True) => GuildCreateEvent::Unavailable(@json.from_json(json, path~))
    _ => GuildCreateEvent::Available(@json.from_json(json, path~))
  }
}
