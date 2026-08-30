///|
async test "webhook token ref send delegates bound credentials and body" {
  let client = Client("test-token")
  defer client.close()
  let captured_method = Ref("")
  let captured_path = Ref("")
  let captured_body = Ref(Json::null())
  client.perform_override_.val = Some((route, path, _headers, body, _files) => {
    captured_method.val = @debug.to_string(route.method_())
    captured_path.val = path
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let webhook_id : @model.WebhookId = Id(400UL)
  try
    client.webhook_token_ref(webhook_id, "token-a").send(content="hello")
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail message decoding")
  }
  inspect(captured_method.val, content="Post")
  inspect(captured_path.val, content="/api/v10/webhooks/400/token-a?wait=true")
  json_inspect(captured_body.val, content={ "content": "hello" })
}

///|
async test "webhook ref edit delegates bot-authenticated audit reason" {
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
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let webhook_id : @model.WebhookId = Id(410UL)
  try
    client.webhook_ref(webhook_id).edit(name="renamed", reason="audit")
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail webhook decoding")
  }
  inspect(captured_method.val, content="Patch")
  inspect(captured_path.val, content="/api/v10/webhooks/410")
  json_inspect(captured_body.val, content={ "name": "renamed" })
  guard captured_headers.val is Some(headers) else {
    fail("expected request headers")
  }
  debug_inspect(
    headers.get("x-audit-log-reason"),
    content=(
      #|Some("audit")
    ),
  )
  // WebhookTokenRef::edit intentionally has no reason parameter because token
  // routes do not support audit-log reasons.
}

///|
async test "webhook message ref edit delegates nullable content" {
  let client = Client("test-token")
  defer client.close()
  let captured_method = Ref("")
  let captured_path = Ref("")
  let captured_body = Ref(Json::null())
  client.perform_override_.val = Some((route, path, _headers, body, _files) => {
    captured_method.val = @debug.to_string(route.method_())
    captured_path.val = path
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let webhook_id : @model.WebhookId = Id(420UL)
  let message_id : @model.MessageId = Id(430UL)
  try
    client
    .webhook_token_ref(webhook_id, "token-b")
    .message_ref(message_id)
    .edit(clear_content=true)
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail message decoding")
  }
  inspect(captured_method.val, content="Patch")
  inspect(
    captured_path.val,
    content="/api/v10/webhooks/420/token-b/messages/430",
  )
  json_inspect(captured_body.val, content={ "content": null })
}

///|
async test "invite ref target users delegates the uploaded file" {
  let client = Client("test-token")
  defer client.close()
  let captured_method = Ref("")
  let captured_path = Ref("")
  let captured_files : Ref[Array[FileUpload]?] = Ref(None)
  client.perform_override_.val = Some((route, path, _headers, _body, files) => {
    captured_method.val = @debug.to_string(route.method_())
    captured_path.val = path
    captured_files.val = files
    { status: 204, headers: Map([]), body: Json::null(), }
  })
  let file = FileUpload(
    "target-users.csv",
    b"user_id\n123\n",
    content_type="text/csv",
  )
  client.invite_ref("invite-a").update_target_users(file)
  inspect(captured_method.val, content="Put")
  inspect(captured_path.val, content="/api/v10/invites/invite-a/target-users")
  guard captured_files.val is Some(files) else {
    fail("expected uploaded files")
  }
  inspect(files.length(), content="1")
  inspect(files[0].filename, content="target-users.csv")
  inspect(files[0].content.length(), content="12")
  inspect(files[0].content_type, content="text/csv")
}
