///|
const MANAGER_HELLO : String =
  #|{"op":10,"d":{"heartbeat_interval":60000}}

///|
fn manager_ready_frame(shard_id : Int32, shard_count : Int32) -> String {
  (
    #|{"op":0,"s":1,"t":"READY","d":{"v":10,"user":{"id":"1","username":"bot","discriminator":"0","global_name":null,"avatar":null},"guilds":[],"session_id":"SESSION_ID","resume_gateway_url":"wss://resume.example","application":{"id":"42"},"shard":[SHARD_ID,SHARD_COUNT]}}
  )
  .replace(old="SESSION_ID", new="sess-\{shard_id}")
  .replace(old="SHARD_ID", new=shard_id.to_string())
  .replace(old="SHARD_COUNT", new=shard_count.to_string())
}

///|
fn manager_message_delete_frame(id : String) -> String {
  (
    #|{"op":0,"s":2,"t":"MESSAGE_DELETE","d":{"id":"MESSAGE_ID","channel_id":"6"}}
  ).replace(old="MESSAGE_ID", new=id)
}

///|
fn manager_gateway_info(
  shards~ : Int32 = 2,
  remaining~ : Int32 = 100,
  max_concurrency~ : Int32 = 1,
) -> @model.GatewayBotInfo {
  {
    url: "wss://gateway.example",
    shards,
    session_start_limit: {
      total: 1000,
      remaining,
      reset_after: 60000L,
      max_concurrency,
    },
  }
}

///|
fn identify_shard(payload : Json) -> (Int32, Int32) raise {
  guard payload
    is {
      "op": Number(2, ..),
      "d": { "shard": [Number(id, ..), Number(count, ..)], .. },
      ..
    } else {
    fail("expected identify, got \{payload.stringify()}")
  }
  (id.to_int(), count.to_int())
}

///|
fn ready_shard(ready : @model.Ready) -> Int32 raise {
  guard ready.shard is Some([id, ..]) else {
    fail("expected READY shard tuple")
  }
  id
}

///|
/// Observe the expected queue delivery without advancing virtual time.
async fn[T] manager_get(
  clock : @netruntime.VirtualClock,
  queue : @aqueue.Queue[T],
  stage : String,
) -> T {
  let received : Ref[T?] = Ref(None)
  clock.settle(until=() => {
    received.val = queue.try_get() catch { _ => None }
    received.val is Some(_)
  }) catch {
    _ => fail("\{stage} did not happen")
  }
  received.val.unwrap()
}

///|
/// The IDENTIFY `transport` has sent, if any.
fn sent_identify(transport : @gatewaysim.FakeTransport) -> Json? {
  for frame in transport.sent {
    if frame is { "op": Number(2, ..), .. } {
      return Some(frame)
    }
  }
  None
}

///|
/// Fire timers in deadline order until every transport has sent an IDENTIFY,
/// and return the virtual time each one was sent at.
async fn identify_times(
  clock : @netruntime.VirtualClock,
  transports : Array[@gatewaysim.FakeTransport],
) -> Array[Int64] {
  let times : Array[Int64?] = transports.map(_ => None)
  clock.settle(until=() => {
    transports.all(transport => sent_identify(transport) is Some(_)) ||
    (
      transports.any(transport => sent_identify(transport) is Some(_)) &&
      clock.pending().length() == transports.length() + 1
    )
  })
  while true {
    for index, transport in transports {
      if times[index] is None && sent_identify(transport) is Some(_) {
        times[index] = Some(clock.now_unix_ms())
      }
    }
    if times.iter().all(time => time is Some(_)) {
      break
    }
    guard clock.advance_to_next() else { fail("an IDENTIFY was never sent") }
    clock.settle(until=() => {
      transports.all(transport => sent_identify(transport) is Some(_)) ||
      clock.pending().length() == transports.length() + 1
    })
  }
  times.map(time => time.unwrap())
}

