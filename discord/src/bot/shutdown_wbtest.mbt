///|
async test "handler tracker counts bodies while they run" {
  let tracker = HandlerTracker::new()
  let release : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  @async.with_task_group(group => {
    let spawner = tracker.spawner(body => group.spawn_bg(body))
    spawner(() => release.get())
    spawner(() => ())
    // Spawned, not started yet.
    assert_eq(tracker.active, 0)
    @async.pause()
    assert_eq(tracker.active, 1)
    // A spawner that never runs the body leaves nothing tracked.
    let dropping = tracker.spawner(_ => ())
    dropping(() => fail("must not run"))
    assert_eq(tracker.active, 1)
    let idle = group.spawn(() => tracker.wait_idle())
    release.put(())
    idle.wait()
    assert_eq(tracker.active, 0)
  })
}

///|
/// Run a bot with one command that waits for `release`, request shutdown
/// while it runs, and return the virtual time `run` took to return after the
/// shutdown, with the warnings it reported.
async fn shutdown_with_running_handler(
  grace_ms : Int32,
  finish_after_ms : Int32?,
) -> (Int64, Array[String]) {
  let clock = @netruntime.VirtualClock()
  let transport = @gatewaysim.FakeTransport(clock~)
  let app = @app.AppBuilder()
  let warnings : Array[String] = []
  app.on_warn(warning => warnings.push(warning.to_string()))
  let started : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  app.command(
    @app.slash(
      name="raw",
      description="Long-running command",
      args=@interaction.Args::unit(),
      handler=Raw(_ => {
        started.put(())
        match finish_after_ms {
          Some(ms) => (clock : &@hclock.Clock).sleep(ms)
          None => (clock : &@hclock.Clock).sleep(2147483647)
        }
      }),
    ),
  )
  let bot = BotBuilder(
    app.build(),
    token="test-token",
    client=Client("test-token"),
    gateway_url="wss://gateway.example",
    shutdown_grace_ms=grace_ms,
  )
  bot.core.gateway_bot_info_.val = Some(manager_gateway_info(shards=1))
  bot.core.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
  bot.core.use_test_time(clock)
  let ready_contexts : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.on(Events::ready(), (ctx, _) => ready_contexts.put(ctx))
  let bot_bot = bot.build()
  let returned_at : Ref[Int64?] = Ref(None)
  let shutdown_at = Ref(0L)
  @async.with_task_group(group => {
    group.spawn_bg(() => {
      bot_bot.run()
      returned_at.val = Some(clock.now_unix_ms())
    })
    transport.put(BOT_HELLO)
    transport.put(bot_ready_frame())
    let ctx = ready_contexts.get()
    transport.put(command_frame(2, "500000000000000001"))
    started.get()
    shutdown_at.val = clock.now_unix_ms()
    ctx.shutdown()
    clock.settle(until=() => {
      returned_at.val is Some(_) ||
      (transport.close_calls.val == 1 && clock.pending().contains(grace_ms))
    })
    if returned_at.val is None {
      assert_true(clock.advance_to_next())
      clock.settle(until=() => returned_at.val is Some(_))
    }
    assert_eq(transport.close_calls.val, 1)
    assert_eq(transport.close_code.val, Some(1000))
  })
  guard returned_at.val is Some(at) else { fail("run never returned") }
  (at - shutdown_at.val, warnings)
}

///|
async test "shutdown waits for handlers within the grace period" {
  let (took, warnings) = shutdown_with_running_handler(5000, Some(3000))
  assert_eq(took, 3000L)
  assert_eq(warnings, [])
}

///|
async test "shutdown cancels handlers still running after the grace period" {
  let (took, warnings) = shutdown_with_running_handler(5000, None)
  assert_eq(took, 5000L)
  assert_eq(warnings, [
    "1 handlers were still running 5000 ms after shutdown; cancelling them",
  ])
}

///|
/// Run a bot on `clock` with seeded shard randomness, so heartbeat jitter and
/// backoff are the same on every run (a zero first jitter would beat before
/// IDENTIFY with no timer). Virtual time alone is not enough: the shards'
/// default randomness is seeded from the system.
fn BotCore::use_test_time(
  self : BotCore,
  clock : @netruntime.VirtualClock,
  rand~ : @random.Rand = @random.Rand::chacha8(),
) -> Unit {
  self.clock_.val = clock
  self.rand_.val = Some(rand)
}

