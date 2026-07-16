///|
priv suberror MiddlewareFailure derive(Debug)

///|
async test "middleware execution order is onion-style" {
  let client = Client("test-token")
  defer client.close()
  client.perform_override_.val = Some((_route, _path, _headers, _body, _files) => {
    status: 200,
    headers: Map([]),
    body: { "ok": true },
  })
  let order : Array[String] = []
  let first : HttpMiddleware = (request, next) => {
    order.push("a-in")
    let response = next(request)
    order.push("a-out")
    response
  }
  let second : HttpMiddleware = (request, next) => {
    order.push("b-in")
    let response = next(request)
    order.push("b-out")
    response
  }
  client..middleware(first).middleware(second)
  ignore(client.request(GetGateway))
  inspect(order.join(", "), content="a-in, b-in, b-out, a-out")
}

///|
async test "middleware request headers reach transport" {
  let client = Client("test-token")
  defer client.close()
  let captured_header = Ref("")
  client.perform_override_.val = Some((_route, _path, headers, _body, _files) => {
    captured_header.val = headers.get_or_default("x-middleware", "")
    { status: 200, headers: Map([]), body: Json::null() }
  })
  client.middleware((request, next) => {
    next({ ..request, headers: { "x-middleware": "present" } })
  })
  ignore(client.request(GetGateway))
  inspect(captured_header.val, content="present")
}

///|
async test "request headers default to bot auth and allow bearer override" {
  let client = Client("test-token")
  defer client.close()
  let captured_authorizations : Array[String] = []
  client.perform_override_.val = Some((_route, _path, headers, _body, _files) => {
    captured_authorizations.push(headers.get_or_default("authorization", ""))
    { status: 200, headers: Map([]), body: Json::null() }
  })
  ignore(client.request(GetGateway))
  ignore(
    client.request(GetGateway, headers={ "authorization": "Bearer oauth-token" }),
  )
  debug_inspect(
    captured_authorizations,
    content=(
      #|["Bot test-token", "Bearer oauth-token"]
    ),
  )
}

///|
async test "github-compatible webhook sends its event without bot auth" {
  let client = Client("test-token")
  defer client.close()
  let captured_github_event = Ref("")
  let captured_authorization = Ref(false)
  client.perform_override_.val = Some((_route, _path, headers, _body, _files) => {
    captured_github_event.val = headers.get_or_default("x-github-event", "")
    captured_authorization.val = headers.contains("authorization")
    { status: 200, headers: Map([]), body: Json::null() }
  })
  let webhook_id : @model.WebhookId = Id(10UL)
  client.execute_github_compatible_webhook(
    webhook_id,
    "webhook-token",
    { "ref": "refs/heads/main" },
    github_event="push",
  )
  inspect(captured_github_event.val, content="push")
  assert_false(captured_authorization.val)
}

///|
async test "middleware may short-circuit without transport" {
  let client = Client("test-token")
  defer client.close()
  let calls = Ref(0)
  client.perform_override_.val = Some((_route, _path, _headers, _body, _files) => {
    calls.val += 1
    { status: 200, headers: Map([]), body: { "transport": true } }
  })
  client.middleware((_request, _next) => {
    status: 200,
    headers: { "x-short-circuit": "true" },
    body: { "short_circuit": true },
  })
  let response = client.request(GetGateway)
  inspect(calls.val, content="0")
  guard response is { "short_circuit": True, .. } else {
    fail("expected synthetic response")
  }
}

///|
async test "middleware sees final response after 429 retries" {
  let client = Client("test-token", max_retries=1, request_timeout_ms=1000)
  defer client.close()
  let calls = Ref(0)
  client.perform_override_.val = Some((_route, _path, _headers, _body, _files) => {
    calls.val += 1
    if calls.val == 1 {
      {
        status: 429,
        headers: { "x-ratelimit-global": "true", "retry-after": "0" },
        body: { "retry_after": 0.0 },
      }
    } else {
      { status: 200, headers: Map([]), body: { "ok": true } }
    }
  })
  let next_returns = Ref(0)
  let observed_status = Ref(0)
  client.middleware((request, next) => {
    let response = next(request)
    next_returns.val += 1
    observed_status.val = response.status
    response
  })
  ignore(client.request(GetGateway))
  inspect(calls.val, content="2")
  inspect(next_returns.val, content="1")
  inspect(observed_status.val, content="200")
}

///|
async test "middleware failures surface as transport errors" {
  let client = Client("test-token")
  defer client.close()
  client.middleware((_request, _next) => raise MiddlewareFailure)
  try client.request(GetGateway) catch {
    Transport(message~) => assert_true(message.contains("MiddlewareFailure"))
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected transport error")
  }
}

///|
async test "middleware observes wire errors before API mapping" {
  let client = Client("test-token")
  defer client.close()
  client.perform_override_.val = Some((_route, _path, _headers, _body, _files) => {
    status: 404,
    headers: { "x-wire": "visible" },
    body: { "code": 10003, "message": "Unknown Channel" },
  })
  let observed_status = Ref(0)
  let observed_header = Ref("")
  let observed_body = Ref(Json::null())
  client.middleware((request, next) => {
    let response = next(request)
    observed_status.val = response.status
    observed_header.val = response.headers.get_or_default("x-wire", "")
    observed_body.val = response.body
    response
  })
  try client.request(GetGateway) catch {
    Api(status~, error~) => {
      inspect(status, content="404")
      inspect(error.code, content="10003")
    }
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected API error")
  }
  inspect(observed_status.val, content="404")
  inspect(observed_header.val, content="visible")
  guard observed_body.val is { "code": Number(10003.0, ..), .. } else {
    fail("expected middleware to observe the wire body")
  }
}