///|
async test "shard config resolves auto fixed and range selections" {
  let client = @dhttp.Client("test-token")
  let app = @app.AppBuilder()
  let auto = BotBuilder(app.build(), token="test-token", shards=Auto)
  assert_true(auto.core.compression_ is None)
  auto.core.gateway_bot_info_.val = Some(manager_gateway_info(shards=3))
  let auto_config = auto.core.resolve_shards(client)
  debug_inspect(
    (auto_config.ids, auto_config.count, auto_config.max_concurrency),
    content="([0, 1, 2], 3, 1)",
  )

  let fixed = BotBuilder(app.build(), token="test-token", shards=Fixed(count=2))
  fixed.core.gateway_bot_info_.val = Some(manager_gateway_info())
  let fixed_config = fixed.core.resolve_shards(client)
  debug_inspect((fixed_config.ids, fixed_config.count), content="([0, 1], 2)")

  let compressed = BotBuilder(app.build(), token="test-token", compress=true)
  assert_true(compressed.core.compression_ is Some(ZlibStream))
  let zstd = BotBuilder(
    app.build(),
    token="test-token",
    compress=true,
    compression=ZstdStream,
  )
  assert_true(zstd.core.compression_ is Some(ZstdStream))

  let injected_queue = @queue.InMemoryQueue()
  let coordinated = BotBuilder(
    app.build(),
    token="test-token",
    identify_queue=(injected_queue : &@queue.IdentifyQueue),
  )
  guard coordinated.core.identify_queue_ is Some(_) else {
    fail("expected injected identify queue")
  }

  let ranged = BotBuilder(
    app.build(),
    token="test-token",
    shards=Range(ids=[1, 3], count=4),
  )
  ranged.core.gateway_bot_info_.val = Some(manager_gateway_info())
  let range_config = ranged.core.resolve_shards(client)
  debug_inspect((range_config.ids, range_config.count), content="([1, 3], 4)")

  let limited = BotBuilder(
    app.build(),
    token="test-token",
    shards=Fixed(count=2),
  )
  limited.core.gateway_bot_info_.val = Some(manager_gateway_info(remaining=1))
  try limited.core.resolve_shards(client) catch {
    SessionStartLimitExceeded(required=2, remaining=1, reset_after_ms=60000L) =>
      ()
    error => fail("unexpected error: \{error}")
  } noraise {
    _ => fail("expected session start limit failure")
  }

  // A saved session RESUMEs instead of identifying, so it is not counted.
  let saved = manager_bot_session(0, 2)
  let resumed = BotBuilder(
    app.build(),
    token="test-token",
    shards=Fixed(count=2),
    sessions={ 0: saved },
  )
  resumed.core.gateway_bot_info_.val = Some(manager_gateway_info(remaining=1))
  let resumed_config = resumed.core.resolve_shards(client)
  debug_inspect(
    (resumed_config.ids, resumed_config.count),
    content="([0, 1], 2)",
  )
  let exhausted = BotBuilder(
    app.build(),
    token="test-token",
    shards=Fixed(count=2),
    sessions={ 0: saved },
  )
  exhausted.core.gateway_bot_info_.val = Some(manager_gateway_info(remaining=0))
  try exhausted.core.resolve_shards(client) catch {
    SessionStartLimitExceeded(required=1, remaining=0, reset_after_ms=60000L) =>
      ()
    error => fail("unexpected error: \{error}")
  } noraise {
    _ => fail("expected session start limit failure for the unsaved shard")
  }

  // A snapshot recorded under another shard count cannot RESUME this layout.
  let foreign_app = @app.AppBuilder()
  let warnings : Array[String] = []
  foreign_app.on_warn(warning => warnings.push(warning.to_string()))
  let foreign = BotBuilder(
    foreign_app.build(),
    token="test-token",
    shards=Fixed(count=2),
    sessions={ 0: manager_bot_session(0, 3) },
  )
  foreign.core.gateway_bot_info_.val = Some(manager_gateway_info(remaining=1))
  try foreign.core.resolve_shards(client) catch {
    SessionStartLimitExceeded(required=2, remaining=1, reset_after_ms=60000L) =>
      ()
    error => fail("unexpected error: \{error}")
  } noraise {
    _ => fail("expected the foreign snapshot to count as an identify")
  }
  inspect(
    warnings.join("\n"),
    content=(
      #|ignoring saved session for shard 0: its READY was recorded for shard [0, 3] but the bot resolved shard [0, 2], so the shard identifies instead
    ),
  )
  client.close()
}

