///|
fn fetched_command(fixture : String) -> @model.ApplicationCommand raise {
  @json.from_json(@json.parse(fixture))
}

///|
fn fetched_ping(
  name? : String = "ping",
  description? : String = "Check latency",
) -> @model.ApplicationCommand raise {
  fetched_command(
    (
      #|{
      #|  "id": "900000000000000001",
      #|  "application_id": "400000000000000001",
      #|  "type": 1,
      #|  "name": "NAME_PLACEHOLDER",
      #|  "description": "DESCRIPTION_PLACEHOLDER",
      #|  "default_member_permissions": null,
      #|  "version": "900000000000000002",
      #|  "dm_permission": true
      #|}
    )
    .replace(old="NAME_PLACEHOLDER", new=name)
    .replace(old="DESCRIPTION_PLACEHOLDER", new=description),
  )
}

///|
test "commands_in_sync compares declarations and ignores server fields" {
  let ping = @interaction.CommandSpec::slash("ping", "Check latency")
  let echo_arg = @interaction.arg_string(
    name="text",
    description="Text to echo",
  )
  let echo = @interaction.CommandSpec::slash(
    "echo",
    "Echo text",
    options=@interaction.Args::of(echo_arg).definitions(),
  )
  let echo_matching = fetched_command(
    (
      #|{
      #|  "id": "900000000000000003",
      #|  "application_id": "400000000000000001",
      #|  "type": 1,
      #|  "name": "echo",
      #|  "description": "Echo text",
      #|  "options": [
      #|    {
      #|      "type": 3,
      #|      "name": "text",
      #|      "description": "Text to echo",
      #|      "required": true
      #|    }
      #|  ],
      #|  "default_member_permissions": null,
      #|  "version": "900000000000000004"
      #|}
    ),
  )
  let echo_wrong_required = fetched_command(
    (
      #|{
      #|  "id": "900000000000000003",
      #|  "application_id": "400000000000000001",
      #|  "type": 1,
      #|  "name": "echo",
      #|  "description": "Echo text",
      #|  "options": [
      #|    {
      #|      "type": 3,
      #|      "name": "text",
      #|      "description": "Text to echo",
      #|      "required": false
      #|    }
      #|  ],
      #|  "default_member_permissions": null,
      #|  "version": "900000000000000004"
      #|}
    ),
  )
  let ping_with_option = fetched_command(
    (
      #|{
      #|  "id": "900000000000000001",
      #|  "application_id": "400000000000000001",
      #|  "type": 1,
      #|  "name": "ping",
      #|  "description": "Check latency",
      #|  "options": [
      #|    {"type":3,"name":"extra","description":"Extra","required":false}
      #|  ],
      #|  "default_member_permissions": null,
      #|  "version": "900000000000000002"
      #|}
    ),
  )
  debug_inspect(
    [
      @app.commands_in_sync([ping], [fetched_ping()]),
      @app.commands_in_sync([ping], [fetched_ping(description="Changed")]),
      @app.commands_in_sync([ping], [ping_with_option]),
      @app.commands_in_sync([echo], [echo_wrong_required]),
      @app.commands_in_sync([ping], [fetched_ping(name="other")]),
      @app.commands_in_sync([echo], [echo_matching]),
    ],
    content="[true, false, false, false, false, true]",
  )
}

