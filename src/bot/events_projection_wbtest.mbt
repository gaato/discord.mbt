///|
/// Checks one typed event descriptor end to end: the descriptor's kind agrees
/// with the dispatch-name mapping, a matching dispatch payload projects to
/// `Some`, and a mismatched event (`RESUMED`) projects to `None`.
fn[T] check_projection(
  name : String,
  fixture : String,
  descriptor : EventType[T],
) -> Unit raise {
  guard descriptor.kind() == @model.EventKind::of_name(name) else {
    fail("\{name}: descriptor kind does not match the dispatch name")
  }
  let event = @model.dispatch_event(name, @json.parse(fixture))
  guard descriptor.project(event) is Some(_) else {
    fail("\{name}: expected Some from a matching dispatch payload")
  }
  guard event_kind(event) == descriptor.kind() else {
    fail("\{name}: event_kind disagrees with the descriptor")
  }
  let mismatch = @model.dispatch_event("RESUMED", @json.parse("null"))
  guard descriptor.project(mismatch) is None else {
    fail("\{name}: expected None from a mismatched event")
  }
}

///|
test "event kinds classify the payload-free and unknown events" {
  guard event_kind(@model.dispatch_event("RESUMED", @json.parse("null")))
    is KResumed else {
    fail("expected KResumed")
  }
  guard event_kind(@model.dispatch_event("SOMETHING_NEW", @json.parse("{}")))
    is KUnknown else {
    fail("expected KUnknown")
  }
}

///|
test "raw event handlers trigger the explicit-intents warning" {
  let app = @app.App()
  let warnings : Array[String] = []
  app.on_warn(message => warnings.push(message))
  let bot = Bot(app, token="test-token")
  bot.on_event((_, _) => ())
  ignore(bot.resolved_intents())
  assert_true(
    warnings.contains(
      "raw event handlers do not imply gateway intents; pass intents explicitly for the events they consume",
    ),
  )
}

