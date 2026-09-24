///|
async test "guild ref edit delegates nullable fields and audit reason" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let captured_method = Ref("")
  let captured_path = Ref("")
  let captured_headers : Ref[Map[String, String]?] = Ref(None)
  let captured_body = Ref(Json::null())
  perform.val = Some((route, path, headers, body, _files) => {
    captured_method.val = @debug.to_string(route.method_())
    captured_path.val = path
    captured_headers.val = Some(headers)
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let guild_id : @model.GuildId = Id(200UL)
  try
    client.guild_ref(guild_id).edit(name="nn", clear_icon=true, reason="r")
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail guild decoding")
  }
  inspect(captured_method.val, content="Patch")
  inspect(captured_path.val, content="/api/v10/guilds/200")
  json_inspect(captured_body.val, content={ "name": "nn", "icon": null })
  guard captured_headers.val is Some(headers) else {
    fail("expected request headers")
  }
  debug_inspect(
    headers.get("x-audit-log-reason"),
    content=(
      #|Some("r")
    ),
  )
}

///|
test "guild ref members preserves paginator validation" {
  let client = Client("test-token")
  defer client.close()
  let guild_id : @model.GuildId = Id(210UL)
  try client.guild_ref(guild_id).members(page_size=0) catch {
    Validation(message~) =>
      inspect(message, content="guild member limit must be between 1 and 1000")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected paginator validation")
  }
}

///|
async test "member ref unban delegates the audit reason header" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let captured_method = Ref("")
  let captured_path = Ref("")
  let captured_headers : Ref[Map[String, String]?] = Ref(None)
  perform.val = Some((route, path, headers, _body, _files) => {
    captured_method.val = @debug.to_string(route.method_())
    captured_path.val = path
    captured_headers.val = Some(headers)
    { status: 204, headers: Map([]), body: Json::null(), }
  })
  let guild_id : @model.GuildId = Id(220UL)
  let user_id : @model.UserId = Id(230UL)
  client.member_ref(guild_id, user_id).unban(reason="appeal")
  inspect(captured_method.val, content="Delete")
  inspect(captured_path.val, content="/api/v10/guilds/220/bans/230")
  guard captured_headers.val is Some(headers) else {
    fail("expected request headers")
  }
  debug_inspect(
    headers.get("x-audit-log-reason"),
    content=(
      #|Some("appeal")
    ),
  )
}

///|
async test "role ref edit delegates bound ids and audit reason" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let captured_method = Ref("")
  let captured_path = Ref("")
  let captured_headers : Ref[Map[String, String]?] = Ref(None)
  let captured_body = Ref(Json::null())
  perform.val = Some((route, path, headers, body, _files) => {
    captured_method.val = @debug.to_string(route.method_())
    captured_path.val = path
    captured_headers.val = Some(headers)
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let guild_id : @model.GuildId = Id(240UL)
  let role_id : @model.RoleId = Id(250UL)
  try
    client.role_ref(guild_id, role_id).edit(name="moderator", reason="r")
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail role decoding")
  }
  inspect(captured_method.val, content="Patch")
  inspect(captured_path.val, content="/api/v10/guilds/240/roles/250")
  json_inspect(captured_body.val, content={ "name": "moderator" })
  guard captured_headers.val is Some(headers) else {
    fail("expected request headers")
  }
  debug_inspect(
    headers.get("x-audit-log-reason"),
    content=(
      #|Some("r")
    ),
  )
}

///|
async test "guild ref search messages preserves query parameters" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let captured_path = Ref("")
  perform.val = Some((_route, path, _headers, _body, _files) => {
    captured_path.val = path
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let guild_id : @model.GuildId = Id(260UL)
  let author_id : @model.UserId = Id(270UL)
  try
    client
    .guild_ref(guild_id)
    .search_messages(limit=10, content="hello world", pinned=true, author_id=[
      author_id,
    ])
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail search result decoding")
  }
  inspect(
    captured_path.val,
    content="/api/v10/guilds/260/messages/search?limit=10&content=hello%20world&pinned=true&author_id=270",
  )
}
