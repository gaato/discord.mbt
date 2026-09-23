///|
test "intent derivation strips privileged intents and warns" {
  let app = @app.App()
  let bot = Bot(app, token="token")
  let warnings : Array[String] = []
  app.on_warn(message => warnings.push(message))
  bot.on(Events::message_create(), (_, _) => ())
  bot.on(Events::guild_member_add(), (_, _) => ())
  inspect(bot.resolved_intents().bits(), content="4608")
  inspect(warnings.length(), content="1")
  assert_true(warnings[0].contains("privileged intent"))
  let explicit_app = @app.App()
  let explicit = Bot(
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
  let app = @app.App()
  let bot = Bot(app, token="token")
  let cache = @cache.InMemoryCache(resources=@cache.CacheResources::default())
  bot.attach_cache(cache)
  let filter = bot.event_filter()
  assert_true(filter(KReady))
  assert_true(filter(KInviteDelete))
  guard bot.cache_ is Some(attached) else { fail("expected attached cache") }
  attached.update(
    GuildDelete({ id: @model.Id::parse("100"), unavailable: true, }),
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
  let app = @app.App()
  let warnings : Array[String] = []
  app.on_warn(message => warnings.push(message))
  let bot = Bot(app, token="test-token")
  bot.on_telemetry(_ => raise RuntimeTestFailure)
  bot.emit_telemetry(DecodeError(marker="DECODE_ERROR:test"))
  inspect(warnings.length(), content="1")
  assert_true(warnings[0].contains("telemetry hook failed"))
}

///|
struct BotFakeTransport {
  incoming : @aqueue.Queue[String]
  outgoing : @aqueue.Queue[Json]
}

///|
fn BotFakeTransport::BotFakeTransport() -> BotFakeTransport {
  { incoming: Queue(kind=Unbounded), outgoing: Queue(kind=Unbounded), }
}

///|
impl @gateway.GatewayTransport for BotFakeTransport with fn recv(self) {
  Text(self.incoming.get())
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
async test "bot restores context before replay and snapshots live sessions" {
  let transport = BotFakeTransport()
  let urls : Array[String] = []
  let app = @app.App()
  let commands : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  app.command(
    @app.slash(
      name="raw",
      description="Raw command",
      args=@interaction.Args::unit(),
      handler=Raw(_ => commands.put(())),
    ),
  )
  let client = @dhttp.Client("test-token")
  defer client.close()
  let rest_calls = Ref(0)
  client.middleware((_request, _next) => {
    rest_calls.val += 1
    { status: 200, headers: Map([]), body: Json::array([]), }
  })
  guard @json.parse(bot_ready_frame()) is { "d": ready_json, .. } else {
    fail("expected READY payload")
  }
  let ready : @model.Ready = @json.from_json(ready_json)
  let saved : BotSession = {
    gateway: {
      id: ready.session_id,
      resume_url: ready.resume_gateway_url,
      sequence: 41L,
    },
    ready,
  }
  let bot = Bot(
    app,
    token="test-token",
    intents=@model.Intents::guild_messages(),
    client~,
    gateway_url="wss://gateway.example",
    sync=Global,
    resume={ 0: saved },
  )
  // Mutating caller-owned input after construction cannot alter the seed.
  saved.gateway.sequence = 999L
  saved.ready.guilds.push({ id: @model.Id::parse("999"), unavailable: true, })
  bot.connector_.val = Some(url => {
    urls.push(url)
    (transport : &@gateway.GatewayTransport)
  })
  let ready_calls = Ref(0)
  bot.on(Events::ready(), (_, _) => ready_calls.val += 1)
  let events : @aqueue.Queue[(GatewayCtx, String)] = Queue(kind=Unbounded)
  bot.on(Events::message_delete(), (ctx, event) => {
    events.put((ctx, event.id.to_string()))
  })
  let service_contexts : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.service(name="resume-service", ctx => service_contexts.put(ctx))
  assert_true(bot.sessions().is_empty())
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, () => bot.run())
    transport.incoming.put(BOT_HELLO)
    guard transport.outgoing.get()
      is {
        "op": Number(6, ..),
        "d": { "session_id": String("sess-bot"), "seq": Number(41, ..), .. },
        ..
      } else {
      fail("expected saved RESUME")
    }
    assert_true(urls[0].has_prefix("wss://resume.example/?v=10"))
    transport.incoming.put(message_delete_frame(42, "700"))
    let (ctx, id) = events.get()
    assert_eq(id, "700")
    assert_eq(ctx.ready().session_id, "sess-bot")
    let service_ctx = service_contexts.get()
    assert_true(physical_equal(ctx, service_ctx))
    transport.incoming.put(command_frame(43, "500000000000000701"))
    commands.get()
    assert_eq(ready_calls.val, 0)
    assert_eq(rest_calls.val, 0)
    transport.incoming.put("{\"op\":0,\"t\":\"RESUMED\",\"s\":44,\"d\":{}}")
    transport.incoming.put(message_delete_frame(45, "701"))
    let (post_ctx, post_id) = events.get()
    assert_eq(post_id, "701")
    assert_true(physical_equal(ctx, post_ctx))
    assert_true(service_contexts.try_get() is None)
    assert_eq(ready_calls.val, 0)
    let sessions = bot.sessions()
    guard sessions.get(0) is Some(session) else {
      fail("expected live BotSession")
    }
    assert_eq(session.gateway.sequence, 45L)
    assert_eq(session.ready.session_id, "sess-bot")
    assert_eq(session.ready.guilds.length(), 0)
    let encoded = ToJson::to_json(session)
    let decoded : BotSession = @json.from_json(encoded)
    assert_eq(decoded.gateway.sequence, 45L)
    assert_eq(decoded.ready.session_id, "sess-bot")
    session.gateway.sequence = 777L
    session.ready.guilds.push({
      id: @model.Id::parse("998"),
      unavailable: true,
    })
    guard bot.sessions().get(0) is Some(again) else {
      fail("expected independent BotSession snapshot")
    }
    assert_eq(again.gateway.sequence, 45L)
    assert_eq(again.ready.guilds.length(), 0)
    ctx.shutdown()
    running.wait()
    assert_true(bot.sessions().is_empty())
  })
}