///|
test "every typed event descriptor projects its own dispatch and rejects others" {
  check_projection(
    "APPLICATION_COMMAND_PERMISSIONS_UPDATE",
    (
      #|{"id":"800","application_id":"900","guild_id":"100","permissions":[]}
    ),
    Events::application_command_permissions_update(),
  )
  check_projection(
    "AUTO_MODERATION_ACTION_EXECUTION",
    (
      #|{"guild_id":"100","action":{"type":1},"rule_id":"800","rule_trigger_type":1,"user_id":"200","content":"spam","matched_keyword":null,"matched_content":null}
    ),
    Events::auto_moderation_action_execution(),
  )
  let automod_rule =
    #|{"id":"800","guild_id":"100","name":"rule","creator_id":"200","event_type":1,"trigger_type":1,"trigger_metadata":{},"actions":[],"enabled":true,"exempt_roles":[],"exempt_channels":[]}
  check_projection(
    "AUTO_MODERATION_RULE_CREATE",
    automod_rule,
    Events::auto_moderation_rule_create(),
  )
  check_projection(
    "AUTO_MODERATION_RULE_DELETE",
    automod_rule,
    Events::auto_moderation_rule_delete(),
  )
  check_projection(
    "AUTO_MODERATION_RULE_UPDATE",
    automod_rule,
    Events::auto_moderation_rule_update(),
  )
  let channel =
    #|{"id":"400","type":0}
  check_projection("CHANNEL_CREATE", channel, Events::channel_create())
  check_projection("CHANNEL_DELETE", channel, Events::channel_delete())
  check_projection("CHANNEL_UPDATE", channel, Events::channel_update())
  check_projection(
    "CHANNEL_INFO",
    (
      #|{"guild_id":"100","channels":[{"id":"400"}]}
    ),
    Events::channel_info(),
  )
  check_projection(
    "CHANNEL_PINS_UPDATE",
    (
      #|{"channel_id":"400"}
    ),
    Events::channel_pins_update(),
  )
  let entitlement =
    #|{"id":"1","sku_id":"2","application_id":"900","type":8,"deleted":false}
  check_projection(
    "ENTITLEMENT_CREATE",
    entitlement,
    Events::entitlement_create(),
  )
  check_projection(
    "ENTITLEMENT_DELETE",
    entitlement,
    Events::entitlement_delete(),
  )
  check_projection(
    "ENTITLEMENT_UPDATE",
    entitlement,
    Events::entitlement_update(),
  )
  check_projection(
    "GUILD_AUDIT_LOG_ENTRY_CREATE",
    (
      #|{"guild_id":"100","id":"900","action_type":1,"target_id":null,"user_id":"200"}
    ),
    Events::guild_audit_log_entry_create(),
  )
  let ban =
    #|{"guild_id":"100","user":{"id":"200","username":"nelly","discriminator":"0","avatar":null}}
  check_projection("GUILD_BAN_ADD", ban, Events::guild_ban_add())
  check_projection("GUILD_BAN_REMOVE", ban, Events::guild_ban_remove())
  check_projection(
    "GUILD_CREATE",
    (
      #|{"id":"100","unavailable":true}
    ),
    Events::guild_create(),
  )
  check_projection(
    "GUILD_DELETE",
    (
      #|{"id":"100","unavailable":true}
    ),
    Events::guild_delete(),
  )
  check_projection(
    "GUILD_EMOJIS_UPDATE",
    (
      #|{"guild_id":"100","emojis":[]}
    ),
    Events::guild_emojis_update(),
  )
  check_projection(
    "GUILD_INTEGRATIONS_UPDATE",
    (
      #|{"guild_id":"100"}
    ),
    Events::guild_integrations_update(),
  )
  check_projection(
    "GUILD_MEMBER_ADD",
    (
      #|{"guild_id":"100","user":{"id":"200","username":"nelly","discriminator":"0","avatar":null},"roles":[],"joined_at":"2024-01-02T03:04:05.000000+00:00"}
    ),
    Events::guild_member_add(),
  )
  check_projection(
    "GUILD_MEMBER_REMOVE",
    (
      #|{"guild_id":"100","user":{"id":"200","username":"nelly","discriminator":"0","avatar":null}}
    ),
    Events::guild_member_remove(),
  )
  check_projection(
    "GUILD_MEMBERS_CHUNK",
    (
      #|{"guild_id":"100","members":[],"chunk_index":0,"chunk_count":1}
    ),
    Events::guild_members_chunk(),
  )
  check_projection(
    "GUILD_MEMBER_UPDATE",
    (
      #|{"guild_id":"100","roles":[],"user":{"id":"200","username":"nelly","discriminator":"0","avatar":null},"avatar":null,"joined_at":"2024-01-02T03:04:05.000000+00:00"}
    ),
    Events::guild_member_update(),
  )
  let role_event =
    #|{"guild_id":"100","role":{"id":"300","name":"role","color":0,"hoist":false,"position":0,"permissions":"0","managed":false,"mentionable":false}}
  check_projection("GUILD_ROLE_CREATE", role_event, Events::guild_role_create())
  check_projection("GUILD_ROLE_UPDATE", role_event, Events::guild_role_update())
  check_projection(
    "GUILD_ROLE_DELETE",
    (
      #|{"guild_id":"100","role_id":"300"}
    ),
    Events::guild_role_delete(),
  )
  let scheduled_event =
    #|{"id":"700","guild_id":"100","channel_id":null,"name":"event","scheduled_start_time":"2024-01-02T03:04:05.000000+00:00","scheduled_end_time":null,"privacy_level":2,"status":1,"entity_type":3,"entity_id":null,"entity_metadata":{"location":"moon"},"recurrence_rule":null}
  check_projection(
    "GUILD_SCHEDULED_EVENT_CREATE",
    scheduled_event,
    Events::guild_scheduled_event_create(),
  )
  check_projection(
    "GUILD_SCHEDULED_EVENT_DELETE",
    scheduled_event,
    Events::guild_scheduled_event_delete(),
  )
  check_projection(
    "GUILD_SCHEDULED_EVENT_UPDATE",
    scheduled_event,
    Events::guild_scheduled_event_update(),
  )
  let scheduled_event_user =
    #|{"guild_scheduled_event_id":"700","user_id":"200","guild_id":"100"}
  check_projection(
    "GUILD_SCHEDULED_EVENT_USER_ADD",
    scheduled_event_user,
    Events::guild_scheduled_event_user_add(),
  )
  check_projection(
    "GUILD_SCHEDULED_EVENT_USER_REMOVE",
    scheduled_event_user,
    Events::guild_scheduled_event_user_remove(),
  )
  let soundboard_sound =
    #|{"name":"boing","sound_id":"1","volume":1.0,"emoji_id":null,"emoji_name":null,"guild_id":"100","available":true}
  check_projection(
    "GUILD_SOUNDBOARD_SOUND_CREATE",
    soundboard_sound,
    Events::guild_soundboard_sound_create(),
  )
  check_projection(
    "GUILD_SOUNDBOARD_SOUND_UPDATE",
    soundboard_sound,
    Events::guild_soundboard_sound_update(),
  )
  check_projection(
    "GUILD_SOUNDBOARD_SOUND_DELETE",
    (
      #|{"sound_id":"1","guild_id":"100"}
    ),
    Events::guild_soundboard_sound_delete(),
  )
  let soundboard_sounds =
    #|{"soundboard_sounds":[],"guild_id":"100"}
  check_projection(
    "GUILD_SOUNDBOARD_SOUNDS_UPDATE",
    soundboard_sounds,
    Events::guild_soundboard_sounds_update(),
  )
  check_projection(
    "SOUNDBOARD_SOUNDS",
    soundboard_sounds,
    Events::soundboard_sounds(),
  )
  check_projection(
    "GUILD_STICKERS_UPDATE",
    (
      #|{"guild_id":"100","stickers":[]}
    ),
    Events::guild_stickers_update(),
  )
  check_projection(
    "GUILD_UPDATE",
    (
      #|{"id":"100","name":"sandbox","icon":null,"splash":null,"discovery_splash":null,"owner_id":"200","afk_channel_id":null,"afk_timeout":300,"verification_level":0,"default_message_notifications":0,"explicit_content_filter":0,"roles":[],"emojis":[],"features":[],"mfa_level":0,"application_id":null,"system_channel_id":null,"system_channel_flags":0,"rules_channel_id":null,"vanity_url_code":null,"description":null,"banner":null,"premium_tier":0,"preferred_locale":"en-US","public_updates_channel_id":null,"safety_alerts_channel_id":null}
    ),
    Events::guild_update(),
  )
  let integration =
    #|{"guild_id":"100","id":"1","name":"integration"}
  check_projection(
    "INTEGRATION_CREATE",
    integration,
    Events::integration_create(),
  )
  check_projection(
    "INTEGRATION_UPDATE",
    integration,
    Events::integration_update(),
  )
  check_projection(
    "INTEGRATION_DELETE",
    (
      #|{"id":"1","guild_id":"100"}
    ),
    Events::integration_delete(),
  )
  check_projection(
    "INTERACTION_CREATE",
    (
      #|{"id":"1","application_id":"900","type":2,"token":"interaction-token","version":1,"user":{"id":"200","username":"nelly","discriminator":"0","avatar":null},"data":{"id":"600","name":"ping","type":1}}
    ),
    Events::interaction_create(),
  )
  check_projection(
    "INVITE_CREATE",
    (
      #|{"channel_id":"400","code":"moon","created_at":"2024-01-02T03:04:05.000000+00:00","max_age":3600,"max_uses":0,"temporary":false,"uses":0,"expires_at":null}
    ),
    Events::invite_create(),
  )
  check_projection(
    "INVITE_DELETE",
    (
      #|{"channel_id":"400","guild_id":"100","code":"moon"}
    ),
    Events::invite_delete(),
  )
  let message =
    #|{"id":"500","channel_id":"400","author":{"id":"200","username":"nelly","discriminator":"0","avatar":null},"content":"hello","timestamp":"2024-01-02T03:04:05.000000+00:00","edited_timestamp":null,"tts":false,"mention_everyone":false,"mentions":[],"mention_roles":[],"attachments":[],"embeds":[],"pinned":false,"type":0}
  check_projection("MESSAGE_CREATE", message, Events::message_create())
  check_projection("MESSAGE_UPDATE", message, Events::message_update())
  check_projection(
    "MESSAGE_DELETE",
    (
      #|{"id":"500","channel_id":"400"}
    ),
    Events::message_delete(),
  )
  check_projection(
    "MESSAGE_DELETE_BULK",
    (
      #|{"ids":["500","501"],"channel_id":"400"}
    ),
    Events::message_delete_bulk(),
  )
  let poll_vote =
    #|{"user_id":"200","channel_id":"400","message_id":"500","answer_id":1}
  check_projection(
    "MESSAGE_POLL_VOTE_ADD",
    poll_vote,
    Events::message_poll_vote_add(),
  )
  check_projection(
    "MESSAGE_POLL_VOTE_REMOVE",
    poll_vote,
    Events::message_poll_vote_remove(),
  )
  check_projection(
    "MESSAGE_REACTION_ADD",
    (
      #|{"user_id":"200","channel_id":"400","message_id":"500","emoji":{"id":null,"name":"✅"},"burst":false,"type":0}
    ),
    Events::message_reaction_add(),
  )
  check_projection(
    "MESSAGE_REACTION_REMOVE",
    (
      #|{"user_id":"200","channel_id":"400","message_id":"500","emoji":{"id":null,"name":"✅"},"burst":false,"type":0}
    ),
    Events::message_reaction_remove(),
  )
  check_projection(
    "MESSAGE_REACTION_REMOVE_ALL",
    (
      #|{"channel_id":"400","message_id":"500"}
    ),
    Events::message_reaction_remove_all(),
  )
  check_projection(
    "MESSAGE_REACTION_REMOVE_EMOJI",
    (
      #|{"channel_id":"400","message_id":"500","emoji":{"id":null,"name":"✅"}}
    ),
    Events::message_reaction_remove_emoji(),
  )
  check_projection(
    "PRESENCE_UPDATE",
    (
      #|{"user":{"id":"200"},"guild_id":"100","status":"online"}
    ),
    Events::presence_update(),
  )
  check_projection(
    "RATE_LIMITED",
    (
      #|{"opcode":8,"retry_after":1.5,"meta":{}}
    ),
    Events::rate_limited(),
  )
  check_projection(
    "READY",
    (
      #|{"v":10,"user":{"id":"1","username":"bot","discriminator":"0","avatar":null},"guilds":[],"session_id":"sess","resume_gateway_url":"wss://resume.example","application":{"id":"900"}}
    ),
    Events::ready(),
  )
  let stage_instance =
    #|{"id":"1","guild_id":"100","channel_id":"400","topic":"stage","privacy_level":2,"guild_scheduled_event_id":null}
  check_projection(
    "STAGE_INSTANCE_CREATE",
    stage_instance,
    Events::stage_instance_create(),
  )
  check_projection(
    "STAGE_INSTANCE_DELETE",
    stage_instance,
    Events::stage_instance_delete(),
  )
  check_projection(
    "STAGE_INSTANCE_UPDATE",
    stage_instance,
    Events::stage_instance_update(),
  )
  let subscription =
    #|{"id":"1","user_id":"200","sku_ids":[],"entitlement_ids":[],"renewal_sku_ids":null,"current_period_start":"2024-01-02T03:04:05.000000+00:00","current_period_end":"2024-02-02T03:04:05.000000+00:00","status":0,"canceled_at":null}
  check_projection(
    "SUBSCRIPTION_CREATE",
    subscription,
    Events::subscription_create(),
  )
  check_projection(
    "SUBSCRIPTION_DELETE",
    subscription,
    Events::subscription_delete(),
  )
  check_projection(
    "SUBSCRIPTION_UPDATE",
    subscription,
    Events::subscription_update(),
  )
  check_projection(
    "THREAD_CREATE",
    (
      #|{"id":"700","type":11,"newly_created":true}
    ),
    Events::thread_create(),
  )
  check_projection(
    "THREAD_DELETE",
    (
      #|{"id":"700","guild_id":"100","parent_id":"400","type":11}
    ),
    Events::thread_delete(),
  )
  check_projection(
    "THREAD_LIST_SYNC",
    (
      #|{"guild_id":"100","threads":[],"members":[]}
    ),
    Events::thread_list_sync(),
  )
  check_projection(
    "THREAD_MEMBERS_UPDATE",
    (
      #|{"id":"700","guild_id":"100","member_count":1}
    ),
    Events::thread_members_update(),
  )
  check_projection(
    "THREAD_MEMBER_UPDATE",
    (
      #|{"guild_id":"100","id":"700","user_id":"200","join_timestamp":"2024-01-02T03:04:05.000000+00:00","flags":0}
    ),
    Events::thread_member_update(),
  )
  check_projection(
    "THREAD_UPDATE",
    (
      #|{"id":"700","type":11}
    ),
    Events::thread_update(),
  )
  check_projection(
    "TYPING_START",
    (
      #|{"channel_id":"400","user_id":"200","timestamp":123}
    ),
    Events::typing_start(),
  )
  check_projection(
    "USER_UPDATE",
    (
      #|{"id":"1","username":"bot","discriminator":"0","avatar":null}
    ),
    Events::user_update(),
  )
  check_projection(
    "VOICE_CHANNEL_EFFECT_SEND",
    (
      #|{"channel_id":"400","guild_id":"100","user_id":"200"}
    ),
    Events::voice_channel_effect_send(),
  )
  check_projection(
    "VOICE_CHANNEL_START_TIME_UPDATE",
    (
      #|{"id":"400","guild_id":"100"}
    ),
    Events::voice_channel_start_time_update(),
  )
  check_projection(
    "VOICE_CHANNEL_STATUS_UPDATE",
    (
      #|{"id":"400","guild_id":"100","status":null}
    ),
    Events::voice_channel_status_update(),
  )
  check_projection(
    "VOICE_SERVER_UPDATE",
    (
      #|{"token":"voice-token","guild_id":"100","endpoint":null}
    ),
    Events::voice_server_update(),
  )
  check_projection(
    "VOICE_STATE_UPDATE",
    (
      #|{"guild_id":"100","channel_id":"400","user_id":"200","session_id":"sess","deaf":false,"mute":false,"self_deaf":false,"self_mute":false,"suppress":false,"request_to_speak_timestamp":null}
    ),
    Events::voice_state_update(),
  )
  check_projection(
    "WEBHOOKS_UPDATE",
    (
      #|{"guild_id":"100","channel_id":"400"}
    ),
    Events::webhooks_update(),
  )
}
