///|
test "event intent table covers every intent group" {
  let cases : Array[(@model.EventKind, UInt)] = [
    (KGuildCreate, @model.Intents::guilds().bits()),
    (KGuildMemberAdd, @model.Intents::guild_members().bits()),
    (KGuildBanAdd, @model.Intents::guild_moderation().bits()),
    (KGuildEmojisUpdate, @model.Intents::guild_expressions().bits()),
    (KIntegrationCreate, @model.Intents::guild_integrations().bits()),
    (KWebhooksUpdate, @model.Intents::guild_webhooks().bits()),
    (KInviteCreate, @model.Intents::guild_invites().bits()),
    (KVoiceStateUpdate, @model.Intents::guild_voice_states().bits()),
    (KPresenceUpdate, @model.Intents::guild_presences().bits()),
    (KMessageDeleteBulk, @model.Intents::guild_messages().bits()),
    (
      KMessageReactionAdd,
      (@model.Intents::guild_message_reactions() |
      @model.Intents::direct_message_reactions()).bits(),
    ),
    (
      KTypingStart,
      (@model.Intents::guild_message_typing() |
      @model.Intents::direct_message_typing()).bits(),
    ),
    (KMessageCreate, @model.Intents::guild_messages().bits()),
    (KMessageCreate, @model.Intents::direct_messages().bits()),
    (KMessageReactionRemove, @model.Intents::direct_message_reactions().bits()),
    (KTypingStart, @model.Intents::direct_message_typing().bits()),
    (
      KGuildScheduledEventCreate,
      @model.Intents::guild_scheduled_events().bits(),
    ),
    (
      KAutoModerationRuleCreate,
      @model.Intents::auto_moderation_configuration().bits(),
    ),
    (
      KAutoModerationActionExecution,
      @model.Intents::auto_moderation_execution().bits(),
    ),
    (KMessagePollVoteAdd, @model.Intents::guild_message_polls().bits()),
    (KMessagePollVoteAdd, @model.Intents::direct_message_polls().bits()),
  ]
  debug_inspect(
    cases.map(case => {
      let (event, intent) = case
      event.required_intents().contains(@model.Intents::from_bits(intent))
    }),
    content=(
      #|[
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|  true,
      #|]
    ),
  )
}

///|
test "event intents union contexts and omit field visibility intents" {
  debug_inspect(
    [
      @model.EventKind::KMessageCreate.required_intents().bits(),
      @model.EventKind::KMessageReactionAdd.required_intents().bits(),
      @model.EventKind::KTypingStart.required_intents().bits(),
      @model.EventKind::KMessagePollVoteAdd.required_intents().bits(),
      @model.EventKind::KThreadMembersUpdate.required_intents().bits(),
      @model.EventKind::KChannelCreate.required_intents().bits(),
      @model.EventKind::KChannelPinsUpdate.required_intents().bits(),
      @model.EventKind::KVoiceChannelStatusUpdate.required_intents().bits(),
      @model.EventKind::KVoiceChannelStartTimeUpdate.required_intents().bits(),
    ],
    content=(
      #|[4608, 9216, 18432, 50331648, 3, 1, 4097, 1, 1]
    ),
  )
  assert_false(
    @model.EventKind::KMessageCreate
    .required_intents()
    .contains(@model.Intents::message_content()),
  )
}

///|
test "intent-free events require none" {
  debug_inspect(
    [
      @model.EventKind::KReady,
      KResumed,
      KInteractionCreate,
      KVoiceServerUpdate,
      KUserUpdate,
      KGuildMembersChunk,
      KSoundboardSounds,
      KChannelInfo,
      KUnknown,
    ].map(event => event.required_intents().bits()),
    content=(
      #|[0, 0, 0, 0, 0, 0, 0, 0, 0]
    ),
  )
}
