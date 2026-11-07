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
#derive(Debug)
pub(all) struct GuildMemberAddEvent {
  guild_id : GuildId
  guild_member : GuildMember
}

///|
/// Decodes the guild member add event from its Discord JSON representation.
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
#derive(ToJson, FromJson, Debug)
pub(all) struct GuildMemberRemoveEvent {
  guild_id : GuildId
  user : User
}

///|
/// Mutable guild-member fields delivered by GUILD_MEMBER_UPDATE.
#derive(ToJson, FromJson, Debug)
pub(all) struct GuildMemberUpdateEvent {
  guild_id : GuildId
  roles : Array[RoleId]
  user : User
  nick : Nullable[String]?
  avatar : Nullable[ImageHash]
  banner : Nullable[ImageHash]?
  collectibles : Nullable[Collectibles]?
  joined_at : Nullable[Timestamp]
  premium_since : Nullable[Timestamp]?
  deaf : Bool?
  mute : Bool?
  pending : Bool?
  communication_disabled_until : Nullable[Timestamp]?
  flags : GuildMemberFlags?
  avatar_decoration_data : Nullable[AvatarDecorationData]?
}

///|
/// A user ban added to or removed from a guild.
#derive(ToJson, FromJson, Debug)
pub(all) struct GuildBanEvent {
  guild_id : GuildId
  user : User
}

///|
/// A chunk returned by a gateway guild-member request.
#derive(ToJson, FromJson, Debug)
pub(all) struct GuildMembersChunkEvent {
  guild_id : GuildId
  members : Array[GuildMember]
  chunk_index : Int32
  chunk_count : Int32
  not_found : Array[Json]?
  presences : Array[PresenceUpdateEvent]?
  nonce : String?
}

///|
/// Guild emoji collection replacement.
#derive(ToJson, FromJson, Debug)
pub(all) struct GuildEmojisUpdateEvent {
  guild_id : GuildId
  emojis : Array[Emoji]
}

///|
/// Guild sticker collection replacement.
#derive(ToJson, FromJson, Debug)
pub(all) struct GuildStickersUpdateEvent {
  guild_id : GuildId
  stickers : Array[Sticker]
}

///|
/// Notification that a guild's integrations changed.
#derive(ToJson, FromJson, Debug)
pub(all) struct GuildIntegrationsUpdateEvent {
  guild_id : GuildId
}

///|
/// A role created or updated in a guild.
#derive(ToJson, FromJson, Debug)
pub(all) struct GuildRoleEvent {
  guild_id : GuildId
  role : Role
}

///|
/// A role deleted from a guild.
#derive(ToJson, FromJson, Debug)
pub(all) struct GuildRoleDeleteEvent {
  guild_id : GuildId
  role_id : RoleId
}

///|
/// A user added to or removed from a scheduled guild event.
#derive(ToJson, FromJson, Debug)
pub(all) struct GuildScheduledEventUserEvent {
  guild_scheduled_event_id : ScheduledEventId
  user_id : UserId
  guild_id : GuildId
}

///|
/// A soundboard sound deleted from a guild.
#derive(ToJson, FromJson, Debug)
pub(all) struct GuildSoundboardSoundDeleteEvent {
  sound_id : SoundboardSoundId
  guild_id : GuildId
}

///|
/// The complete soundboard sound collection for a guild.
#derive(ToJson, FromJson, Debug)
pub(all) struct SoundboardSoundsEvent {
  soundboard_sounds : Array[SoundboardSound]
  guild_id : GuildId
}

///|
/// A guild integration payload retained raw alongside its guild id.
#derive(Debug)
pub(all) struct IntegrationEvent {
  guild_id : GuildId
  integration : Json
}

///|
/// Decodes the integration event from its Discord JSON representation.
pub impl @json.FromJson for IntegrationEvent with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise JsonDecodeError((path, "expected integration event (object)"))
  }
  { guild_id: event_field(fields, "guild_id", path), integration: json, }
}

