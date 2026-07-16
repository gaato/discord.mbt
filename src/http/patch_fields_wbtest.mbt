///|
test "patch fields omit missing values and preserve empty arrays" {
  json_inspect(
    message_patch_builder(None, false, None, None, None).build(),
    content=Json::empty_object(),
  )
  json_inspect(
    message_patch_builder(None, false, Some([]), Some([]), None).build(),
    content={ "embeds": [], "components": [] },
  )
  json_inspect(
    command_patch_body(
      None,
      None,
      Some([]),
      None,
      false,
      None,
      None,
      false,
      None,
      false,
      None,
      None,
      None,
    ),
    content={ "options": [] },
  )
}

///|
test "message patch adds and combines the Components V2 flag" {
  let components : Array[@model.Component] = [
    Container({ id: None, components: [], accent_color: None, spoiler: None }),
  ]
  json_inspect(
    message_patch_builder(None, false, None, Some(components), None).build(),
    content={ "components": [{ "components": [], "type": 17 }], "flags": 32768 },
  )
  json_inspect(
    message_patch_builder(
      None,
      false,
      None,
      Some(components),
      Some(@model.MessageFlags::ephemeral()),
    ).build(),
    content={ "components": [{ "components": [], "type": 17 }], "flags": 32832 },
  )
}

///|
test "nullable patch fields distinguish set and clear" {
  json_inspect(
    message_patch_builder(Some("updated"), false, None, None, None).build(),
    content={ "content": "updated" },
  )
  json_inspect(message_patch_builder(None, true, None, None, None).build(), content={
    "content": null,
  })
  json_inspect(
    command_patch_body(
      None,
      None,
      None,
      None,
      true,
      None,
      None,
      false,
      None,
      false,
      None,
      None,
      None,
    ),
    content={ "default_member_permissions": null },
  )
}

///|
test "nullable patch fields reject set and clear together" {
  try
    message_patch_builder(Some("updated"), true, None, None, None) |> ignore
  catch {
    err =>
      debug_inspect(
        err,
        content=(
          #|Validation(message="content and clear_content cannot both be set")
        ),
      )
  } noraise {
    _ => fail("expected content conflict validation")
  }
  try
    command_patch_body(
      None,
      None,
      None,
      Some(@model.Permissions::view_channel()),
      true,
      None,
      None,
      false,
      None,
      false,
      None,
      None,
      None,
    )
    |> ignore
  catch {
    err =>
      debug_inspect(
        err,
        content=(
          #|Validation(message="default_member_permissions and clear_default_member_permissions cannot both be set")
        ),
      )
  } noraise {
    _ => fail("expected default permissions conflict validation")
  }
}
