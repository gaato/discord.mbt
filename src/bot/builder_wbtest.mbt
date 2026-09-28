///|
test "build rejects configurations that cannot run" {
  let app = @app.AppBuilder().build()
  let cases : Array[(String, BotBuilder)] = [
    ("empty token", BotBuilder(app, token="")),
    ("zero count", BotBuilder(app, token="t", shards=Fixed(count=0))),
    ("outside", BotBuilder(app, token="t", shards=Single(id=2, count=2))),
    ("duplicate", BotBuilder(app, token="t", shards=Range(ids=[1, 1], count=4))),
  ]
  let seen = cases.map(entry => {
    let (label, builder) = entry
    try builder.build() |> ignore catch {
      error => "\{label}: \{Repr(error)}"
    } noraise {
      _ => "\{label}: built"
    }
  })
  debug_inspect(
    seen,
    content=(
      #|[
      #|  "empty token: EmptyToken",
      #|  "zero count: InvalidShardConfig(message=\"shard count must be positive\")",
      #|  "outside: InvalidShardConfig(message=\"shard id 2 is outside 0..<2\")",
      #|  "duplicate: InvalidShardConfig(message=\"duplicate shard id 1\")",
      #|]
    ),
  )
  // Auto layouts come from Discord at run time, so build accepts them.
  BotBuilder(app, token="t", shards=Auto).build() |> ignore
}

///|
test "a built bot keeps the registrations it was built with" {
  let builder = BotBuilder(@app.AppBuilder().build(), token="t")
  builder.on(Events::ready(), (_, _) => ())
  let bot = builder.build()
  builder.on(Events::message_create(), (_, _) => ())
  builder.service(name="late", _ => ())
  assert_eq(bot.core.typed_events_.length(), 1)
  assert_eq(bot.core.services_.length(), 0)
  assert_eq(builder.build().core.typed_events_.length(), 2)
  // Intents were resolved from the registrations at build time.
  assert_true(bot.core.frozen_intents_ is Some(_))
}

///|
async test "a bot runs once at a time and may run again after it stops" {
  let app = @app.AppBuilder()
  let builder = middleware_runtime_bot(app.build(), BotFakeTransport())
  let ready_contexts : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  builder.on(Events::ready(), (ctx, _) => ready_contexts.put(ctx))
  let bot = builder.build()
  for round in 0..<2 {
    // Each run opens a fresh connection, as a real restart would.
    let transport = BotFakeTransport()
    bot.core.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
    @async.with_task_group(group => {
      let running = group.spawn(no_wait=true, () => bot.run())
      transport.incoming.put(BOT_HELLO)
      guard transport.outgoing.get() is { "op": Number(2, ..), .. } else {
        fail("expected identify (round \{round})")
      }
      transport.incoming.put(bot_ready_frame())
      let ctx = ready_contexts.get()
      try bot.run() catch {
        AlreadyRunning => ()
        error => fail("unexpected error: \{Repr(error)}")
      } noraise {
        _ => fail("a second run started while the first was running")
      }
      ctx.shutdown()
      running.wait()
    })
  }
}

///|
async test "a supplied client's telemetry reaches the bot once, across restarts" {
  let requests = Ref(0)
  let client = @dhttp.Client::offline(_ => {
    requests.val += 1
    @dhttp.HttpResponse::{
      status: 200,
      headers: Map([]),
      body: {
        "id": "1",
        "username": "bot",
        "discriminator": "0",
        "global_name": null,
        "avatar": null,
      },
    }
  })
  let app = @app.AppBuilder()
  let builder = BotBuilder(
    app.build(),
    token="test-token",
    intents=@model.Intents::guild_messages(),
    client~,
    gateway_url="wss://gateway.example",
  )
  builder.core.gateway_bot_info_.val = Some(manager_gateway_info())
  let ready_contexts : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  builder.on(Events::ready(), (ctx, _) => ready_contexts.put(ctx))
  let http_events = Ref(0)
  builder.on_telemetry(event => {
    if event is HttpRequest(..) {
      http_events.val += 1
    }
  })
  let bot = builder.build()
  for _ in 0..<2 {
    let transport = BotFakeTransport()
    bot.core.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
    @async.with_task_group(group => {
      let running = group.spawn(no_wait=true, () => bot.run())
      transport.incoming.put(BOT_HELLO)
      guard transport.outgoing.get() is { "op": Number(2, ..), .. } else {
        fail("expected identify")
      }
      transport.incoming.put(bot_ready_frame())
      let ctx = ready_contexts.get()
      ctx.shutdown()
      running.wait()
    })
  }
  let before = requests.val
  client.get_current_user() |> ignore
  assert_eq(requests.val, before + 1)
  assert_eq(http_events.val, before + 1)
}