///|
/// A guild integration deletion.
#derive(ToJson, FromJson, Debug)
pub(all) struct IntegrationDeleteEvent {
  id : IntegrationId
  guild_id : GuildId
  application_id : ApplicationId?
}

///|
/// An invite created in a channel.
#derive(ToJson, FromJson, Debug)
pub(all) struct InviteCreateEvent {
  channel_id : ChannelId
  code : String
  created_at : Timestamp
  guild_id : GuildId?
  inviter : User?
  max_age : Int32
  max_uses : Int32
  target_type : InviteTargetType?
  target_user : User?
  // Partial applications are deferred to the complete application domain.
  target_application : Json?
  temporary : Bool
  uses : Int32
  expires_at : Nullable[Timestamp]
  role_ids : Array[RoleId]?
}

///|
/// An invite deleted from a channel.
#derive(ToJson, FromJson, Debug)
pub(all) struct InviteDeleteEvent {
  channel_id : ChannelId
  guild_id : GuildId?
  code : String
}

///|
/// A message deletion containing only resource identifiers.
#derive(ToJson, FromJson, Debug)
pub(all) struct MessageDeleteEvent {
  id : MessageId
  channel_id : ChannelId
  guild_id : GuildId?
}

///|
/// A bulk message deletion.
#derive(ToJson, FromJson, Debug)
pub(all) struct MessageDeleteBulkEvent {
  ids : Array[MessageId]
  channel_id : ChannelId
  guild_id : GuildId?
}

///|
/// A reaction added to a message.
#derive(ToJson(fields(typ(rename="type"), guild_member(rename="member"))), FromJson(fields(typ(rename="type"), guild_member(rename="member"))), Debug)
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
  typ : Int32
}

///|
/// A reaction removed from a message.
#derive(ToJson(fields(typ(rename="type"))), FromJson(fields(typ(rename="type"))), Debug)
pub(all) struct MessageReactionRemoveEvent {
  user_id : UserId
  channel_id : ChannelId
  message_id : MessageId
  guild_id : GuildId?
  emoji : Emoji
  burst : Bool
  typ : Int32
}

///|
/// All reactions removed from a message.
#derive(ToJson, FromJson, Debug)
pub(all) struct MessageReactionRemoveAllEvent {
  channel_id : ChannelId
  message_id : MessageId
  guild_id : GuildId?
}

///|
/// Every reaction for one emoji removed from a message.
#derive(ToJson, FromJson, Debug)
pub(all) struct MessageReactionRemoveEmojiEvent {
  channel_id : ChannelId
  message_id : MessageId
  guild_id : GuildId?
  emoji : Emoji
}

///|
/// A user added or removed a vote from a poll answer.
#derive(ToJson, FromJson, Debug)
pub(all) struct MessagePollVoteEvent {
  user_id : UserId
  channel_id : ChannelId
  message_id : MessageId
  guild_id : GuildId?
  answer_id : Int32
}

///|
/// A user began typing in a channel.
#derive(ToJson(fields(guild_member(rename="member"))), Debug)
pub(all) struct TypingStartEvent {
  channel_id : ChannelId
  guild_id : GuildId?
  user_id : UserId
  timestamp : Int64
  guild_member : GuildMember?
}

///|
#derive(FromJson(fields(guild_member(rename="member"))))
struct TypingStartEventWire {
  channel_id : ChannelId
  guild_id : GuildId?
  user_id : UserId
  timestamp : Double
  guild_member : GuildMember?
}

///|
/// Decodes the typing start event from its Discord JSON representation.
pub impl @json.FromJson for TypingStartEvent with fn from_json(json, path) {
  let wire : TypingStartEventWire = @json.from_json(json, path~)
  {
    channel_id: wire.channel_id,
    guild_id: wire.guild_id,
    user_id: wire.user_id,
    timestamp: wire.timestamp.to_int64(),
    guild_member: wire.guild_member,
  }
}

///|
/// The most recent pin timestamp changed for a channel.
#derive(ToJson, FromJson, Debug)
pub(all) struct ChannelPinsUpdateEvent {
  guild_id : GuildId?
  channel_id : ChannelId
  last_pin_timestamp : Nullable[Timestamp]?
}

