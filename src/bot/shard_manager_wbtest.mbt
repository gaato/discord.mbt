///|
struct ManagerFakeTransport {
  incoming : @aqueue.Queue[String]
  outgoing : @aqueue.Queue[(Int64, Json)]
  closed : Ref[Bool]
}

///|
fn ManagerFakeTransport::new() -> ManagerFakeTransport {
  {
    incoming: @aqueue.Queue::new(kind=Unbounded),
    outgoing: @aqueue.Queue::new(kind=Unbounded),
    closed: Ref(false),
  }
}

///|
fn ManagerFakeTransport::server_close(
  self : ManagerFakeTransport,
  code : Int,
) -> Unit {
  self.incoming.close(
    error=@gateway.TransportClosed(code=Some(code), reason="server closed"),
  )
}

///|
impl @gateway.GatewayTransport for ManagerFakeTransport with fn recv(self) {
  @gateway.GatewayFrame::Text(
    self.incoming.get() catch {
      error => raise error
    },
  )
}

///|
impl @gateway.GatewayTransport for ManagerFakeTransport with fn send(self, text) {
  self.outgoing.put((@async.now(), @json.parse(text)))
}

///|
impl @gateway.GatewayTransport for ManagerFakeTransport with fn close(
  self,
  code~,
) {
  self.closed.val = true
  self.incoming.close(
    error=@gateway.TransportClosed(code=Some(code), reason="client closed"),
  )
}

///|
const MANAGER_HELLO : String =
  #|{"op":10,"d":{"heartbeat_interval":60000}}

///|
fn manager_ready_frame(shard_id : Int, shard_count : Int) -> String {
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
  shards? : Int = 2,
  remaining? : Int = 100,
  max_concurrency? : Int = 1,
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
fn identify_shard(payload : Json) -> (Int, Int) raise {
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
fn ready_shard(ready : @model.Ready) -> Int raise {
  guard ready.shard is Some([id, ..]) else {
    fail("expected READY shard tuple")
  }
  id
}

///|
async fn[T] manager_get(queue : @aqueue.Queue[T], stage : String) -> T {
  match @async.with_timeout_opt(1000, () => queue.get()) {
    Some(value) => value
    None => fail("timed out waiting for \{stage}")
  }
}

///|
async test "shard config resolves auto fixed and range selections" {
  let client = @dhttp.Client::new("test-token")
  let app = @app.App::new(sync=@app.CommandSync::Disabled)
  let auto = Bot::new(app, token="test-token", shards=Auto)
  assert_false(auto.compress_)
  auto.gateway_bot_info_.val = Some(manager_gateway_info(shards=3))
  let auto_config = auto.resolve_shards(client)
  debug_inspect(
    (auto_config.ids, auto_config.count, auto_config.max_concurrency),
    content="([0, 1, 2], 3, 1)",
  )

  let fixed = Bot::new(app, token="test-token", shards=Fixed(count=2))
  fixed.gateway_bot_info_.val = Some(manager_gateway_info())
  let fixed_config = fixed.resolve_shards(client)
  debug_inspect((fixed_config.ids, fixed_config.count), content="([0, 1], 2)")

  let compressed = Bot::new(app, token="test-token", compress=true)
  assert_true(compressed.compress_)

  let ranged = Bot::new(
    app,
    token="test-token",
    shards=Range(ids=[1, 3], count=4),
  )
  ranged.gateway_bot_info_.val = Some(manager_gateway_info())
  let range_config = ranged.resolve_shards(client)
  debug_inspect((range_config.ids, range_config.count), content="([1, 3], 4)")

  let limited = Bot::new(app, token="test-token", shards=Fixed(count=2))
  limited.gateway_bot_info_.val = Some(manager_gateway_info(remaining=1))
  try limited.resolve_shards(client) catch {
    SessionStartLimitExceeded(required=2, remaining=1, reset_after_ms=60000L) =>
      ()
    error => fail("unexpected error: \{error}")
  } noraise {
    _ => fail("expected session start limit failure")
  }
  client.close()
}

///|
async test "fixed shards share identify queue and dispatch path" {
  let first = ManagerFakeTransport::new()
  let second = ManagerFakeTransport::new()
  let pending : Array[ManagerFakeTransport] = [second, first]
  let app = @app.App::new(sync=@app.CommandSync::Disabled)
  let bot = Bot::new(
    app,
    token="test-token",
    intents=@model.Intents::guild_messages(),
    client=@dhttp.Client::new("test-token"),
    shards=Fixed(count=2),
  )
  bot.gateway_bot_info_.val = Some(manager_gateway_info(max_concurrency=1))
  bot.identify_spacing_ms_.val = 60
  bot.connector_.val = Some(_ => {
    match pending.pop() {
      Some(transport) => (transport : &@gateway.GatewayTransport)
      None => raise @gateway.TransportClosed(code=None, reason="no transport")
    }
  })
  let ready_contexts : @aqueue.Queue[GatewayCtx] = @aqueue.Queue::new(
    kind=Unbounded,
  )
  bot.on(Events::ready(), (ctx, _) => ready_contexts.put(ctx))
  let deleted : @aqueue.Queue[(String, Int)] = @aqueue.Queue::new(
    kind=Unbounded,
  )
  bot.on(Events::message_delete(), (ctx, event) => {
    deleted.put((event.id.to_string(), ready_shard(ctx.ready())))
  })
  let identified : Array[Int] = []
  bot.on_telemetry(event => {
    if event is @telemetry.TelemetryEvent::ShardIdentified(shard_id~) {
      identified.push(shard_id)
    }
  })

  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, allow_failure=true, () => bot.run())
    first.incoming.put(MANAGER_HELLO)
    second.incoming.put(MANAGER_HELLO)
    let (first_at, first_identify) = manager_get(
      first.outgoing,
      "first identify",
    )
    let (second_at, second_identify) = manager_get(
      second.outgoing,
      "second identify",
    )
    let (first_id, first_count) = identify_shard(first_identify)
    let (second_id, second_count) = identify_shard(second_identify)
    assert_eq(first_count, 2)
    assert_eq(second_count, 2)
    assert_true(first_id != second_id)
    let identify_gap = if first_at > second_at {
      first_at - second_at
    } else {
      second_at - first_at
    }
    assert_true(identify_gap >= 50L)

    first.incoming.put(manager_ready_frame(first_id, 2))
    second.incoming.put(manager_ready_frame(second_id, 2))
    let first_ctx = manager_get(ready_contexts, "first READY handler")
    let second_ctx = manager_get(ready_contexts, "second READY handler")
    assert_true(
      ready_shard(first_ctx.ready()) != ready_shard(second_ctx.ready()),
    )

    first.incoming.put(manager_message_delete_frame("700"))
    second.incoming.put(manager_message_delete_frame("701"))
    let first_delete = manager_get(deleted, "first message handler")
    let second_delete = manager_get(deleted, "second message handler")
    assert_true(first_delete.0 != second_delete.0)
    assert_true(first_delete.1 != second_delete.1)
    assert_eq(identified.length(), 2)
    assert_true(identified.contains(0))
    assert_true(identified.contains(1))

    first_ctx.shutdown()
    guard @async.with_timeout_opt(1000, () => running.wait()) is Some(_) else {
      fail("timed out stopping shards")
    }
  })
  assert_true(first.closed.val)
  assert_true(second.closed.val)
}