///|
async test "bot reports supplied sessions while resolving shards" {
  let transport = BotFakeTransport()
  let app = @app.App()
  let client = @dhttp.Client("test-token")
  defer client.close()
  let gateway_requested : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let gateway_release : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  client.middleware((_request, _next) => {
    gateway_requested.put(())
    gateway_release.get()
    { status: 200, headers: Map([]), body: { "url": "wss://gateway.example" }, }
  })
  guard @json.parse(bot_ready_frame()) is { "d": ready_json, .. } else {
    fail("expected READY payload")
  }
  let ready : @model.Ready = @json.from_json(ready_json)
  let saved : BotSession = {
    gateway: {
      id: ready.session_id,
      resume_url: ready.resume_gateway_url,
      sequence: 41L,
    },
    ready,
  }
  let bot = Bot(
    app,
    token="test-token",
    intents=@model.Intents::guild_messages(),
    client~,
    resume={ 0: saved },
  )
  bot.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
  let events : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.on(Events::message_delete(), (ctx, _) => events.put(ctx))
  assert_true(bot.sessions().is_empty())
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, () => bot.run())
    gateway_requested.get()
    // The gateway lookup is still pending: the supplied snapshot is reported.
    guard bot.sessions().get(0) is Some(pending) else {
      fail("expected supplied BotSession while resolving shards")
    }
    assert_eq(pending.gateway.sequence, 41L)
    assert_eq(pending.ready.session_id, "sess-bot")
    pending.gateway.sequence = 999L
    gateway_release.put(())
    transport.incoming.put(BOT_HELLO)
    guard transport.outgoing.get() is { "op": Number(6, ..), .. } else {
      fail("expected saved RESUME")
    }
    guard bot.sessions().get(0) is Some(connecting) else {
      fail("expected BotSession while connecting")
    }
    assert_eq(connecting.gateway.sequence, 41L)
    transport.incoming.put(message_delete_frame(42, "700"))
    let ctx = events.get()
    ctx.shutdown()
    running.wait()
    assert_true(bot.sessions().is_empty())
  })
}

///|
async test "bot identifies instead of resuming a session from another shard layout" {
  let transport = BotFakeTransport()
  let app = @app.App()
  let warnings : Array[String] = []
  app.on_warn(message => warnings.push(message))
  let client = @dhttp.Client("test-token")
  defer client.close()
  client.middleware((_request, _next) => {
    status: 200,
    headers: Map([]),
    body: Json::array([]),
  })
  guard @json.parse(
      bot_ready_frame().replace(old="\"shard\":[0,1]", new="\"shard\":[0,2]"),
    )
    is { "d": ready_json, .. } else {
    fail("expected READY payload")
  }
  let ready : @model.Ready = @json.from_json(ready_json)
  let saved : BotSession = {
    gateway: {
      id: ready.session_id,
      resume_url: ready.resume_gateway_url,
      sequence: 41L,
    },
    ready,
  }
  let bot = Bot(
    app,
    token="test-token",
    intents=@model.Intents::guild_messages(),
    client~,
    gateway_url="wss://gateway.example",
    resume={ 0: saved },
  )
  bot.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
  let ready_contexts : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.on(Events::ready(), (ctx, _) => ready_contexts.put(ctx))
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, () => bot.run())
    transport.incoming.put(BOT_HELLO)
    guard transport.outgoing.get()
      is {
        "op": Number(2, ..),
        "d": { "shard": [Number(0, ..), Number(1, ..)], .. },
        ..
      } else {
      fail("expected IDENTIFY for the resolved layout")
    }
    assert_true(bot.sessions().is_empty())
    transport.incoming.put(bot_ready_frame())
    let ctx = ready_contexts.get()
    assert_eq(ctx.ready().session_id, "sess-bot")
    guard bot.sessions().get(0) is Some(live) else {
      fail("expected the new session snapshot")
    }
    assert_eq(live.ready.shard, Some([0, 1]))
    ctx.shutdown()
    running.wait()
  })
  inspect(
    warnings.join("\n"),
    content=(
      #|ignoring saved session for shard 0: its READY was recorded for shard [0, 2] but the bot resolved shard [0, 1], so the shard identifies instead
    ),
  )
}

