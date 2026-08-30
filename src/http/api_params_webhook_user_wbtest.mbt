///|
/// Wire-shape coverage for the webhook and user parameters added from the
/// 2026-07-16 parameter-completeness audit.
async test "execute webhook forwards caller-supplied flags" {
  let client = Client("test-token")
  defer client.close()
  let captured_body = Ref(Json::null())
  client.perform_override_.val = Some((_route, _path, _headers, body, _files) => {
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let webhook_id : @model.WebhookId = Id(1UL)
  try
    client.execute_webhook(
      webhook_id,
      "tok",
      content="quiet",
      flags=@model.MessageFlags::suppress_notifications(),
    )
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail message decoding")
  }
  json_inspect(captured_body.val, content={ "content": "quiet", "flags": 4096 })
}

///|
async test "edit webhook message forwards flags, query, and kept attachments" {
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
  let message_id : @model.MessageId = Id(2UL)
  try
    client.edit_webhook_message(
      webhook_id,
      "tok",
      message_id,
      flags=@model.MessageFlags::suppress_embeds(),
      thread_id=Id(77UL),
      with_components=true,
      keep_attachments=[
        {
          id: Id(9UL),
          filename: None,
          title: None,
          description: None,
          duration_secs: None,
          waveform: None,
          is_spoiler: Some(true),
        },
      ],
    )
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail message decoding")
  }
  inspect(
    captured_path.val,
    content="/api/v10/webhooks/1/tok/messages/2?thread_id=77&with_components=true",
  )
  json_inspect(captured_body.val, content={
    "flags": 4,
    "attachments": [{ "id": "9", "is_spoiler": true }],
  })
}

///|
async test "modify current user forwards and clears the banner" {
  let client = Client("test-token")
  defer client.close()
  let captured_body = Ref(Json::null())
  client.perform_override_.val = Some((_route, _path, _headers, body, _files) => {
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  try client.modify_current_user(banner="data:image/png;base64,AAAA") catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail user decoding")
  }
  json_inspect(captured_body.val, content={
    "banner": "data:image/png;base64,AAAA",
  })
  try client.modify_current_user(clear_banner=true) catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail user decoding")
  }
  json_inspect(captured_body.val, content={ "banner": null })
}
