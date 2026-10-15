///|
test "event kind maps every previously uncovered known dispatch name" {
  assert_true(
    @model.EventKind::of_name("APPLICATION_COMMAND_PERMISSIONS_UPDATE")
    is KApplicationCommandPermissionsUpdate,
  )
  assert_true(@model.EventKind::of_name("CHANNEL_DELETE") is KChannelDelete)
  assert_true(@model.EventKind::of_name("INVITE_CREATE") is KInviteCreate)
  assert_true(
    @model.EventKind::of_name("MESSAGE_DELETE_BULK") is KMessageDeleteBulk,
  )
  assert_true(@model.EventKind::of_name("PRESENCE_UPDATE") is KPresenceUpdate)
  assert_true(
    @model.EventKind::of_name("STAGE_INSTANCE_CREATE") is KStageInstanceCreate,
  )
  assert_true(@model.EventKind::of_name("WEBHOOKS_UPDATE") is KWebhooksUpdate)
}

///|
test "dispatch decodes channel info, entitlement, ban, and emoji payloads" {
  let channel = @model.dispatch_event(
    "CHANNEL_INFO",
    @json.parse(
      "{\"guild_id\":\"100\",\"channels\":[{\"id\":\"400\",\"status\":null,\"voice_start_time\":null}]}",
    ),
  )
  assert_true(channel is ChannelInfo(_))
  let entitlement = @model.dispatch_event(
    "ENTITLEMENT_CREATE",
    @json.parse(
      "{\"id\":\"700\",\"sku_id\":\"701\",\"application_id\":\"702\",\"user_id\":\"200\",\"type\":1,\"deleted\":false}",
    ),
  )
  assert_true(entitlement is EntitlementCreate(_))
  let user = "{\"id\":\"200\",\"username\":\"Nelly\",\"discriminator\":\"0\",\"global_name\":null,\"avatar\":null}"
  let ban = @model.dispatch_event(
    "GUILD_BAN_REMOVE",
    @json.parse("{\"guild_id\":\"100\",\"user\":\{user}}"),
  )
  assert_true(ban is GuildBanRemove(_))
  let emojis = @model.dispatch_event(
    "GUILD_EMOJIS_UPDATE",
    @json.parse("{\"guild_id\":\"100\",\"emojis\":[]}"),
  )
  assert_true(emojis is GuildEmojisUpdate(_))
}

///|
test "dispatch decodes scheduled event user and soundboard deletion payloads" {
  let payload = @json.parse(
    "{\"guild_scheduled_event_id\":\"800\",\"user_id\":\"200\",\"guild_id\":\"100\"}",
  )
  assert_true(
    @model.dispatch_event("GUILD_SCHEDULED_EVENT_USER_ADD", payload)
    is GuildScheduledEventUserAdd(_),
  )
  assert_true(
    @model.dispatch_event("GUILD_SCHEDULED_EVENT_USER_REMOVE", payload)
    is GuildScheduledEventUserRemove(_),
  )
  let deleted = @model.dispatch_event(
    "GUILD_SOUNDBOARD_SOUND_DELETE",
    @json.parse("{\"sound_id\":\"900\",\"guild_id\":\"100\"}"),
  )
  assert_true(deleted is GuildSoundboardSoundDelete(_))
  let sounds = @model.dispatch_event(
    "GUILD_SOUNDBOARD_SOUNDS_UPDATE",
    @json.parse("{\"soundboard_sounds\":[],\"guild_id\":\"100\"}"),
  )
  assert_true(sounds is GuildSoundboardSoundsUpdate(_))
}

///|
test "dispatch decodes integration and invite create payloads" {
  let integration = @model.dispatch_event(
    "INTEGRATION_CREATE",
    @json.parse(
      "{\"guild_id\":\"100\",\"id\":\"300\",\"name\":\"Twitch\",\"type\":\"twitch\"}",
    ),
  )
  assert_true(integration is IntegrationCreate(_))
  let invite = @model.dispatch_event(
    "INVITE_CREATE",
    @json.parse(
      "{\"channel_id\":\"400\",\"code\":\"real-shape\",\"created_at\":\"2026-07-16T00:00:00Z\",\"guild_id\":\"100\",\"max_age\":3600,\"max_uses\":5,\"temporary\":false,\"uses\":0,\"expires_at\":null}",
    ),
  )
  assert_true(invite is InviteCreate(_))
}

///|
test "dispatch decodes poll and reaction removal payloads" {
  let poll = @model.dispatch_event(
    "MESSAGE_POLL_VOTE_ADD",
    @json.parse(
      "{\"user_id\":\"200\",\"channel_id\":\"400\",\"message_id\":\"500\",\"guild_id\":\"100\",\"answer_id\":2}",
    ),
  )
  assert_true(poll is MessagePollVoteAdd(_))
  let reaction = @model.dispatch_event(
    "MESSAGE_REACTION_REMOVE",
    @json.parse(
      "{\"user_id\":\"200\",\"channel_id\":\"400\",\"message_id\":\"500\",\"guild_id\":\"100\",\"emoji\":{\"id\":null,\"name\":\"x\"},\"burst\":false,\"type\":0}",
    ),
  )
  assert_true(reaction is MessageReactionRemove(_))
  let all = @model.dispatch_event(
    "MESSAGE_REACTION_REMOVE_ALL",
    @json.parse(
      "{\"channel_id\":\"400\",\"message_id\":\"500\",\"guild_id\":\"100\"}",
    ),
  )
  assert_true(all is MessageReactionRemoveAll(_))
  let emoji = @model.dispatch_event(
    "MESSAGE_REACTION_REMOVE_EMOJI",
    @json.parse(
      "{\"channel_id\":\"400\",\"message_id\":\"500\",\"guild_id\":\"100\",\"emoji\":{\"id\":null,\"name\":\"x\"}}",
    ),
  )
  assert_true(emoji is MessageReactionRemoveEmoji(_))
}

///|
test "dispatch decodes stage and voice channel update payloads" {
  let stage = @model.dispatch_event(
    "STAGE_INSTANCE_CREATE",
    @json.parse(
      "{\"id\":\"600\",\"guild_id\":\"100\",\"channel_id\":\"400\",\"topic\":\"Town hall\",\"privacy_level\":2,\"guild_scheduled_event_id\":null}",
    ),
  )
  assert_true(stage is StageInstanceCreate(_))
  let start = @model.dispatch_event(
    "VOICE_CHANNEL_START_TIME_UPDATE",
    @json.parse(
      "{\"id\":\"400\",\"guild_id\":\"100\",\"voice_start_time\":\"1700000000000\"}",
    ),
  )
  assert_true(start is VoiceChannelStartTimeUpdate(_))
  let status = @model.dispatch_event(
    "VOICE_CHANNEL_STATUS_UPDATE",
    @json.parse("{\"id\":\"400\",\"guild_id\":\"100\",\"status\":\"Pairing\"}"),
  )
  assert_true(status is VoiceChannelStatusUpdate(_))
}