///|
fn bot_ready_frame() -> String {
  (
    #|{"op":0,"s":1,"t":"READY","d":{"v":10,"user":{"id":"1","username":"bot","discriminator":"0","global_name":null,"avatar":null},"guilds":[],"session_id":"sess-bot","resume_gateway_url":"wss://resume.example","application":{"id":"42"},"shard":[0,1]}}
  )
}

///|
fn bot_saved_session() -> BotSession raise {
  guard @json.parse(bot_ready_frame()) is { "d": ready_json, .. } else {
    fail("expected READY payload")
  }
  let ready : @model.Ready = @json.from_json(ready_json)
  {
    gateway: {
      id: ready.session_id,
      resume_url: ready.resume_gateway_url,
      sequence: 41L,
    },
    ready,
  }
}

///|
async test "empty Bot replay starts services on RESUMED" {
  let transport = BotFakeTransport()
  let bot = Bot(
    @app.App(),
    token="test-token",
    gateway_url="wss://gateway.example",
    resume={ 0: bot_saved_session() },
  )
  bot.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
  let service_contexts : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.service(name="empty-replay-service", ctx => service_contexts.put(ctx))
  let ready_calls = Ref(0)
  bot.on(Events::ready(), (_, _) => ready_calls.val += 1)
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, () => bot.run())
    transport.incoming.put(BOT_HELLO)
    guard transport.outgoing.get() is { "op": Number(6, ..), .. } else {
      fail("expected RESUME")
    }
    assert_true(service_contexts.try_get() is None)
    transport.incoming.put("{\"op\":0,\"t\":\"RESUMED\",\"s\":42,\"d\":{}}")
    let ctx = service_contexts.get()
    assert_eq(ctx.ready().session_id, "sess-bot")
    assert_eq(ready_calls.val, 0)
    ctx.shutdown()
    running.wait()
  })
}

///|
async test "bot rejects mismatched saved session before REST or connector" {
  let saved = bot_saved_session()
  let bad : BotSession = {
    gateway: {
      id: "different",
      resume_url: saved.gateway.resume_url,
      sequence: 41L,
    },
    ready: saved.ready,
  }
  let client = @dhttp.Client("test-token")
  defer client.close()
  let rest_calls = Ref(0)
  let connector_calls = Ref(0)
  client.middleware((_request, _next) => {
    rest_calls.val += 1
    fail("mismatched session reached REST")
  })
  let bot = Bot(
    @app.App(),
    token="test-token",
    client~,
    gateway_url="wss://gateway.example",
    resume={ 0: bad },
  )
  bot.connector_.val = Some(_ => {
    connector_calls.val += 1
    fail("mismatched session reached connector")
  })
  try bot.run() catch {
    InvalidShardConfig(message~) =>
      inspect(
        message,
        content="saved session for shard 0 has mismatched gateway and READY session ids",
      )
    error => fail("unexpected snapshot error: \{Repr(error)}")
  } noraise {
    _ => fail("mismatched snapshot unexpectedly ran")
  }
  assert_eq(rest_calls.val, 0)
  assert_eq(connector_calls.val, 0)
}