///|
fn manager_bot_session(
  shard_id : Int32,
  shard_count : Int32,
) -> BotSession raise {
  guard @json.parse(manager_ready_frame(shard_id, shard_count))
    is { "d": ready_json, .. } else {
    fail("expected READY payload")
  }
  let ready : @model.Ready = @json.from_json(ready_json)
  {
    gateway: {
      id: ready.session_id,
      resume_url: ready.resume_gateway_url,
      sequence: 1L,
    },
    ready,
  }
}

///|
async test "fixed shards share identify queue and dispatch path" {
  let clock = @netruntime.VirtualClock()
  let first = @gatewaysim.FakeTransport(clock~)
  let second = @gatewaysim.FakeTransport(clock~)
  let pending : Array[@gatewaysim.FakeTransport] = [second, first]
  let app = @app.AppBuilder()
  let bot = BotBuilder(
    app.build(),
    token="test-token",
    intents=@model.Intents::guild_messages(),
    client=Client("test-token"),
    shards=Fixed(count=2),
  )
  bot.core.gateway_bot_info_.val = Some(manager_gateway_info(max_concurrency=1))
  bot.core.connector_.val = Some(_ => {
    match pending.pop() {
      Some(transport) => (transport : &@gateway.GatewayTransport)
      None => raise @gateway.TransportClosed(code=None, reason="no transport")
    }
  })
  bot.core.use_test_time(clock)
  let ready_contexts : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.on(Events::ready(), (ctx, _) => ready_contexts.put(ctx))
  let deleted : @aqueue.Queue[(String, Int32)] = Queue(kind=Unbounded)
  bot.on(Events::message_delete(), (ctx, event) => {
    deleted.put((event.id.to_string(), ready_shard(ctx.ready())))
  })
  let identified : Array[Int32] = []
  bot.on_telemetry(event => {
    if event is ShardIdentified(shard_id~) {
      identified.push(shard_id)
    }
  })

  let bot_bot = bot.build()
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, allow_failure=true, () => {
      bot_bot.run()
    })
    let started_at = clock.now_unix_ms()
    first.put(MANAGER_HELLO)
    second.put(MANAGER_HELLO)
    // One bucket: one shard identifies at once, the other a full spacing
    // later.
    let times = identify_times(clock, [first, second])
    times.sort()
    assert_eq(times, [started_at, started_at + 5250L])
    guard sent_identify(first) is Some(first_identify) else {
      fail("expected first identify")
    }
    guard sent_identify(second) is Some(second_identify) else {
      fail("expected second identify")
    }
    let (first_id, first_count) = identify_shard(first_identify)
    let (second_id, second_count) = identify_shard(second_identify)
    assert_eq(first_count, 2)
    assert_eq(second_count, 2)
    assert_true(first_id != second_id)

    first.put(manager_ready_frame(first_id, 2))
    second.put(manager_ready_frame(second_id, 2))
    let first_ctx = manager_get(clock, ready_contexts, "first READY handler")
    let second_ctx = manager_get(clock, ready_contexts, "second READY handler")
    assert_true(
      ready_shard(first_ctx.ready()) != ready_shard(second_ctx.ready()),
    )

    first.put(manager_message_delete_frame("700"))
    second.put(manager_message_delete_frame("701"))
    let first_delete = manager_get(clock, deleted, "first message handler")
    let second_delete = manager_get(clock, deleted, "second message handler")
    assert_true(first_delete.0 != second_delete.0)
    assert_true(first_delete.1 != second_delete.1)
    assert_eq(identified.length(), 2)
    assert_true(identified.contains(0))
    assert_true(identified.contains(1))

    first_ctx.shutdown()
    running.wait()
  })
  assert_eq(first.close_calls.val, 1)
  assert_eq(second.close_calls.val, 1)
}

