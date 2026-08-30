///|
test "Components V2 validation permits empty incompatible arrays" {
  let components : Array[@model.Component] = [
    TextDisplay({ id: None, content: "layout content", }),
  ]
  let flags = message_flags_with_components_v2(
    None,
    None,
    Some([]),
    Some(components),
    sticker_ids=[],
  )
  inspect(flags.unwrap().bits(), content="32768")
}

///|
async test "create followup combines ephemeral and Components V2 flags" {
  let client = Client("test-token")
  defer client.close()
  let captured_body = Ref(Json::null())
  client.perform_override_.val = Some((_route, _path, _headers, body, _files) => {
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let application_id : @model.ApplicationId = Id(10UL)
  let components : Array[@model.Component] = [
    TextDisplay({ id: None, content: "private layout", }),
  ]
  try
    client.create_followup(
      application_id,
      "interaction-token",
      components~,
      flags=@model.MessageFlags::ephemeral(),
    )
    |> ignore
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail message decoding")
  }
  json_inspect(captured_body.val, content={
    "components": [{ "content": "private layout", "type": 10 }],
    "flags": 32832,
  })
}

///|
async test "create message adds Components V2 and rejects stickers" {
  let client = Client("test-token")
  defer client.close()
  let captured_body = Ref(Json::null())
  client.perform_override_.val = Some((_route, _path, _headers, body, _files) => {
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let channel_id : @model.ChannelId = Id(20UL)
  let components : Array[@model.Component] = [
    Separator({ id: None, divider: Some(true), spacing: None, }),
  ]
  try client.create_message(channel_id, components~) |> ignore catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail message decoding")
  }
  json_inspect(captured_body.val, content={
    "components": [{ "divider": true, "type": 14 }],
    "flags": 32768,
    "allowed_mentions": { "parse": ["users", "roles"] },
  })
  let sticker_id : @model.StickerId = Id(30UL)
  try
    client.create_message(channel_id, components~, sticker_ids=[sticker_id])
    |> ignore
  catch {
    err =>
      debug_inspect(
        err,
        content=(
          #|Validation(message="Components V2 cannot be combined with content, embeds, sticker_ids, or poll")
        ),
      )
  } noraise {
    _ => fail("expected Components V2 sticker validation")
  }
}

///|
async test "execute webhook adds Components V2 and rejects content" {
  let client = Client("test-token")
  defer client.close()
  let captured_body = Ref(Json::null())
  client.perform_override_.val = Some((_route, _path, _headers, body, _files) => {
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let webhook_id : @model.WebhookId = Id(40UL)
  let components : Array[@model.Component] = [
    Container({ id: None, components: [], accent_color: None, spoiler: None, }),
  ]
  try
    client.execute_webhook(webhook_id, "webhook-token", components~) |> ignore
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail message decoding")
  }
  json_inspect(captured_body.val, content={
    "components": [{ "components": [], "type": 17 }],
    "flags": 32768,
  })
  try
    client.execute_webhook(
      webhook_id,
      "webhook-token",
      content="legacy content",
      components~,
    )
    |> ignore
  catch {
    err =>
      debug_inspect(
        err,
        content=(
          #|Validation(message="Components V2 cannot be combined with content, embeds, sticker_ids, or poll")
        ),
      )
  } noraise {
    _ => fail("expected Components V2 content validation")
  }
}