///|
test "commands_in_sync normalizes command defaults and uses type plus name" {
  let slash = @interaction.CommandSpec::slash("inspect", "Inspect a target")
  assert_false(slash.to_json().stringify().contains("\"type\""))
  let response = fetched_command(
    (
      #|{
      #|  "id": "900000000000000010",
      #|  "application_id": "400000000000000001",
      #|  "type": 1,
      #|  "name": "inspect",
      #|  "description": "Inspect a target",
      #|  "default_member_permissions": null,
      #|  "dm_permission": true,
      #|  "nsfw": false,
      #|  "integration_types": [0],
      #|  "contexts": null,
      #|  "version": "900000000000000011"
      #|}
    ),
  )
  let wrong_nsfw = fetched_command(
    response
    .to_json()
    .stringify()
    .replace(old="\"nsfw\":false", new="\"nsfw\":true"),
  )
  let wrong_integration = fetched_command(
    response
    .to_json()
    .stringify()
    .replace(old="\"integration_types\":[0]", new="\"integration_types\":[1]"),
  )
  let wrong_contexts = fetched_command(
    response
    .to_json()
    .stringify()
    .replace(old="\"contexts\":null", new="\"contexts\":[0]"),
  )
  let wrong_dm_permission = fetched_command(
    response
    .to_json()
    .stringify()
    .replace(old="\"dm_permission\":true", new="\"dm_permission\":false"),
  )
  let wrong_permissions = fetched_command(
    response
    .to_json()
    .stringify()
    .replace(
      old="\"default_member_permissions\":null",
      new="\"default_member_permissions\":\"8\"",
    ),
  )
  let wrong_type = fetched_command(
    response.to_json().stringify().replace(old="\"type\":1", new="\"type\":2"),
  )
  debug_inspect(
    [
      @app.commands_in_sync([slash], [response]),
      @app.commands_in_sync([slash], [wrong_nsfw]),
      @app.commands_in_sync([slash], [wrong_integration]),
      @app.commands_in_sync([slash], [wrong_contexts]),
      @app.commands_in_sync([slash], [wrong_dm_permission]),
      @app.commands_in_sync([slash], [wrong_permissions]),
      @app.commands_in_sync([slash], [wrong_type]),
    ],
    content="[true, false, false, false, false, false, false]",
  )
  let explicit_defaults = @interaction.CommandSpec::slash(
    "inspect",
    "Inspect a target",
    nsfw=false,
    integration_types=[@model.ApplicationIntegrationType::GuildInstall],
  )
  let omitted_defaults = fetched_command(
    (
      #|{
      #|  "id": "900000000000000014",
      #|  "application_id": "400000000000000001",
      #|  "name": "inspect",
      #|  "description": "Inspect a target",
      #|  "default_member_permissions": null,
      #|  "version": "900000000000000015"
      #|}
    ),
  )
  assert_true(@app.commands_in_sync([explicit_defaults], [omitted_defaults]))
  let user = @interaction.CommandSpec::user("inspect")
  let user_response = fetched_command(
    (
      #|{
      #|  "id": "900000000000000012",
      #|  "application_id": "400000000000000001",
      #|  "type": 2,
      #|  "name": "inspect",
      #|  "description": "",
      #|  "default_member_permissions": null,
      #|  "dm_permission": true,
      #|  "nsfw": false,
      #|  "integration_types": [0],
      #|  "contexts": null,
      #|  "version": "900000000000000013"
      #|}
    ),
  )
  assert_true(@app.commands_in_sync([slash, user], [response, user_response]))
}

///|
test "intent derivation strips privileged intents and warns" {
  let app = @app.App::new(sync=@app.CommandSync::Disabled)
  let bot = Bot::new(app, token="token")
  let warnings : Array[String] = []
  app.on_warn(message => warnings.push(message))
  bot.on(Events::message_create(), (_, _) => ())
  bot.on(Events::guild_member_add(), (_, _) => ())
  inspect(bot.resolved_intents().bits(), content="4608")
  inspect(warnings.length(), content="1")
  assert_true(warnings[0].contains("privileged intent"))
  let explicit_app = @app.App::new(sync=@app.CommandSync::Disabled)
  let explicit = Bot::new(
    explicit_app,
    token="token",
    intents=@model.Intents::guilds(),
  )
  let explicit_warnings : Array[String] = []
  explicit_app.on_warn(message => explicit_warnings.push(message))
  explicit.on(Events::message_create(), (_, _) => ())
  inspect(explicit.resolved_intents().bits(), content="1")
  inspect(explicit_warnings.length(), content="1")
}

///|
test "cache attachment keeps the gateway filter open and shares state" {
  let app = @app.App::new(sync=@app.CommandSync::Disabled)
  let bot = Bot::new(app, token="token")
  let cache = @cache.InMemoryCache::new(
    resources=@cache.CacheResources::default(),
  )
  bot.attach_cache(cache)
  let filter = bot.event_filter()
  assert_true(filter(KReady))
  assert_true(filter(KInviteDelete))
  guard bot.cache_ is Some(attached) else { fail("expected attached cache") }
  attached.update(
    @model.Event::GuildDelete({ id: @model.Id::parse("100"), unavailable: true }),
  )
  let guild_id : @model.GuildId = @model.Id::parse("100")
  assert_true(cache.is_guild_unavailable(guild_id))
}

///|
priv suberror RuntimeTestFailure {
  RuntimeTestFailure
} derive(Debug)

///|
test "bot telemetry hook failures flow to app warnings" {
  let app = @app.App::new(sync=@app.CommandSync::Disabled)
  let warnings : Array[String] = []
  app.on_warn(message => warnings.push(message))
  let bot = Bot::new(app, token="test-token")
  bot.on_telemetry(_ => raise RuntimeTestFailure)
  bot.emit_telemetry(
    @telemetry.TelemetryEvent::DecodeError(marker="DECODE_ERROR:test"),
  )
  inspect(warnings.length(), content="1")
  assert_true(warnings[0].contains("telemetry hook failed"))
}

