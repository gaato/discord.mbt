///|
fn command_options(fixture : String) -> @interaction.CommandOptions raise {
  let data : @model.CommandData = @json.from_json(@json.parse(fixture))
  @interaction.CommandOptions::from_data(data)
}

///|
test "typed command spec derives options from Args" {
  let args = @interaction.Args::map2(
    @interaction.arg_string(name="text", description="Text to echo"),
    @interaction.arg_int(
      name="times",
      description="Repeat count",
      min=1L,
      max=5L,
    ).with_default(1L),
    (text, times) => (text, times),
  )
  let command = slash(
    name="echo",
    description="Echo some text",
    args~,
    handler=Raw(_ => ()),
  )
  json_inspect(command.spec().to_json(), content={
    "name": "echo",
    "description": "Echo some text",
    "options": [
      {
        "type": 3,
        "name": "text",
        "description": "Text to echo",
        "required": true,
      },
      {
        "type": 4,
        "name": "times",
        "description": "Repeat count",
        "required": false,
        "min_value": 1,
        "max_value": 5,
      },
    ],
  })
  inspect(command.erase().name(), content="echo")
}

///|
test "localized command builders reach the registration payload" {
  let command = slash(
    name="greet",
    description="Greet a user",
    name_localizations={ "ja": "あいさつ" },
    description_localizations={ "ja": "ユーザーにあいさつ" },
    args=@interaction.Args::of(
      @interaction.arg_string(
        name="style",
        description="Greeting style",
        name_localizations={ "ja": "スタイル" },
        description_localizations={ "ja": "あいさつの形式" },
        choices=[
          @interaction.string_choice("Friendly", "friendly", name_localizations={
            "ja": "親しみやすい",
          }),
        ],
      ),
    ),
    handler=Raw(_ => ()),
  )
  json_inspect(command.spec().to_json(), content={
    "name": "greet",
    "name_localizations": { "ja": "あいさつ" },
    "description": "Greet a user",
    "description_localizations": { "ja": "ユーザーにあいさつ" },
    "options": [
      {
        "type": 3,
        "name": "style",
        "name_localizations": { "ja": "スタイル" },
        "description": "Greeting style",
        "description_localizations": { "ja": "あいさつの形式" },
        "required": true,
        "choices": [
          {
            "name": "Friendly",
            "name_localizations": { "ja": "親しみやすい" },
            "value": "friendly",
          },
        ],
      },
    ],
  })
  json_inspect(
    @interaction.CommandSpec::slash("plain", "Plain command").to_json(),
    content={ "name": "plain", "description": "Plain command" },
  )
}

///|
test "localized group and context command builders reach their specs" {
  let grouped = slash_group(
    name="admin",
    description="Administration",
    name_localizations={ "ja": "管理" },
    description_localizations={ "ja": "管理機能" },
    children=[
      subcommand_group(
        name="member",
        description="Member tools",
        name_localizations={ "ja": "メンバー" },
        description_localizations={ "ja": "メンバー機能" },
        children=[
          subcommand(
            name="show",
            description="Show a member",
            name_localizations={ "ja": "表示" },
            description_localizations={ "ja": "メンバーを表示" },
            args=@interaction.Args::unit(),
            handler=Raw(_ => ()),
          ),
        ],
      ),
    ],
  )
  let user = user_command(
    name="Inspect user",
    name_localizations={ "ja": "ユーザーを確認" },
    handler=Raw(_ => ()),
  )
  let message = message_command(
    name="Inspect message",
    name_localizations={ "ja": "メッセージを確認" },
    handler=Raw(_ => ()),
  )
  json_inspect(
    [grouped.spec().to_json(), user.spec().to_json(), message.spec().to_json()],
    content=[
      {
        "name": "admin",
        "name_localizations": { "ja": "管理" },
        "description": "Administration",
        "description_localizations": { "ja": "管理機能" },
        "options": [
          {
            "type": 2,
            "name": "member",
            "name_localizations": { "ja": "メンバー" },
            "description": "Member tools",
            "description_localizations": { "ja": "メンバー機能" },
            "options": [
              {
                "type": 1,
                "name": "show",
                "name_localizations": { "ja": "表示" },
                "description": "Show a member",
                "description_localizations": { "ja": "メンバーを表示" },
              },
            ],
          },
        ],
      },
      {
        "name": "Inspect user",
        "name_localizations": { "ja": "ユーザーを確認" },
        "description": "",
        "type": 2,
      },
      {
        "name": "Inspect message",
        "name_localizations": { "ja": "メッセージを確認" },
        "description": "",
        "type": 3,
      },
    ],
  )
}

