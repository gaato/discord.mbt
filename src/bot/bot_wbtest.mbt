///|
fn typed_event(name : String, fixture : String) -> @model.Event raise {
  @model.dispatch_event(name, @json.parse(fixture))
}

///|
test "typed event descriptors project representative payloads" {
  let command_permissions = typed_event(
    "APPLICATION_COMMAND_PERMISSIONS_UPDATE",
    (
      #|{"id":"800","application_id":"900","guild_id":"100","permissions":[]}
    ),
  )
  guard Events::application_command_permissions_update().project(
      command_permissions,
    )
    is Some(command_permissions_payload) else {
    fail("expected command permissions payload")
  }
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
  let guild_create = typed_event(
    "GUILD_CREATE",
    (
      #|{"id":"100","unavailable":true}
    ),
  )
  guard Events::guild_create().project(guild_create)
    is Some(Unavailable(guild_create_payload)) else {
    fail("expected guild create payload")
  }
  let presence = typed_event(
    "PRESENCE_UPDATE",
    (
      #|{"user":{"id":"200"},"guild_id":false,"status":"online"}
    ),
  )
  guard Events::presence_update().project(presence) is Some(presence_payload) else {
    fail("expected presence payload")
  }
  let subscription_fixture =
    #|{"id":"600","user_id":"200","sku_ids":["610"],"entitlement_ids":["620"],"renewal_sku_ids":null,"current_period_start":"2025-06-01T00:00:00Z","current_period_end":"2025-07-01T00:00:00Z","status":0,"canceled_at":null}
  let subscription_create = typed_event(
    "SUBSCRIPTION_CREATE", subscription_fixture,
  )
  let subscription_update = typed_event(
    "SUBSCRIPTION_UPDATE", subscription_fixture,
  )
  let subscription_delete = typed_event(
    "SUBSCRIPTION_DELETE", subscription_fixture,
  )
  guard Events::subscription_create().project(subscription_create)
    is Some(subscription_create_payload) else {
    fail("expected subscription create payload")
  }
  guard Events::subscription_update().project(subscription_update)
    is Some(subscription_update_payload) else {
    fail("expected subscription update payload")
  }
  guard Events::subscription_delete().project(subscription_delete)
    is Some(subscription_delete_payload) else {
    fail("expected subscription delete payload")
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
      command_permissions_payload.application_id.to_string(),
      guild_create_payload.id.to_string(),
      presence_payload.status.map(status => status.to_string()).unwrap_or(""),
      subscription_create_payload.id.to_string(),
      subscription_update_payload.id.to_string(),
      subscription_delete_payload.id.to_string(),
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
      #|  "900",
      #|  "100",
      #|  "online",
      #|  "600",
      #|  "600",
      #|  "600",
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
  let actual : ReadOnlyArray[@model.EventKind] = [
    Events::application_command_permissions_update().kind(),
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
    Events::guild_create().kind(),
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
    Events::presence_update().kind(),
    Events::rate_limited().kind(),
    Events::ready().kind(),
    Events::stage_instance_create().kind(),
    Events::stage_instance_delete().kind(),
    Events::stage_instance_update().kind(),
    Events::subscription_create().kind(),
    Events::subscription_delete().kind(),
    Events::subscription_update().kind(),
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
  let expected : ReadOnlyArray[@model.EventKind] = [
    KApplicationCommandPermissionsUpdate,
    KAutoModerationActionExecution,
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
    KGuildCreate,
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
    KPresenceUpdate,
    KRateLimited,
    KReady,
    KStageInstanceCreate,
    KStageInstanceDelete,
    KStageInstanceUpdate,
    KSubscriptionCreate,
    KSubscriptionDelete,
    KSubscriptionUpdate,
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

///|
priv struct PendingBotVoiceTransport {
  incoming : @aqueue.Queue[@voice.VoiceFrame]
  outgoing : @aqueue.Queue[Json]
  recv_started : @aqueue.Queue[Unit]
  close_calls : Ref[Int]
}

///|
fn PendingBotVoiceTransport::new() -> PendingBotVoiceTransport {
  {
    incoming: Queue(kind=Unbounded),
    outgoing: Queue(kind=Unbounded),
    recv_started: Queue(kind=Unbounded),
    close_calls: Ref(0),
  }
}

///|
impl @voice.VoiceTransport for PendingBotVoiceTransport with fn recv(self) {
  self.recv_started.put(())
  self.incoming.get()
}

///|
impl @voice.VoiceTransport for PendingBotVoiceTransport with fn send_text(
  self,
  text,
) {
  self.outgoing.put(@json.parse(text))
}

///|
impl @voice.VoiceTransport for PendingBotVoiceTransport with fn send_binary(
  _self,
  _bytes,
) {

}

///|
impl @voice.VoiceTransport for PendingBotVoiceTransport with fn close(
  self,
  code~,
) {
  self.close_calls.val += 1
  self.incoming.close(
    error=@voice.VoiceTransportClosed(code=Some(code), reason="client close"),
  )
}

///|
fn bot_voice_test_credentials() -> @voice.VoiceCredentials {
  {
    server_id: "guild",
    session_id: "session",
    token: "token",
    endpoint: "voice.example",
  }
}

///|
fn[X] pending_bot_voice_connection(
  group : @async.TaskGroup[X],
  transport : PendingBotVoiceTransport,
  leave_calls : Ref[Int],
) -> @voice.VoiceConnection {
  @voice.VoiceConnection::start(
    group,
    bot_voice_test_credentials(),
    user_id="100",
    channel_id=7UL,
    leave=() => leave_calls.val += 1,
    rejoin=() => bot_voice_test_credentials(),
    connector=_ => (transport : &@voice.VoiceTransport),
    receive=false,
  )
}

///|
async test "voice ready timeout disconnects the pending connection" {
  let transport = PendingBotVoiceTransport::new()
  let leave_calls = Ref(0)
  @async.with_task_group(group => {
    let connection = pending_bot_voice_connection(group, transport, leave_calls)
    transport.recv_started.get()
    try wait_ready_or_disconnect(connection, 10) catch {
      @voice.VoiceError::JoinTimeout => ()
      error => fail("unexpected ready-wait error: \{Repr(error)}")
    } noraise {
      _ => fail("voice ready wait unexpectedly succeeded")
    }
    assert_eq(leave_calls.val, 1)
    assert_eq(transport.close_calls.val, 1)
    assert_eq(connection.state(), Closed(code=None))
  })
}

///|
async test "voice ready cancellation disconnects the pending connection" {
  let transport = PendingBotVoiceTransport::new()
  let leave_calls = Ref(0)
  @async.with_task_group(group => {
    let connection = pending_bot_voice_connection(group, transport, leave_calls)
    transport.recv_started.get()
    let started : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
    let waiting = group.spawn(no_wait=true, allow_failure=true, () => {
      started.put(())
      wait_ready_or_disconnect(connection, 60_000)
    })
    started.get()
    waiting.cancel()
    try waiting.wait() catch {
      @async.TaskCancelled => ()
      error => fail("unexpected ready-wait cancellation error: \{Repr(error)}")
    } noraise {
      _ => fail("cancelled voice ready wait unexpectedly completed")
    }
    assert_eq(leave_calls.val, 1)
    assert_eq(transport.close_calls.val, 1)
    assert_eq(connection.state(), Closed(code=None))
  })
}

///|
async test "join_voice reuses its per-guild connection and handles a failed server-update rejoin" {
  if !@voice.shim_available() {
    return
  }
  let transport = BotFakeTransport()
  let client = @dhttp.Client("test-token")
  defer client.close()
  let bot = Bot(
    @app.App(),
    token="test-token",
    client~,
    intents=@model.Intents::guild_voice_states(),
    gateway_url="wss://gateway.example",
  )
  bot.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
  let ready : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.on(Events::ready(), (ctx, _) => ready.put(ctx))
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, () => bot.run())
    transport.incoming.put(BOT_HELLO)
    transport.outgoing.get() |> ignore
    transport.incoming.put(bot_ready_frame())
    let ctx = ready.get()
    let voice_transport = PendingBotVoiceTransport::new()
    let connection = pending_bot_voice_connection(
      group,
      voice_transport,
      Ref(0),
    )
    voice_transport.incoming.put(
      Text("{\"op\":8,\"d\":{\"heartbeat_interval\":60000}}"),
    )
    voice_transport.outgoing.get() |> ignore
    voice_transport.incoming.put(
      Text(
        "{\"op\":4,\"d\":{\"mode\":\"aead_aes256_gcm_rtpsize\",\"secret_key\":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\"dave_protocol_version\":0}}",
      ),
    )
    assert_eq(connection.next_event(), ConnectionReady)
    let guild_id : @model.GuildId = Id(100UL)
    ctx.voice_connections_[guild_id] = connection
    assert_true(physical_equal(ctx.join_voice(guild_id, Id(200UL)), connection))
    let gate = ctx.voice_join_gates_[guild_id]
    assert_true(physical_equal(ctx.join_voice(guild_id, Id(200UL)), connection))
    assert_true(physical_equal(ctx.voice_join_gates_[guild_id], gate))
    assert_eq(transport.outgoing.try_get(), None)
    let watching = group.spawn(no_wait=true, () => {
      ctx.watch_voice_server_updates(
        guild_id,
        Id(200UL),
        false,
        true,
        1000,
        connection,
        Ref(false),
      )
    })
    @async.pause()
    assert_eq(ctx.collector_.waiters.length(), 1)
    transport.outgoing.close(
      error=@gateway.TransportClosed(
        code=None,
        reason="fake rejoin send failure",
      ),
    )
    ctx.collector_.dispatch(
      @model.Event::VoiceServerUpdate({
        guild_id,
        token: "new-token",
        endpoint: Value("voice-new.example"),
      }),
    )
    watching.wait()
    assert_eq(connection.state(), Closed(code=None))
    assert_eq(ctx.voice_connections_.length(), 0)
    assert_eq(ctx.collector_.waiters.length(), 0)
    ctx.shutdown()
    running.wait()
  })
}

///|
async test "join_voice evicts closed connections and releases its gate after send failure" {
  let transport = BotFakeTransport()
  let client = @dhttp.Client("test-token")
  defer client.close()
  let bot = Bot(
    @app.App(),
    token="test-token",
    client~,
    intents=@model.Intents::guild_voice_states(),
    gateway_url="wss://gateway.example",
  )
  bot.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
  let ready : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.on(Events::ready(), (ctx, _) => ready.put(ctx))
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, () => bot.run())
    transport.incoming.put(BOT_HELLO)
    transport.outgoing.get() |> ignore
    transport.incoming.put(bot_ready_frame())
    let ctx = ready.get()
    let connection = pending_bot_voice_connection(
      group,
      PendingBotVoiceTransport::new(),
      Ref(0),
    )
    connection.disconnect()
    let guild_id : @model.GuildId = Id(100UL)
    ctx.voice_connections_[guild_id] = connection
    transport.outgoing.close(
      error=@gateway.TransportClosed(code=None, reason="fake send failure"),
    )
    try ctx.join_voice(guild_id, Id(200UL)) |> ignore catch {
      @gateway.TransportClosed(reason~, ..) =>
        assert_eq(reason, "fake send failure")
      error => fail("unexpected join error: \{Repr(error)}")
    } noraise {
      _ => fail("expected the join send to fail")
    }
    assert_eq(ctx.voice_connections_.length(), 0)
    assert_eq(ctx.collector_.waiters.length(), 0)
    let gate = ctx.voice_join_gates_[guild_id]
    gate.acquire()
    gate.release()
    ctx.shutdown()
    running.wait()
  })
}

