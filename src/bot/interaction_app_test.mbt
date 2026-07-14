///|
fn app_interaction(fixture : String) -> @model.Interaction raise {
  @json.from_json(@json.parse(fixture))
}

///|
fn app_ping() -> @model.Interaction raise {
  app_interaction(
    (
      #|{
      #|  "id": "500000000000000100",
      #|  "application_id": "400000000000000001",
      #|  "type": 1,
      #|  "token": "interaction-token",
      #|  "version": 1
      #|}
    ),
  )
}

///|
fn app_command(name : String, id : String) -> @model.Interaction raise {
  app_interaction(
    (
      #|{
      #|  "id": "INTERACTION_ID",
      #|  "application_id": "400000000000000001",
      #|  "type": 2,
      #|  "token": "interaction-token",
      #|  "version": 1,
      #|  "data": {
      #|    "id": "600000000000000100",
      #|    "name": "COMMAND_NAME",
      #|    "type": 1
      #|  }
      #|}
    )
    .replace(old="INTERACTION_ID", new=id)
    .replace(old="COMMAND_NAME", new=name),
  )
}

///|
async test "interaction app dispatches captured responses and completion outcomes" {
  let bot = @bot.Bot::new(token="test-token", sync=Disabled)
  let warnings : Array[String] = []
  bot.on_warn(message => warnings.push(message))
  let waiter_results : @aqueue.Queue[Bool] = @aqueue.Queue::new(kind=Unbounded)
  let slow_finished : @aqueue.Queue[Unit] = @aqueue.Queue::new(kind=Unbounded)
  bot.command(
    @bot.slash(
      name="immediate",
      description="Immediate response",
      args=@interaction.Args::unit(),
      handler=Immediate((_, _) => {
        @bot.InitialResponse::message(content="hello from http")
      }),
    ),
  )
  bot.command(
    @bot.slash(
      name="silent",
      description="No initial response",
      args=@interaction.Args::unit(),
      handler=Raw(_ => ()),
    ),
  )
  bot.command(
    @bot.slash(
      name="deferred",
      description="Deferred without gateway waiter",
      args=@interaction.Args::unit(),
      handler=Deferred(ephemeral=false, (ctx, _) => {
        waiter_results.put(
          ctx.wait_for_component(custom_id="never", timeout_ms=1) is None,
        )
      }),
    ),
  )
  bot.command(
    @bot.slash(
      name="slow",
      description="Slow initial response",
      args=@interaction.Args::unit(),
      handler=Raw(raw => {
        @async.sleep(100)
        raw.respond(content="late")
        slow_finished.put(())
      }),
    ),
  )
  let client = @dhttp.Client::new(
    "test-token",
    base_url="http://127.0.0.1:1",
    max_connections=1,
  )
  defer client.close()
  @async.with_task_group(group => {
    // Explicit client/id plus sync=false must perform no startup HTTP.
    let app = bot.start_interaction_app(
      group,
      client~,
      application_id=@model.Id::parse("400000000000000001"),
      sync=false,
    )
    match app.handle_interaction(app_ping()) {
      Reply(response~, files~) => {
        assert_true(response.typ == Pong)
        assert_true(files is None)
      }
      outcome => fail("expected Pong reply, got \{to_repr(outcome)}")
    }
    match
      app.handle_interaction(app_command("immediate", "500000000000000101")) {
      Reply(response~, files~) => {
        assert_true(response.typ == ChannelMessageWithSource)
        assert_true(files is None)
        inspect(
          response.to_json().stringify(),
          content=(
            #|{"type":4,"data":{"content":"hello from http"}}
          ),
        )
      }
      outcome => fail("expected command reply, got \{to_repr(outcome)}")
    }
    match app.handle_interaction(app_command("missing", "500000000000000102")) {
      NoRoute => ()
      outcome => fail("expected NoRoute, got \{to_repr(outcome)}")
    }
    match
      @async.with_timeout_opt(250, () => {
        app.handle_interaction(app_command("silent", "500000000000000103"))
      }) {
      Some(NoResponse) => ()
      outcome => fail("expected prompt NoResponse, got \{to_repr(outcome)}")
    }
    match
      app.handle_interaction(app_command("deferred", "500000000000000106")) {
      Reply(response~, files=_) =>
        assert_true(response.typ == DeferredChannelMessageWithSource)
      outcome => fail("expected deferred reply, got \{to_repr(outcome)}")
    }
    assert_true(waiter_results.get())
    assert_true(
      warnings.contains(
        "component waiting is unavailable without a gateway connection",
      ),
    )
    match
      app.handle_interaction(
        app_command("slow", "500000000000000104"),
        deadline_ms=10,
      ) {
      TimedOut => ()
      outcome => fail("expected TimedOut, got \{to_repr(outcome)}")
    }
    guard @async.with_timeout_opt(500, () => slow_finished.get()) is Some(_) else {
      fail("timed-out handler did not continue in the app task group")
    }
    guard app.handle(app_command("immediate", "500000000000000105").to_json())
      is Some(json) else {
      fail("expected JSON callback")
    }
    inspect(
      json.stringify(),
      content=(
        #|{"type":4,"data":{"content":"hello from http"}}
      ),
    )
  })
}
