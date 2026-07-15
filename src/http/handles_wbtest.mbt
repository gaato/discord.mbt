///|
async test "message ref reply delegates a message reference" {
  let client = Client("test-token")
  defer client.close()
  let captured_path = Ref("")
  let captured_body = Ref(Json::null())
  client.perform_override_.val = Some((_route, path, _headers, body, _files) => {
    captured_path.val = path
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null() }
  })
  let channel_id : @model.ChannelId = Id(10UL)
  let message_id : @model.MessageId = Id(20UL)
  try client.message_ref(channel_id, message_id).reply(content="hello") catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail message decoding")
  }
  inspect(captured_path.val, content="/api/v10/channels/10/messages")
  json_inspect(captured_body.val, content={
    "content": "hello",
    "allowed_mentions": { "parse": ["users", "roles"] },
    "message_reference": { "message_id": "20" },
  })
}

///|
async test "member ref ban delegates the audit reason header" {
  let client = Client("test-token")
  defer client.close()
  let captured_path = Ref("")
  let captured_headers : Ref[Map[String, String]?] = Ref(None)
  let captured_body = Ref(Json::null())
  client.perform_override_.val = Some((_route, path, headers, body, _files) => {
    captured_path.val = path
    captured_headers.val = Some(headers)
    captured_body.val = body.unwrap_or(Json::null())
    { status: 204, headers: Map([]), body: Json::null() }
  })
  let guild_id : @model.GuildId = Id(30UL)
  let user_id : @model.UserId = Id(40UL)
  client
  .member_ref(guild_id, user_id)
  .ban(delete_message_seconds=3600, reason="remove spam")
  inspect(captured_path.val, content="/api/v10/guilds/30/bans/40")
  guard captured_headers.val is Some(headers) else {
    fail("expected request headers")
  }
  debug_inspect(
    headers.get("x-audit-log-reason"),
    content=(
      #|Some("remove spam")
    ),
  )
  json_inspect(captured_body.val, content={ "delete_message_seconds": 3600 })
}

///|
test "channel ref messages preserves paginator validation" {
  let client = Client("test-token")
  defer client.close()
  let channel_id : @model.ChannelId = Id(50UL)
  try client.channel_ref(channel_id).messages(page_size=0) catch {
    Validation(message~) =>
      inspect(message, content="message limit must be 1 through 100")
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected paginator validation")
  }
}
