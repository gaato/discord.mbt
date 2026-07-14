///|
fn command_options(fixture : String) -> @interaction.CommandOptions raise {
  let data : @model.CommandData = @json.from_json(@json.parse(fixture))
  @interaction.CommandOptions::from_data(data)
}

///|
fn typed_event(name : String, fixture : String) -> @model.Event raise {
  @model.dispatch_event(name, @json.parse(fixture))
}

///|
test "typed command spec derives options from Args" {
  let args = @interaction.Args::map2(
    @interaction.arg_string(name="text", description="Text to echo"),
    @interaction.arg_int(
      name="times",
      description="Repeat count",
      min=1L,
      max=5L,
    )
    |> @interaction.default(1L),
    (text, times) => (text, times),
  )
  let command = slash(
    name="echo",
    description="Echo some text",
    args~,
    handler=Raw(_ => ()),
  )
  json_inspect(command.spec().to_json(), content={
    "name": "echo",
    "description": "Echo some text",
    "options": [
      {
        "type": 3,
        "name": "text",
        "description": "Text to echo",
        "required": true,
      },
      {
        "type": 4,
        "name": "times",
        "description": "Repeat count",
        "required": false,
        "min_value": 1,
        "max_value": 5,
      },
    ],
  })
  inspect(command.erase().name(), content="echo")
}

///|
test "command argument decode errors become InvalidArgument" {
  let fixture =
    #|{
    #|  "id": "107000000000000201",
    #|  "name": "echo",
    #|  "type": 1,
    #|  "options": []
    #|}
  let args = @interaction.Args::of(
    @interaction.arg_string(name="text", description="Text to echo"),
  )
  try decode_command_args(args, command_options(fixture)) catch {
    error =>
      debug_inspect(
        error,
        content=(
          #|InvalidArgument("MissingOption(name=\"text\")")
        ),
      )
  } noraise {
    _ => fail("expected decode to fail")
  }
}

///|
test "initial response data matches framework message response shape" {
  let response = InitialResponse::message(
    content="done",
    files=[
      @dhttp.FileUpload::new("report.txt", b"ok", description="Result report"),
    ],
    ephemeral=true,
  )
  json_inspect(response.message_data(), content={
    "content": "done",
    "attachments": [
      { "id": 0, "filename": "report.txt", "description": "Result report" },
    ],
    "flags": 64,
  })
}