///|
async test "rejected Bot resume uses the next actual READY" {
  let first = BotFakeTransport()
  let second = BotFakeTransport()
  let urls : Array[String] = []
  let connected : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let app = @app.App()
  let client = @dhttp.Client("test-token")
  defer client.close()
  let sync_calls = Ref(0)
  client.middleware((_request, _next) => {
    sync_calls.val += 1
    { status: 200, headers: Map([]), body: Json::array([]), }
  })
  let bot = Bot(
    app,
    token="test-token",
    client~,
    gateway_url="wss://gateway.example",
    sync=Global,
    resume={ 0: bot_saved_session() },
  )
  bot.connector_.val = Some(url => {
    urls.push(url)
    if urls.length() == 1 {
      (first : &@gateway.GatewayTransport)
    } else {
      connected.put(())
      (second : &@gateway.GatewayTransport)
    }
  })
  let ready_calls = Ref(0)
  let ready_contexts : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.on(Events::ready(), (ctx, _) => {
    ready_calls.val += 1
    ready_contexts.put(ctx)
  })
  let service_contexts : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.service(name="new-ready-service", ctx => service_contexts.put(ctx))
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, () => bot.run())
    first.incoming.put(BOT_HELLO)
    guard first.outgoing.get() is { "op": Number(6, ..), .. } else {
      fail("expected saved RESUME")
    }
    first.incoming.put("{\"op\":9,\"d\":false}")
    connected.get()
    assert_eq(ready_calls.val, 0)
    assert_eq(sync_calls.val, 0)
    assert_true(bot.sessions().is_empty())
    assert_true(urls[1].has_prefix("wss://gateway.example/?v=10"))
    second.incoming.put(BOT_HELLO)
    guard second.outgoing.get() is { "op": Number(2, ..), .. } else {
      fail("expected Identify after invalid session")
    }
    second.incoming.put(
      bot_ready_frame().replace(old="sess-bot", new="new-session"),
    )
    let ctx = ready_contexts.get()
    assert_eq(ctx.ready().session_id, "new-session")
    assert_eq(ready_calls.val, 1)
    assert_true(sync_calls.val > 0)
    assert_true(physical_equal(ctx, service_contexts.get()))
    guard bot.sessions().get(0) is Some(live) else {
      fail("expected new session snapshot")
    }
    assert_eq(live.gateway.id, "new-session")
    assert_eq(live.ready.session_id, "new-session")
    ctx.shutdown()
    running.wait()
  })
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
fn message_update_frame(sequence : Int, id : String) -> String {
  (
    #|{"op":0,"s":SEQUENCE_PLACEHOLDER,"t":"MESSAGE_UPDATE","d":{"id":"ID_PLACEHOLDER","channel_id":"6","author":{"id":"200","username":"nelly","discriminator":"0","avatar":null},"content":"edited","timestamp":"2025-06-01T10:00:00Z","edited_timestamp":"2025-06-01T10:05:00Z","tts":false,"mention_everyone":false,"mentions":[],"mention_roles":[],"attachments":[],"embeds":[],"pinned":false,"type":0}}
  )
  .replace(old="SEQUENCE_PLACEHOLDER", new=sequence.to_string())
  .replace(old="ID_PLACEHOLDER", new=id)
}

///|
fn channel_create_frame(sequence : Int, id : String) -> String {
  (
    #|{"op":0,"s":SEQUENCE_PLACEHOLDER,"t":"CHANNEL_CREATE","d":{"id":"ID_PLACEHOLDER","type":11,"guild_id":"100","name":"cached-thread"}}
  )
  .replace(old="SEQUENCE_PLACEHOLDER", new=sequence.to_string())
  .replace(old="ID_PLACEHOLDER", new=id)
}

///|
fn middleware_runtime_bot(app : @app.App, transport : BotFakeTransport) -> Bot {
  let bot = Bot(
    app,
    token="test-token",
    intents=@model.Intents::guild_messages(),
    client=Client("test-token"),
    gateway_url="wss://gateway.example",
  )
  bot.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
  bot
}

///|
async test "gateway contexts expose heartbeat latency" {
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
    assert_true(ctx.cache() is None)
    debug_inspect(ctx.latency_ms(), content="None")
    debug_inspect(ctx.app().latency_ms(), content="None")
    transport.incoming.put(
      (
        #|{"op":1,"d":null}
      ),
    )
    guard transport.outgoing.get() is { "op": Number(1, ..), .. } else {
      fail("expected heartbeat")
    }
    transport.incoming.put(
      (
        #|{"op":11,"d":null}
      ),
    )
    @async.sleep(1)
    guard ctx.latency_ms() is Some(shard_latency) else {
      fail("expected shard heartbeat latency")
    }
    assert_eq(ctx.app().latency_ms(), Some(shard_latency))
    ctx.shutdown()
    running.wait()
  })
}

///|
async test "bot without sync performs no command requests" {
  let transport = BotFakeTransport()
  let app = @app.App()
  let rest_paths : Array[String] = []
  let client = @dhttp.Client("test-token")
  defer client.close()
  client.middleware((request, _next) => {
    rest_paths.push(request.route.path())
    { status: 200, headers: Map([]), body: Json::array([]), }
  })
  let bot = Bot(
    app,
    token="test-token",
    intents=@model.Intents::guilds(),
    client~,
    gateway_url="wss://gateway.example",
  )
  bot.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
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
    assert_false(rest_paths.any(path => path.contains("/commands")))
    ctx.shutdown()
    running.wait()
  })
}

///|
async test "bot warns when sync deletes undeclared commands" {
  let guild_a : @model.GuildId = @model.Id::parse("100")
  let guild_b : @model.GuildId = @model.Id::parse("101")
  for
    entry in [
      (@app.CommandScope::Global, ["global scope"]),
      (
        @app.CommandScope::Guilds([guild_a, guild_b]),
        ["guild 100", "guild 101"],
      ),
    ] {
    let (scope, targets) = entry
    let transport = BotFakeTransport()
    let app = @app.App()
    let warnings = []
    app.on_warn(message => warnings.push(message))
    let client = @dhttp.Client("test-token")
    defer client.close()
    client.middleware((request, _next) => {
      let body : Json = if request.route.method_() is Get {
        [
          { "id": "10", "name": "old" },
          { "id": "11", "type": 2, "name": "inspect" },
        ]
      } else {
        []
      }
      { status: 200, headers: Map([]), body, }
    })
    let bot = Bot(
      app,
      token="test-token",
      intents=@model.Intents::guilds(),
      client~,
      gateway_url="wss://gateway.example",
      sync=scope,
    )
    bot.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
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
      assert_eq(
        warnings,
        targets.map(target => {
          "command sync deleted old, 2:inspect in \{target}; use sync_unowned=Keep to preserve undeclared commands"
        }),
      )
      ctx.shutdown()
      running.wait()
    })
  }
}

