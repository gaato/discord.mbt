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
  bot.gateway_bot_info_.val = Some(manager_gateway_info())
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
    ctx.voice_.connections[guild_id] = connection
    assert_true(physical_equal(ctx.join_voice(guild_id, Id(200UL)), connection))
    let gate = ctx.voice_.join_gates[guild_id]
    assert_true(physical_equal(ctx.join_voice(guild_id, Id(200UL)), connection))
    assert_true(physical_equal(ctx.voice_.join_gates[guild_id], gate))
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
    assert_eq(ctx.voice_.connections.length(), 0)
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
  bot.gateway_bot_info_.val = Some(manager_gateway_info())
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
    ctx.voice_.connections[guild_id] = connection
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
    assert_eq(ctx.voice_.connections.length(), 0)
    assert_eq(ctx.collector_.waiters.length(), 0)
    let gate = ctx.voice_.join_gates[guild_id]
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
    bot.gateway_bot_info_.val = Some(manager_gateway_info())
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

///|
async test "voice credentials register both collectors before opcode 4" {
  let transport = BotFakeTransport()
  let app = @app.App()
  let bot = middleware_runtime_bot(app, transport)
  let ready_contexts : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.on(Events::ready(), (ctx, _) => ready_contexts.put(ctx))
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, () => bot.run())
    transport.incoming.put(BOT_HELLO)
    guard transport.outgoing.get() is { "op": Number(2, ..), .. } else {
      fail("expected identify")
    }
    transport.incoming.put(bot_ready_frame())
    let ctx = ready_contexts.get()
    let guild_id : @model.GuildId = @model.Id::parse("100")
    let channel_id : @model.ChannelId = @model.Id::parse("200")
    let credentials = group.spawn(no_wait=true, () => {
      ctx.request_voice_credentials(guild_id, channel_id, false, true, 500)
    })
    guard transport.outgoing.get()
      is {
        "op": Number(4, ..),
        "d": {
          "guild_id": String("100"),
          "channel_id": String("200"),
          "self_mute": False,
          "self_deaf": True,
          ..
        },
        ..
      } else {
      fail("expected voice state update")
    }
    // Deliver both events as soon as opcode 4 is observed. A null endpoint
    // must not consume the server waiter.
    transport.incoming.put(voice_server_frame(2, None, "stale-token"))
    transport.incoming.put(voice_state_frame(3, "voice-session"))
    transport.incoming.put(
      voice_server_frame(4, Some("voice.example"), "voice-token"),
    )
    debug_inspect(
      credentials.wait(),
      content=(
        #|{
        #|  server_id: "100",
        #|  session_id: "voice-session",
        #|  token: "voice-token",
        #|  endpoint: "voice.example",
        #|}
      ),
    )
    ctx.shutdown()
    running.wait()
  })
}

///|
async test "join_voice fails before opcode 4 without guild voice states intent" {
  let transport = BotFakeTransport()
  let app = @app.App()
  let bot = middleware_runtime_bot(app, transport)
  let ready_contexts : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.on(Events::ready(), (ctx, _) => ready_contexts.put(ctx))
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, () => bot.run())
    transport.incoming.put(BOT_HELLO)
    guard transport.outgoing.get() is { "op": Number(2, ..), .. } else {
      fail("expected identify")
    }
    transport.incoming.put(bot_ready_frame())
    let ctx = ready_contexts.get()
    let guild_id : @model.GuildId = @model.Id::parse("100")
    let channel_id : @model.ChannelId = @model.Id::parse("200")
    try
      @async.with_timeout(
        100,
        () => ctx.join_voice(guild_id, channel_id, timeout_ms=60_000),
        error=@voice.VoiceError::JoinTimeout,
      )
    catch {
      @voice.VoiceError::MissingIntent(intent~) =>
        inspect(intent, content="GUILD_VOICE_STATES")
      @voice.VoiceError::JoinTimeout =>
        fail("join_voice waited instead of diagnosing the missing intent")
      error => fail("unexpected voice join error: \{Repr(error)}")
    } noraise {
      _ => fail("join_voice unexpectedly succeeded")
    }
    assert_true(transport.outgoing.try_get() is None)
    ctx.shutdown()
    running.wait()
  })
}

///|
test "voice state command encodes a disconnect as a null channel" {
  let disconnect = voice_state_command(
    @model.Id::parse("100"),
    None,
    false,
    true,
  )
  inspect(
    disconnect.stringify(),
    content=(
      #|{"op":4,"d":{"guild_id":"100","channel_id":null,"self_mute":false,"self_deaf":true}}
    ),
  )
}

///|
fn voice_state_frame(sequence : Int, endpoint_session : String) -> String {
  (
    #|{"op":0,"s":SEQUENCE_PLACEHOLDER,"t":"VOICE_STATE_UPDATE","d":{"guild_id":"100","channel_id":"200","user_id":"1","session_id":"SESSION_PLACEHOLDER","deaf":false,"mute":false,"self_deaf":false,"self_mute":false,"suppress":false,"request_to_speak_timestamp":null}}
  )
  .replace(old="SEQUENCE_PLACEHOLDER", new=sequence.to_string())
  .replace(old="SESSION_PLACEHOLDER", new=endpoint_session)
}

///|
fn voice_server_frame(
  sequence : Int,
  endpoint : String?,
  token : String,
) -> String {
  let endpoint_json = match endpoint {
    Some(value) => "\"\{value}\""
    None => "null"
  }
  (
    #|{"op":0,"s":SEQUENCE_PLACEHOLDER,"t":"VOICE_SERVER_UPDATE","d":{"token":"TOKEN_PLACEHOLDER","guild_id":"100","endpoint":ENDPOINT_PLACEHOLDER}}
  )
  .replace(old="SEQUENCE_PLACEHOLDER", new=sequence.to_string())
  .replace(old="TOKEN_PLACEHOLDER", new=token)
  .replace(old="ENDPOINT_PLACEHOLDER", new=endpoint_json)
}