///|
test "typed event descriptors project representative payloads" {
  let pins = typed_event(
    "CHANNEL_PINS_UPDATE",
    (
      #|{"channel_id":"400","guild_id":"100","last_pin_timestamp":null}
    ),
  )
  guard Events::channel_pins_update().project(pins) is Some(pins_payload) else {
    fail("expected channel pins payload")
  }
  let bulk = typed_event(
    "MESSAGE_DELETE_BULK",
    (
      #|{"ids":["500","501"],"channel_id":"400","guild_id":"100"}
    ),
  )
  guard Events::message_delete_bulk().project(bulk) is Some(bulk_payload) else {
    fail("expected bulk delete payload")
  }
  let voice = typed_event(
    "VOICE_SERVER_UPDATE",
    (
      #|{"token":"voice-token","guild_id":"100","endpoint":null}
    ),
  )
  guard Events::voice_server_update().project(voice) is Some(voice_payload) else {
    fail("expected voice server payload")
  }
  let limited = typed_event(
    "RATE_LIMITED",
    (
      #|{"opcode":8,"retry_after":1.5,"meta":{}}
    ),
  )
  guard Events::rate_limited().project(limited) is Some(limited_payload) else {
    fail("expected rate limited payload")
  }
  let typing = @model.Event::TypingStart({
    channel_id: @model.Id::parse("400"),
    guild_id: None,
    user_id: @model.Id::parse("200"),
    timestamp: 123L,
    guild_member: None,
  })
  guard Events::typing_start().project(typing) is Some(typing_payload) else {
    fail("expected typing payload")
  }
  let invite = typed_event(
    "INVITE_DELETE",
    (
      #|{"channel_id":"400","guild_id":"100","code":"moon"}
    ),
  )
  guard Events::invite_delete().project(invite) is Some(invite_payload) else {
    fail("expected invite payload")
  }
  let thread = typed_event(
    "THREAD_DELETE",
    (
      #|{"id":"700","guild_id":"100","parent_id":"400","type":11}
    ),
  )
  guard Events::thread_delete().project(thread) is Some(thread_payload) else {
    fail("expected thread payload")
  }
  let guild = typed_event(
    "GUILD_DELETE",
    (
      #|{"id":"100","unavailable":true}
    ),
  )
  guard Events::guild_delete().project(guild) is Some(guild_payload) else {
    fail("expected guild delete payload")
  }
  let webhooks = typed_event(
    "WEBHOOKS_UPDATE",
    (
      #|{"guild_id":"100","channel_id":"400"}
    ),
  )
  guard Events::webhooks_update().project(webhooks) is Some(webhooks_payload) else {
    fail("expected webhooks payload")
  }
  let integrations = typed_event(
    "GUILD_INTEGRATIONS_UPDATE",
    (
      #|{"guild_id":"100"}
    ),
  )
  guard Events::guild_integrations_update().project(integrations)
    is Some(integrations_payload) else {
    fail("expected integrations payload")
  }
  debug_inspect(
    [
      pins_payload.channel_id.to_string(),
      bulk_payload.ids.length().to_string(),
      voice_payload.token,
      limited_payload.opcode.to_string(),
      typing_payload.user_id.to_string(),
      invite_payload.code,
      thread_payload.id.to_string(),
      guild_payload.id.to_string(),
      webhooks_payload.channel_id.to_string(),
      integrations_payload.guild_id.to_string(),
    ],
    content=(
      #|[
      #|  "400",
      #|  "2",
      #|  "voice-token",
      #|  "8",
      #|  "200",
      #|  "moon",
      #|  "700",
      #|  "100",
      #|  "400",
      #|  "100",
      #|]
    ),
  )
  assert_true(Events::voice_server_update().project(pins) is None)
}

///|
test "event descriptors delegate required intents" {
  debug_inspect(
    [
      Events::channel_create().required_intents().bits(),
      Events::voice_channel_status_update().required_intents().bits(),
      Events::voice_channel_start_time_update().required_intents().bits(),
      Events::message_create().required_intents().bits(),
      Events::ready().required_intents().bits(),
    ],
    content="[1, 1, 1, 4608, 0]",
  )
}