///|
async test "bot Keep preserves other owners and emits no deletion warning" {
  let transport = BotFakeTransport()
  let app = @app.App()
  app.command(
    @app.slash(
      name="ping",
      description="Ping",
      args=@interaction.Args::unit(),
      handler=Raw(_ => ()),
    ),
  )
  let warnings = []
  app.on_warn(message => warnings.push(message))
  let bodies : Array[Json] = []
  let client = @dhttp.Client("test-token")
  defer client.close()
  client.middleware((request, _next) => {
    if request.route.method_() is Put && request.body is Some(body) {
      bodies.push(body)
    }
    let body : Json = if request.route.method_() is Get {
      [
        { "id": "10", "name": "other" },
        { "id": "11", "type": 4, "name": "Launch", "handler": 2 },
      ]
    } else {
      []
    }
    { status: 200, headers: Map([]), body, }
  })
  let bot = Bot(
    app,
    token="test-token",
    intents=@model.Intents::guilds(),
    client~,
    gateway_url="wss://gateway.example",
    sync=Global,
    sync_unowned=Keep,
  )
  bot.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
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
    assert_eq(warnings, [])
    json_inspect(bodies, content=[
      [
        { "name": "ping", "description": "Ping" },
        { "id": "10", "name": "other" },
        { "id": "11", "type": 4, "name": "Launch", "handler": 2 },
      ],
    ])
    ctx.shutdown()
    running.wait()
  })
}

///|
async test "bot sync failures stay fail-fast" {
  for fail_get in [true, false] {
    let transport = BotFakeTransport()
    let app = @app.App()
    let warnings = []
    app.on_warn(message => warnings.push(message))
    let client = @dhttp.Client("test-token")
    defer client.close()
    client.middleware((request, _next) => {
      if (request.route.method_() is Get) == fail_get {
        raise @dhttp.DiscordHttpError::Transport(message="sync failed")
      }
      {
        status: 200,
        headers: Map([]),
        body: Json::array([{ "id": "10", "name": "old" }]),
      }
    })
    let bot = Bot(
      app,
      token="test-token",
      intents=@model.Intents::guilds(),
      client~,
      gateway_url="wss://gateway.example",
      sync=Global,
    )
    bot.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
    let ready_called = Ref(false)
    bot.on(Events::ready(), (ctx, _) => {
      ready_called.val = true
      ctx.shutdown()
    })
    try
      @async.with_task_group(group => {
        let running = group.spawn(no_wait=true, () => bot.run())
        transport.incoming.put(BOT_HELLO)
        guard transport.outgoing.get() is { "op": Number(2, ..), .. } else {
          fail("expected identify")
        }
        transport.incoming.put(bot_ready_frame())
        running.wait()
      })
    catch {
      @dhttp.DiscordHttpError::Transport(message="sync failed") => ()
      error => fail("unexpected sync error: \{Repr(error)}")
    } noraise {
      _ => fail("expected sync failure")
    }
    assert_false(ready_called.val)
    assert_eq(warnings, [])
  }
}

///|
async test "gateway context resolves cached channels and falls back to REST" {
  let transport = BotFakeTransport()
  let app = @app.App()
  let rest_calls = Ref(0)
  let client = @dhttp.Client("test-token")
  defer client.close()
  client.middleware((_request, _next) => {
    rest_calls.val += 1
    {
      status: 200,
      headers: Map([]),
      body: {
        "id": "301",
        "type": 0,
        "guild_id": "100",
        "name": "rest-channel",
      },
    }
  })
  let bot = Bot(
    app,
    token="test-token",
    intents=@model.Intents::guilds(),
    client~,
    gateway_url="wss://gateway.example",
  )
  bot.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
  let cache = @cache.InMemoryCache(resources=@cache.CacheResources::default())
  bot.attach_cache(cache)
  let ready_contexts : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.on(Events::ready(), (ctx, _) => ready_contexts.put(ctx))
  let resolved : @aqueue.Queue[(String, @model.ChannelType)] = Queue(
    kind=Unbounded,
  )
  bot.on(Events::channel_create(), (ctx, event) => {
    let channel = ctx.resolve_channel(event.id)
    resolved.put((channel.id.to_string(), channel.typ))
  })
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, () => bot.run())
    transport.incoming.put(BOT_HELLO)
    guard transport.outgoing.get() is { "op": Number(2, ..), .. } else {
      fail("expected identify")
    }
    transport.incoming.put(bot_ready_frame())
    let ctx = ready_contexts.get()
    assert_true(ctx.cache() is Some(_))
    transport.incoming.put(channel_create_frame(2, "300"))
    let (id, typ) = resolved.get()
    inspect(id, content="300")
    debug_inspect(typ, content="PublicThread")
    inspect(rest_calls.val, content="0")
    let missing_id : @model.ChannelId = @model.Id::parse("301")
    let fetched = ctx.resolve_channel(missing_id)
    debug_inspect(fetched.name, content="Some(Value(\"rest-channel\"))")
    inspect(rest_calls.val, content="1")
    assert_true(cache.channel(missing_id) is None)
    ctx.shutdown()
    running.wait()
  })
}

