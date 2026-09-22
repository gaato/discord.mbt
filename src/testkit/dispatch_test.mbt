///|
/// Run one interaction through a real Framework with an offline client and
/// return whether it matched and the captured initial callback.
async fn dispatch(
  app : @app.App,
  interaction : @model.Interaction,
  client? : @http.Client,
) -> (Bool, @framework.CapturedResponse?) {
  let client = client.unwrap_or_else(() => {
    @http.Client::offline(request => {
      fail("unexpected REST call: \{request.route.path()}")
    })
  })
  let application_id = @testkit.default_application_id()
  let framework = @framework.Framework(client, application_id)
  app.attach(framework, client~, application_id~) |> ignore
  let (gate, capture) = @framework.ResponseGate::capture(interaction)
  let matched = framework.process_with(interaction, gate~)
  (matched, capture.try_get())
}

///|
fn raw_app(run : async (@framework.CommandCtx) -> Unit) -> @app.App {
  let app = @app.App()
  app.on_warn(_ => ())
  app.command(
    @app.slash(
      name="run",
      description="Run",
      args=@interaction.Args::unit(),
      handler=Raw(run),
    ),
  )
  app
}

///|
priv suberror HandlerBoom derive(Debug)

///|
priv suberror PolicyBoom derive(Debug)

///|
async test "the default policy answers every HandlerError with an error reply" {
  let cases : Array[(@app.HandlerError, String)] = [
    (UserMessage(message="custom", ephemeral=false), "custom"),
    (GuildOnly, "server"),
    (DmOnly, "direct message"),
    (CheckFailed, "cannot use"),
    (MissingPermission(@model.Permissions(8UL)), "Missing required permission"),
    (OnCooldown(retry_after_ms=250L), "250 ms"),
    (InvalidArgument("bad"), "Invalid argument: bad"),
  ]
  for case in cases {
    let (error, expected) = case
    let app = raw_app(_ => raise error)
    let (matched, captured) = dispatch(app, @testkit.slash("run"))
    assert_true(matched)
    guard captured
      is Some(
        { response: { data: Some({ "content": String(content), .. }), .. }, .. }
      ) else {
      fail("expected an error reply for \{Repr(error)}")
    }
    assert_true(content.contains(expected))
  }
}

///|
async test "checks, argument decoding, and middleware fail through the policy" {
  let failures : Array[Error] = []
  let checked = raw_app(_ => fail("must not run"))
  checked.error_policy((_, error) => failures.push(error))
  checked.command(
    @app.slash(
      name="checked",
      description="Checked",
      args=@interaction.Args::unit(),
      handler=Raw(_ => fail("must not run")),
    ).check(_ => false),
  )
  checked.command(
    @app.slash(
      name="decode",
      description="Decode",
      args=@interaction.Args::of(
        @interaction.arg_string(name="value", description="Value"),
      ),
      handler=Raw(_ => fail("decode must reject")),
    ),
  )
  let order : Array[String] = []
  checked.middleware((ctx, next) => {
    order.push("before")
    if ctx.target() is Command(name="run") {
      raise @app.HandlerError::CheckFailed
    }
    next()
    order.push("after")
  })
  let (matched, _) = dispatch(checked, @testkit.slash("missing"))
  assert_false(matched)
  for name in ["checked", "decode", "run"] {
    let (matched, captured) = dispatch(checked, @testkit.slash(name))
    assert_true(matched)
    assert_true(captured is None)
  }
  assert_true(
    failures
    is [
      @app.HandlerError::CheckFailed,
      @app.HandlerError::InvalidArgument(_),
      @app.HandlerError::CheckFailed,
    ],
  )
  assert_eq(order, ["before", "before", "before"])
}

///|
async test "a reply followed by a failing policy keeps the reply and warns" {
  let app = raw_app(ctx => {
    ctx.respond(content="sent")
    raise HandlerBoom
  })
  let warnings : Array[String] = []
  app.on_warn(message => warnings.push(message))
  let state : Ref[@framework.ResponseState?] = Ref(None)
  app.error_policy((ctx, error) => {
    state.val = ctx.response_state()
    assert_true(error is HandlerBoom)
    raise PolicyBoom
  })
  let (_, captured) = dispatch(app, @testkit.slash("run"))
  json_inspect(captured.unwrap().response.to_json(), content={
    "type": 4,
    "data": { "content": "sent" },
  })
  assert_true(state.val is Some(Sent(_)))
  assert_true(warnings is [warning] && warning.contains("PolicyBoom"))
}

