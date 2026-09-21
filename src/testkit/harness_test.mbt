///|
async test "initial files and payloads are snapshots and the Client closes before return" {
  let client : Ref[@http.Client?] = Ref(None)
  let files = [@http.FileUpload("data.txt", b"data")]
  let app = raw_app(ctx => {
    client.val = Some(ctx.client)
    ctx.respond(content="file", files~)
    files.clear()
  })
  let result = @testkit.Harness(app).dispatch(@testkit.slash("run"))
  let first = result.initial_response().unwrap()
  assert_eq(first.files.unwrap().length(), 1)
  first.files.unwrap().clear()
  assert_eq(result.initial_response().unwrap().files.unwrap().length(), 1)
  try client.val.unwrap().get_gateway() catch {
    @http.DiscordHttpError::Transport(..) => ()
    error => raise error
  } noraise {
    _ => fail("owned Client must be closed")
  }
}

///|
async test "invalid timeout leaves harness reusable and fake failure stays latched" {
  let app = raw_app(_ => ())
  let harness = @testkit.Harness(app)
  try harness.dispatch(@testkit.slash("run"), timeout_ms=0) catch {
    @testkit.TestkitError::InvalidConfiguration(_) => ()
    error => raise error
  } noraise {
    _ => fail("expected timeout configuration rejection")
  }
  assert_true(harness.dispatch(@testkit.slash("run")).no_response())
  let twice = raw_app(ctx => {
    ignore(ctx.client.get_gateway() catch { _ => "caught" })
    ignore(ctx.client.get_gateway() catch { _ => "caught again" })
  })
  try @testkit.Harness(twice).dispatch(@testkit.slash("run")) catch {
    @testkit.TestkitError::UnexpectedRest => ()
    error => raise error
  } noraise {
    _ => fail("expected latched error")
  }
}

///|
async test "checks and response validation cannot be skipped by the harness" {
  let checked = @app.App()
  checked.command(
    @app.slash(
      name="run",
      description="Run",
      args=@interaction.Args::unit(),
      handler=Raw(_ => fail("must not run")),
    ).check(_ => false),
  )
  assert_true(
    @testkit.Harness(checked).dispatch(@testkit.slash("run")).errors()
    is [App(Handler(_, @app.HandlerError::CheckFailed))],
  )
  let invalid = raw_app(ctx => {
    ctx.respond(embeds=[@model.Embed(description="x".repeat(4097))])
  })
  let result = @testkit.Harness(invalid).dispatch(@testkit.slash("run"))
  assert_true(result.initial_response() is None)
  assert_true(
    result.errors() is [App(Handler(_, @http.DiscordHttpError::Validation(..)))],
  )
  let doubled = raw_app(ctx => {
    ctx.respond(content="first")
    ctx.respond(content="second")
  })
  let result = @testkit.Harness(doubled).dispatch(@testkit.slash("run"))
  assert_true(result.initial_response() is Some(_))
  assert_eq(result.errors().length(), 1)
}

///|
priv suberror HandlerBoom derive(Debug)

///|
priv suberror PolicyBoom derive(Debug)

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
fn response(body : Json, status? : Int = 200) -> @http.HttpResponse {
  { body, status, headers: Map([]), }
}

///|
async test "routing, no response and policy response are independent" {
  let app = raw_app(_ => ())
  let harness = @testkit.Harness(app)
  assert_eq(harness.dispatch(@testkit.slash("missing")).routing, NoRoute)
  assert_true(harness.dispatch(@testkit.slash("run")).no_response())
  let denied = raw_app(_ => raise @app.HandlerError::GuildOnly)
  let result = @testkit.Harness(denied).dispatch(@testkit.slash("run"))
  assert_eq(result.routing, Matched)
  assert_true(result.initial_response() is Some(_))
  assert_true(
    result.errors()
    is [App(Handler(Command(name="run"), @app.HandlerError::GuildOnly))],
  )
  assert_false(result.no_response())
  harness.assert_rest_complete()
}

///|
async test "reply then fail preserves reply and ordered original and policy errors" {
  let app = raw_app(ctx => {
    ctx.respond(content="sent")
    raise HandlerBoom
  })
  let policy_called = Ref(false)
  app.error_policy((ctx, _) => {
    policy_called.val = ctx.response_state() is Some(Sent(_))
    raise PolicyBoom
  })
  let result = @testkit.Harness(app).dispatch(@testkit.slash("run"))
  assert_true(policy_called.val)
  json_inspect(result.initial_response().unwrap().response.to_json(), content={
    "type": 4,
    "data": { "content": "sent" },
  })
  assert_true(
    result.errors()
    is [App(Handler(_, HandlerBoom)), App(ErrorPolicy(_, PolicyBoom))],
  )
  result.errors().clear()
  assert_eq(result.errors().length(), 2)
}