///|
async test "unsupported compression rejects before REST or connector setup" {
  if @gateway.zlib_stream_supported() {
    return
  }
  let client = @dhttp.Client("test-token")
  defer client.close()
  let rest_calls = Ref(0)
  let connector_calls = Ref(0)
  client.middleware((_request, _next) => {
    rest_calls.val += 1
    fail("compression reached REST")
  })
  let bot = Bot(@app.App(), token="test-token", client~, compress=true)
  bot.connector_.val = Some(_ => {
    connector_calls.val += 1
    fail("compression reached connector")
  })
  try bot.run() catch {
    InvalidShardConfig(message~) =>
      inspect(
        message,
        content="compress=true requires zlib-stream inflate, which this backend does not provide",
      )
    error => fail("unexpected compression error: \{Repr(error)}")
  } noraise {
    _ => fail("unsupported compression unexpectedly ran")
  }
  assert_eq(rest_calls.val, 0)
  assert_eq(connector_calls.val, 0)
}

///|
async test "event middleware drops handlers after wire-level cache updates" {
  let transport = BotFakeTransport()
  let app = @app.App()
  let bot = middleware_runtime_bot(app, transport)
  let cache = @cache.InMemoryCache(resources=CacheResources(messages=true))
  bot.attach_cache(cache)
  bot.middleware((_, event, next) => {
    match event {
      MessageCreate(_) => ()
      _ => next(event)
    }
  })
  let ready_contexts : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.on(Events::ready(), (ctx, _) => ready_contexts.put(ctx))
  let handler_events : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  bot.on(Events::message_create(), (_, _) => handler_events.put(()))
  let message_dispatches = Ref(0)
  bot.on_telemetry(event => {
    match event {
      EventDispatched(kind="KMessageCreate", ..) => message_dispatches.val += 1
      _ => ()
    }
  })
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, () => bot.run())
    transport.incoming.put(BOT_HELLO)
    guard transport.outgoing.get() is { "op": Number(2, ..), .. } else {
      fail("expected identify")
    }
    transport.incoming.put(bot_ready_frame())
    let ctx = ready_contexts.get()
    transport.incoming.put(message_create_frame(2, "701"))
    let channel_id : @model.ChannelId = @model.Id::parse("6")
    let message_id : @model.MessageId = @model.Id::parse("701")
    let cache_updated = Ref(false)
    for _ in 0..<50 {
      if cache.message(channel_id, message_id) is Some(message) {
        inspect(message.content, content="cached")
        cache_updated.val = true
        break
      }
      @async.sleep(1)
    }
    assert_true(cache_updated.val)
    assert_true(
      @async.with_timeout_opt(100, () => handler_events.get()) is None,
    )
    inspect(message_dispatches.val, content="0")
    ctx.shutdown()
    running.wait()
  })
}

///|
async test "event middleware transforms events for typed handlers" {
  let transport = BotFakeTransport()
  let app = @app.App()
  let bot = middleware_runtime_bot(app, transport)
  bot.middleware((_, event, next) => {
    match event {
      MessageCreate(payload) => {
        let message = { ..payload.message, content: "transformed", }
        next(MessageCreate({ ..payload, message, }))
      }
      _ => next(event)
    }
  })
  let ready_contexts : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.on(Events::ready(), (ctx, _) => ready_contexts.put(ctx))
  let contents : @aqueue.Queue[String] = Queue(kind=Unbounded)
  bot.on(Events::message_create(), (_, event) => {
    contents.put(event.message.content)
  })
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, () => bot.run())
    transport.incoming.put(BOT_HELLO)
    guard transport.outgoing.get() is { "op": Number(2, ..), .. } else {
      fail("expected identify")
    }
    transport.incoming.put(bot_ready_frame())
    let ctx = ready_contexts.get()
    transport.incoming.put(message_create_frame(2, "702"))
    inspect(contents.get(), content="transformed")
    ctx.shutdown()
    running.wait()
  })
}