///|
async test "shutdown from a handler starts the grace once every shard has closed" {
  let clock = @netruntime.VirtualClock()
  let first = @gatewaysim.FakeTransport(clock~)
  let second = @gatewaysim.FakeTransport(clock~)
  // The second shard takes longer to close than the grace allows.
  second.close_takes_ms.val = 3000
  let pending : Array[@gatewaysim.FakeTransport] = [second, first]
  let app = @app.AppBuilder()
  let warnings : Array[String] = []
  app.on_warn(warning => warnings.push(warning.to_string()))
  let ready_ctx : Ref[GatewayCtx?] = Ref(None)
  let stopped = Ref(false)
  app.command(
    @app.slash(
      name="raw",
      description="Stop the bot",
      args=@interaction.Args::unit(),
      handler=Raw(_ => {
        guard ready_ctx.val is Some(ctx) else { fail("no context") }
        ctx.shutdown()
        stopped.val = true
      }),
    ),
  )
  let bot = BotBuilder(
    app.build(),
    token="test-token",
    client=Client("test-token"),
    shards=Fixed(count=2),
    shutdown_grace_ms=1000,
  )
  bot.core.gateway_bot_info_.val = Some(manager_gateway_info(max_concurrency=2))
  bot.core.connector_.val = Some(_ => {
    match pending.pop() {
      Some(transport) => (transport : &@gateway.GatewayTransport)
      None => raise @gateway.TransportClosed(code=None, reason="no transport")
    }
  })
  bot.core.use_test_time(clock)
  bot.on(Events::ready(), (ctx, _) => ready_ctx.val = Some(ctx))
  let bot_bot = bot.build()
  let returned = Ref(false)
  @async.with_task_group(group => {
    group.spawn_bg(() => {
      bot_bot.run()
      returned.val = true
    })
    first.put(MANAGER_HELLO)
    second.put(MANAGER_HELLO)
    ignore(identify_times(clock, [first, second]))
    for transport in [first, second] {
      guard sent_identify(transport) is Some(identify) else {
        fail("expected identify")
      }
      let (shard_id, _) = identify_shard(identify)
      transport.put(manager_ready_frame(shard_id, 2))
    }
    clock.settle(until=() => ready_ctx.val is Some(_))
    first.put(command_frame(2, "500000000000000001"))
    clock.settle(until=() => {
      second.close_calls.val == 1 && clock.pending().contains(3000)
    })
    clock.advance(3000)
    clock.settle(until=() => returned.val)
  })
  assert_true(returned.val)
  assert_true(stopped.val)
  assert_eq(warnings, [])
  assert_eq(first.close_calls.val, 1)
  assert_eq(second.close_calls.val, 1)
}

///|
/// Handlers that run until the test releases them by id, recording when each
/// started.
priv struct HeldHandlers {
  clock : @netruntime.VirtualClock
  started : Array[(String, Int64)]
  releases : Map[String, @aqueue.Queue[Unit]]
}

///|
async fn HeldHandlers::hold(self : HeldHandlers, id : String) -> Unit {
  self.started.push((id, self.clock.now_unix_ms()))
  let release : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  self.releases[id] = release
  release.get()
}

///|
async fn HeldHandlers::release(self : HeldHandlers, id : String) -> Unit {
  guard self.releases.get(id) is Some(release) else {
    abort("\{id} never started")
  }
  release.put(())
}

