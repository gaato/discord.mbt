///|
fn sync_stub_client(
  requests : Array[String],
  bodies : Array[Json],
  fetched : Array[Json],
) -> @dhttp.Client {
  let client = @dhttp.Client("test-token")
  client.middleware((request, _next) => {
    requests.push(
      "\{@debug.to_string(request.route.method_())} \{request.route.path()}",
    )
    if request.route.method_() is Put && request.body is Some(body) {
      bodies.push(body)
    }
    let body = if request.route.method_() is Get {
      Json::array(fetched)
    } else {
      Json::array([])
    }
    { status: 200, headers: Map([]), body, }
  })
  client
}

///|
fn entry_point() -> Json {
  {
    "id": "900",
    "application_id": "42",
    "version": "901",
    "guild_id": "100",
    "name_localized": "Launch localized",
    "description_localized": "Play localized",
    "type": 4,
    "name": "Launch",
    "description": "Play",
    "handler": 2,
    "name_localizations": { "ja": "起動" },
    "some_future_field": { "version": "keep nested fields", "values": [1, 2] },
  }
}

///|
async test "entry point command is re-sent in the overwrite payload" {
  for unowned in [@framework.UnownedCommands::Delete, Keep] {
    let remote = entry_point()
    let original = remote.stringify()
    let requests = []
    let bodies = []
    let client = sync_stub_client(requests, bodies, [remote])
    defer client.close()
    let report = @framework.sync_command_scope(
      client,
      @model.Id::parse("42"),
      [@interaction.CommandSpec::slash("ping", "Ping")],
      unowned~,
    )
    assert_true(report.overwritten)
    assert_eq(report.created, ["ping"])
    assert_eq(report.preserved, ["4:Launch"])
    assert_eq(report.deleted, [])
    assert_true(report.guild_id is None)
    assert_eq(requests, [
      "Get /applications/42/commands?with_localizations=true", "Put /applications/42/commands",
    ])
    json_inspect(bodies, content=[
      [
        { "name": "ping", "description": "Ping" },
        {
          "id": "900",
          "type": 4,
          "name": "Launch",
          "description": "Play",
          "handler": 2,
          "name_localizations": { "ja": "起動" },
          "some_future_field": {
            "version": "keep nested fields",
            "values": [1, 2],
          },
        },
      ],
    ])
    assert_eq(remote.stringify(), original)
  }
}

///|
async test "in-sync catalog with an entry point sends no overwrite" {
  let ping = @interaction.CommandSpec::slash("ping", "Ping")
  for unowned in [@framework.UnownedCommands::Delete, Keep] {
    let requests = []
    let bodies = []
    let client = sync_stub_client(requests, bodies, [
      entry_point(),
      ping.to_json(),
    ])
    defer client.close()
    let report = @framework.sync_command_scope(
      client,
      @model.Id::parse("42"),
      [ping],
      unowned~,
    )
    assert_false(report.overwritten)
    assert_eq(report.unchanged, ["ping"])
    assert_eq(report.preserved, ["4:Launch"])
    assert_eq(requests, [
      "Get /applications/42/commands?with_localizations=true",
    ])
    assert_eq(bodies, [])
  }
}

///|
async test "Keep re-sends undeclared commands with their ids" {
  let requests = []
  let bodies = []
  let remote : Json = {
    "id": "902",
    "type": 2,
    "name": "inspect",
    "application_id": "42",
    "version": "903",
    "some_future_field": true,
  }
  let client = sync_stub_client(requests, bodies, [remote])
  defer client.close()
  let fw = @framework.Framework(client, @model.Id::parse("42"))
  fw.command(@interaction.CommandSpec::slash("inspect", "Inspect"), _ => ())
  |> ignore
  let report = fw.sync_global(unowned=Keep)
  assert_eq(report.created, ["inspect"])
  assert_eq(report.preserved, ["2:inspect"])
  assert_eq(report.deleted, [])
  assert_true(report.overwritten)
  json_inspect(bodies, content=[
    [
      { "name": "inspect", "description": "Inspect" },
      { "id": "902", "type": 2, "name": "inspect", "some_future_field": true },
    ],
  ])
}