///|
/// Ephemeral voice-channel information returned for a guild.
#derive(ToJson, FromJson, Debug)
pub(all) struct ChannelInfoEvent {
  guild_id : GuildId
  channels : Array[ChannelInfo]
}

///|
/// Ephemeral status and voice-session data for one channel.
#derive(ToJson, FromJson, Debug)
pub(all) struct ChannelInfo {
  id : ChannelId
  status : Nullable[String]?
  voice_start_time : Nullable[Int64]?
}

///|
/// A thread channel delivered with THREAD_CREATE-only metadata.
#derive(Debug)
pub(all) struct ThreadCreateEvent {
  channel : Channel
  newly_created : Bool?
}

///|
/// Decodes the thread create event from its Discord JSON representation.
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
#derive(ToJson, FromJson, Debug)
pub(all) struct ThreadListSyncEvent {
  guild_id : GuildId
  channel_ids : Array[ChannelId]?
  threads : Array[Channel]
  members : Array[ThreadMember]
}

///|
/// Membership changes for a thread.
#derive(ToJson, FromJson, Debug)
pub(all) struct ThreadMembersUpdateEvent {
  id : ChannelId
  guild_id : GuildId
  member_count : Int32
  added_members : Array[ThreadMember]?
  removed_member_ids : Array[UserId]?
}

///|
/// The current user's thread membership decoded from a flattened object.
#derive(Debug)
pub(all) struct ThreadMemberUpdateEvent {
  guild_id : GuildId
  thread_member : ThreadMember
}

///|
/// Decodes the thread member update event from its Discord JSON representation.
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
#derive(ToJson(fields(typ(rename="type"))), FromJson(fields(typ(rename="type"))), Debug)
pub(all) struct ThreadDeleteEvent {
  id : ChannelId
  guild_id : GuildId
  parent_id : ChannelId
  typ : ChannelType
}

///|
/// Webhook configuration changed in a guild channel.
#derive(ToJson, FromJson, Debug)
pub(all) struct WebhooksUpdateEvent {
  guild_id : GuildId
  channel_id : ChannelId
}

///|
/// Voice server connection information for a guild.
#derive(ToJson, FromJson, Debug)
pub(all) struct VoiceServerUpdateEvent {
  token : String
  guild_id : GuildId
  endpoint : Nullable[String]
}

///|
/// A visual or soundboard effect sent in a voice channel.
#derive(ToJson, FromJson, Debug)
pub(all) struct VoiceChannelEffectSendEvent {
  channel_id : ChannelId
  guild_id : GuildId
  user_id : UserId
  emoji : Nullable[Emoji]?
  animation_type : Nullable[Int32]?
  animation_id : Int32?
  // Discord sends either a snowflake string or a numeric built-in sound id.
  sound_id : Json?
  sound_volume : Double?
}

///|
/// A voice channel's text status changed.
#derive(ToJson, FromJson, Debug)
pub(all) struct VoiceChannelStatusUpdateEvent {
  id : ChannelId
  guild_id : GuildId
  status : Nullable[String]
}

///|
/// A voice channel's session start time changed.
#derive(ToJson, FromJson, Debug)
pub(all) struct VoiceChannelStartTimeUpdateEvent {
  id : ChannelId
  guild_id : GuildId
  voice_start_time : Nullable[Int64]?
}

///|
/// An auto-moderation action was executed against user content.
#derive(ToJson, FromJson, Debug)
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
}

///|
/// An audit-log entry created in a guild, decoded from the flattened object.
#derive(Debug)
pub(all) struct GuildAuditLogEntryCreateEvent {
  guild_id : GuildId
  entry : AuditLogEntry
}

///|
/// Decodes the guild audit log entry create event from its Discord JSON representation.
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
#derive(ToJson, FromJson, Debug)
pub(all) struct GatewayRateLimitedEvent {
  opcode : Int32
  retry_after : Double
  meta : Json
}
