///|
async test "public transport sees prepared headers after middleware and typed decode" {
  let called = Ref(false)
  let client = @http.Client("synthetic", transport=request => {
    called.val = true
    assert_eq(request.path, "/api/v10/gateway")
    assert_eq(request.headers["authorization"], "Bot synthetic")
    assert_eq(request.headers["x-test"], "middleware")
    assert_false(request.headers.contains("content-type"))
    { status: 200, headers: Map([]), body: { "url": "wss://example.invalid" }, }
  })
  client.middleware((request, next) => {
    request.headers["x-test"] = "middleware"
    next(request)
  })
  assert_eq(client.get_gateway(), "wss://example.invalid")
  assert_true(called.val)
  client.close()
  called.val = false
  try client.get_gateway() catch {
    @http.DiscordHttpError::Transport(..) => ()
    error => raise error
  } noraise {
    _ => fail("closed client must fail")
  }
  assert_false(called.val)
}

///|
async test "public transport cannot bypass sticker and file validation" {
  let called = Ref(false)
  let client = @http.Client("synthetic", transport=_ => {
    called.val = true
    { status: 204, headers: Map([]), body: Json::null(), }
  })
  defer client.close()
  let sticker = @http.Route::CreateGuildSticker(guild_id=Id(1UL))
  for
    body in [Json::array([]), { "name": 1, "description": "ok", "tags": "ok" }] {
    try
      client.request(sticker, body~, files=[@http.FileUpload("a.png", b"image")])
    catch {
      @http.DiscordHttpError::Validation(..) => ()
      error => raise error
    } noraise {
      _ => fail("invalid form must not reach transport")
    }
  }
  try client.request(GetGateway, files=[@http.FileUpload("", b"file")]) catch {
    @http.DiscordHttpError::Validation(..) => ()
    error => raise error
  } noraise {
    _ => fail("invalid file must not reach transport")
  }
  assert_false(called.val)
}

///|
async test "public transport preserves timeout cleanup and configured retries" {
  let cleaned = Ref(false)
  let client = @http.Client("synthetic", request_timeout_ms=5, transport=_ => {
    defer {
      cleaned.val = true
    }
    @async.sleep(10000)
    { status: 204, headers: Map([]), body: Json::null(), }
  })
  defer client.close()
  try client.get_gateway() catch {
    @http.DiscordHttpError::Timeout(timeout_ms=5) => assert_true(cleaned.val)
    error => raise error
  } noraise {
    _ => fail("expected timeout")
  }
  let attempts = Ref(0)
  let retrying = @http.Client("synthetic", max_retries=1, transport=_ => {
    attempts.val += 1
    if attempts.val == 1 {
      { status: 429, headers: Map([]), body: { "retry_after": 0 }, }
    } else {
      {
        status: 200,
        headers: Map([]),
        body: { "url": "wss://example.invalid" },
      }
    }
  })
  defer retrying.close()
  assert_eq(retrying.get_gateway(), "wss://example.invalid")
  assert_eq(attempts.val, 2)
}
