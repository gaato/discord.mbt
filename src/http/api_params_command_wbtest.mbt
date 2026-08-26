///|
/// Wire-shape coverage for the application-command parameters added from the
/// 2026-07-16 parameter-completeness audit.
async test "create global command forwards localizations and installation scopes" {
  let client = Client("test-token")
  defer client.close()
  let captured_body = Ref(Json::null())
  client.perform_override_.val = Some((_route, _path, _headers, body, _files) => {
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null() }
  })
  let application_id : @model.ApplicationId = Id(1UL)
  try
    client.create_global_command(
      application_id,
      "probe",
      description="a probe",
      name_localizations={ "ja": "プローブ" },
      description_localizations={ "ja": "プローブです" },
      integration_types=[GuildInstall, UserInstall],
      contexts=[Guild, BotDm],
    )
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail command decoding")
  }
  json_inspect(captured_body.val, content={
    "name": "probe",
    "name_localizations": { "ja": "プローブ" },
    "description": "a probe",
    "description_localizations": { "ja": "プローブです" },
    "integration_types": [0, 1],
    "contexts": [0, 1],
  })
}

///|
async test "create command requires a description only for chat input" {
  let client = Client("test-token")
  defer client.close()
  client.perform_override_.val = Some((_route, _path, _headers, _body, _files) => {
    status: 200,
    headers: Map([]),
    body: Json::null(),
  })
  let application_id : @model.ApplicationId = Id(1UL)
  try client.create_global_command(application_id, "probe") catch {
    Validation(message~) =>
      inspect(
        message,
        content="description is required for CHAT_INPUT commands",
      )
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected a validation error")
  }
  // a USER command needs no description
  let captured_body = Ref(Json::null())
  client.perform_override_.val = Some((_route, _path, _headers, body, _files) => {
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null() }
  })
  try client.create_global_command(application_id, "probe", typ=User) catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail command decoding")
  }
  json_inspect(captured_body.val, content={ "name": "probe", "type": 2 })
}

///|
async test "edit global command clears localizations with explicit nulls" {
  let client = Client("test-token")
  defer client.close()
  let captured_body = Ref(Json::null())
  client.perform_override_.val = Some((_route, _path, _headers, body, _files) => {
    captured_body.val = body.unwrap_or(Json::null())
    { status: 200, headers: Map([]), body: Json::null() }
  })
  let application_id : @model.ApplicationId = Id(1UL)
  let command_id : @model.CommandId = Id(2UL)
  try
    client.edit_global_command(
      application_id,
      command_id,
      clear_name_localizations=true,
      clear_description_localizations=true,
      handler=AppHandler,
    )
  catch {
    Deserialize(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the fake response to fail command decoding")
  }
  json_inspect(captured_body.val, content={
    "name_localizations": null,
    "description_localizations": null,
    "handler": 1,
  })
}

///|
async test "command list endpoints append the with_localizations query" {
  let client = Client("test-token")
  defer client.close()
  let captured_path = Ref("")
  client.perform_override_.val = Some((_route, path, _headers, _body, _files) => {
    captured_path.val = path
    { status: 200, headers: Map([]), body: Json::array([]) }
  })
  let application_id : @model.ApplicationId = Id(1UL)
  let guild_id : @model.GuildId = Id(2UL)
  ignore(client.get_global_commands(application_id, with_localizations=true))
  inspect(
    captured_path.val,
    content="/api/v10/applications/1/commands?with_localizations=true",
  )
  ignore(client.get_guild_commands(application_id, guild_id))
  inspect(
    captured_path.val,
    content="/api/v10/applications/1/guilds/2/commands",
  )
  ignore(
    client
    .application_ref(application_id)
    .guild_commands(guild_id, with_localizations=false),
  )
  inspect(
    captured_path.val,
    content="/api/v10/applications/1/guilds/2/commands?with_localizations=false",
  )
}