///|
async test "voice server watcher unregisters after collector failure or a nonready update" {
  for fail_wait in [false, true] {
    let transport = BotFakeTransport()
    let client = @dhttp.Client("test-token")
    defer client.close()
    let bot = Bot(
      @app.App(),
      token="test-token",
      client~,
      intents=@model.Intents::guild_voice_states(),
      gateway_url="wss://gateway.example",
    )
    bot.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
    let ready : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
    bot.on(Events::ready(), (ctx, _) => ready.put(ctx))
    @async.with_task_group(group => {
      let running = group.spawn(no_wait=true, () => bot.run())
      transport.incoming.put(BOT_HELLO)
      transport.outgoing.get() |> ignore
      transport.incoming.put(bot_ready_frame())
      let ctx = ready.get()
      let connection = pending_bot_voice_connection(
        group,
        PendingBotVoiceTransport::new(),
        Ref(0),
      )
      let watching = group.spawn(no_wait=true, () => {
        ctx.watch_voice_server_updates(
          Id(100UL),
          Id(200UL),
          false,
          true,
          1000,
          connection,
          Ref(false),
        )
      })
      @async.pause()
      assert_eq(ctx.collector_.waiters.length(), 1)
      if fail_wait {
        ctx.collector_.waiters[0].queue.close(
          error=@voice.VoiceError::Disconnected,
        )
      } else {
        ctx.collector_.dispatch(
          @model.Event::VoiceServerUpdate({
            guild_id: Id(100UL),
            token: "voice-token",
            endpoint: Value("voice.example"),
          }),
        )
      }
      watching.wait()
      assert_eq(ctx.collector_.waiters.length(), 0)
      assert_eq(connection.state(), Connecting)
      connection.disconnect()
      ctx.shutdown()
      running.wait()
    })
  }
}