///|
async test "raw autocomplete preserves Framework-only failure policy" {
  let app = @app.App()
  app.on_warn(_ => ())
  app.error_policy((_, _) => fail("raw autocomplete must not call App policy"))
  app.autocomplete("find", _ => raise HandlerBoom)
  let result = @testkit.Harness(app).dispatch(
    @testkit.autocomplete("find", options=[]),
  )
  assert_true(result.errors() is [App(Framework(_, HandlerBoom))])
  assert_true(result.initial_response() is None)
}

///|
async test "typed autocomplete records original failure and sends empty choices" {
  let app = @app.App()
  app.on_warn(_ => ())
  app.command(
    @app.slash(
      name="find",
      description="Find",
      args=@interaction.Args::of(
        @interaction.arg_string(name="q", description="Query", suggest=(_, _) => {
          raise HandlerBoom
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
  let result = @testkit.Harness(app).dispatch(
    @testkit.autocomplete("find", options=[option]),
  )
  assert_true(
    result.errors() is [App(Handler(Autocomplete(name="find"), HandlerBoom))],
  )
  json_inspect(result.initial_response().unwrap().response.to_json(), content={
    "type": 8,
    "data": { "choices": [] },
  })
}

///|
async test "strict REST works through typed decode and preserves snapshots" {
  let payload : Json = { "items": [1] }
  let route = @http.Route::custom(request_method=Post, path="/example?limit=2")
  let app = raw_app(ctx => {
    let got = ctx.client.request(route, body=payload, files=[
      @http.FileUpload("test.txt", b"hello", content_type="text/plain"),
    ])
    assert_eq(got, { "ok": true })
    if payload is Object(fields) {
      fields["items"] = [2]
    }
    ctx.respond(content="ok")
  })
  let harness = @testkit.Harness(app)
  let reply : Json = { "ok": true }
  harness.expect_rest(route, response(reply))
  if reply is Object(fields) {
    fields["ok"] = false
  }
  let result = harness.dispatch(@testkit.slash("run"))
  assert_true(result.errors().is_empty())
  let request = result.requests()[0]
  assert_eq(request.path, "/api/v10/example?limit=2")
  assert_eq(request.body, Some({ "items": [1] }))
  assert_eq(request.files.unwrap()[0].content(), b"hello")
  assert_eq(request.files.unwrap()[0].filename(), "test.txt")
  assert_eq(request.files.unwrap()[0].content_type(), "text/plain")
  request.headers.clear()
  assert_false(result.requests()[0].headers.is_empty())
  harness.assert_rest_complete()
}

///|
async test "REST mismatch cannot be swallowed and poisons only that harness" {
  let expected = @http.Route::custom(request_method=Get, path="/example?q=1")
  let actual = @http.Route::custom(request_method=Get, path="/example?q=2")
  let app = raw_app(ctx => {
    ignore(ctx.client.request(actual) catch { _ => Json::null() })
  })
  let harness = @testkit.Harness(app)
  harness.expect_rest(expected, response(Json::null()))
  try harness.dispatch(@testkit.slash("run")) catch {
    @testkit.TestkitError::RestMismatch => ()
    error => raise error
  } noraise {
    _ => fail("expected strict mismatch")
  }
  assert_eq(harness.last_requests().length(), 1)
  assert_eq(harness.last_requests()[0].route.path(), "/example?q=2")
  harness.last_requests()[0].headers.clear()
  assert_false(harness.last_requests()[0].headers.is_empty())
  try harness.dispatch(@testkit.slash("run")) catch {
    @testkit.TestkitError::FailedHarness => ()
    error => raise error
  } noraise {
    _ => fail("expected poisoned harness")
  }
  try @testkit.Harness(app).dispatch(@testkit.slash("run")) catch {
    @testkit.TestkitError::UnexpectedRest => ()
    error => raise error
  } noraise {
    _ => fail("expected unqueued request failure")
  }
}

///|
async test "REST scripts span dispatches, require exhaustion, and do not retry 429" {
  let app = raw_app(ctx => ignore(ctx.client.get_gateway()))
  let harness = @testkit.Harness(app)
  harness.expect_rest(GetGateway, response({ "url": "wss://example.invalid" }))
  harness.expect_rest(
    GetGateway,
    response({ "retry_after": 100.0 }, status=429),
  )
  assert_true(harness.dispatch(@testkit.slash("run")).no_response())
  try harness.assert_rest_complete() catch {
    @testkit.TestkitError::UnconsumedRest(1) => ()
    error => raise error
  } noraise {
    _ => fail("expected leftover")
  }
  let result = harness.dispatch(@testkit.slash("run"))
  assert_eq(result.requests().length(), 1)
  assert_true(
    result.errors()
    is [App(Handler(_, @http.DiscordHttpError::RateLimited(..)))],
  )
  harness.assert_rest_complete()
}

///|
async test "defer edit followup use REST while initial callback is captured" {
  let app = raw_app(ctx => {
    ctx.defer_response()
    ignore(ctx.edit_response(content="edited"))
    ignore(ctx.followup(content="followup"))
    raise @app.HandlerError::UserMessage(
      message="error followup",
      ephemeral=true,
    )
  })
  let harness = @testkit.Harness(app)
  let application_id = @testkit.default_application_id()
  let token = "testkit-interaction-token"
  harness.expect_rest(
    EditOriginalInteractionResponse(application_id~, token~),
    response(@testkit.message().to_json()),
  )
  harness.expect_rest(
    CreateFollowupMessage(application_id~, token~),
    response(@testkit.message().to_json()),
  )
  harness.expect_rest(
    CreateFollowupMessage(application_id~, token~),
    response(@testkit.message().to_json()),
  )
  let result = harness.dispatch(@testkit.slash("run"))
  assert_eq(result.requests().length(), 3)
  assert_eq(result.errors().length(), 1)
  assert_true(
    result.initial_response().unwrap().response.typ
    is DeferredChannelMessageWithSource,
  )
  harness.assert_rest_complete()
}

///|
async test "timeout joins cleanup and does not invoke error policy" {
  let cleaned = Ref(false)
  let app = raw_app(_ => {
    defer {
      cleaned.val = true
    }
    @async.sleep(10000)
  })
  app.error_policy((_, _) => fail("cancellation is not an App failure"))
  let harness = @testkit.Harness(app)
  try harness.dispatch(@testkit.slash("run"), timeout_ms=10) catch {
    @testkit.TestkitError::DispatchTimeout => assert_true(cleaned.val)
    error => raise error
  } noraise {
    _ => fail("expected timeout")
  }
  try harness.assert_rest_complete() catch {
    @testkit.TestkitError::FailedHarness => ()
    error => raise error
  } noraise {
    _ => fail("expected poisoned harness")
  }
}

///|
async test "parallel harnesses isolate observers and reentry is Busy" {
  let app = raw_app(_ => {
    @async.sleep(1)
    raise HandlerBoom
  })
  let first = @testkit.Harness(app)
  let second = @testkit.Harness(app)
  @async.with_task_group(group => {
    let one = group.spawn(() => first.dispatch(@testkit.slash("run")))
    let two = group.spawn(() => second.dispatch(@testkit.slash("run")))
    assert_eq(one.wait().errors().length(), 1)
    assert_eq(two.wait().errors().length(), 1)
  })
  let app2 = @app.App()
  let harness = @testkit.Harness(app2)
  app2.command(
    @app.slash(
      name="run",
      description="Run",
      args=@interaction.Args::unit(),
      handler=Raw(_ => {
        try harness.dispatch(@testkit.slash("run")) catch {
          @testkit.TestkitError::Busy => ()
          error => raise error
        } noraise {
          _ => fail("expected busy")
        }
      }),
    ),
  )
  assert_true(harness.dispatch(@testkit.slash("run")).no_response())
}

///|
async test "outer cancellation waits for cleanup and propagates" {
  let cleaned = Ref(false)
  let started = @async.Semaphore(1)
  started.acquire()
  let app = raw_app(_ => {
    defer {
      cleaned.val = true
    }
    started.release()
    @async.sleep(10000)
  })
  app.error_policy((_, _) => fail("cancellation is not a failure"))
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      ignore(@testkit.Harness(app).dispatch(@testkit.slash("run")))
    })
    started.acquire()
    task.cancel()
  })
  assert_true(cleaned.val)
}

///|
async test "real middleware check and decode failures reach policy" {
  let app = @app.App()
  let order : Array[String] = []
  app.middleware((_, next) => {
    order.push("before")
    next()
    order.push("after")
  })
  app.command(
    @app.slash(
      name="decode",
      description="Decode",
      args=@interaction.Args::of(
        @interaction.arg_string(name="value", description="Value"),
      ),
      handler=Raw(_ => fail("decode must reject")),
    ),
  )
  let result = @testkit.Harness(app).dispatch(@testkit.slash("decode"))
  assert_true(
    result.errors() is [App(Handler(_, @app.HandlerError::InvalidArgument(_)))],
  )
  assert_eq(order, ["before"])
  let checked = raw_app(_ => fail("check must reject"))
  // Middleware uses the same policy boundary as checks.
  checked.middleware((_, _) => raise @app.HandlerError::CheckFailed)
  assert_true(
    @testkit.Harness(checked).dispatch(@testkit.slash("run")).errors()
    is [App(Handler(_, @app.HandlerError::CheckFailed))],
  )
}

///|
async test "malformed context rejects before a handler and application id mismatch raises" {
  let app = @app.App()
  app.on_component_raw(prefix="button", _ => fail("must reject"))
  let interaction = @testkit.component("button")
  let result = @testkit.Harness(app).dispatch({ ..interaction, message: None, })
  assert_eq(result.routing, Rejected)
  assert_true(result.errors() is [Dispatch(_)])
  try
    @testkit.Harness(app).dispatch({
      ..interaction,
      application_id: @model.Id(1UL),
    })
  catch {
    @testkit.TestkitError::InvalidConfiguration(_) => ()
    error => raise error
  } noraise {
    _ => fail("expected id mismatch")
  }
}
