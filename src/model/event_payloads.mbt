///|
fn[T : @json.FromJson] event_field(
  fields : Map[String, Json],
  key : String,
  path : @json.JsonPath,
) -> T raise @json.JsonDecodeError {
  match fields.get(key) {
    Some(value) => @json.from_json(value, path=path.add_key(key))
    None => raise JsonDecodeError((path.add_key(key), "missing required field"))
  }
}

///|
/// A guild member joined event decoded from Discord's flattened member object.
pub(all) struct GuildMemberAddEvent {
  guild_id : GuildId
  guild_member : GuildMember
} derive(Debug)

///|
pub impl @json.FromJson for GuildMemberAddEvent with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise JsonDecodeError((path, "expected guild member add event (object)"))
  }
  {
    guild_id: event_field(fields, "guild_id", path),
    guild_member: @json.from_json(json, path~),
  }
}

///|
/// A user removed from a guild.
pub(all) struct GuildMemberRemoveEvent {
  guild_id : GuildId
  user : User
} derive(ToJson, FromJson, Debug)

///|
/// Mutable guild-member fields delivered by GUILD_MEMBER_UPDATE.
pub(all) struct GuildMemberUpdateEvent {
  guild_id : GuildId
  roles : Array[RoleId]
  user : User
  nick : Nullable[String]?
  avatar : Nullable[ImageHash]
  joined_at : Nullable[Timestamp]
  premium_since : Nullable[Timestamp]?
  deaf : Bool?
  mute : Bool?
  pending : Bool?
  communication_disabled_until : Nullable[Timestamp]?
  flags : GuildMemberFlags?
  avatar_decoration_data : Nullable[AvatarDecorationData]?
} derive(ToJson, FromJson, Debug)

///|
/// A user ban added to or removed from a guild.
pub(all) struct GuildBanEvent {
  guild_id : GuildId
  user : User
} derive(ToJson, FromJson, Debug)

///|
/// A chunk returned by a gateway guild-member request.
pub(all) struct GuildMembersChunkEvent {
  guild_id : GuildId
  members : Array[GuildMember]
  chunk_index : Int
  chunk_count : Int
  not_found : Array[Json]?
  presences : Array[PresenceUpdateEvent]?
  nonce : String?
} derive(ToJson, FromJson, Debug)

///|
/// Guild emoji collection replacement.
pub(all) struct GuildEmojisUpdateEvent {
  guild_id : GuildId
  emojis : Array[Emoji]
} derive(ToJson, FromJson, Debug)

///|
/// Guild sticker collection replacement.
pub(all) struct GuildStickersUpdateEvent {
  guild_id : GuildId
  stickers : Array[Sticker]
} derive(ToJson, FromJson, Debug)

///|
/// Notification that a guild's integrations changed.
pub(all) struct GuildIntegrationsUpdateEvent {
  guild_id : GuildId
} derive(ToJson, FromJson, Debug)

///|
/// A role created or updated in a guild.
pub(all) struct GuildRoleEvent {
  guild_id : GuildId
  role : Role
} derive(ToJson, FromJson, Debug)

///|
/// A role deleted from a guild.
pub(all) struct GuildRoleDeleteEvent {
  guild_id : GuildId
  role_id : RoleId
} derive(ToJson, FromJson, Debug)

///|
/// A user added to or removed from a scheduled guild event.
pub(all) struct GuildScheduledEventUserEvent {
  guild_scheduled_event_id : ScheduledEventId
  user_id : UserId
  guild_id : GuildId
} derive(ToJson, FromJson, Debug)

///|
/// A soundboard sound deleted from a guild.
pub(all) struct GuildSoundboardSoundDeleteEvent {
  sound_id : SoundboardSoundId
  guild_id : GuildId
} derive(ToJson, FromJson, Debug)

///|
/// The complete soundboard sound collection for a guild.
pub(all) struct SoundboardSoundsEvent {
  soundboard_sounds : Array[SoundboardSound]
  guild_id : GuildId
} derive(ToJson, FromJson, Debug)

///|
/// A guild integration payload retained raw alongside its guild id.
pub(all) struct IntegrationEvent {
  guild_id : GuildId
  integration : Json
} derive(Debug)

///|
pub impl @json.FromJson for IntegrationEvent with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise JsonDecodeError((path, "expected integration event (object)"))
  }
  { guild_id: event_field(fields, "guild_id", path), integration: json }
}