///|
struct BotFakeTransport {
  incoming : @aqueue.Queue[String]
  outgoing : @aqueue.Queue[Json]
}

///|
fn BotFakeTransport::new() -> BotFakeTransport {
  {
    incoming: @aqueue.Queue::new(kind=Unbounded),
    outgoing: @aqueue.Queue::new(kind=Unbounded),
  }
}

///|
impl @gateway.GatewayTransport for BotFakeTransport with fn recv(self) {
  @gateway.GatewayFrame::Text(
    self.incoming.get() catch {
      error => raise error
    },
  )
}

///|
impl @gateway.GatewayTransport for BotFakeTransport with fn send(self, text) {
  self.outgoing.put(@json.parse(text) catch { _ => Json::null() })
}

///|
impl @gateway.GatewayTransport for BotFakeTransport with fn close(self, code~) {
  self.incoming.close(
    error=@gateway.TransportClosed(code=Some(code), reason="client closed"),
  )
}

///|
const BOT_HELLO : String =
  #|{"op":10,"d":{"heartbeat_interval":60000}}

///|
fn bot_ready_frame() -> String {
  (
    #|{"op":0,"s":1,"t":"READY","d":{"v":10,"user":{"id":"1","username":"bot","discriminator":"0","global_name":null,"avatar":null},"guilds":[],"session_id":"sess-bot","resume_gateway_url":"wss://resume.example","application":{"id":"42"},"shard":[0,1]}}
  )
}

///|
fn command_frame(sequence : Int, id : String, name? : String = "raw") -> String {
  (
    #|{"op":0,"s":SEQUENCE_PLACEHOLDER,"t":"INTERACTION_CREATE","d":{"id":"ID_PLACEHOLDER","application_id":"42","type":2,"token":"interaction-token","version":1,"user":{"id":"200000000000000001","username":"nelly","discriminator":"0","global_name":"Nelly","avatar":null},"data":{"id":"600000000000000001","name":"NAME_PLACEHOLDER","type":1}}}
  )
  .replace(old="SEQUENCE_PLACEHOLDER", new=sequence.to_string())
  .replace(old="ID_PLACEHOLDER", new=id)
  .replace(old="NAME_PLACEHOLDER", new=name)
}

///|
fn malformed_interaction_frame(sequence : Int) -> String {
  (
    #|{"op":0,"s":SEQUENCE_PLACEHOLDER,"t":"INTERACTION_CREATE","d":{"id":"500000000000000099","application_id":"42","type":"not-a-number","token":"payload-must-stay-private","version":1}}
  ).replace(old="SEQUENCE_PLACEHOLDER", new=sequence.to_string())
}

///|
fn message_delete_frame(sequence : Int, id : String) -> String {
  (
    #|{"op":0,"s":SEQUENCE_PLACEHOLDER,"t":"MESSAGE_DELETE","d":{"id":"ID_PLACEHOLDER","channel_id":"6"}}
  )
  .replace(old="SEQUENCE_PLACEHOLDER", new=sequence.to_string())
  .replace(old="ID_PLACEHOLDER", new=id)
}

///|
fn message_create_frame(sequence : Int, id : String) -> String {
  (
    #|{"op":0,"s":SEQUENCE_PLACEHOLDER,"t":"MESSAGE_CREATE","d":{"id":"ID_PLACEHOLDER","channel_id":"6","author":{"id":"200","username":"nelly","discriminator":"0","avatar":null},"content":"cached","timestamp":"2025-06-01T10:00:00Z","edited_timestamp":null,"tts":false,"mention_everyone":false,"mentions":[],"mention_roles":[],"attachments":[],"embeds":[],"pinned":false,"type":0}}
  )
  .replace(old="SEQUENCE_PLACEHOLDER", new=sequence.to_string())
  .replace(old="ID_PLACEHOLDER", new=id)
}