///|
async test "event middleware order is onion-style" {
  let transport = BotFakeTransport()
  let app = @app.App()
  let bot = middleware_runtime_bot(app, transport)
  let trace : Array[String] = []
  let first : EventMiddleware = (_, event, next) => {
    match event {
      MessageDelete(_) => {
        trace.push("a-in")
        next(event)
        trace.push("a-out")
      }
      _ => next(event)
    }
  }
  let second : EventMiddleware = (_, event, next) => {
    match event {
      MessageDelete(_) => {
        trace.push("b-in")
        next(event)
        trace.push("b-out")
      }
      _ => next(event)
    }
  }
  bot..middleware(first).middleware(second)
  let ready_contexts : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.on(Events::ready(), (ctx, _) => ready_contexts.put(ctx))
  let handled : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  bot.on(Events::message_delete(), (_, _) => handled.put(()))
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, () => bot.run())
    transport.incoming.put(BOT_HELLO)
    guard transport.outgoing.get() is { "op": Number(2, ..), .. } else {
      fail("expected identify")
    }
    transport.incoming.put(bot_ready_frame())
    let ctx = ready_contexts.get()
    transport.incoming.put(message_delete_frame(2, "703"))
    handled.get()
    for _ in 0..<50 {
      if trace.length() == 4 {
        break
      }
      @async.sleep(1)
    }
    inspect(trace.join(", "), content="a-in, b-in, b-out, a-out")
    ctx.shutdown()
    running.wait()
  })
}

///|
async test "interaction routing survives dropped gateway events" {
  let transport = BotFakeTransport()
  let app = @app.App()
  let commands : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  app.command(
    @app.slash(
      name="raw",
      description="Raw command",
      args=@interaction.Args::unit(),
      handler=Raw(_ => commands.put(())),
    ),
  )
  let bot = middleware_runtime_bot(app, transport)
  bot.middleware((_, _, _) => ())
  let service_contexts : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.service(name="capture-context", ctx => service_contexts.put(ctx))
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, () => bot.run())
    transport.incoming.put(BOT_HELLO)
    guard transport.outgoing.get() is { "op": Number(2, ..), .. } else {
      fail("expected identify")
    }
    transport.incoming.put(bot_ready_frame())
    let ctx = service_contexts.get()
    transport.incoming.put(command_frame(2, "500000000000000701"))
    guard @async.with_timeout_opt(500, () => commands.get()) is Some(_) else {
      fail("interaction routing was dropped by event middleware")
    }
    ctx.shutdown()
    running.wait()
  })
}

///|
async test "event middleware failures warn and preserve later dispatch" {
  let transport = BotFakeTransport()
  let app = @app.App()
  let warnings : Array[String] = []
  app.on_warn(message => warnings.push(message))
  let bot = middleware_runtime_bot(app, transport)
  let failed = Ref(false)
  bot.middleware((_, event, next) => {
    match event {
      MessageDelete(_) if !failed.val => {
        failed.val = true
        raise RuntimeTestFailure
      }
      _ => next(event)
    }
  })
  let ready_contexts : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.on(Events::ready(), (ctx, _) => ready_contexts.put(ctx))
  let handled : @aqueue.Queue[String] = Queue(kind=Unbounded)
  bot.on(Events::message_delete(), (_, event) => {
    handled.put(event.id.to_string())
  })
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, () => bot.run())
    transport.incoming.put(BOT_HELLO)
    guard transport.outgoing.get() is { "op": Number(2, ..), .. } else {
      fail("expected identify")
    }
    transport.incoming.put(bot_ready_frame())
    let ctx = ready_contexts.get()
    transport.incoming.put(message_delete_frame(2, "704"))
    for _ in 0..<50 {
      if warnings.length() == 1 {
        break
      }
      @async.sleep(1)
    }
    inspect(warnings.length(), content="1")
    assert_true(warnings[0].contains("event middleware failed"))
    transport.incoming.put(message_delete_frame(3, "705"))
    inspect(handled.get(), content="705")
    ctx.shutdown()
    running.wait()
  })
}

///|
async test "bot updates cache before typed event handlers" {
  let transport = BotFakeTransport()
  let app = @app.App()
  let bot = Bot(
    app,
    token="test-token",
    intents=@model.Intents::guild_messages(),
    client=Client("test-token"),
    gateway_url="wss://gateway.example",
  )
  bot.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
  let cache = @cache.InMemoryCache(resources=CacheResources(messages=true))
  bot.attach_cache(cache)
  let ready_contexts : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.on(Events::ready(), (ctx, _) => ready_contexts.put(ctx))
  let observed : @aqueue.Queue[Bool] = Queue(kind=Unbounded)
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
async test "message update handlers receive the cached previous revision" {
  let transport = BotFakeTransport()
  let app = @app.App()
  let bot = middleware_runtime_bot(app, transport)
  let cache = @cache.InMemoryCache(resources=CacheResources(messages=true))
  bot.attach_cache(cache)
  let ready_contexts : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.on(Events::ready(), (ctx, _) => ready_contexts.put(ctx))
  let created : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  bot.on(Events::message_create(), (_, _) => created.put(()))
  let observed : @aqueue.Queue[String] = Queue(kind=Unbounded)
  bot.on(Events::message_update(), (_, event) => {
    observed.put(event.before.map(message => message.content).unwrap_or("none"))
  })
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, () => bot.run())
    transport.incoming.put(BOT_HELLO)
    guard transport.outgoing.get() is { "op": Number(2, ..), .. } else {
      fail("expected identify")
    }
    transport.incoming.put(bot_ready_frame())
    let ctx = ready_contexts.get()
    transport.incoming.put(message_create_frame(2, "706"))
    created.get()
    transport.incoming.put(message_update_frame(3, "706"))
    inspect(observed.get(), content="cached")
    let channel_id : @model.ChannelId = @model.Id::parse("6")
    let message_id : @model.MessageId = @model.Id::parse("706")
    guard cache.message(channel_id, message_id) is Some(message) else {
      fail("expected updated cached message")
    }
    inspect(message.content, content="edited")
    ctx.shutdown()
    running.wait()
  })
}