///|
test "command argument decode errors become InvalidArgument" {
  let fixture =
    #|{
    #|  "id": "107000000000000201",
    #|  "name": "echo",
    #|  "type": 1,
    #|  "options": []
    #|}
  let args = @interaction.Args::of(
    @interaction.arg_string(name="text", description="Text to echo"),
  )
  try decode_command_args(args, command_options(fixture)) catch {
    error =>
      debug_inspect(
        error,
        content=(
          #|InvalidArgument("MissingOption(name=\"text\")")
        ),
      )
  } noraise {
    _ => fail("expected decode to fail")
  }
}

///|
fn guard_dm_interaction(
  name : String,
  id : String,
  user_id? : String = "200000000000000001",
) -> @model.Interaction raise {
  @json.from_json(
    @json.parse(
      (
        #|{"id":"INTERACTION_ID","application_id":"400000000000000001","type":2,"token":"interaction-token","version":1,"user":{"id":"USER_ID","username":"nelly","discriminator":"0","global_name":"Nelly","avatar":null},"data":{"id":"600000000000000001","name":"COMMAND_NAME","type":1}}
      )
      .replace(old="INTERACTION_ID", new=id)
      .replace(old="USER_ID", new=user_id)
      .replace(old="COMMAND_NAME", new=name),
    ),
  )
}

///|
fn guard_guild_interaction(
  name : String,
  id : String,
  permissions? : String = "2048",
  user_id? : String = "200000000000000001",
) -> @model.Interaction raise {
  @json.from_json(
    @json.parse(
      (
        #|{"id":"INTERACTION_ID","application_id":"400000000000000001","type":2,"token":"interaction-token","version":1,"guild_id":"800000000000000001","member":{"user":{"id":"USER_ID","username":"nelly","discriminator":"0","global_name":"Nelly","avatar":null},"roles":[],"joined_at":"2025-06-01T10:00:00Z","deaf":false,"mute":false,"permissions":"PERMISSIONS"},"data":{"id":"600000000000000001","name":"COMMAND_NAME","type":1}}
      )
      .replace(old="INTERACTION_ID", new=id)
      .replace(old="USER_ID", new=user_id)
      .replace(old="PERMISSIONS", new=permissions)
      .replace(old="COMMAND_NAME", new=name),
    ),
  )
}

///|
async fn dispatch_guard_interaction(
  framework : @framework.Framework,
  interaction : @model.Interaction,
) -> Unit {
  let (gate, _) = @framework.ResponseGate::capture(interaction)
  assert_true(framework.process_with(interaction, gate~))
}

///|
async test "command checks run in order and stop before the handler" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let app = App(sync=Disabled)
  let trace : Array[String] = []
  let errors : Array[String] = []
  app.error_policy((_, error) => {
    match error {
      HandlerError::CheckFailed => errors.push("CheckFailed")
      _ => errors.push("unexpected")
    }
  })
  app.command(
    slash(
      name="guarded",
      description="Guarded command",
      args=@interaction.Args::unit(),
      handler=Raw(_ => trace.push("handler")),
    )
    .check(_ => {
      trace.push("first")
      true
    })
    .check(_ => {
      trace.push("second")
      false
    })
    .check(_ => {
      trace.push("third")
      true
    }),
  )
  let framework = @framework.Framework(
    client,
    @model.Id::parse("400000000000000001"),
  )
  app.attach(
    framework,
    client~,
    application_id=@model.Id::parse("400000000000000001"),
  )
  |> ignore
  dispatch_guard_interaction(
    framework,
    guard_dm_interaction("guarded", "500000000000000001"),
  )
  debug_inspect(trace, content="[\"first\", \"second\"]")
  debug_inspect(errors, content="[\"CheckFailed\"]")
}

