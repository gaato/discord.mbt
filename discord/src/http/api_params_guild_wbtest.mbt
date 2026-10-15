///|
/// Wire-shape coverage for the guild parameters added from the 2026-07-16
/// parameter-completeness audit.
async test "modify guild member forwards flags" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let captured_body = Ref(Json::null())
  perform.val = Some((_route, _path, _headers, body, _files) => {
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let guild_id : @model.GuildId = Id(1UL)
  let user_id : @model.UserId = Id(2UL)
  try
    client.modify_guild_member(
      guild_id,
      user_id,
      flags=@model.GuildMemberFlags::bypasses_verification(),
    )
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail member decoding")
  }
  json_inspect(captured_body.val, content={ "flags": 4 })
}

///|
async test "role wrappers forward colors, icon, and unicode emoji" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let captured_body = Ref(Json::null())
  perform.val = Some((_route, _path, _headers, body, _files) => {
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let guild_id : @model.GuildId = Id(1UL)
  let role_id : @model.RoleId = Id(2UL)
  try
    client.create_guild_role(
      guild_id,
      name="probe",
      colors={
        primary_color: 0xff0000,
        secondary_color: Null,
        tertiary_color: Null,
      },
      icon="data:image/png;base64,AAAA",
      unicode_emoji="🦊",
    )
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail role decoding")
  }
  json_inspect(captured_body.val, content={
    "name": "probe",
    "colors": {
      "primary_color": 16711680,
      "secondary_color": null,
      "tertiary_color": null,
    },
    "icon": "data:image/png;base64,AAAA",
    "unicode_emoji": "🦊",
  })
  try
    client.modify_guild_role(
      guild_id,
      role_id,
      clear_icon=true,
      clear_unicode_emoji=true,
    )
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail role decoding")
  }
  json_inspect(captured_body.val, content={
    "icon": null,
    "unicode_emoji": null,
  })
}

///|
async test "auto moderation create omits trigger metadata when absent" {
  let (client, perform) = offline_test_client()
  defer client.close()
  let captured_body = Ref(Json::null())
  perform.val = Some((_route, _path, _headers, body, _files) => {
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null(), }
  })
  let guild_id : @model.GuildId = Id(1UL)
  try
    client.create_auto_moderation_rule(
      guild_id,
      "spam rule",
      MessageSend,
      Spam,
      [{ typ: BlockMessage, metadata: None, }],
    )
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail rule decoding")
  }
  json_inspect(captured_body.val, content={
    "name": "spam rule",
    "event_type": 1,
    "trigger_type": 3,
    "actions": [{ "type": 1 }],
  })
}