///|
async test "bot updates cache before typed event handlers" {
  let transport = BotFakeTransport::new()
  let app = @app.App::new(sync=@app.CommandSync::Disabled)
  let bot = Bot::new(
    app,
    token="test-token",
    intents=@model.Intents::guild_messages(),
    client=@dhttp.Client::new("test-token"),
    gateway_url="wss://gateway.example",
  )
  bot.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
  let cache = @cache.InMemoryCache::new(
    resources=@cache.CacheResources::new(messages=true),
  )
  bot.attach_cache(cache)
  let ready_contexts : @aqueue.Queue[GatewayCtx] = @aqueue.Queue::new(
    kind=Unbounded,
  )
  bot.on(Events::ready(), (ctx, _) => ready_contexts.put(ctx))
  let observed : @aqueue.Queue[Bool] = @aqueue.Queue::new(kind=Unbounded)
  bot.on(Events::message_create(), (_, event) => {
    observed.put(
      cache.message(event.message.channel_id, event.message.id) is Some(_),
    )
  })
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, () => bot.run())
    transport.incoming.put(BOT_HELLO)
    guard transport.outgoing.get() is { "op": Number(2, ..), .. } else {
      fail("expected identify")
    }
    transport.incoming.put(bot_ready_frame())
    let ctx = ready_contexts.get()
    transport.incoming.put(message_create_frame(2, "700"))
    assert_true(observed.get())
    ctx.shutdown()
    running.wait()
  })
}

///|
async test "bot run dispatches concurrently, survives handlers, and shuts down" {
  let empty_app = @app.App::new(sync=@app.CommandSync::Disabled)
  try Bot::new(empty_app, token="").run() catch {
    @app.AppConfigError::EmptyToken => ()
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected empty token error")
  }
  let transport = BotFakeTransport::new()
  let app = @app.App::new(sync=@app.CommandSync::Disabled, max_in_flight=8)
  let bot = Bot::new(
    app,
    token="test-token",
    client=@dhttp.Client::new("test-token"),
    gateway_url="wss://gateway.example",
  )
  bot.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
  let ready_contexts : @aqueue.Queue[GatewayCtx] = @aqueue.Queue::new(
    kind=Unbounded,
  )
  bot.on(Events::ready(), (ctx, _) => ready_contexts.put(ctx))
  let command_count = Ref(0)
  let first_started : @aqueue.Queue[Unit] = @aqueue.Queue::new(kind=Unbounded)
  let release_first : @aqueue.Queue[Unit] = @aqueue.Queue::new(kind=Unbounded)
  let second_started : @aqueue.Queue[Unit] = @aqueue.Queue::new(kind=Unbounded)
  app.command(
    @app.slash(
      name="raw",
      description="Raw command",
      args=@interaction.Args::unit(),
      handler=Raw(_ => {
        command_count.val += 1
        if command_count.val == 1 {
          first_started.put(())
          release_first.get()
        } else {
          second_started.put(())
          release_first.put(())
        }
      }),
    ),
  )
  app.command(
    @app.slash(
      name="fail",
      description="Failing command",
      args=@interaction.Args::unit(),
      handler=Raw(_ => raise RuntimeTestFailure),
    ),
  )
  let event_calls : @aqueue.Queue[Int] = @aqueue.Queue::new(kind=Unbounded)
  let event_count = Ref(0)
  bot.on(Events::message_delete(), (_, _) => {
    event_count.val += 1
    event_calls.put(event_count.val)
    if event_count.val == 1 {
      raise RuntimeTestFailure
    }
  })
  let policy_calls : @aqueue.Queue[String] = @aqueue.Queue::new(kind=Unbounded)
  app.error_policy((failure, _) => {
    policy_calls.put("\{to_repr(failure.origin())}")
  })
  // No raw event handler is registered, so the gateway filter can reject
  // unrelated events before decoding/queuing them.
  let filter = bot.event_filter()
  assert_true(filter(KReady))
  assert_true(filter(KInteractionCreate))
  assert_true(filter(KMessageDelete))
  assert_false(filter(KInviteDelete))
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, () => bot.run())
    transport.incoming.put(BOT_HELLO)
    guard transport.outgoing.get() is { "op": Number(2, ..), .. } else {
      fail("expected identify")
    }
    transport.incoming.put(bot_ready_frame())
    let ctx = ready_contexts.get()
    inspect(ctx.app().application_id().to_string(), content="42")
    inspect(ctx.ready().application.id.to_string(), content="42")
    // The first command blocks. The second must still be pulled and dispatched,
    // otherwise component-waiter style command flows would deadlock.
    transport.incoming.put(command_frame(2, "500000000000000001"))
    first_started.get()
    transport.incoming.put(command_frame(3, "500000000000000002"))
    guard @async.with_timeout_opt(500, () => second_started.get()) is Some(_) else {
      fail("the event loop awaited a command handler")
    }
    transport.incoming.put(command_frame(4, "500000000000000003", name="fail"))
    assert_true(policy_calls.get().contains("Command"))
    transport.incoming.put(message_delete_frame(5, "700000000000000001"))
    inspect(event_calls.get(), content="1")
    assert_true(policy_calls.get().contains("KMessageDelete"))
    // A second event arriving after the failure proves the loop stayed alive.
    transport.incoming.put(message_delete_frame(6, "700000000000000002"))
    inspect(event_calls.get(), content="2")
    ctx.shutdown()
    running.wait()
  })
  inspect(command_count.val, content="2")
}