///|
async test "built-in scope and permission checks use invocation data" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let app = App(sync=Disabled)
  let handled : Array[String] = []
  let errors : Array[String] = []
  app.error_policy((_, error) => {
    match error {
      HandlerError::GuildOnly => errors.push("GuildOnly")
      HandlerError::DmOnly => errors.push("DmOnly")
      HandlerError::MissingPermission(_) => errors.push("MissingPermission")
      _ => errors.push("unexpected")
    }
  })
  app.command(
    slash(
      name="guild",
      description="Guild command",
      args=@interaction.Args::unit(),
      handler=Raw(_ => handled.push("guild")),
    )
    .check(guild_only())
    .check(required_permissions(@model.Permissions::send_messages())),
  )
  app.command(
    slash(
      name="dm",
      description="DM command",
      args=@interaction.Args::unit(),
      handler=Raw(_ => handled.push("dm")),
    ).check(dm_only()),
  )
  let framework = @framework.Framework(
    client,
    @model.Id::parse("400000000000000001"),
  )
  app.attach(
    framework,
    client~,
    application_id=@model.Id::parse("400000000000000001"),
  )
  |> ignore
  dispatch_guard_interaction(
    framework,
    guard_dm_interaction("guild", "500000000000000010"),
  )
  dispatch_guard_interaction(
    framework,
    guard_guild_interaction("guild", "500000000000000011"),
  )
  dispatch_guard_interaction(
    framework,
    guard_guild_interaction("guild", "500000000000000013", permissions="0"),
  )
  dispatch_guard_interaction(
    framework,
    guard_guild_interaction("guild", "500000000000000014", permissions="8"),
  )
  dispatch_guard_interaction(
    framework,
    guard_guild_interaction("dm", "500000000000000012"),
  )
  debug_inspect(handled, content="[\"guild\", \"guild\"]")
  debug_inspect(
    errors,
    content="[\"GuildOnly\", \"MissingPermission\", \"DmOnly\"]",
  )
}

///|
async test "command cooldown reports retry time and recovers" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let app = App(sync=Disabled)
  let clock = Ref(1_000L)
  app.set_clock(() => clock.val)
  let handled = Ref(0)
  let retries : Array[Int64] = []
  app.error_policy((_, error) => {
    match error {
      HandlerError::OnCooldown(retry_after_ms~) => retries.push(retry_after_ms)
      _ => fail("unexpected guard error: \{to_repr(error)}")
    }
  })
  app.command(
    slash(
      name="limited",
      description="Limited command",
      args=@interaction.Args::unit(),
      handler=Raw(_ => handled.val += 1),
    ).cooldown(seconds=10, bucket=User),
  )
  let framework = @framework.Framework(
    client,
    @model.Id::parse("400000000000000001"),
  )
  app.attach(
    framework,
    client~,
    application_id=@model.Id::parse("400000000000000001"),
  )
  |> ignore
  dispatch_guard_interaction(
    framework,
    guard_dm_interaction("limited", "500000000000000020"),
  )
  dispatch_guard_interaction(
    framework,
    guard_dm_interaction("limited", "500000000000000021"),
  )
  clock.val = 5_000L
  dispatch_guard_interaction(
    framework,
    guard_dm_interaction("limited", "500000000000000022"),
  )
  clock.val = 11_000L
  dispatch_guard_interaction(
    framework,
    guard_dm_interaction("limited", "500000000000000023"),
  )
  inspect(handled.val, content="2")
  debug_inspect(retries, content="[10000, 6000]")
}

///|
async test "guild and global cooldown buckets share the intended scope" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let app = App(sync=Disabled)
  app.set_clock(() => 1_000L)
  let guild_runs = Ref(0)
  let global_runs = Ref(0)
  let cooldowns = Ref(0)
  app.error_policy((_, error) => {
    match error {
      HandlerError::OnCooldown(_) => cooldowns.val += 1
      _ => fail("unexpected bucket error: \{to_repr(error)}")
    }
  })
  app.command(
    slash(
      name="guild-bucket",
      description="Guild bucket",
      args=@interaction.Args::unit(),
      handler=Raw(_ => guild_runs.val += 1),
    ).cooldown(seconds=10, bucket=Guild),
  )
  app.command(
    slash(
      name="global-bucket",
      description="Global bucket",
      args=@interaction.Args::unit(),
      handler=Raw(_ => global_runs.val += 1),
    ).cooldown(seconds=10, bucket=Global),
  )
  let framework = @framework.Framework(
    client,
    @model.Id::parse("400000000000000001"),
  )
  app.attach(
    framework,
    client~,
    application_id=@model.Id::parse("400000000000000001"),
  )
  |> ignore
  dispatch_guard_interaction(
    framework,
    guard_guild_interaction(
      "guild-bucket",
      "500000000000000030",
      user_id="200000000000000001",
    ),
  )
  dispatch_guard_interaction(
    framework,
    guard_guild_interaction(
      "guild-bucket",
      "500000000000000031",
      user_id="200000000000000002",
    ),
  )
  dispatch_guard_interaction(
    framework,
    guard_dm_interaction(
      "global-bucket",
      "500000000000000032",
      user_id="200000000000000001",
    ),
  )
  dispatch_guard_interaction(
    framework,
    guard_dm_interaction(
      "global-bucket",
      "500000000000000033",
      user_id="200000000000000002",
    ),
  )
  inspect(guild_runs.val, content="1")
  inspect(global_runs.val, content="1")
  inspect(cooldowns.val, content="2")
}

