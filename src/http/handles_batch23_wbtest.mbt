///|
async test "handle unit delegations pin every bound id at the wire boundary" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let calls : Array[String] = []
  perform.val = Some((route, path, _headers, _body, _files) => {
    calls.push("\{@debug.to_string(route.method_())} \{path}")
    { status: 204, headers: Map([]), body: Json::null(), }
  })
  let application_id : @model.ApplicationId = Id(10UL)
  let emoji_id : @model.EmojiId = Id(11UL)
  let command_id : @model.CommandId = Id(12UL)
  let entitlement_id : @model.EntitlementId = Id(13UL)
  client.application_emoji_ref(application_id, emoji_id).delete()
  client.global_command_ref(application_id, command_id).delete()
  client.entitlement_ref(application_id, entitlement_id).consume()
  client.entitlement_ref(application_id, entitlement_id).delete_test()

  let guild_id : @model.GuildId = Id(20UL)
  let channel_id : @model.ChannelId = Id(30UL)
  let message_id : @model.MessageId = Id(40UL)
  let user_id : @model.UserId = Id(50UL)
  let role_id : @model.RoleId = Id(60UL)
  let integration_id : @model.IntegrationId = Id(70UL)
  let channel = client.channel_ref(channel_id)
  channel.group_dm_add_recipient(user_id, "oauth-token", nick="Nelly")
  channel.group_dm_remove_recipient(user_id)
  channel.join_thread()
  channel.leave_thread()
  channel.add_thread_member(user_id)
  channel.remove_thread_member(user_id)
  channel.delete_stage_instance(reason="cleanup")

  let member_handle = client.member_ref(guild_id, user_id)
  member_handle.kick(reason="cleanup")
  member_handle.add_role(role_id, reason="grant")
  member_handle.remove_role(role_id, reason="revoke")
  client
  .guild_ref(guild_id)
  .delete_integration(integration_id, reason="cleanup")
  client.guild_ref(guild_id).leave()
  client.role_ref(guild_id, role_id).delete(reason="cleanup")

  let message = client.message_ref(channel_id, message_id)
  message.delete(reason="cleanup")
  message.unpin(reason="cleanup")
  message.react("wave:80")
  message.delete_reactions()
  message.delete_reactions_for("wave:80")

  let webhook_id : @model.WebhookId = Id(80UL)
  client.webhook_ref(webhook_id).delete(reason="cleanup")
  let webhook = client.webhook_token_ref(webhook_id, "tok")
  webhook.delete()
  webhook.send_slack({ "text": "hello" }, thread_id=channel_id, wait=false)
  webhook.send_github(
    { "action": "opened" },
    github_event="issues",
    thread_id=channel_id,
    wait=true,
  )

  let sticker_id : @model.StickerId = Id(90UL)
  let sound_id : @model.SoundboardSoundId = Id(91UL)
  let event_id : @model.ScheduledEventId = Id(92UL)
  let rule_id : @model.AutoModerationRuleId = Id(93UL)
  client.sticker_ref(guild_id, sticker_id).delete(reason="cleanup")
  client.soundboard_sound_ref(guild_id, sound_id).delete(reason="cleanup")
  client.scheduled_event_ref(guild_id, event_id).delete(reason="cleanup")
  client.auto_moderation_rule_ref(guild_id, rule_id).delete(reason="cleanup")

  assert_eq(calls, [
    "Delete /api/v10/applications/10/emojis/11", "Delete /api/v10/applications/10/commands/12",
    "Post /api/v10/applications/10/entitlements/13/consume", "Delete /api/v10/applications/10/entitlements/13",
    "Put /api/v10/channels/30/recipients/50", "Delete /api/v10/channels/30/recipients/50",
    "Put /api/v10/channels/30/thread-members/@me", "Delete /api/v10/channels/30/thread-members/@me",
    "Put /api/v10/channels/30/thread-members/50", "Delete /api/v10/channels/30/thread-members/50",
    "Delete /api/v10/stage-instances/30", "Delete /api/v10/guilds/20/members/50",
    "Put /api/v10/guilds/20/members/50/roles/60", "Delete /api/v10/guilds/20/members/50/roles/60",
    "Delete /api/v10/guilds/20/integrations/70", "Delete /api/v10/users/@me/guilds/20",
    "Delete /api/v10/guilds/20/roles/60", "Delete /api/v10/channels/30/messages/40",
    "Delete /api/v10/channels/30/messages/pins/40", "Put /api/v10/channels/30/messages/40/reactions/wave%3A80/@me",
    "Delete /api/v10/channels/30/messages/40/reactions", "Delete /api/v10/channels/30/messages/40/reactions/wave%3A80",
    "Delete /api/v10/webhooks/80", "Delete /api/v10/webhooks/80/tok", "Post /api/v10/webhooks/80/tok/slack?thread_id=30&wait=false",
    "Post /api/v10/webhooks/80/tok/github?thread_id=30&wait=true", "Delete /api/v10/guilds/20/stickers/90",
    "Delete /api/v10/guilds/20/soundboard-sounds/91", "Delete /api/v10/guilds/20/scheduled-events/92",
    "Delete /api/v10/guilds/20/auto-moderation/rules/93",
  ])
}