///|
async test "message update handlers receive no before when messages are disabled" {
  let transport = BotFakeTransport()
  let app = @app.App()
  let bot = middleware_runtime_bot(app, transport)
  bot.attach_cache(InMemoryCache(resources=@cache.CacheResources::default()))
  let ready_contexts : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.on(Events::ready(), (ctx, _) => ready_contexts.put(ctx))
  let observed : @aqueue.Queue[Bool] = Queue(kind=Unbounded)
  bot.on(Events::message_update(), (_, event) => {
    observed.put(event.before is None)
  })
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, () => bot.run())
    transport.incoming.put(BOT_HELLO)
    guard transport.outgoing.get() is { "op": Number(2, ..), .. } else {
      fail("expected identify")
    }
    transport.incoming.put(bot_ready_frame())
    let ctx = ready_contexts.get()
    transport.incoming.put(message_update_frame(2, "707"))
    assert_true(observed.get())
    ctx.shutdown()
    running.wait()
  })
}

///|
async test "bot run dispatches concurrently, survives handlers, and shuts down" {
  let empty_app = @app.App()
  try Bot(empty_app, token="").run() catch {
    @app.AppConfigError::EmptyToken => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected empty token error")
  }
  let transport = BotFakeTransport()
  let app = @app.App(max_in_flight=8)
  let bot = Bot(
    app,
    token="test-token",
    client=Client("test-token"),
    gateway_url="wss://gateway.example",
  )
  bot.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
  let ready_contexts : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.on(Events::ready(), (ctx, _) => ready_contexts.put(ctx))
  let command_count = Ref(0)
  let first_started : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let release_first : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let second_started : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
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
  let event_calls : @aqueue.Queue[Int] = Queue(kind=Unbounded)
  let event_count = Ref(0)
  bot.on(Events::message_delete(), (_, _) => {
    event_count.val += 1
    event_calls.put(event_count.val)
    if event_count.val == 1 {
      raise RuntimeTestFailure
    }
  })
  let policy_calls : @aqueue.Queue[String] = Queue(kind=Unbounded)
  app.error_policy((failure, _) => policy_calls.put("\{Repr(failure.origin())}"))
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
  let filter_app = @app.App()
  let filter_bot = Bot(filter_app, token="test-token")
  filter_bot.on_decode_error((_, _) => ())
  let filter = filter_bot.event_filter()
  assert_true(filter(KReady))
  assert_true(filter(KInteractionCreate))
  assert_false(filter(KMessageDelete))
  assert_false(filter(KInviteDelete))

  let transport = BotFakeTransport()
  let app = @app.App()
  let warnings : Array[String] = []
  app.on_warn(message => warnings.push(message))
  let bot = Bot(
    app,
    token="test-token",
    intents=@model.Intents::guild_messages(),
    client=Client("test-token"),
    gateway_url="wss://gateway.example",
  )
  bot.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
  let ready_contexts : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.on(Events::ready(), (ctx, _) => ready_contexts.put(ctx))
  let decode_errors : Array[(String, Json)] = []
  bot.on_decode_error((marker, payload) => decode_errors.push((marker, payload)))
  let saw_identified = Ref(false)
  let saw_decode_telemetry = Ref(false)
  let saw_decode_dispatch = Ref(false)
  bot.on_telemetry(event => {
    match event {
      ShardIdentified(shard_id=0) => saw_identified.val = true
      DecodeError(marker~) =>
        saw_decode_telemetry.val = marker.has_prefix(
          "DECODE_ERROR:INTERACTION_CREATE:",
        )
      EventDispatched(kind="KUnknown", handler_count=1) =>
        saw_decode_dispatch.val = true
      _ => ()
    }
  })
  let raw_decode_errors : @aqueue.Queue[(String, Json)] = Queue(kind=Unbounded)
  bot.on_event((_, event) => {
    match event {
      Unknown(t~, d~) if t.has_prefix("DECODE_ERROR:") =>
        raw_decode_errors.put((t, d))
      _ => ()
    }
  })
  let normal_events : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
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
