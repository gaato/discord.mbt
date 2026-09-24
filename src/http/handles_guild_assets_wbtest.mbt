///|
async test "template ref fetch resolves by code without the bound guild id" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let captured_method = Ref("")
  let captured_path = Ref("")
  perform.val = Some((route, path, _headers, _body, _files) => {
    captured_method.val = @debug.to_string(route.method_())
    captured_path.val = path
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let guild_id : @model.GuildId = Id(300UL)
  try client.guild_ref(guild_id).template_ref("code-a").fetch() catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail template decoding")
  }
  inspect(captured_method.val, content="Get")
  inspect(captured_path.val, content="/api/v10/guilds/templates/code-a")
}

///|
async test "template ref sync uses the bound guild id" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let captured_method = Ref("")
  let captured_path = Ref("")
  perform.val = Some((route, path, _headers, _body, _files) => {
    captured_method.val = @debug.to_string(route.method_())
    captured_path.val = path
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let guild_id : @model.GuildId = Id(310UL)
  try client.guild_template_ref(guild_id, "code-b").sync() catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail template decoding")
  }
  inspect(captured_method.val, content="Put")
  inspect(captured_path.val, content="/api/v10/guilds/310/templates/code-b")
}

///|
async test "emoji ref delete delegates bound ids and audit reason" {
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
  let guild_id : @model.GuildId = Id(320UL)
  let emoji_id : @model.EmojiId = Id(330UL)
  client.emoji_ref(guild_id, emoji_id).delete(reason="cleanup")
  inspect(captured_method.val, content="Delete")
  inspect(captured_path.val, content="/api/v10/guilds/320/emojis/330")
  guard captured_headers.val is Some(headers) else {
    fail("expected request headers")
  }
  debug_inspect(
    headers.get("x-audit-log-reason"),
    content=(
      #|Some("cleanup")
    ),
  )
}

///|
async test "soundboard sound ref edit delegates nullable emoji id" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let captured_method = Ref("")
  let captured_path = Ref("")
  let captured_body = Ref(Json::null())
  perform.val = Some((route, path, _headers, body, _files) => {
    captured_method.val = @debug.to_string(route.method_())
    captured_path.val = path
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let guild_id : @model.GuildId = Id(340UL)
  let sound_id : @model.SoundboardSoundId = Id(350UL)
  try
    client.soundboard_sound_ref(guild_id, sound_id).edit(clear_emoji_id=true)
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail soundboard sound decoding")
  }
  inspect(captured_method.val, content="Patch")
  inspect(
    captured_path.val,
    content="/api/v10/guilds/340/soundboard-sounds/350",
  )
  json_inspect(captured_body.val, content={ "emoji_id": null })
}

///|
test "scheduled event ref users preserves paginator validation" {
  let client = Client("test-token")
  defer client.close()
  let guild_id : @model.GuildId = Id(360UL)
  let event_id : @model.ScheduledEventId = Id(370UL)
  try client.scheduled_event_ref(guild_id, event_id).users(page_size=0) catch {
    Validation(message~) =>
      inspect(
        message,
        content="scheduled event user limit must be between 1 and 100",
      )
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected paginator validation")
  }
}
