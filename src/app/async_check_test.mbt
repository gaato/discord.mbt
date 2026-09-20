///|
priv suberror AsyncCheckFailure derive(Debug)

///|
fn async_check_interaction(
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
fn async_check_framework(
  app : @app.App,
  client : @dhttp.Client,
) -> @framework.Framework raise {
  let application_id = @model.Id::parse("400000000000000001")
  let framework = @framework.Framework(client, application_id)
  app.attach(framework, client~, application_id~) |> ignore
  framework
}

///|
async fn run_async_check(
  framework : @framework.Framework,
  interaction : @model.Interaction,
) -> @framework.CapturedResponse? {
  let (gate, capture) = @framework.ResponseGate::capture(interaction)
  assert_true(framework.process_with(interaction, gate~))
  capture.try_get()
}

///|
async test "async check may await REST before deciding" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let allow = Ref(false)
  let requests = Ref(0)
  client.middleware((request, _next) => {
    requests.val += 1
    assert_eq(request.route.path(), "/gateway")
    {
      status: 200,
      headers: Map([]),
      body: {
        "url": if allow.val {
          "wss://allowed.example"
        } else {
          "wss://denied.example"
        },
      },
    }
  })
  let app = @app.App()
  let handled = Ref(0)
  app.command(
    @app.slash(
      name="rest-guarded",
      description="REST guarded command",
      args=@interaction.Args::unit(),
      handler=Raw(_ => handled.val += 1),
    ).check(ctx => ctx.app().http().get_gateway() == "wss://allowed.example"),
  )
  let framework = async_check_framework(app, client)
  guard run_async_check(
      framework,
      async_check_interaction("rest-guarded", "500000000000000801"),
    )
    is Some(denied) else {
    fail("expected the default check-failed response")
  }
  inspect(
    denied.response.to_json().stringify(),
    content=(
      #|{"type":4,"data":{"content":"You cannot use this command.","flags":64}}
    ),
  )
  assert_eq(handled.val, 0)
  allow.val = true
  assert_true(
    run_async_check(
      framework,
      async_check_interaction("rest-guarded", "500000000000000802"),
    )
    is None,
  )
  assert_eq(handled.val, 1)
  assert_eq(requests.val, 2)
}

///|
async test "a non-HandlerError raised by a check reaches the error policy unchanged" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let app = @app.App()
  let received = Ref(false)
  app.error_policy((_, error) => {
    match error {
      AsyncCheckFailure => received.val = true
      _ => fail("unexpected check error: \{Repr(error)}")
    }
  })
  app.command(
    @app.slash(
      name="failing-check",
      description="Failing check command",
      args=@interaction.Args::unit(),
      handler=Raw(_ => fail("handler must not run")),
    ).check(_ => raise AsyncCheckFailure),
  )
  let framework = async_check_framework(app, client)
  assert_true(
    run_async_check(
      framework,
      async_check_interaction("failing-check", "500000000000000803"),
    )
    is None,
  )
  assert_true(received.val)
}
