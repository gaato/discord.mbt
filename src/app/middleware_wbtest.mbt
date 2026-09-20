///|
fn middleware_target_label(target : InteractionTarget) -> String {
  match target {
    Command(name~) => "command:\{name}"
    Component(custom_id~) => "component:\{custom_id}"
    Modal(custom_id~) => "modal:\{custom_id}"
  }
}

///|
fn middleware_command_interaction(
  name : String,
  id : String,
) -> @model.Interaction raise {
  @json.from_json(
    @json.parse(
      (
        #|{"id":"INTERACTION_ID","application_id":"400000000000000001","type":2,"token":"interaction-token","version":1,"user":{"id":"200000000000000001","username":"nelly","discriminator":"0","global_name":"Nelly","avatar":null},"data":{"id":"600000000000000001","name":"COMMAND_NAME","type":1}}
      )
      .replace(old="INTERACTION_ID", new=id)
      .replace(old="COMMAND_NAME", new=name),
    ),
  )
}

///|
fn middleware_component_interaction(
  custom_id : String,
  id : String,
) -> @model.Interaction raise {
  @json.from_json(
    @json.parse(
      (
        #|{"id":"INTERACTION_ID","application_id":"400000000000000001","type":3,"token":"interaction-token","version":1,"user":{"id":"200000000000000001","username":"nelly","discriminator":"0","global_name":"Nelly","avatar":null},"message":{"id":"700000000000000001","channel_id":"800000000000000001","author":{"id":"200000000000000002","username":"bot","discriminator":"0","global_name":null,"avatar":null},"content":"component host","timestamp":"2025-06-01T10:00:00.000000+00:00","edited_timestamp":null,"tts":false,"mention_everyone":false,"mentions":[],"mention_roles":[],"attachments":[],"embeds":[],"pinned":false,"type":0},"data":{"custom_id":"CUSTOM_ID","component_type":2}}
      )
      .replace(old="INTERACTION_ID", new=id)
      .replace(old="CUSTOM_ID", new=custom_id),
    ),
  )
}

///|
fn middleware_modal_interaction(
  custom_id : String,
  id : String,
) -> @model.Interaction raise {
  @json.from_json(
    @json.parse(
      (
        #|{"id":"INTERACTION_ID","application_id":"400000000000000001","type":5,"token":"interaction-token","version":1,"user":{"id":"200000000000000001","username":"nelly","discriminator":"0","global_name":"Nelly","avatar":null},"data":{"custom_id":"CUSTOM_ID","components":[]}}
      )
      .replace(old="INTERACTION_ID", new=id)
      .replace(old="CUSTOM_ID", new=custom_id),
    ),
  )
}

///|
fn middleware_autocomplete_interaction(
  name : String,
  id : String,
) -> @model.Interaction raise {
  @json.from_json(
    @json.parse(
      (
        #|{"id":"INTERACTION_ID","application_id":"400000000000000001","type":4,"token":"interaction-token","version":1,"data":{"id":"600000000000000001","name":"COMMAND_NAME","type":1,"options":[{"name":"query","type":3,"value":"m","focused":true}]}}
      )
      .replace(old="INTERACTION_ID", new=id)
      .replace(old="COMMAND_NAME", new=name),
    ),
  )
}

///|
fn middleware_test_framework(
  app : App,
  client : @dhttp.Client,
) -> @framework.Framework raise {
  let framework = @framework.Framework(
    client,
    @model.Id::parse("400000000000000001"),
  )
  app.attach(
    framework,
    client~,
    application_id=@model.Id::parse("400000000000000001"),
  )
  |> ignore
  framework
}

///|
async fn process_middleware_interaction(
  framework : @framework.Framework,
  interaction : @model.Interaction,
) -> @framework.CapturedResponse? {
  let (gate, capture) = @framework.ResponseGate::capture(interaction)
  assert_true(framework.process_with(interaction, gate~))
  capture.try_get()
}

///|
async test "interaction middleware order covers commands components and modals" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let app = App()
  let trace : Array[String] = []
  let first : InteractionMiddleware = (ctx, next) => {
    let target = middleware_target_label(ctx.target())
    assert_true(ctx.user().id.to_string() == "200000000000000001")
    assert_true(ctx.scope() is Dm(_))
    assert_true(ctx.guild_id() is None)
    trace.push("\{target}:a-in")
    next()
    trace.push("\{target}:a-out")
  }
  let second : InteractionMiddleware = (ctx, next) => {
    let target = middleware_target_label(ctx.target())
    assert_true(ctx.interaction().token == "interaction-token")
    trace.push("\{target}:b-in")
    next()
    trace.push("\{target}:b-out")
  }
  app..middleware(first).middleware(second)
  app.command(
    slash(
      name="ordered",
      description="Ordered middleware",
      args=@interaction.Args::unit(),
      handler=Raw(_ => trace.push("command:ordered:handler")),
    ),
  )
  app.on_component(
    prefix="button:",
    Raw(_ => trace.push("component:button:item:handler")),
  )
  app.on_modal_raw(prefix="form:", _ => trace.push("modal:form:item:handler"))
  let framework = middleware_test_framework(app, client)
  process_middleware_interaction(
    framework,
    middleware_command_interaction("ordered", "500000000000000601"),
  )
  |> ignore
  process_middleware_interaction(
    framework,
    middleware_component_interaction("button:item", "500000000000000602"),
  )
  |> ignore
  process_middleware_interaction(
    framework,
    middleware_modal_interaction("form:item", "500000000000000603"),
  )
  |> ignore
  inspect(
    trace.join(", "),
    content="command:ordered:a-in, command:ordered:b-in, command:ordered:handler, command:ordered:b-out, command:ordered:a-out, component:button:item:a-in, component:button:item:b-in, component:button:item:handler, component:button:item:b-out, component:button:item:a-out, modal:form:item:a-in, modal:form:item:b-in, modal:form:item:handler, modal:form:item:b-out, modal:form:item:a-out",
  )
}