///|
async test "response validation and double responses fail inside the handler" {
  let failures : Array[Error] = []
  let invalid = raw_app(ctx => {
    ctx.respond(embeds=[@model.Embed(description="x".repeat(4097))])
  })
  invalid.error_policy((_, error) => failures.push(error))
  let (_, captured) = dispatch(invalid, @testkit.slash("run"))
  assert_true(captured is None)
  assert_true(failures is [@http.DiscordHttpError::Validation(..)])
  let doubled = raw_app(ctx => {
    ctx.respond(content="first")
    ctx.respond(content="second")
  })
  doubled.error_policy((_, error) => failures.push(error))
  let (_, captured) = dispatch(doubled, @testkit.slash("run"))
  assert_true(captured is Some(_))
  assert_eq(failures.length(), 2)
}

///|
async test "component and modal failures expose the interaction and user" {
  let app = @app.App()
  let seen : Array[(@app.FailureOrigin, @model.User?)] = []
  app.error_policy((ctx, _) => {
    assert_true(ctx.interaction() is Some(_))
    seen.push((ctx.origin(), ctx.user()))
  })
  app.on_component_raw(prefix="button", _ => raise HandlerBoom)
  app.on_modal_raw(prefix="form", _ => raise HandlerBoom)
  let actor = @testkit.user(username="member")
  let guild = (@model.Id(9UL), @testkit.guild_member(user=actor))
  let base = @testkit.interaction(guild~)
  for
    input in [
      @testkit.component("button", base~),
      @testkit.modal("form", base~),
      @testkit.component("button"),
    ] {
    let (matched, captured) = dispatch(app, input)
    assert_true(matched)
    assert_true(captured is None)
  }
  assert_true(
    seen
    is [
      (Component(custom_id="button"), Some({ username: "member", .. })),
      (Modal(custom_id="form"), Some({ username: "member", .. })),
      (Component(custom_id="button"), Some(_)),
    ],
  )
}

///|
async test "raw autocomplete failures stay in the Framework" {
  let app = @app.App()
  let warnings : Array[String] = []
  app.on_warn(message => warnings.push(message))
  app.error_policy((_, _) => fail("raw autocomplete must not call App policy"))
  app.autocomplete("find", _ => raise HandlerBoom)
  let (matched, captured) = dispatch(
    app,
    @testkit.autocomplete("find", options=[]),
  )
  assert_true(matched)
  assert_true(captured is None)
  assert_true(warnings is [warning] && warning.contains("HandlerBoom"))
}

///|
async test "a failing typed suggestion reaches the policy and sends no choices" {
  let app = @app.App()
  app.on_warn(_ => ())
  app.command(
    @app.slash(
      name="find",
      description="Find",
      args=@interaction.Args::of(
        @interaction.arg_string(name="q", description="Query", suggest=(_, _) => {
          raise @app.HandlerError::UserMessage(message="no", ephemeral=true)
        }),
      ),
      handler=Raw(_ => ()),
    ),
  )
  let option : @model.CommandDataOption = @json.from_json({
    "name": "q",
    "type": 3,
    "value": "x",
    "focused": true,
  })
  let (matched, captured) = dispatch(
    app,
    @testkit.autocomplete("find", options=[option]),
  )
  assert_true(matched)
  json_inspect(captured.unwrap().response.to_json(), content={
    "type": 8,
    "data": { "choices": [] },
  })
}

///|
async test "a malformed component payload is rejected before the handler" {
  let app = @app.App()
  app.on_component_raw(prefix="button", _ => fail("must reject"))
  let interaction = @testkit.component("button")
  let client = @http.Client::offline(_ => fail("no REST call expected"))
  try dispatch(app, { ..interaction, message: None, }, client~) catch {
    _ => ()
  } noraise {
    _ => fail("expected the framework to reject the payload")
  }
}
