///|
fn ok(body : Json) -> @http.HttpResponse {
  { status: 200, headers: Map([]), body, }
}

///|
async test "offline handler is the innermost step of the middleware chain" {
  let seen : Array[String] = []
  let client = @http.Client::offline(request => {
    seen.push("handler:\{request.headers["x-order"]}")
    ok({ "url": "wss://example.invalid" })
  })
  client.middleware((request, next) => {
    request.headers["x-order"] = "outer"
    seen.push("outer")
    next(request)
  })
  client.middleware((request, next) => {
    request.headers["x-order"] = "inner"
    seen.push("inner")
    next(request)
  })
  assert_eq(client.get_gateway(), "wss://example.invalid")
  assert_eq(seen, ["outer", "inner", "handler:inner"])
}

///|
async test "offline handler sees the logical request and typed decoding runs" {
  let routes : Array[@http.Route] = []
  let client = @http.Client::offline(request => {
    routes.push(request.route)
    match request.route {
      CreateMessage(channel_id~) => {
        assert_eq(channel_id, Id(7UL))
        assert_true(request.body is Some({ "content": "hi", .. }))
        assert_true(
          request.files is Some([file]) &&
          file.filename() == "a.txt" &&
          file.content() == b"text" &&
          file.content_type() == "text/plain",
        )
        ok({ "code": 0, "message": "not a message" })
      }
      _ => fail("unexpected route")
    }
  })
  try
    client.create_message(Id(7UL), content="hi", files=[
      @http.FileUpload("a.txt", b"text", content_type="text/plain"),
    ])
  catch {
    @http.DiscordHttpError::Deserialize(..) => ()
    error => raise error
  } noraise {
    _ => fail("a non-message body must not decode")
  }
  assert_true(routes is [CreateMessage(channel_id=Id(7UL))])
}

///|
async test "offline responses map to typed errors without retry or waiting" {
  let attempts = Ref(0)
  let client = @http.Client::offline(request => {
    attempts.val += 1
    match request.route {
      GetGateway =>
        {
          status: 429,
          headers: { "x-ratelimit-global": "true" },
          body: { "retry_after": 2.5 },
        }
      _ =>
        {
          status: 404,
          headers: Map([]),
          body: { "code": 10003, "message": "Unknown Channel" },
        }
    }
  })
  try client.get_gateway() catch {
    @http.DiscordHttpError::RateLimited(retry_after_ms=2500L, global=true) => ()
    error => raise error
  } noraise {
    _ => fail("expected RateLimited")
  }
  assert_eq(attempts.val, 1)
  try client.get_channel(Id(1UL)) catch {
    @http.DiscordHttpError::Api(status=404, error~) =>
      assert_eq(error.code, 10003)
    error => raise error
  } noraise {
    _ => fail("expected Api")
  }
}

///|
async test "offline handler errors propagate through the typed boundary" {
  let client = @http.Client::offline(request => {
    match request.route {
      GetGateway => fail("handler broke")
      _ => raise @http.DiscordHttpError::Timeout(timeout_ms=1)
    }
  })
  try client.get_gateway() catch {
    @http.DiscordHttpError::Transport(message~) =>
      assert_true(message.contains("handler broke"))
    error => raise error
  } noraise {
    _ => fail("expected Transport")
  }
  try client.get_channel(Id(1UL)) catch {
    @http.DiscordHttpError::Timeout(timeout_ms=1) => ()
    error => raise error
  } noraise {
    _ => fail("expected Timeout")
  }
}

///|
async test "offline client still validates and can be closed" {
  let called = Ref(false)
  let client = @http.Client::offline(_ => {
    called.val = true
    { status: 204, headers: Map([]), body: Json::null(), }
  })
  try client.request(GetGateway, files=[@http.FileUpload("", b"file")]) catch {
    @http.DiscordHttpError::Validation(..) => ()
    error => raise error
  } noraise {
    _ => fail("an invalid file must not reach the handler")
  }
  assert_false(called.val)
  assert_eq(client.to_string(), "discord.Client")
  client.close()
  try client.get_gateway() catch {
    @http.DiscordHttpError::Transport(..) => ()
    error => raise error
  } noraise {
    _ => fail("a closed client must fail")
  }
  assert_false(called.val)
}

///|
async test "offline calls emit per-attempt HTTP telemetry" {
  let client = @http.Client::offline(request => {
    match request.route {
      GetGateway =>
        { status: 429, headers: Map([]), body: { "retry_after": 1 }, }
      GetChannel(..) => fail("broken")
      _ => ok({ "url": "wss://example.invalid" })
    }
  })
  let events : Array[@telemetry.TelemetryEvent] = []
  client.on_telemetry(event => events.push(event))
  for
    route in [
      @http.Route::GetGateway,
      GetChannel(channel_id=Id(1UL)),
      GetCurrentUser,
    ] {
    let _ = client.request(route) catch { _ => Json::null() }
  }
  assert_true(
    events
    is [
      HttpRequest(status=429, retries=0, ..),
      HttpRateLimited(retry_after_ms=1000L, global=false, ..),
      HttpRequest(status=0, ..),
      HttpRequest(status=200, ..),
    ],
  )
}