///|
async test "interaction middleware short-circuits checks and handler" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let app = App()
  let clock_ran = Ref(false)
  let check_ran = Ref(false)
  let handler_ran = Ref(false)
  app.set_clock(() => {
    clock_ran.val = true
    1_000L
  })
  app.middleware((_ctx, _next) => ())
  app.command(
    slash(
      name="short-circuit",
      description="Short circuit",
      args=@interaction.Args::unit(),
      handler=Raw(_ => handler_ran.val = true),
    ).check(_ => {
      check_ran.val = true
      true
    }),
  )
  let framework = middleware_test_framework(app, client)
  process_middleware_interaction(
    framework,
    middleware_command_interaction("short-circuit", "500000000000000610"),
  )
  |> ignore
  assert_false(clock_ran.val)
  assert_false(check_ran.val)
  assert_false(handler_ran.val)
}

///|
async test "interaction middleware may send the initial response" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let app = App()
  let handler_ran = Ref(false)
  app.middleware((ctx, _next) => ctx.respond("blocked"))
  app.command(
    slash(
      name="respond",
      description="Middleware response",
      args=@interaction.Args::unit(),
      handler=Raw(_ => handler_ran.val = true),
    ),
  )
  let framework = middleware_test_framework(app, client)
  guard process_middleware_interaction(
      framework,
      middleware_command_interaction("respond", "500000000000000620"),
    )
    is Some(captured) else {
    fail("expected middleware response")
  }
  assert_false(handler_ran.val)
  inspect(
    captured.response.to_json().stringify(),
    content=(
      #|{"type":4,"data":{"content":"blocked","flags":64}}
    ),
  )
}

///|
async test "middleware CheckFailed matches a failing command check" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let app = App()
  app.middleware((ctx, next) => {
    match ctx.target() {
      Command(name~) if name == "middleware-denied" =>
        raise HandlerError::CheckFailed
      _ => next()
    }
  })
  app.command(
    slash(
      name="middleware-denied",
      description="Denied by middleware",
      args=@interaction.Args::unit(),
      handler=Raw(_ => fail("middleware-denied handler must not run")),
    ),
  )
  app.command(
    slash(
      name="check-denied",
      description="Denied by check",
      args=@interaction.Args::unit(),
      handler=Raw(_ => fail("check-denied handler must not run")),
    ).check(_ => false),
  )
  let framework = middleware_test_framework(app, client)
  guard process_middleware_interaction(
      framework,
      middleware_command_interaction("middleware-denied", "500000000000000630"),
    )
    is Some(middleware_response) else {
    fail("expected middleware error response")
  }
  guard process_middleware_interaction(
      framework,
      middleware_command_interaction("check-denied", "500000000000000631"),
    )
    is Some(check_response) else {
    fail("expected check error response")
  }
  inspect(
    middleware_response.response.to_json().stringify(),
    content=(
      #|{"type":4,"data":{"content":"You cannot use this command.","flags":64}}
    ),
  )
  assert_true(
    middleware_response.response.to_json().stringify() ==
    check_response.response.to_json().stringify(),
  )
}

///|
async test "middleware guild_scope failures flow through the error policy" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let app = App()
  app.middleware((ctx, next) => {
    match ctx.target() {
      Command(name~) if name == "guild-required" => {
        ctx.guild_scope() |> ignore
        next()
      }
      _ => next()
    }
  })
  app.command(
    slash(
      name="guild-required",
      description="Requires a guild",
      args=@interaction.Args::unit(),
      handler=Raw(_ => fail("guild-required handler must not run in a DM")),
    ),
  )
  let framework = middleware_test_framework(app, client)
  guard process_middleware_interaction(
      framework,
      middleware_command_interaction("guild-required", "500000000000000632"),
    )
    is Some(captured) else {
    fail("expected guild-only error response")
  }
  inspect(
    captured.response.to_json().stringify(),
    content=(
      #|{"type":4,"data":{"content":"This command can only be used in a server.","flags":64}}
    ),
  )
}

///|
async test "interaction middleware wraps command checks" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let app = App()
  let trace : Array[String] = []
  app.middleware((_ctx, next) => {
    trace.push("middleware-in")
    next()
    trace.push("middleware-out")
  })
  app.command(
    slash(
      name="wrapped-check",
      description="Wrapped check",
      args=@interaction.Args::unit(),
      handler=Raw(_ => trace.push("handler")),
    ).check(_ => {
      trace.push("check")
      true
    }),
  )
  let framework = middleware_test_framework(app, client)
  process_middleware_interaction(
    framework,
    middleware_command_interaction("wrapped-check", "500000000000000640"),
  )
  |> ignore
  debug_inspect(
    trace,
    content="[\"middleware-in\", \"check\", \"handler\", \"middleware-out\"]",
  )
}

///|
async test "autocomplete bypasses interaction middleware" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let app = App()
  let middleware_ran = Ref(false)
  let autocomplete_ran = Ref(false)
  app.middleware((_ctx, next) => {
    middleware_ran.val = true
    next()
  })
  app.autocomplete("search", raw => {
    autocomplete_ran.val = true
    raw.suggest([])
  })
  let framework = middleware_test_framework(app, client)
  guard process_middleware_interaction(
      framework,
      middleware_autocomplete_interaction("search", "500000000000000650"),
    )
    is Some(captured) else {
    fail("expected autocomplete response")
  }
  assert_false(middleware_ran.val)
  assert_true(autocomplete_ran.val)
  assert_true(captured.response.typ == Autocomplete)
}