///|
async test "fatal close fails the manager and closes sibling shards" {
  let clock = @netruntime.VirtualClock()
  let first = @gatewaysim.FakeTransport(clock~)
  let second = @gatewaysim.FakeTransport(clock~)
  let pending : Array[@gatewaysim.FakeTransport] = [second, first]
  let app = @app.AppBuilder()
  let bot = BotBuilder(
    app.build(),
    token="test-token",
    client=Client("test-token"),
    shards=Fixed(count=2),
  )
  bot.core.gateway_bot_info_.val = Some(manager_gateway_info(max_concurrency=2))
  bot.core.connector_.val = Some(_ => {
    match pending.pop() {
      Some(transport) => (transport : &@gateway.GatewayTransport)
      None => raise @gateway.TransportClosed(code=None, reason="no transport")
    }
  })
  bot.core.use_test_time(clock)
  let ready : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  bot.on(Events::ready(), (_, _) => ready.put(()))

  let bot_bot = bot.build()
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, allow_failure=true, () => {
      bot_bot.run()
    })
    first.put(MANAGER_HELLO)
    second.put(MANAGER_HELLO)
    let first_identify = first.outgoing.get()
    let second_identify = second.outgoing.get()
    let (first_id, _) = identify_shard(first_identify)
    let (second_id, _) = identify_shard(second_identify)
    first.put(manager_ready_frame(first_id, 2))
    second.put(manager_ready_frame(second_id, 2))
    ready.get()
    ready.get()

    first.server_close(Some(4014))
    try running.wait() catch {
      BotError::FatallyClosed(code=4014) => ()
      error => fail("unexpected error: \{error}")
    } noraise {
      _ => fail("expected fatal close")
    }
  })
  assert_eq(second.close_calls.val, 1)
}

///|
async test "voice state updates go to the shard that owns the guild" {
  let clock = @netruntime.VirtualClock()
  let first = @gatewaysim.FakeTransport(clock~)
  let second = @gatewaysim.FakeTransport(clock~)
  let pending : Array[@gatewaysim.FakeTransport] = [second, first]
  let app = @app.AppBuilder()
  let bot = BotBuilder(
    app.build(),
    token="test-token",
    client=Client("test-token"),
    shards=Fixed(count=2),
  )
  bot.core.gateway_bot_info_.val = Some(manager_gateway_info(max_concurrency=2))
  bot.core.connector_.val = Some(_ => {
    match pending.pop() {
      Some(transport) => (transport : &@gateway.GatewayTransport)
      None => raise @gateway.TransportClosed(code=None, reason="no transport")
    }
  })
  bot.core.use_test_time(clock)
  let ready : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.on(Events::ready(), (ctx, _) => ready.put(ctx))
  let bot_bot = bot.build()
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, allow_failure=true, () => {
      bot_bot.run()
    })
    first.put(MANAGER_HELLO)
    second.put(MANAGER_HELLO)
    let first_identify = manager_get(clock, first.outgoing, "first identify")
    let second_identify = manager_get(clock, second.outgoing, "second identify")
    let (first_id, _) = identify_shard(first_identify)
    let (second_id, _) = identify_shard(second_identify)
    first.put(manager_ready_frame(first_id, 2))
    second.put(manager_ready_frame(second_id, 2))
    let ctx = manager_get(clock, ready, "first READY handler")
    manager_get(clock, ready, "second READY handler") |> ignore
    // (guild_id >> 22) % 2: 1 << 22 is on shard 1 and 2 << 22 on shard 0,
    // whichever shard's context sends the command.
    let on_shard_one : @model.Id[@model.GuildMarker] = Id(4194304UL)
    let on_shard_zero : @model.Id[@model.GuildMarker] = Id(8388608UL)
    ctx.update_voice_state({
      guild_id: on_shard_one,
      channel_id: Some(Id(7UL)),
      self_mute: false,
      self_deaf: false,
    })
    ctx.update_voice_state({
      guild_id: on_shard_zero,
      channel_id: None,
      self_mute: false,
      self_deaf: false,
    })
    let (one, zero) = if first_id == 1 {
      (first, second)
    } else {
      (second, first)
    }
    let sent_one = manager_get(clock, one.outgoing, "shard 1 voice state")
    let sent_zero = manager_get(clock, zero.outgoing, "shard 0 voice state")
    guard sent_one
      is { "op": Number(4, ..), "d": { "guild_id": "4194304", .. }, .. } else {
      fail("shard 1 got \{sent_one.stringify()}")
    }
    guard sent_zero
      is { "op": Number(4, ..), "d": { "guild_id": "8388608", .. }, .. } else {
      fail("shard 0 got \{sent_zero.stringify()}")
    }
    ctx.shutdown()
    running.wait()
  })
}

