///|
priv suberror ResponseStateFailure derive(Debug)

///|
fn state_flow_framework(
  app : @app.App,
  client : @dhttp.Client,
) -> @framework.Framework raise {
  let application_id = @model.Id::parse("400000000000000001")
  let framework = @framework.Framework(client, application_id)
  app.attach(framework, client~, application_id~) |> ignore
  framework
}

///|
fn state_flow_client(routes : Array[String]) -> @dhttp.Client {
  let client = @dhttp.Client("test-token")
  client.middleware((request, _) => {
    assert_true(request.route.method_() is Post)
    routes.push(request.route.path())
    json_inspect(request.body.unwrap_or(Json::null()), content={
      "content": "policy reply",
      "flags": 64,
    })
    { status: 200, headers: Map([]), body: app_test_message().to_json(), }
  })
  client
}

///|
async fn assert_state_followup(
  app : @app.App,
  interaction : @model.Interaction,
  expected : @framework.ResponseState,
) -> Unit {
  let routes : Array[String] = []
  let warnings : Array[String] = []
  let states : Array[@framework.ResponseState?] = []
  let client = state_flow_client(routes)
  defer client.close()
  app.on_warn(message => warnings.push(message))
  app.error_policy((ctx, error) => {
    assert_true(error is ResponseStateFailure)
    states.push(ctx.response_state())
    ctx.respond_error(content="policy reply")
  })
  let framework = state_flow_framework(app, client)
  let (gate, capture) = @framework.ResponseGate::capture(interaction)
  assert_true(framework.process_with(interaction, gate~))
  assert_eq(states, [Some(expected)])
  assert_eq(gate.state(), expected)
  assert_eq(gate.state(), Sent(capture.get().response.typ))
  assert_eq(routes, ["/webhooks/400000000000000001/interaction-token"])
  assert_eq(warnings, [])
}

///|
async test "raw command handler that responds then raises gets a followup" {
  let app = @app.App()
  app.command(
    @app.slash(
      name="raw-failure",
      description="Fail after responding",
      args=@interaction.Args::unit(),
      handler=Raw(raw => {
        assert_true(raw.response_state() is Pending)
        raw.respond(content="initial")
        assert_true(raw.response_state() is Sent(ChannelMessageWithSource))
        raise ResponseStateFailure
      }),
    ),
  )
  assert_state_followup(
    app,
    app_command("raw-failure", "500000000000000801"),
    Sent(ChannelMessageWithSource),
  )
}

///|
async test "raw component handler that responds then raises gets a followup" {
  let app = @app.App()
  let route = @app.component_route(id="raw", state=@app.CustomIdCodec::string())
  app.on_component(
    route,
    Raw(raw => {
      assert_true(raw.response_state() is Pending)
      raw.respond(content="initial")
      assert_true(raw.response_state() is Sent(ChannelMessageWithSource))
      raise ResponseStateFailure
    }),
  )
  assert_state_followup(
    app,
    app_component(app_route_button_id(route, "failure"), "500000000000000802"),
    Sent(ChannelMessageWithSource),
  )
}

///|
async test "raw modal handler that responds then raises gets a followup" {
  let app = @app.App()
  app.on_modal(
    @app.modal(
      custom_id="raw-form",
      title="Raw form",
      fields=@app.ModalFields::of(
        @app.text_field(custom_id="note", label="Note"),
      ),
    ),
    Raw(raw => {
      assert_true(raw.response_state() is Pending)
      raw.respond(content="initial")
      assert_true(raw.response_state() is Sent(ChannelMessageWithSource))
      raise ResponseStateFailure
    }),
  )
  assert_state_followup(
    app,
    app_modal_submit("raw-form", "note", "500000000000000803"),
    Sent(ChannelMessageWithSource),
  )
}

///|
async test "immediate handler responding through raw then raising gets a followup" {
  let app = @app.App()
  app.command(
    @app.slash(
      name="immediate-failure",
      description="Respond through raw",
      args=@interaction.Args::unit(),
      handler=Immediate((ctx, _) => {
        ctx.raw().respond(content="initial")
        raise ResponseStateFailure
      }),
    ),
  )
  assert_state_followup(
    app,
    app_command("immediate-failure", "500000000000000804"),
    Sent(ChannelMessageWithSource),
  )
}

///|
async test "deferred handler failure follows up" {
  let app = @app.App()
  app.command(
    @app.slash(
      name="deferred-failure",
      description="Fail after deferring",
      args=@interaction.Args::unit(),
      handler=Deferred(ephemeral=true, (ctx, _) => {
        assert_true(
          ctx.raw().response_state() is Sent(DeferredChannelMessageWithSource),
        )
        raise ResponseStateFailure
      }),
    ),
  )
  assert_state_followup(
    app,
    app_command("deferred-failure", "500000000000000805"),
    Sent(DeferredChannelMessageWithSource),
  )
}