///|
async test "bot reports gateway decode errors and preserves dispatch" {
  // Decode-error observers do not request any additional event kinds.
  let filter_app = @app.App::new(sync=@app.CommandSync::Disabled)
  let filter_bot = Bot::new(filter_app, token="test-token")
  filter_bot.on_decode_error((_, _) => ())
  let filter = filter_bot.event_filter()
  assert_true(filter(KReady))
  assert_true(filter(KInteractionCreate))
  assert_false(filter(KMessageDelete))
  assert_false(filter(KInviteDelete))

  let transport = BotFakeTransport::new()
  let app = @app.App::new(sync=@app.CommandSync::Disabled)
  let warnings : Array[String] = []
  app.on_warn(message => warnings.push(message))
  let bot = Bot::new(
    app,
    token="test-token",
    intents=@model.Intents::guild_messages(),
    client=@dhttp.Client::new("test-token"),
    gateway_url="wss://gateway.example",
  )
  bot.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
  let ready_contexts : @aqueue.Queue[GatewayCtx] = @aqueue.Queue::new(
    kind=Unbounded,
  )
  bot.on(Events::ready(), (ctx, _) => ready_contexts.put(ctx))
  let decode_errors : Array[(String, Json)] = []
  bot.on_decode_error((marker, payload) => decode_errors.push((marker, payload)))
  let saw_identified = Ref(false)
  let saw_decode_telemetry = Ref(false)
  let saw_decode_dispatch = Ref(false)
  bot.on_telemetry(event => {
    match event {
      @telemetry.TelemetryEvent::ShardIdentified(shard_id=0) =>
        saw_identified.val = true
      @telemetry.TelemetryEvent::DecodeError(marker~) =>
        saw_decode_telemetry.val = marker.has_prefix(
          "DECODE_ERROR:INTERACTION_CREATE:",
        )
      @telemetry.TelemetryEvent::EventDispatched(
        kind="KUnknown",
        handler_count=1
      ) => saw_decode_dispatch.val = true
      _ => ()
    }
  })
  let raw_decode_errors : @aqueue.Queue[(String, Json)] = @aqueue.Queue::new(
    kind=Unbounded,
  )
  bot.on_event((_, event) => {
    match event {
      Unknown(t~, d~) if t.has_prefix("DECODE_ERROR:") =>
        raw_decode_errors.put((t, d))
      _ => ()
    }
  })
  let normal_events : @aqueue.Queue[Unit] = @aqueue.Queue::new(kind=Unbounded)
  bot.on(Events::message_delete(), (_, _) => normal_events.put(()))
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, () => bot.run())
    transport.incoming.put(BOT_HELLO)
    guard transport.outgoing.get() is { "op": Number(2, ..), .. } else {
      fail("expected identify")
    }
    transport.incoming.put(bot_ready_frame())
    let ctx = ready_contexts.get()
    transport.incoming.put(malformed_interaction_frame(2))
    let (raw_marker, raw_payload) = raw_decode_errors.get()
    assert_true(raw_marker.has_prefix("DECODE_ERROR:INTERACTION_CREATE:"))
    guard raw_payload is { "token": String("payload-must-stay-private"), .. } else {
      fail("expected the undecoded interaction payload")
    }
    inspect(decode_errors.length(), content="1")
    let (marker, payload) = decode_errors[0]
    assert_eq(marker, raw_marker)
    assert_eq(payload.stringify(), raw_payload.stringify())
    inspect(warnings.length(), content="1")
    assert_true(warnings[0].contains("DECODE_ERROR:INTERACTION_CREATE:"))
    assert_false(warnings[0].contains("payload-must-stay-private"))
    assert_true(saw_identified.val)
    assert_true(saw_decode_telemetry.val)
    assert_true(saw_decode_dispatch.val)

    // An ordinary dispatch proves the loop continues and does not notify the
    // decode-error observers.
    transport.incoming.put(message_delete_frame(3, "700000000000000099"))
    normal_events.get()
    inspect(decode_errors.length(), content="1")
    inspect(warnings.length(), content="1")
    ctx.shutdown()
    running.wait()
  })
}
