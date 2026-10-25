///|
async test "a handler waiting at full capacity still receives its component" {
  let app = @app.AppBuilder(max_in_flight=1)
  let waiting : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let woke : @aqueue.Queue[Bool] = Queue(kind=Unbounded)
  app.command(
    @app.slash(
      name="confirm",
      description="Wait for a button",
      args=@interaction.Args::unit(),
      handler=Deferred(ephemeral=true, (ctx, _) => {
        waiting.put(())
        let pressed = ctx.wait_for_component(
          @app.component_route(
            id="confirm-yes",
            state=@app.CustomIdCodec::unit(),
          ),
          (),
          timeout_ms=2000,
        )
        woke.put(pressed is Some(_))
      }),
    ),
  )
  let client = @dhttp.Client("test-token")
  defer client.close()
  let application_id = @model.Id::parse("400000000000000001")
  let clock = @netruntime.VirtualClock()
  let framework = @framework.Framework(client, application_id, clock~)
  let waiter : @app.ComponentWaiter = (custom_id, user, timeout_ms) => {
    framework.wait_for_component(custom_id~, user?, timeout_ms?)
  }
  app.build().attach(framework, client~, application_id~, waiter~) |> ignore
  @async.with_task_group(group => {
    let command = app_command("confirm", "500000000000000900")
    group.spawn_bg(() => {
      let (gate, _) = @framework.ResponseGate::capture(command, clock~)
      framework.process_with(command, gate~) |> ignore
    })
    waiting.get()
    // The only permit is held by the waiting handler; routing must not need it.
    let component = app_component("confirm-yes", "500000000000000901")
    let (gate, _) = @framework.ResponseGate::capture(component, clock~)
    assert_true(framework.process_with(component, gate~))
    assert_true(woke.get())
  })
}

///|
async test "handler capacity waits count against the response deadline" {
  let app = @app.AppBuilder(max_in_flight=1)
  let warnings : Array[String] = []
  app.on_warn(warning => warnings.push(warning.to_string()))
  let release : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let holding : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let quick_ran = Ref(false)
  app.command(
    @app.slash(
      name="hold",
      description="Hold the only permit",
      args=@interaction.Args::unit(),
      handler=Raw(_ => {
        holding.put(())
        release.get()
      }),
    ),
  )
  app.command(
    @app.slash(
      name="quick",
      description="Answer immediately",
      args=@interaction.Args::unit(),
      handler=Immediate((_, _) => {
        quick_ran.val = true
        @app.CommandReply::message(content="quick")
      }),
    ),
  )
  let client = @dhttp.Client("test-token")
  defer client.close()
  let clock = @netruntime.VirtualClock()
  @async.with_task_group(group => {
    let endpoint = app
      .build()
      .serve(
        group,
        access=Client(client),
        application_id=@model.Id::parse("400000000000000001"),
        clock~,
      )
    group.spawn_bg(() => {
      endpoint.handle_interaction(
        app_command("hold", "500000000000000902"),
        deadline_ms=5000,
      )
      |> ignore
    })
    holding.get()
    let quick = group.spawn(() => {
      endpoint.handle_interaction(
        app_command("quick", "500000000000000903"),
        deadline_ms=50,
      )
    })
    // The endpoint's timeout and the admission waiter's capacity wait both
    // end with the window.
    clock.settle(until=() => {
      clock.pending().filter(ms => ms == 50).length() == 2
    })
    clock.advance(50)
    assert_true(quick.wait() is TimedOut)
    release.put(())
    clock.settle(until=() => warnings.length() == 1)
    assert_false(quick_ran.val)
    assert_eq(warnings, [
      "interaction dropped (command:quick): the response deadline passed before the handler could start",
    ])
  })
}