///|
/// A guild integration deletion.
pub(all) struct IntegrationDeleteEvent {
  id : IntegrationId
  guild_id : GuildId
  application_id : ApplicationId?
} derive(ToJson, FromJson, Debug)

///|
/// An invite created in a channel.
pub(all) struct InviteCreateEvent {
  channel_id : ChannelId
  code : String
  created_at : Timestamp
  guild_id : GuildId?
  inviter : User?
  max_age : Int
  max_uses : Int
  target_type : InviteTargetType?
  target_user : User?
  // Partial applications are deferred to the complete application domain.
  target_application : Json?
  temporary : Bool
  uses : Int
  expires_at : Nullable[Timestamp]
  role_ids : Array[RoleId]?
} derive(ToJson, FromJson, Debug)

///|
/// An invite deleted from a channel.
pub(all) struct InviteDeleteEvent {
  channel_id : ChannelId
  guild_id : GuildId?
  code : String
} derive(ToJson, FromJson, Debug)

///|
/// A message deletion containing only resource identifiers.
pub(all) struct MessageDeleteEvent {
  id : MessageId
  channel_id : ChannelId
  guild_id : GuildId?
} derive(ToJson, FromJson, Debug)

///|
/// A bulk message deletion.
pub(all) struct MessageDeleteBulkEvent {
  ids : Array[MessageId]
  channel_id : ChannelId
  guild_id : GuildId?
} derive(ToJson, FromJson, Debug)

///|
/// A reaction added to a message.
pub(all) struct MessageReactionAddEvent {
  user_id : UserId
  channel_id : ChannelId
  message_id : MessageId
  guild_id : GuildId?
  guild_member : GuildMember?
  emoji : Emoji
  message_author_id : UserId?
  burst : Bool
  burst_colors : Array[String]?
  typ : Int
} derive (
  ToJson(fields(typ(rename="type"), guild_member(rename="member"))),
  FromJson(fields(typ(rename="type"), guild_member(rename="member"))),
  Debug,
)

///|
/// A reaction removed from a message.
pub(all) struct MessageReactionRemoveEvent {
  user_id : UserId
  channel_id : ChannelId
  message_id : MessageId
  guild_id : GuildId?
  emoji : Emoji
  burst : Bool
  typ : Int
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// All reactions removed from a message.
pub(all) struct MessageReactionRemoveAllEvent {
  channel_id : ChannelId
  message_id : MessageId
  guild_id : GuildId?
} derive(ToJson, FromJson, Debug)

///|
/// Every reaction for one emoji removed from a message.
pub(all) struct MessageReactionRemoveEmojiEvent {
  channel_id : ChannelId
  message_id : MessageId
  guild_id : GuildId?
  emoji : Emoji
} derive(ToJson, FromJson, Debug)

///|
/// A user added or removed a vote from a poll answer.
pub(all) struct MessagePollVoteEvent {
  user_id : UserId
  channel_id : ChannelId
  message_id : MessageId
  guild_id : GuildId?
  answer_id : Int
} derive(ToJson, FromJson, Debug)

///|
/// A user began typing in a channel.
pub(all) struct TypingStartEvent {
  channel_id : ChannelId
  guild_id : GuildId?
  user_id : UserId
  timestamp : Int64
  guild_member : GuildMember?
} derive (
  ToJson(fields(guild_member(rename="member"))),
  FromJson(fields(guild_member(rename="member"))),
  Debug,
)

///|
/// The most recent pin timestamp changed for a channel.
pub(all) struct ChannelPinsUpdateEvent {
  guild_id : GuildId?
  channel_id : ChannelId
  last_pin_timestamp : Nullable[Timestamp]?
} derive(ToJson, FromJson, Debug)

///|
/// Ephemeral voice-channel information returned for a guild.
pub(all) struct ChannelInfoEvent {
  guild_id : GuildId
  channels : Array[ChannelInfo]
} derive(ToJson, FromJson, Debug)

///|
/// Ephemeral status and voice-session data for one channel.
pub(all) struct ChannelInfo {
  id : ChannelId
  status : Nullable[String]?
  voice_start_time : Nullable[Int64]?
} derive(ToJson, FromJson, Debug)

///|
/// A thread channel delivered with THREAD_CREATE-only metadata.
pub(all) struct ThreadCreateEvent {
  channel : Channel
  newly_created : Bool?
} derive(Debug)

///|
pub impl @json.FromJson for ThreadCreateEvent with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise JsonDecodeError((path, "expected thread create event (object)"))
  }
  {
    channel: @json.from_json(json, path~),
    newly_created: match fields.get("newly_created") {
      None => None
      Some(value) =>
        Some(@json.from_json(value, path=path.add_key("newly_created")))
    },
  }
}

