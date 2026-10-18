///|
async test "handler tracker waits for spawned work and forgets failed spawns" {
  let tracker = HandlerTracker::new()
  let release : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  @async.with_task_group(group => {
    let spawner = tracker.spawner(body => group.spawn_bg(body))
    spawner(() => release.get())
    spawner(() => ())
    assert_eq(tracker.active, 2)
    let failing = tracker.spawner(_ => raise RuntimeTestFailure)
    try failing(() => ()) catch {
      RuntimeTestFailure => ()
      error => fail("unexpected \{Repr(error)}")
    } noraise {
      _ => fail("expected the spawn to fail")
    }
    assert_eq(tracker.active, 2)
    let idle = group.spawn(() => tracker.wait_idle())
    @async.pause()
    assert_eq(tracker.active, 1)
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
  let clock = @simclock.VirtualClock()
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
    clock.settle()
    transport.put(BOT_HELLO)
    transport.put(bot_ready_frame())
    let ctx = ready_contexts.get()
    transport.put(command_frame(2, "500000000000000001"))
    started.get()
    shutdown_at.val = clock.now_unix_ms()
    ctx.shutdown()
    while returned_at.val is None && clock.advance_to_next() {
      ()
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
  clock : @simclock.VirtualClock,
  rand~ : @random.Rand = @random.Rand::chacha8(),
) -> Unit {
  self.clock_.val = clock
  self.rand_.val = Some(rand)
}

///|
async test "shutdown from a handler starts the grace once every shard has closed" {
  let clock = @simclock.VirtualClock()
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
    clock.settle()
    first.put(command_frame(2, "500000000000000001"))
    while !returned.val && clock.advance_to_next() {
      ()
    }
  })
  assert_true(returned.val)
  assert_true(stopped.val)
  assert_eq(warnings, [])
  assert_eq(first.close_calls.val, 1)
  assert_eq(second.close_calls.val, 1)
}
