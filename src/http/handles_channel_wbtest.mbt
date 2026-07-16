///|
async test "channel ref edit delegates nullable fields and audit reason" {
  let client = Client("test-token")
  defer client.close()
  let captured_method = Ref("")
  let captured_path = Ref("")
  let captured_headers : Ref[Map[String, String]?] = Ref(None)
  let captured_body = Ref(Json::null())
  client.perform_override_.val = Some((route, path, headers, body, _files) => {
    captured_method.val = @debug.to_string(route.method_())
    captured_path.val = path
    captured_headers.val = Some(headers)
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null() }
  })
  let channel_id : @model.ChannelId = Id(100UL)
  try
    client.channel_ref(channel_id).edit(name="n", clear_topic=true, reason="r")
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail channel decoding")
  }
  inspect(captured_method.val, content="Patch")
  inspect(captured_path.val, content="/api/v10/channels/100")
  json_inspect(captured_body.val, content={ "name": "n", "topic": null })
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
async test "channel ref follow keeps announcement and target direction" {
  let client = Client("test-token")
  defer client.close()
  let captured_path = Ref("")
  let captured_body = Ref(Json::null())
  client.perform_override_.val = Some((_route, path, _headers, body, _files) => {
    captured_path.val = path
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null() }
  })
  let announcement_channel_id : @model.ChannelId = Id(110UL)
  let target_channel_id : @model.ChannelId = Id(120UL)
  try
    client.channel_ref(announcement_channel_id).follow(target_channel_id)
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail followed channel decoding")
  }
  inspect(captured_path.val, content="/api/v10/channels/110/followers")
  json_inspect(captured_body.val, content={ "webhook_channel_id": "120" })
}

///|
async test "channel ref create stage instance binds the channel id" {
  let client = Client("test-token")
  defer client.close()
  let captured_path = Ref("")
  let captured_body = Ref(Json::null())
  client.perform_override_.val = Some((_route, path, _headers, body, _files) => {
    captured_path.val = path
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null() }
  })
  let channel_id : @model.ChannelId = Id(130UL)
  try client.channel_ref(channel_id).create_stage_instance("town hall") catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail stage instance decoding")
  }
  inspect(captured_path.val, content="/api/v10/stage-instances")
  json_inspect(captured_body.val, content={
    "channel_id": "130",
    "topic": "town hall",
  })
}

///|
async test "message ref reaction deletions bind message and user ids" {
  let client = Client("test-token")
  defer client.close()
  let captured_paths : Array[String] = []
  client.perform_override_.val = Some((_route, path, _headers, _body, _files) => {
    captured_paths.push(path)
    { status: 204, headers: Map([]), body: Json::null() }
  })
  let channel_id : @model.ChannelId = Id(140UL)
  let message_id : @model.MessageId = Id(150UL)
  let user_id : @model.UserId = Id(170UL)
  let message = client.message_ref(channel_id, message_id)
  message.unreact("wave:160")
  message.delete_user_reaction("wave:160", user_id)
  guard captured_paths is [unreact_path, user_reaction_path] else {
    fail("expected two captured request paths")
  }
  inspect(
    unreact_path,
    content="/api/v10/channels/140/messages/150/reactions/wave%3A160/@me",
  )
  inspect(
    user_reaction_path,
    content="/api/v10/channels/140/messages/150/reactions/wave%3A160/170",
  )
}

///|
test "message ref poll voters preserves paginator validation" {
  let client = Client("test-token")
  defer client.close()
  let channel_id : @model.ChannelId = Id(180UL)
  let message_id : @model.MessageId = Id(190UL)
  try
    client
    .message_ref(channel_id, message_id)
    .poll_answer_voters(1, page_size=0)
  catch {
    Validation(message~) =>
      inspect(message, content="poll voter limit must be between 1 and 100")
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected paginator validation")
  }
}