///|
async test "slow middleware on a deferring route is acknowledged automatically" {
  let app = @app.AppBuilder()
  let requests : Array[String] = []
  let client = @dhttp.Client("test-token")
  defer client.close()
  client.middleware((request, _) => {
    requests.push("\{Repr(request.route.method_())} \{request.route.path()}")
    { status: 200, headers: Map([]), body: app_test_message().to_json(), }
  })
  let handled : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let clock = @netruntime.VirtualClock()
  app.middleware((ctx, next) => {
    if ctx.interaction().data is Some(Command(data)) && data.name == "denied" {
      (clock : &@hclock.Clock).sleep(200)
      raise @app.HandlerError::CheckFailed
    }
    (clock : &@hclock.Clock).sleep(200)
    next()
  })
  app.command(
    @app.slash(
      name="report",
      description="Slow to authorize",
      args=@interaction.Args::unit(),
      handler=Deferred(ephemeral=true, (ctx, _) => {
        ctx.raw().edit_response(content="done") |> ignore
        handled.put(())
      }),
    ),
  )
  app.command(
    @app.slash(
      name="denied",
      description="Slow to refuse",
      args=@interaction.Args::unit(),
      handler=Deferred(ephemeral=true, (_, _) => ()),
    ),
  )
  @async.with_task_group(group => {
    let endpoint = app
      .build()
      .serve(
        group,
        access=Client(client),
        application_id=@model.Id::parse("400000000000000001"),
        clock~,
      )
    // 1100 ms leaves 100 ms before the watchdog's 1000 ms margin, while the
    // middleware still has 100 ms to go.
    let report = group.spawn(() => {
      endpoint.handle_interaction(
        app_command("report", "500000000000000904"),
        deadline_ms=1100,
      )
    })
    clock.settle(until=() => {
      clock.pending().contains(100) && clock.pending().contains(200)
    })
    clock.advance(100)
    guard report.wait() is Reply(response~, ..) else {
      fail("expected an automatic deferral")
    }
    assert_eq(response.typ, DeferredChannelMessageWithSource)
    json_inspect(response.data.unwrap(), content={ "flags": 64 })
    assert_true(handled.try_get() is None)
    clock.advance(100)
    handled.get()
    let denied = group.spawn(() => {
      endpoint.handle_interaction(
        app_command("denied", "500000000000000905"),
        deadline_ms=1100,
      )
    })
    clock.settle(until=() => {
      clock.pending().contains(100) && clock.pending().contains(200)
    })
    clock.advance(100)
    guard denied.wait() is Reply(response~, ..) else {
      fail("expected an automatic deferral")
    }
    assert_eq(response.typ, DeferredChannelMessageWithSource)
    clock.advance(100)
    clock.settle(until=() => requests.length() == 2)
    assert_eq(requests, [
      "Patch /webhooks/400000000000000001/interaction-token/messages/@original",
      "Patch /webhooks/400000000000000001/interaction-token/messages/@original",
    ])
  })
}

///|
async test "fast failures on a deferring route stay ephemeral initial responses" {
  let app = @app.AppBuilder()
  app.command(
    @app.slash(
      name="refused",
      description="Refused quickly",
      args=@interaction.Args::unit(),
      handler=Deferred(ephemeral=false, (_, _) => ()),
    ).check(_ => false),
  )
  let client = @dhttp.Client("test-token")
  defer client.close()
  let clock = @netruntime.VirtualClock()
  @async.with_task_group(group => {
    let endpoint = app
      .build()
      .serve(
        group,
        access=Client(client),
        application_id=@model.Id::parse("400000000000000001"),
        clock~,
      )
    guard endpoint.handle_interaction(
        app_command("refused", "500000000000000906"),
      )
      is Reply(response~, ..) else {
      fail("expected an initial error response")
    }
    assert_eq(response.typ, ChannelMessageWithSource)
    json_inspect(response.data.unwrap(), content={
      "content": "You cannot use this command.",
      "flags": 64,
    })
  })
}

///|
async test "a deferred interaction beyond max_pending is refused before it is acknowledged" {
  // The default policy answers `Busy` with a try-again message.
  let app = @app.AppBuilder(max_in_flight=1, max_pending=1)
  let release : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let holding : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let ran : Array[String] = []
  app.command(
    @app.slash(
      name="hold",
      description="Hold the only permit",
      args=@interaction.Args::unit(),
      handler=Raw(_ => {
        holding.put(())
        release.get()
      }),
    ),
  )
  app.command(
    @app.slash(
      name="later",
      description="Deferred work",
      args=@interaction.Args::unit(),
      handler=Deferred(ephemeral=false, (ctx, _) => {
        ran.push(ctx.interaction().id.to_string())
      }),
    ),
  )
  let client = @dhttp.Client("test-token")
  defer client.close()
  client.middleware((_, _) => {
    status: 200,
    headers: Map([]),
    body: app_test_message().to_json(),
  })
  let clock = @netruntime.VirtualClock()
  @async.with_task_group(group => {
    let endpoint = app
      .build()
      .serve(
        group,
        access=Client(client),
        application_id=@model.Id::parse("400000000000000001"),
        clock~,
      )
    group.spawn_bg(() => {
      endpoint.handle_interaction(
        app_command("hold", "500000000000000970"),
        deadline_ms=5000,
      )
      |> ignore
    })
    holding.get()
    // The first deferred interaction waits for the permit (and is deferred on
    // time by the watchdog); it fills max_pending.
    let first = group.spawn(() => {
      endpoint.handle_interaction(
        app_command("later", "500000000000000971"),
        deadline_ms=1200,
      )
    })
    clock.settle(until=() => clock.pending().contains(200))
    clock.advance(50)
    let refused = endpoint.handle_interaction(
      app_command("later", "500000000000000972"),
      deadline_ms=1200,
    )
    guard refused is Reply(response~, ..) else {
      fail("expected the busy reply, got \{Repr(refused)}")
    }
    json_inspect(response.to_json(), content={
      "type": 4,
      "data": {
        "content": "The bot is busy right now. Please try again in a moment.",
        "flags": 64,
      },
    })
    // The watchdog defers the first one 200 ms after it arrived.
    clock.advance(150)
    guard first.wait() is Reply(response~, ..) else {
      fail("expected the first interaction to be deferred")
    }
    assert_eq(response.typ, DeferredChannelMessageWithSource)
    release.put(())
    clock.settle(until=() => ran.length() == 1)
    assert_eq(ran, ["500000000000000971"])
  })
}