///|
async test "a voice state update for a shard run elsewhere raises" {
  let clock = @netruntime.VirtualClock()
  let transport = @gatewaysim.FakeTransport(clock~)
  let app = @app.AppBuilder()
  let bot = BotBuilder(
    app.build(),
    token="test-token",
    client=Client("test-token"),
    gateway_url="wss://gateway.example",
    shards=Single(id=0, count=2),
  )
  bot.core.gateway_bot_info_.val = Some(manager_gateway_info())
  bot.core.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
  bot.core.use_test_time(clock)
  let ready : @aqueue.Queue[GatewayCtx] = Queue(kind=Unbounded)
  bot.on(Events::ready(), (ctx, _) => ready.put(ctx))
  let bot_bot = bot.build()
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, allow_failure=true, () => {
      bot_bot.run()
    })
    transport.put(MANAGER_HELLO)
    manager_get(clock, transport.outgoing, "identify") |> ignore
    transport.put(manager_ready_frame(0, 2))
    let ctx = manager_get(clock, ready, "READY handler")
    try
      ctx.update_voice_state({
        guild_id: Id(4194304UL),
        channel_id: None,
        self_mute: false,
        self_deaf: false,
      })
    catch {
      BotError::ShardNotManaged(shard_id=1) as error =>
        assert_eq(error.to_string(), "shard 1 is not run by this process")
      error => fail("unexpected error: \{error}")
    } noraise {
      _ => fail("expected ShardNotManaged")
    }
    ctx.shutdown()
    running.wait()
  })
}

///|
test "static_layout names every selection except Auto" {
  debug_inspect(
    ShardConfig::Auto.static_layout(),
    content=(
      #|None
    ),
  )
  debug_inspect(
    Single(id=2, count=4).static_layout(),
    content=(
      #|Some(([2], 4))
    ),
  )
  debug_inspect(
    Fixed(count=3).static_layout(),
    content=(
      #|Some(([0, 1, 2], 3))
    ),
  )
  debug_inspect(
    Fixed(count=-1).static_layout(),
    content=(
      #|Some(([], -1))
    ),
  )
  debug_inspect(
    Range(ids=[1, 3], count=4).static_layout(),
    content=(
      #|Some(([1, 3], 4))
    ),
  )
}

///|
test "session_start_refusal refuses more sessions than remain" {
  let limit = (remaining : Int32) => @model.SessionStartLimit::{
    total: 1000,
    remaining,
    reset_after: 60000L,
    max_concurrency: 1,
  }
  let rows : Array[(Int32, Int32)] = [(0, 1), (1, 1), (1, 2), (0, 0)]
  let refusals = rows.map(row => {
    let (remaining, required) = row
    session_start_refusal(limit(remaining), required~)
  })
  debug_inspect(
    refusals,
    content=(
      #|[
      #|  Some(
      #|    SessionStartLimitExceeded(
      #|      required=1,
      #|      remaining=0,
      #|      reset_after_ms=60000,
      #|    ),
      #|  ),
      #|  None,
      #|  Some(
      #|    SessionStartLimitExceeded(
      #|      required=2,
      #|      remaining=1,
      #|      reset_after_ms=60000,
      #|    ),
      #|  ),
      #|  None,
      #|]
    ),
  )
}