///|
async test "fatal close fails the manager and closes sibling shards" {
  let first = ManagerFakeTransport::new()
  let second = ManagerFakeTransport::new()
  let pending : Array[ManagerFakeTransport] = [second, first]
  let app = @app.App::new(sync=@app.CommandSync::Disabled)
  let bot = Bot::new(
    app,
    token="test-token",
    client=@dhttp.Client::new("test-token"),
    shards=Fixed(count=2),
  )
  bot.gateway_bot_info_.val = Some(manager_gateway_info(max_concurrency=2))
  bot.identify_spacing_ms_.val = 1
  bot.connector_.val = Some(_ => {
    match pending.pop() {
      Some(transport) => (transport : &@gateway.GatewayTransport)
      None => raise @gateway.TransportClosed(code=None, reason="no transport")
    }
  })
  let ready : @aqueue.Queue[Unit] = @aqueue.Queue::new(kind=Unbounded)
  bot.on(Events::ready(), (_, _) => ready.put(()))

  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, allow_failure=true, () => bot.run())
    first.incoming.put(MANAGER_HELLO)
    second.incoming.put(MANAGER_HELLO)
    let (_, first_identify) = first.outgoing.get()
    let (_, second_identify) = second.outgoing.get()
    let (first_id, _) = identify_shard(first_identify)
    let (second_id, _) = identify_shard(second_identify)
    first.incoming.put(manager_ready_frame(first_id, 2))
    second.incoming.put(manager_ready_frame(second_id, 2))
    ready.get()
    ready.get()

    first.server_close(4014)
    try running.wait() catch {
      BotError::FatallyClosed(code=4014) => ()
      error => fail("unexpected error: \{error}")
    } noraise {
      _ => fail("expected fatal close")
    }
  })
  assert_true(second.closed.val)
}
