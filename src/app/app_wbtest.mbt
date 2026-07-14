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
test "initial response data matches framework message response shape" {
  let response = InitialResponse::message(
    content="done",
    files=[
      @dhttp.FileUpload::new("report.txt", b"ok", description="Result report"),
    ],
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
  let duplicate = App::new(sync=Disabled)
  let command = slash(
    name="same",
    description="Duplicate",
    args=@interaction.Args::unit(),
    handler=Raw(_ => ()),
  )
  duplicate.command(command)
  duplicate.command(command)
  try duplicate.validate() catch {
    AppConfigError::DuplicateCommand(name~) => inspect(name, content="same")
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected duplicate command error")
  }
  let mixed = App::new(sync=Disabled)
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
  let duplicate_path = App::new(sync=Disabled)
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
    AppConfigError::DuplicateCommandPath(command~, path~) => {
      inspect(command, content="admin")
      inspect(path, content="ping")
    }
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected duplicate path error")
  }
  let nested_group = App::new(sync=Disabled)
  nested_group.command(
    slash_group(name="admin", description="Administrative tools", children=[
      subcommand_group(name="outer", description="Outer group", children=[
        subcommand_group(name="inner", description="Invalid inner group", children=[]),
      ]),
    ]),
  )
  try nested_group.validate() catch {
    AppConfigError::NestedSubcommandGroup(command~, path~) => {
      inspect(command, content="admin")
      inspect(path, content="outer/inner")
    }
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected nested group error")
  }
  let choices_and_suggest = App::new(sync=Disabled)
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
    AppConfigError::ChoicesWithAutocomplete(command~, path~) => {
      inspect(command, content="search")
      inspect(path, content="query")
    }
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected choices and autocomplete error")
  }
  let invalid_order = App::new(sync=Disabled)
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
    AppConfigError::RequiredOptionAfterOptional(command~, path~) => {
      inspect(command, content="ordered")
      inspect(path, content="required")
    }
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected required-after-optional error")
  }
}
