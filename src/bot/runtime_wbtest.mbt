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
      commands_in_sync([ping], [fetched_ping()]),
      commands_in_sync([ping], [fetched_ping(description="Changed")]),
      commands_in_sync([ping], [ping_with_option]),
      commands_in_sync([echo], [echo_wrong_required]),
      commands_in_sync([ping], [fetched_ping(name="other")]),
      commands_in_sync([echo], [echo_matching]),
    ],
    content="[true, false, false, false, false, true]",
  )
}

///|
test "intent derivation strips privileged intents and warns" {
  let bot = Bot::new(token="token", sync=Disabled)
  let warnings : Array[String] = []
  bot.on_warn(message => warnings.push(message))
  bot.on(Events::message_create(), (_, _) => ())
  bot.on(Events::guild_member_add(), (_, _) => ())
  inspect(bot.resolved_intents().bits(), content="4608")
  inspect(warnings.length(), content="1")
  assert_true(warnings[0].contains("privileged intent"))
  let explicit = Bot::new(
    token="token",
    intents=@model.Intents::guilds(),
    sync=Disabled,
  )
  let explicit_warnings : Array[String] = []
  explicit.on_warn(message => explicit_warnings.push(message))
  explicit.on(Events::message_create(), (_, _) => ())
  inspect(explicit.resolved_intents().bits(), content="1")
  inspect(explicit_warnings.length(), content="1")
}

///|
test "bot validates token and duplicate command names before connecting" {
  try Bot::new(token="", sync=Disabled).validate() catch {
    BotConfigError::EmptyToken => ()
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected empty token error")
  }
  let duplicate = Bot::new(token="token", sync=Disabled)
  let command = slash(
    name="same",
    description="Duplicate",
    args=@interaction.Args::unit(),
    handler=Raw(_ => ()),
  )
  duplicate.command(command)
  duplicate.command(command)
  try duplicate.validate() catch {
    BotConfigError::DuplicateCommand(name~) => inspect(name, content="same")
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected duplicate command error")
  }
}

///|
priv suberror RuntimeTestFailure {
  RuntimeTestFailure
} derive(Debug)

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
  self.incoming.get() catch {
    error => raise error
  }
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
    #|{"op":0,"s":SEQUENCE_PLACEHOLDER,"t":"INTERACTION_CREATE","d":{"id":"ID_PLACEHOLDER","application_id":"42","type":2,"token":"interaction-token","version":1,"data":{"id":"600000000000000001","name":"NAME_PLACEHOLDER","type":1}}}
  )
  .replace(old="SEQUENCE_PLACEHOLDER", new=sequence.to_string())
  .replace(old="ID_PLACEHOLDER", new=id)
  .replace(old="NAME_PLACEHOLDER", new=name)
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
async test "bot run dispatches concurrently, survives handlers, and shuts down" {
  let transport = BotFakeTransport::new()
  let bot = Bot::new(
    token="test-token",
    sync=Disabled,
    client=@dhttp.Client::new("test-token"),
    gateway_url="wss://gateway.example",
    max_in_flight=8,
  )
  bot.connector_.val = Some(_ => (transport : &@gateway.GatewayTransport))
  let ready_contexts : @aqueue.Queue[BotCtx] = @aqueue.Queue::new(
    kind=Unbounded,
  )
  bot.on(Events::ready(), (ctx, _) => ready_contexts.put(ctx))
  let command_count = Ref(0)
  let first_started : @aqueue.Queue[Unit] = @aqueue.Queue::new(kind=Unbounded)
  let release_first : @aqueue.Queue[Unit] = @aqueue.Queue::new(kind=Unbounded)
  let second_started : @aqueue.Queue[Unit] = @aqueue.Queue::new(kind=Unbounded)
  bot.command(
    slash(
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
  bot.command(
    slash(
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
  bot.error_policy((failure, _) => {
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
