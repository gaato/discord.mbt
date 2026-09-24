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
  let (client, perform) = offline_test_client()
  defer client.close()
  let captured_body = Ref(Json::null())
  perform.val = Some((_route, _path, _headers, body, _files) => {
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
  let (client, perform) = offline_test_client()
  defer client.close()
  let captured_body = Ref(Json::null())
  perform.val = Some((_route, _path, _headers, body, _files) => {
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
  let (client, perform) = offline_test_client()
  defer client.close()
  let captured_body = Ref(Json::null())
  perform.val = Some((_route, _path, _headers, body, _files) => {
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

///|
test "modal limits are reported as a validation error naming the path" {
  let input = @model.Component::TextInput({
    id: None,
    custom_id: "body",
    style: Some(Paragraph),
    label: None,
    min_length: None,
    max_length: Some(4096),
    required: None,
    value: None,
    placeholder: None,
  })
  let components : Array[@model.Component] = [
    Label({
      id: None,
      label: Some("Body"),
      description: None,
      component: input,
    }),
  ]
  try validate_modal_limits("Edit", components) catch {
    err =>
      debug_inspect(
        err,
        content=(
          #|Validation(message="components[0].component.max_length: 4096 (1 to 4000)")
        ),
      )
  } noraise {
    _ => fail("expected a modal limit violation")
  }
}

///|
async test "message sends reject embeds and components outside Discord's limits" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let requests = Ref(0)
  perform.val = Some((_route, _path, _headers, _body, _files) => {
    requests.val += 1
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let channel_id : @model.ChannelId = Id(20UL)
  try
    client.create_message(channel_id, embeds=[
      @model.Embed(description="x".repeat(4097)),
    ])
    |> ignore
  catch {
    err =>
      debug_inspect(
        err,
        content=(
          #|Validation(message="embeds[0].description: 4097 units (at most 4096)")
        ),
      )
  } noraise {
    _ => fail("expected an embed limit violation")
  }
  let button : @model.Component = @json.from_json({
    "type": 2,
    "style": 1,
    "custom_id": "go",
    "label": "x".repeat(81),
  })
  let components : Array[@model.Component] = [
    ActionRow({ id: None, components: [button], }),
  ]
  let message_id : @model.MessageId = Id(21UL)
  try client.edit_message(channel_id, message_id, components~) |> ignore catch {
    err =>
      debug_inspect(
        err,
        content=(
          #|Validation(message="components[0].components[0].label: 81 units (at most 80)")
        ),
      )
  } noraise {
    _ => fail("expected a component limit violation")
  }
  inspect(requests.val, content="0")
}