///|
test "command validation rejects non-positive cooldowns" {
  let app = App(sync=Disabled)
  app.command(
    slash(
      name="invalid-cooldown",
      description="Invalid cooldown",
      args=@interaction.Args::unit(),
      handler=Raw(_ => ()),
    ).cooldown(seconds=0),
  )
  try app.validate() catch {
    InvalidCooldown(command~, seconds~) => {
      inspect(command, content="invalid-cooldown")
      inspect(seconds, content="0")
    }
    error => fail("unexpected validation error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected invalid cooldown error")
  }
}

///|
test "initial response data matches framework message response shape" {
  let response = InitialResponse::message(
    content="done",
    files=[FileUpload("report.txt", b"ok", description="Result report")],
    ephemeral=true,
  )
  json_inspect(response.message_data(), content={
    "content": "done",
    "attachments": [
      { "id": 0, "filename": "report.txt", "description": "Result report" },
    ],
    "flags": 64,
  })
}

///|
test "initial response emits explicit typed allowed mentions" {
  let response = InitialResponse::message(
    content="quiet",
    allowed_mentions=@model.AllowedMentions::none(),
  )
  json_inspect(response.message_data(), content={
    "content": "quiet",
    "allowed_mentions": { "parse": [] },
  })
}

///|
test "app validates command type names and slash child structure" {
  let duplicate = App(sync=Disabled)
  let command = slash(
    name="same",
    description="Duplicate",
    args=@interaction.Args::unit(),
    handler=Raw(_ => ()),
  )
  duplicate.command(command)
  duplicate.command(command)
  try duplicate.validate() catch {
    DuplicateCommand(name~) => inspect(name, content="same")
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected duplicate command error")
  }
  let mixed = App(sync=Disabled)
  mixed.command(
    slash(
      name="shared",
      description="Slash command",
      args=@interaction.Args::unit(),
      handler=Raw(_ => ()),
    ),
  )
  mixed.command(user_command(name="shared", handler=Raw(_ => ())))
  mixed.validate()
  let duplicate_path = App(sync=Disabled)
  duplicate_path.command(
    slash_group(name="admin", description="Administrative tools", children=[
      subcommand(
        name="ping",
        description="First",
        args=@interaction.Args::unit(),
        handler=Raw(_ => ()),
      ),
      subcommand(
        name="ping",
        description="Second",
        args=@interaction.Args::unit(),
        handler=Raw(_ => ()),
      ),
    ]),
  )
  try duplicate_path.validate() catch {
    DuplicateCommandPath(command~, path~) => {
      inspect(command, content="admin")
      inspect(path, content="ping")
    }
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected duplicate path error")
  }
  let nested_group = App(sync=Disabled)
  nested_group.command(
    slash_group(name="admin", description="Administrative tools", children=[
      subcommand_group(name="outer", description="Outer group", children=[
        subcommand_group(name="inner", description="Invalid inner group", children=[]),
      ]),
    ]),
  )
  try nested_group.validate() catch {
    NestedSubcommandGroup(command~, path~) => {
      inspect(command, content="admin")
      inspect(path, content="outer/inner")
    }
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected nested group error")
  }
  let choices_and_suggest = App(sync=Disabled)
  choices_and_suggest.command(
    slash(
      name="search",
      description="Search",
      args=@interaction.Args::of(
        @interaction.arg_string(
          name="query",
          description="Query",
          choices=[@interaction.string_choice("Moon", "moon")],
          suggest=(_, value) => [@interaction.string_choice(value, value)],
        ),
      ),
      handler=Raw(_ => ()),
    ),
  )
  try choices_and_suggest.validate() catch {
    ChoicesWithAutocomplete(command~, path~) => {
      inspect(command, content="search")
      inspect(path, content="query")
    }
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected choices and autocomplete error")
  }
  let invalid_order = App(sync=Disabled)
  invalid_order.command(
    slash(
      name="ordered",
      description="Option ordering",
      args=@interaction.Args::map2(
        @interaction.arg_string(name="optional", description="Optional").optional(),
        @interaction.arg_string(name="required", description="Required"),
        (_, _) => (),
      ),
      handler=Raw(_ => ()),
    ),
  )
  try invalid_order.validate() catch {
    RequiredOptionAfterOptional(command~, path~) => {
      inspect(command, content="ordered")
      inspect(path, content="required")
    }
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected required-after-optional error")
  }
}