///|
test "all typed event descriptors report their matching kind" {
  let actual = [
    Events::auto_moderation_action_execution().kind(),
    Events::auto_moderation_rule_create().kind(),
    Events::auto_moderation_rule_delete().kind(),
    Events::auto_moderation_rule_update().kind(),
    Events::channel_create().kind(),
    Events::channel_delete().kind(),
    Events::channel_info().kind(),
    Events::channel_pins_update().kind(),
    Events::channel_update().kind(),
    Events::entitlement_create().kind(),
    Events::entitlement_delete().kind(),
    Events::entitlement_update().kind(),
    Events::guild_audit_log_entry_create().kind(),
    Events::guild_ban_add().kind(),
    Events::guild_ban_remove().kind(),
    Events::guild_delete().kind(),
    Events::guild_emojis_update().kind(),
    Events::guild_integrations_update().kind(),
    Events::guild_member_add().kind(),
    Events::guild_member_remove().kind(),
    Events::guild_members_chunk().kind(),
    Events::guild_member_update().kind(),
    Events::guild_role_create().kind(),
    Events::guild_role_delete().kind(),
    Events::guild_role_update().kind(),
    Events::guild_scheduled_event_create().kind(),
    Events::guild_scheduled_event_delete().kind(),
    Events::guild_scheduled_event_update().kind(),
    Events::guild_scheduled_event_user_add().kind(),
    Events::guild_scheduled_event_user_remove().kind(),
    Events::guild_soundboard_sound_create().kind(),
    Events::guild_soundboard_sound_delete().kind(),
    Events::guild_soundboard_sounds_update().kind(),
    Events::guild_soundboard_sound_update().kind(),
    Events::soundboard_sounds().kind(),
    Events::guild_stickers_update().kind(),
    Events::guild_update().kind(),
    Events::integration_create().kind(),
    Events::integration_delete().kind(),
    Events::integration_update().kind(),
    Events::interaction_create().kind(),
    Events::invite_create().kind(),
    Events::invite_delete().kind(),
    Events::message_create().kind(),
    Events::message_delete().kind(),
    Events::message_delete_bulk().kind(),
    Events::message_poll_vote_add().kind(),
    Events::message_poll_vote_remove().kind(),
    Events::message_reaction_add().kind(),
    Events::message_reaction_remove().kind(),
    Events::message_reaction_remove_all().kind(),
    Events::message_reaction_remove_emoji().kind(),
    Events::message_update().kind(),
    Events::rate_limited().kind(),
    Events::ready().kind(),
    Events::stage_instance_create().kind(),
    Events::stage_instance_delete().kind(),
    Events::stage_instance_update().kind(),
    Events::thread_create().kind(),
    Events::thread_delete().kind(),
    Events::thread_list_sync().kind(),
    Events::thread_members_update().kind(),
    Events::thread_member_update().kind(),
    Events::thread_update().kind(),
    Events::typing_start().kind(),
    Events::user_update().kind(),
    Events::voice_channel_effect_send().kind(),
    Events::voice_channel_start_time_update().kind(),
    Events::voice_channel_status_update().kind(),
    Events::voice_server_update().kind(),
    Events::voice_state_update().kind(),
    Events::webhooks_update().kind(),
  ]
  let expected = [
    @model.EventKind::KAutoModerationActionExecution,
    KAutoModerationRuleCreate,
    KAutoModerationRuleDelete,
    KAutoModerationRuleUpdate,
    KChannelCreate,
    KChannelDelete,
    KChannelInfo,
    KChannelPinsUpdate,
    KChannelUpdate,
    KEntitlementCreate,
    KEntitlementDelete,
    KEntitlementUpdate,
    KGuildAuditLogEntryCreate,
    KGuildBanAdd,
    KGuildBanRemove,
    KGuildDelete,
    KGuildEmojisUpdate,
    KGuildIntegrationsUpdate,
    KGuildMemberAdd,
    KGuildMemberRemove,
    KGuildMembersChunk,
    KGuildMemberUpdate,
    KGuildRoleCreate,
    KGuildRoleDelete,
    KGuildRoleUpdate,
    KGuildScheduledEventCreate,
    KGuildScheduledEventDelete,
    KGuildScheduledEventUpdate,
    KGuildScheduledEventUserAdd,
    KGuildScheduledEventUserRemove,
    KGuildSoundboardSoundCreate,
    KGuildSoundboardSoundDelete,
    KGuildSoundboardSoundsUpdate,
    KGuildSoundboardSoundUpdate,
    KSoundboardSounds,
    KGuildStickersUpdate,
    KGuildUpdate,
    KIntegrationCreate,
    KIntegrationDelete,
    KIntegrationUpdate,
    KInteractionCreate,
    KInviteCreate,
    KInviteDelete,
    KMessageCreate,
    KMessageDelete,
    KMessageDeleteBulk,
    KMessagePollVoteAdd,
    KMessagePollVoteRemove,
    KMessageReactionAdd,
    KMessageReactionRemove,
    KMessageReactionRemoveAll,
    KMessageReactionRemoveEmoji,
    KMessageUpdate,
    KRateLimited,
    KReady,
    KStageInstanceCreate,
    KStageInstanceDelete,
    KStageInstanceUpdate,
    KThreadCreate,
    KThreadDelete,
    KThreadListSync,
    KThreadMembersUpdate,
    KThreadMemberUpdate,
    KThreadUpdate,
    KTypingStart,
    KUserUpdate,
    KVoiceChannelEffectSend,
    KVoiceChannelStartTimeUpdate,
    KVoiceChannelStatusUpdate,
    KVoiceServerUpdate,
    KVoiceStateUpdate,
    KWebhooksUpdate,
  ]
  assert_eq(actual.length(), expected.length())
  for i in 0..<actual.length() {
    assert_true(actual[i] == expected[i])
  }
}
