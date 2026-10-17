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
  let clock = @simclock.VirtualClock()
  let builder = middleware_runtime_bot(
    app.build(),
    @gatewaysim.FakeTransport(clock~),
    clock,
  )
  let ready_contexts : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  builder.on(Events::ready(), (ctx, _) => ready_contexts.put(ctx))
  let bot = builder.build()
  for round in 0..<2 {
    // Each run opens a fresh connection, as a real restart would.
    let transport = @gatewaysim.FakeTransport(clock~)
    bot.core.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
    @async.with_task_group(group => {
      let running = group.spawn(no_wait=true, () => bot.run())
      transport.put(BOT_HELLO)
      guard transport.outgoing.get() is { "op": Number(2, ..), .. } else {
        fail("expected identify (round \{round})")
      }
      transport.put(bot_ready_frame())
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
async test "a supplied client reports to the bot once per call, only while it runs" {
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
  builder.on(Events::ready(), (ctx, _) => {
    // One REST call per run, made through the caller's client.
    ctx.app().http().get_current_user() |> ignore
    ready_contexts.put(ctx)
  })
  let http_events = Ref(0)
  builder.on_telemetry(event => {
    if event is HttpRequest(..) {
      http_events.val += 1
    }
  })
  let clock = @simclock.VirtualClock()
  builder.core.use_test_time(clock)
  let bot = builder.build()
  for _ in 0..<2 {
    let transport = @gatewaysim.FakeTransport(clock~)
    bot.core.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
    @async.with_task_group(group => {
      let running = group.spawn(no_wait=true, () => bot.run())
      transport.put(BOT_HELLO)
      guard transport.outgoing.get() is { "op": Number(2, ..), .. } else {
        fail("expected identify")
      }
      transport.put(bot_ready_frame())
      let ctx = ready_contexts.get()
      ctx.shutdown()
      running.wait()
    })
  }
  // Each run forwarded its own call once.
  assert_eq(http_events.val, 2)
  // Once the bot has stopped, the caller's client no longer reports to it.
  client.get_current_user() |> ignore
  assert_eq(requests.val, 3)
  assert_eq(http_events.val, 2)
}

///|
async test "events beyond the backlog skip handlers with telemetry and one warning" {
  let clock = @simclock.VirtualClock()
  let transport = @gatewaysim.FakeTransport(clock~)
  let warnings : Array[String] = []
  let app = @app.AppBuilder()
  app.on_warn(warning => warnings.push(warning.to_string()))
  let builder = BotBuilder(
    app.build(),
    token="test-token",
    intents=@model.Intents::guild_messages(),
    client=Client("test-token"),
    gateway_url="wss://gateway.example",
    event_backlog=2,
  )
  builder.core.gateway_bot_info_.val = Some(manager_gateway_info())
  builder.core.connector_.val = Some(_ => {
    (transport : &@gateway.GatewayTransport)
  })
  builder.core.use_test_time(clock)
  let ready_contexts : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  builder.on(Events::ready(), (ctx, _) => ready_contexts.put(ctx))
  // Subscribing is what lets MESSAGE_CREATE through the gateway filter;
  // middleware alone never widens it.
  builder.on(Events::message_create(), (_, _) => ())
  let blocked : @aqueue.Queue[String] = Queue(kind=Unbounded)
  let release : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let handled : Array[String] = []
  builder.middleware((_, event, next) => {
    if event is MessageCreate(created) {
      let id = created.message.id.to_string()
      handled.push(id)
      // Messages 1 and 2 each hold the only consumer until released.
      if id == "1" || id == "2" {
        blocked.put(id)
        release.get()
      }
    }
    next(event)
  })
  let dropped : Array[String] = []
  builder.on_telemetry(event => {
    if event is EventDropped(kind~, backlog=2) {
      dropped.push(kind)
    }
  })
  let bot = builder.build()
  let send = (id : Int32) => {
    transport.put(message_create_frame(id + 2, id.to_string()))
  }
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, () => bot.run())
    transport.put(BOT_HELLO)
    guard transport.outgoing.get() is { "op": Number(2, ..), .. } else {
      fail("expected identify")
    }
    transport.put(bot_ready_frame())
    let ctx = ready_contexts.get()
    // 1 holds the consumer, 2 and 3 fill the backlog of two, 4 is dropped.
    send(1)
    clock.settle()
    assert_eq(blocked.try_get(), Some("1"))
    for id in 2..<=4 {
      send(id)
    }
    clock.settle()
    assert_eq(dropped.length(), 1)
    // Releasing 1 lets the consumer take 2, which holds it again: one slot
    // frees but the backlog never drains, so the next overflow must not warn
    // a second time.
    release.put(())
    clock.settle()
    assert_eq(blocked.try_get(), Some("2"))
    send(5)
    send(6)
    clock.settle()
    assert_eq(dropped.length(), 2)
    release.put(())
    clock.settle()
    assert_eq(handled.length(), 4)
    ctx.shutdown()
    running.wait()
  })
  assert_eq(handled, ["1", "2", "3", "5"])
  assert_eq(dropped, ["KMessageCreate", "KMessageCreate"])
  assert_eq(warnings.length(), 1)
  assert_true(warnings[0].contains("dropping KMessageCreate"))
}

///|
test "build rejects an event backlog that holds nothing" {
  let builder = BotBuilder(
    @app.AppBuilder().build(),
    token="t",
    event_backlog=0,
  )
  try builder.build() |> ignore catch {
    InvalidEventBacklog(value~) => assert_eq(value, 0)
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected InvalidEventBacklog")
  }
}

///|
test "build rejects a negative shutdown grace" {
  let app = @app.AppBuilder().build()
  try
    BotBuilder(app, token="token", shutdown_grace_ms=-1).build() |> ignore
  catch {
    InvalidShutdownGrace(value~) => assert_eq(value, -1)
    _ => fail("expected InvalidShutdownGrace")
  } noraise {
    _ => fail("expected InvalidShutdownGrace")
  }
  BotBuilder(app, token="token", shutdown_grace_ms=0).build() |> ignore
}

///|
test "build rejects a message size limit below 1" {
  let app = @app.AppBuilder().build()
  for value in [0, -1] {
    try
      BotBuilder(app, token="token", max_message_bytes=value).build() |> ignore
    catch {
      InvalidMaxMessageBytes(value=got) => assert_eq(got, value)
      _ => fail("expected InvalidMaxMessageBytes")
    } noraise {
      _ => fail("expected InvalidMaxMessageBytes for \{value}")
    }
  }
  BotBuilder(app, token="token", max_message_bytes=1).build() |> ignore
}