///|
async test "handlers that have not started when shutdown is requested never start" {
  // One handler permit each for events and for interactions, and a backlog
  // of one: message 1 runs, message 2 waits for a permit, message 3 waits in
  // the backlog; command 1 runs and command 2 waits for a permit. After the
  // shutdown request only message 1 and command 1 may run.
  let clock = @netruntime.VirtualClock()
  let transport = @gatewaysim.FakeTransport(clock~)
  let held = HeldHandlers::{ clock, started: [], releases: Map([]), }
  let app = @app.AppBuilder(max_in_flight=1)
  let warnings : Array[String] = []
  app.on_warn(warning => warnings.push(warning.to_string()))
  app.command(
    @app.slash(
      name="raw",
      description="Held command",
      args=@interaction.Args::unit(),
      handler=Raw(raw => held.hold("command \{raw.interaction.id}")),
    ),
  )
  let bot = BotBuilder(
    app.build(),
    token="test-token",
    client=Client("test-token"),
    gateway_url="wss://gateway.example",
    event_backlog=1,
    shutdown_grace_ms=5000,
  )
  bot.core.gateway_bot_info_.val = Some(manager_gateway_info(shards=1))
  bot.core.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
  bot.core.use_test_time(clock)
  let telemetry : Array[String] = []
  bot.on_telemetry(event => {
    match event {
      EventDispatched(kind~, ..) => telemetry.push("dispatched \{kind}")
      EventDropped(kind~, ..) => telemetry.push("dropped \{kind}")
      EventDiscarded(kind~) => telemetry.push("discarded \{kind}")
      _ => ()
    }
  })
  let ready_contexts : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.on(Events::ready(), (ctx, _) => ready_contexts.put(ctx))
  bot.on(Events::message_delete(), (_, event) => {
    held.hold("message \{event.id}")
  })
  let bot_bot = bot.build()
  let returned_at : Ref[Int64?] = Ref(None)
  @async.with_task_group(group => {
    group.spawn_bg(() => {
      bot_bot.run()
      returned_at.val = Some(clock.now_unix_ms())
    })
    transport.put(BOT_HELLO)
    transport.put(bot_ready_frame())
    let ctx = ready_contexts.get()
    transport.put(message_delete_frame(2, "700000000000000001"))
    transport.put(message_delete_frame(3, "700000000000000002"))
    clock.settle(until=() => {
      held.started.length() == 1 && telemetry.length() == 3
    })
    transport.put(message_delete_frame(4, "700000000000000003"))
    transport.put(command_frame(5, "500000000000000001"))
    clock.settle(until=() => {
      held.started.length() == 2 && telemetry.length() == 4
    })
    transport.put(command_frame(6, "500000000000000002"))
    clock.settle(until=() => {
      telemetry.length() == 5 && clock.pending().contains(2500)
    })
    assert_eq(held.started.map(entry => entry.0), [
      "message 700000000000000001", "command 500000000000000001",
    ])
    clock.advance(100)
    let shutdown_at = clock.now_unix_ms()
    ctx.shutdown()
    clock.settle(until=() => {
      warnings.length() == 2 && transport.close_calls.val == 1
    })
    // The waiting interaction gives up at once; the running handlers finish.
    assert_eq(warnings, [
      "event handlers are 1 events behind; dropping KInteractionCreate and later events until they catch up",
      "interaction dropped (command:raw): the executor was stopping before the handler could start",
    ])
    clock.advance(100)
    held.release("message 700000000000000001")
    held.release("command 500000000000000001")
    clock.settle(until=() => returned_at.val is Some(_))
    assert_eq(returned_at.val, Some(shutdown_at + 100L))
  })
  assert_eq(held.started.map(entry => entry.0), [
    "message 700000000000000001", "command 500000000000000001",
  ])
  // READY, message 1, and message 2 were taken from the backlog (message 2's
  // handler then waited for a permit); the INTERACTION_CREATE events found the
  // backlog full while message 3 waited in it, which shutdown discarded.
  assert_eq(telemetry, [
    "dispatched KReady", "dispatched KMessageDelete", "dispatched KMessageDelete",
    "dropped KInteractionCreate", "dropped KInteractionCreate", "discarded KMessageDelete",
  ])
  assert_eq(clock.pending(), [])
}

///|
/// Collect the event telemetry a bot reports, by kind.
fn event_telemetry(bot : BotBuilder) -> Array[String] {
  let telemetry : Array[String] = []
  bot.on_telemetry(event => {
    match event {
      EventDispatched(kind~, ..) => telemetry.push("dispatched \{kind}")
      EventDropped(kind~, ..) => telemetry.push("dropped \{kind}")
      EventDiscarded(kind~) => telemetry.push("discarded \{kind}")
      _ => ()
    }
  })
  telemetry
}

