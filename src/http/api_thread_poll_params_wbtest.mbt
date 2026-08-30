///|
/// Wire-shape coverage for the poll and thread parameters added after the
/// 2026-07-16 live sweep (the probe had to fall back to raw routes for these).
test "poll create request serializes request-side media without nulls" {
  let poll = @model.PollCreateRequest::{
    question: { text: Some("live probe poll?"), emoji: None, },
    answers: [
      { text: Some("yes"), emoji: None, },
      { text: Some("no"), emoji: None, },
    ],
    duration: Some(1),
    allow_multiselect: Some(true),
    layout_type: Some(Default),
  }
  json_inspect(poll.to_json(), content={
    "question": { "text": "live probe poll?" },
    "answers": [
      { "poll_media": { "text": "yes" } },
      { "poll_media": { "text": "no" } },
    ],
    "duration": 1,
    "allow_multiselect": true,
    "layout_type": 1,
  })
}

///|
async test "create message forwards the poll body" {
  let client = Client("test-token")
  defer client.close()
  let captured_body = Ref(Json::null())
  client.perform_override_.val = Some((_route, _path, _headers, body, _files) => {
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let channel_id : @model.ChannelId = Id(10UL)
  let poll = @model.PollCreateRequest::{
    question: { text: Some("q?"), emoji: None, },
    answers: [{ text: Some("a"), emoji: None, }],
    duration: None,
    allow_multiselect: None,
    layout_type: None,
  }
  try client.create_message(channel_id, poll~) catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail message decoding")
  }
  json_inspect(captured_body.val, content={
    "allowed_mentions": { "parse": ["users", "roles"] },
    "poll": {
      "question": { "text": "q?" },
      "answers": [{ "poll_media": { "text": "a" } }],
    },
  })
}

///|
async test "modify channel forwards the thread-only fields" {
  let client = Client("test-token")
  defer client.close()
  let captured_body = Ref(Json::null())
  client.perform_override_.val = Some((_route, _path, _headers, body, _files) => {
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let channel_id : @model.ChannelId = Id(20UL)
  try
    client.modify_channel(
      channel_id,
      archived=false,
      auto_archive_duration=OneDay,
      locked=true,
      invitable=false,
      flags=@model.ChannelFlags::from_bits(2),
      applied_tags=[Id(5UL)],
    )
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail channel decoding")
  }
  json_inspect(captured_body.val, content={
    "flags": 2,
    "archived": false,
    "auto_archive_duration": 1440,
    "locked": true,
    "invitable": false,
    "applied_tags": ["5"],
  })
}

///|
async test "execute webhook builds thread query and body params" {
  let client = Client("test-token")
  defer client.close()
  let captured_path = Ref("")
  let captured_body = Ref(Json::null())
  client.perform_override_.val = Some((_route, path, _headers, body, _files) => {
    captured_path.val = path
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let webhook_id : @model.WebhookId = Id(1UL)
  try
    client.execute_webhook(
      webhook_id,
      "tok",
      content="hi",
      thread_id=Id(77UL),
      with_components=true,
    )
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail message decoding")
  }
  inspect(
    captured_path.val,
    content="/api/v10/webhooks/1/tok?wait=true&thread_id=77&with_components=true",
  )
  try
    client.execute_webhook(
      webhook_id,
      "tok",
      content="hi",
      thread_name="probe thread",
      applied_tags=[Id(5UL)],
    )
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail message decoding")
  }
  inspect(captured_path.val, content="/api/v10/webhooks/1/tok?wait=true")
  json_inspect(captured_body.val, content={
    "content": "hi",
    "thread_name": "probe thread",
    "applied_tags": ["5"],
  })
}

///|
async test "execute webhook rejects thread_id together with thread_name" {
  let client = Client("test-token")
  defer client.close()
  let webhook_id : @model.WebhookId = Id(1UL)
  try
    client.execute_webhook(
      webhook_id,
      "tok",
      content="hi",
      thread_id=Id(77UL),
      thread_name="probe thread",
    )
  catch {
    Validation(message~) =>
      inspect(
        message,
        content="thread_id and thread_name are mutually exclusive",
      )
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected a validation error")
  }
}

///|
async test "webhook message endpoints append the thread_id query" {
  let client = Client("test-token")
  defer client.close()
  let captured_path = Ref("")
  client.perform_override_.val = Some((_route, path, _headers, _body, _files) => {
    captured_path.val = path
    { status: 204, headers: Map([]), body: Json::null(), }
  })
  let webhook_id : @model.WebhookId = Id(1UL)
  let message_id : @model.MessageId = Id(2UL)
  client.delete_webhook_message(
    webhook_id,
    "tok",
    message_id,
    thread_id=Id(77UL),
  )
  inspect(
    captured_path.val,
    content="/api/v10/webhooks/1/tok/messages/2?thread_id=77",
  )
  client
  .webhook_ref(webhook_id)
  .with_token("tok")
  .message_ref(message_id)
  .delete()
  inspect(captured_path.val, content="/api/v10/webhooks/1/tok/messages/2")
}