///|
async test "definitively rejected initial response lets the policy respond" {
  let app = @app.App()
  let routes : Array[String] = []
  let client = state_flow_client(routes)
  defer client.close()
  let states : Array[@framework.ResponseState?] = []
  let warnings : Array[String] = []
  app.on_warn(message => warnings.push(message))
  app.command(
    @app.slash(
      name="rejected",
      description="Rejected initial response",
      args=@interaction.Args::unit(),
      handler=Immediate((_, _) => @app.CommandReply::message(content="initial")),
    ),
  )
  app.error_policy((ctx, error) => {
    assert_true(error is ResponseStateFailure)
    states.push(ctx.response_state())
    ctx.respond_error(content="policy reply")
    states.push(ctx.response_state())
  })
  let calls = Ref(0)
  let responses : Array[@model.InteractionResponse] = []
  let gate = @framework.ResponseGate(
    ApplicationCommand,
    (response, _) => {
      calls.val += 1
      if calls.val == 1 {
        raise ResponseStateFailure
      }
      responses.push(response)
    },
    rejected=_ => true,
  )
  let framework = state_flow_framework(app, client)
  assert_true(
    framework.process_with(app_command("rejected", "500000000000000806"), gate~),
  )
  assert_eq(states, [Some(Pending), Some(Sent(ChannelMessageWithSource))])
  assert_eq(calls.val, 2)
  assert_eq(responses.length(), 1)
  json_inspect(responses[0].to_json(), content={
    "type": 4,
    "data": { "content": "policy reply", "flags": 64 },
  })
  assert_eq(routes, [])
  assert_eq(warnings, [])
}

///|
async test "unconfirmed initial response is followed up" {
  let app = @app.App()
  let routes : Array[String] = []
  let client = state_flow_client(routes)
  defer client.close()
  let states : Array[@framework.ResponseState?] = []
  let warnings : Array[String] = []
  app.on_warn(message => warnings.push(message))
  app.command(
    @app.slash(
      name="unconfirmed",
      description="Unconfirmed initial response",
      args=@interaction.Args::unit(),
      handler=Immediate((_, _) => @app.CommandReply::message(content="initial")),
    ),
  )
  app.error_policy((ctx, error) => {
    assert_true(error is ResponseStateFailure)
    states.push(ctx.response_state())
    ctx.respond_error(content="policy reply")
  })
  let calls = Ref(0)
  let gate = @framework.ResponseGate(ApplicationCommand, (_, _) => {
    calls.val += 1
    raise ResponseStateFailure
  })
  let framework = state_flow_framework(app, client)
  assert_true(
    framework.process_with(
      app_command("unconfirmed", "500000000000000807"),
      gate~,
    ),
  )
  assert_eq(states, [Some(Unconfirmed(ChannelMessageWithSource))])
  assert_eq(gate.state(), Unconfirmed(ChannelMessageWithSource))
  assert_eq(calls.val, 1)
  assert_eq(routes, ["/webhooks/400000000000000001/interaction-token"])
  assert_eq(warnings, [])
}

///|
async test "middleware raising after next follows up when the handler already responded" {
  let app = @app.App()
  app.middleware((_, next) => {
    next()
    raise ResponseStateFailure
  })
  app.command(
    @app.slash(
      name="middleware-failure",
      description="Respond before middleware raises",
      args=@interaction.Args::unit(),
      handler=Immediate((_, _) => @app.CommandReply::message(content="initial")),
    ),
  )
  assert_state_followup(
    app,
    app_command("middleware-failure", "500000000000000808"),
    Sent(ChannelMessageWithSource),
  )
}

///|
async test "expired interaction only warns" {
  let app = @app.App()
  let warnings : Array[String] = []
  let states : Array[@framework.ResponseState?] = []
  let routes : Array[String] = []
  let client = state_flow_client(routes)
  defer client.close()
  app.on_warn(message => warnings.push(message))
  app.command(
    @app.slash(
      name="expired",
      description="Expired callback window",
      args=@interaction.Args::unit(),
      handler=Raw(raw => raw.respond(content="too late")),
    ),
  )
  app.error_policy((ctx, error) => {
    assert_true(error is @framework.ResponseGateError::Expired)
    states.push(ctx.response_state())
    ctx.respond_error(content="policy reply")
    ctx.respond_error(files=[@dhttp.FileUpload("failure.txt", b"failure")])
  })
  let interaction = app_command("expired", "500000000000000809")
  let (gate, capture) = @framework.ResponseGate::capture(interaction)
  gate.expire()
  let framework = state_flow_framework(app, client)
  assert_true(framework.process_with(interaction, gate~))
  assert_eq(states, [Some(Expired)])
  assert_eq(gate.state(), Expired)
  assert_true(capture.try_get() is None)
  assert_eq(routes, [])
  assert_eq(warnings, [
    "cannot respond to an expired interaction: policy reply", "cannot respond to an expired interaction: files-only error response",
  ])
}