///|
/// Threads and memberships synchronized for a guild.
pub(all) struct ThreadListSyncEvent {
  guild_id : GuildId
  channel_ids : Array[ChannelId]?
  threads : Array[Channel]
  members : Array[ThreadMember]
} derive(ToJson, FromJson, Debug)

///|
/// Membership changes for a thread.
pub(all) struct ThreadMembersUpdateEvent {
  id : ChannelId
  guild_id : GuildId
  member_count : Int
  added_members : Array[ThreadMember]?
  removed_member_ids : Array[UserId]?
} derive(ToJson, FromJson, Debug)

///|
/// The current user's thread membership decoded from a flattened object.
pub(all) struct ThreadMemberUpdateEvent {
  guild_id : GuildId
  thread_member : ThreadMember
} derive(Debug)

///|
pub impl @json.FromJson for ThreadMemberUpdateEvent with fn from_json(
  json,
  path,
) {
  guard json is Object(fields) else {
    raise JsonDecodeError(
      (path, "expected thread member update event (object)"),
    )
  }
  {
    guild_id: event_field(fields, "guild_id", path),
    thread_member: @json.from_json(json, path~),
  }
}

///|
/// A deleted thread's identifying fields.
pub(all) struct ThreadDeleteEvent {
  id : ChannelId
  guild_id : GuildId
  parent_id : ChannelId
  typ : ChannelType
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// Webhook configuration changed in a guild channel.
pub(all) struct WebhooksUpdateEvent {
  guild_id : GuildId
  channel_id : ChannelId
} derive(ToJson, FromJson, Debug)

///|
/// Voice server connection information for a guild.
pub(all) struct VoiceServerUpdateEvent {
  token : String
  guild_id : GuildId
  endpoint : Nullable[String]
} derive(ToJson, FromJson, Debug)

///|
/// A visual or soundboard effect sent in a voice channel.
pub(all) struct VoiceChannelEffectSendEvent {
  channel_id : ChannelId
  guild_id : GuildId
  user_id : UserId
  emoji : Nullable[Emoji]?
  animation_type : Nullable[Int]?
  animation_id : Int?
  // Discord sends either a snowflake string or a numeric built-in sound id.
  sound_id : Json?
  sound_volume : Double?
} derive(ToJson, FromJson, Debug)

///|
/// A voice channel's text status changed.
pub(all) struct VoiceChannelStatusUpdateEvent {
  id : ChannelId
  guild_id : GuildId
  status : Nullable[String]
} derive(ToJson, FromJson, Debug)

///|
/// A voice channel's session start time changed.
pub(all) struct VoiceChannelStartTimeUpdateEvent {
  id : ChannelId
  guild_id : GuildId
  voice_start_time : Nullable[Int64]?
} derive(ToJson, FromJson, Debug)

///|
/// An auto-moderation action was executed against user content.
pub(all) struct AutoModerationActionExecutionEvent {
  guild_id : GuildId
  action : AutoModerationAction
  rule_id : AutoModerationRuleId
  rule_trigger_type : AutoModerationTriggerType
  user_id : UserId
  channel_id : ChannelId?
  message_id : MessageId?
  alert_system_message_id : MessageId?
  content : String
  matched_keyword : Nullable[String]
  matched_content : Nullable[String]
} derive(ToJson, FromJson, Debug)

///|
/// An audit-log entry created in a guild, decoded from the flattened object.
pub(all) struct GuildAuditLogEntryCreateEvent {
  guild_id : GuildId
  entry : AuditLogEntry
} derive(Debug)

///|
pub impl @json.FromJson for GuildAuditLogEntryCreateEvent with fn from_json(
  json,
  path,
) {
  guard json is Object(fields) else {
    raise JsonDecodeError(
      (path, "expected guild audit log entry create event (object)"),
    )
  }
  {
    guild_id: event_field(fields, "guild_id", path),
    entry: @json.from_json(json, path~),
  }
}

///|
/// A gateway request was rate limited.
pub(all) struct GatewayRateLimitedEvent {
  opcode : Int
  retry_after : Double
  meta : Json
} derive(ToJson, FromJson, Debug)