///|
async test "event middleware running at shutdown gets the grace, and the events behind it are discarded" {
  let clock = @netruntime.VirtualClock()
  let transport = @gatewaysim.FakeTransport(clock~)
  let app = @app.AppBuilder()
  let bot = BotBuilder(
    app.build(),
    token="test-token",
    client=Client("test-token"),
    gateway_url="wss://gateway.example",
    shutdown_grace_ms=5000,
  )
  bot.core.gateway_bot_info_.val = Some(manager_gateway_info(shards=1))
  bot.core.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
  bot.core.use_test_time(clock)
  let telemetry = event_telemetry(bot)
  let in_middleware : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let release : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let finished = Ref(false)
  bot.middleware((_, event, next) => {
    if event is MessageDelete(_) {
      in_middleware.put(())
      release.get()
      finished.val = true
    }
    next(event)
  })
  let ready_contexts : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.on(Events::ready(), (ctx, _) => ready_contexts.put(ctx))
  let handled : Array[String] = []
  bot.on(Events::message_delete(), (_, event) => {
    handled.push(event.id.to_string())
  })
  let bot_bot = bot.build()
  let returned_at : Ref[Int64?] = Ref(None)
  @async.with_task_group(group => {
    group.spawn_bg(() => {
      bot_bot.run()
      returned_at.val = Some(clock.now_unix_ms())
    })
    transport.put(BOT_HELLO)
    transport.put(bot_ready_frame())
    let ctx = ready_contexts.get()
    transport.put(message_delete_frame(2, "700000000000000001"))
    in_middleware.get()
    // The runner is inside the middleware for message 1; these wait.
    let queued = ctx.expect_event(Events::message_delete(), event => {
      event.id.to_string() == "700000000000000003"
    })
    transport.put(message_delete_frame(3, "700000000000000002"))
    transport.put(message_delete_frame(4, "700000000000000003"))
    queued.wait() |> ignore
    let shutdown_at = clock.now_unix_ms()
    ctx.shutdown()
    clock.settle(until=() => {
      transport.close_calls.val == 1 && clock.pending().contains(5000)
    })
    assert_eq(returned_at.val, None)
    clock.advance(1000)
    release.put(())
    clock.settle(until=() => returned_at.val is Some(_))
    assert_eq(returned_at.val, Some(shutdown_at + 1000L))
  })
  assert_true(finished.val)
  // Messages 2 and 3 are discarded from the backlog; message 1 when the
  // middleware's `next` passes it on after the request, so no handler starts.
  assert_eq(handled, [])
  assert_eq(telemetry, [
    "dispatched KReady", "discarded KMessageDelete", "discarded KMessageDelete",
    "discarded KMessageDelete",
  ])
}

///|
async test "events the run loop reads after the shutdown request reach no handler" {
  let clock = @netruntime.VirtualClock()
  let transport = @gatewaysim.FakeTransport(clock~)
  let client = @dhttp.Client("test-token")
  defer client.close()
  // The command sync after the first READY holds the run loop while the
  // shutdown is requested, so READY and the message after it are read later.
  let syncing : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let release : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  client.middleware((_request, _next) => {
    syncing.put(())
    release.get()
    { status: 200, headers: Map([]), body: Json::array([]), }
  })
  let bot = BotBuilder(
    @app.AppBuilder().build(),
    token="test-token",
    client~,
    gateway_url="wss://gateway.example",
    sync=Global,
  )
  bot.core.gateway_bot_info_.val = Some(manager_gateway_info(shards=1))
  bot.core.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
  bot.core.use_test_time(clock)
  let telemetry = event_telemetry(bot)
  let handled : Array[String] = []
  bot.on(Events::ready(), (_, _) => handled.push("ready"))
  bot.on(Events::message_delete(), (_, event) => {
    handled.push(event.id.to_string())
  })
  let bot_bot = bot.build()
  let returned = Ref(false)
  @async.with_task_group(group => {
    group.spawn_bg(() => {
      bot_bot.run()
      returned.val = true
    })
    transport.put(BOT_HELLO)
    transport.put(bot_ready_frame())
    syncing.get()
    transport.put(message_delete_frame(2, "700000000000000001"))
    clock.settle(until=() => {
      transport.received.val == 3 && transport.recv_in_flight.val
    })
    guard bot_bot.core.running_shards_.val is [{ context: Some(ctx), .. }] else {
      fail("expected the shard's context")
    }
    ctx.shutdown()
    release.put(())
    clock.settle(until=() => returned.val)
    assert_true(returned.val)
  })
  assert_eq(handled, [])
  assert_eq(telemetry, ["discarded KReady", "discarded KMessageDelete"])
}
