///|
/// Wire-shape coverage for the message parameters added from the
/// 2026-07-16 parameter-completeness audit: full message references,
/// shared client themes, retained attachments, and burst reactions.
async test "create message forwards a full message reference" {
  let client = Client("test-token")
  defer client.close()
  let captured_body = Ref(Json::null())
  client.perform_override_.val = Some((_route, _path, _headers, body, _files) => {
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null() }
  })
  let channel_id : @model.ChannelId = Id(10UL)
  try
    client.create_message(channel_id, message_reference={
      typ: Some(Forward),
      message_id: Some(Id(1UL)),
      channel_id: Some(Id(2UL)),
      guild_id: None,
      fail_if_not_exists: Some(false),
    })
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail message decoding")
  }
  json_inspect(captured_body.val, content={
    "allowed_mentions": { "parse": ["users", "roles"] },
    "message_reference": {
      "type": 1,
      "message_id": "1",
      "channel_id": "2",
      "fail_if_not_exists": false,
    },
  })
}

///|
async test "create message rejects reply_to together with message_reference" {
  let client = Client("test-token")
  defer client.close()
  let channel_id : @model.ChannelId = Id(10UL)
  try
    client.create_message(channel_id, content="hi", reply_to=Id(1UL), message_reference={
      typ: None,
      message_id: Some(Id(1UL)),
      channel_id: None,
      guild_id: None,
      fail_if_not_exists: None,
    })
  catch {
    Validation(message~) =>
      inspect(
        message,
        content="reply_to and message_reference are mutually exclusive",
      )
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected a validation error")
  }
}

///|
async test "create message forwards a shared client theme" {
  let client = Client("test-token")
  defer client.close()
  let captured_body = Ref(Json::null())
  client.perform_override_.val = Some((_route, _path, _headers, body, _files) => {
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null() }
  })
  let channel_id : @model.ChannelId = Id(10UL)
  let theme = @model.SharedClientTheme::{
    colors: ["ff0000", "00ff00"],
    gradient_angle: 45,
    base_mix: 50,
    base_theme: Some(Value(Dark)),
  }
  try client.create_message(channel_id, shared_client_theme=theme) catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail message decoding")
  }
  json_inspect(captured_body.val, content={
    "allowed_mentions": { "parse": ["users", "roles"] },
    "shared_client_theme": {
      "colors": ["ff0000", "00ff00"],
      "gradient_angle": 45,
      "base_mix": 50,
      "base_theme": 1,
    },
  })
}

///|
async test "edit message merges kept attachments with new uploads" {
  let client = Client("test-token")
  defer client.close()
  let captured_body = Ref(Json::null())
  client.perform_override_.val = Some((_route, _path, _headers, body, _files) => {
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null() }
  })
  let channel_id : @model.ChannelId = Id(10UL)
  let message_id : @model.MessageId = Id(20UL)
  let keep = @model.AttachmentRequest::{
    id: Id(555UL),
    filename: None,
    title: None,
    description: Some("keep me"),
    duration_secs: None,
    waveform: None,
    is_spoiler: None,
  }
  try
    client.edit_message(channel_id, message_id, keep_attachments=[keep], files=[
      FileUpload("new.png", b"PNG", is_spoiler=true),
    ])
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail message decoding")
  }
  json_inspect(captured_body.val, content={
    "allowed_mentions": { "parse": ["users", "roles"] },
    "attachments": [
      { "id": "555", "description": "keep me" },
      { "id": 0, "filename": "new.png", "is_spoiler": true },
    ],
  })
  // an explicit empty keep list with no files clears every attachment
  try client.edit_message(channel_id, message_id, keep_attachments=[]) catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail message decoding")
  }
  json_inspect(captured_body.val, content={
    "allowed_mentions": { "parse": ["users", "roles"] },
    "attachments": [],
  })
}

///|
async test "get reactions appends the burst type query" {
  let client = Client("test-token")
  defer client.close()
  let captured_path = Ref("")
  client.perform_override_.val = Some((_route, path, _headers, _body, _files) => {
    captured_path.val = path
    { status: 200, headers: Map([]), body: Json::array([]) }
  })
  let channel_id : @model.ChannelId = Id(1UL)
  let message_id : @model.MessageId = Id(2UL)
  let users = client.get_reactions(
    channel_id,
    message_id,
    "🔥",
    typ=Burst,
    limit=5,
  )
  assert_eq(users.length(), 0)
  inspect(
    captured_path.val,
    content="/api/v10/channels/1/messages/2/reactions/%F0%9F%94%A5?type=1&limit=5",
  )
  let users = client
    .channel_ref(channel_id)
    .message_ref(message_id)
    .reactions("🔥", typ=Normal)
  assert_eq(users.length(), 0)
  inspect(
    captured_path.val,
    content="/api/v10/channels/1/messages/2/reactions/%F0%9F%94%A5?type=0",
  )
}

///|
async test "message ref forwards a message as a snapshot reference" {
  let client = Client("test-token")
  defer client.close()
  let captured_body = Ref(Json::null())
  let captured_path = Ref("")
  client.perform_override_.val = Some((_route, path, _headers, body, _files) => {
    captured_path.val = path
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null() }
  })
  try client.channel_ref(Id(2UL)).message_ref(Id(1UL)).forward(Id(30UL)) catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail message decoding")
  }
  inspect(captured_path.val, content="/api/v10/channels/30/messages")
  json_inspect(captured_body.val, content={
    "allowed_mentions": { "parse": ["users", "roles"] },
    "message_reference": { "type": 1, "message_id": "1", "channel_id": "2" },
  })
}