///|
async test "Delete reports removed names" {
  let requests = []
  let bodies = []
  let client = sync_stub_client(requests, bodies, [
    { "id": "902", "name": "old", "description": "Old" },
    { "id": "903", "type": 3, "name": "inspect" },
  ])
  defer client.close()
  let fw = @framework.Framework(client, @model.Id::parse("42"))
  let report = fw.sync_global()
  assert_eq(report.deleted, ["old", "3:inspect"])
  assert_eq(report.preserved, [])
  assert_true(report.overwritten)
  json_inspect(bodies, content=[[]])
}

///|
test "report classifies created, updated and unchanged" {
  let created = @interaction.CommandSpec::message("inspect")
  let updated = @interaction.CommandSpec::slash("ping", "New")
  let unchanged = @interaction.CommandSpec::user("inspect")
  let (payload, report) = @framework.plan_command_sync(
    [created, updated, unchanged],
    [unchanged.to_json(), { "name": "ping", "description": "Old" }],
    unowned=Delete,
  )
  assert_eq(report.created, ["3:inspect"])
  assert_eq(report.updated, ["ping"])
  assert_eq(report.unchanged, ["2:inspect"])
  assert_eq(report.deleted, [])
  assert_eq(report.preserved, [])
  assert_eq(
    payload,
    Some(
      Json::array([created.to_json(), updated.to_json(), unchanged.to_json()]),
    ),
  )
}

///|
async test "guild scope reports its guild id" {
  let requests = []
  let bodies = []
  let client = sync_stub_client(requests, bodies, [
    { "id": "902", "name": "other", "description": "Other", "guild_id": "100" },
  ])
  defer client.close()
  let fw = @framework.Framework(client, @model.Id::parse("42"))
  fw.command(@interaction.CommandSpec::slash("ping", "Ping"), _ => ()) |> ignore
  let guild_id : @model.GuildId = @model.Id::parse("100")
  let report = fw.sync_guild(guild_id, unowned=Keep)
  assert_eq(report.guild_id, Some(guild_id))
  assert_eq(report.preserved, ["other"])
  assert_eq(requests, [
    "Get /applications/42/guilds/100/commands?with_localizations=true", "Put /applications/42/guilds/100/commands",
  ])
  json_inspect(bodies, content=[
    [
      { "name": "ping", "description": "Ping" },
      { "id": "902", "name": "other", "description": "Other" },
    ],
  ])
}

///|
test "preserving undeclared commands alone needs no overwrite" {
  for unowned in [@framework.UnownedCommands::Delete, Keep] {
    let (payload, report) = @framework.plan_command_sync(
      [],
      [entry_point()],
      unowned~,
    )
    assert_true(payload is None)
    assert_false(report.overwritten)
    assert_eq(report.preserved, ["4:Launch"])
  }
  let (payload, report) = @framework.plan_command_sync(
    [],
    [{ "id": "902", "type": 5, "name": "future" }],
    unowned=Keep,
  )
  assert_true(payload is None)
  assert_false(report.overwritten)
  assert_eq(report.preserved, ["5:future"])
}

///|
test "duplicate remote keys force an overwrite even with no other changes" {
  let ping = @interaction.CommandSpec::slash("ping", "Ping")
  let (payload, report) = @framework.plan_command_sync(
    [ping],
    [ping.to_json(), { "type": 1, "name": "ping", "description": "Ping" }],
    unowned=Delete,
  )
  assert_true(report.overwritten)
  assert_eq(report.unchanged, ["ping"])
  assert_eq(report.created, [])
  assert_eq(report.updated, [])
  assert_eq(report.deleted, [])
  assert_eq(payload, Some(Json::array([ping.to_json()])))
  let (payload, report) = @framework.plan_command_sync(
    [],
    [entry_point(), entry_point()],
    unowned=Keep,
  )
  assert_true(payload is Some(_))
  assert_true(report.overwritten)
}

///|
test "empty scope needs no overwrite" {
  let (payload, report) = @framework.plan_command_sync([], [], unowned=Delete)
  assert_true(payload is None)
  assert_false(report.overwritten)
  assert_eq(report.created, [])
  assert_eq(report.updated, [])
  assert_eq(report.deleted, [])
  assert_eq(report.unchanged, [])
  assert_eq(report.preserved, [])
}
