///|
test "message response data adds the Components V2 flag" {
  let components : Array[@model.Component] = [
    Container({ id: None, components: [], accent_color: None, spoiler: None, }),
  ]
  json_inspect(
    message_response_data(None, None, Some(components), None, None, false),
    content={ "components": [{ "components": [], "type": 17 }], "flags": 32768 },
  )
}

///|
test "message response data combines ephemeral and Components V2 flags" {
  let components : Array[@model.Component] = [
    TextDisplay({ id: None, content: "private layout", }),
  ]
  json_inspect(
    message_response_data(None, None, Some(components), None, None, true),
    content={
      "components": [{ "content": "private layout", "type": 10 }],
      "flags": 32832,
    },
  )
}

///|
test "message response data leaves legacy component flags absent" {
  let components : Array[@model.Component] = [
    ActionRow({ id: None, components: [], }),
  ]
  json_inspect(
    message_response_data(None, None, Some(components), None, None, false),
    content={ "components": [{ "components": [], "type": 1 }] },
  )
}

///|
test "message response data rejects content with Components V2" {
  let components : Array[@model.Component] = [
    Separator({ id: None, divider: Some(true), spacing: None, }),
  ]
  try
    message_response_data(
      Some("legacy content"),
      None,
      Some(components),
      None,
      None,
      false,
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
    _ => fail("expected Components V2 validation")
  }
}
