///|
fn typed_options(fixture : String) -> @interaction.CommandOptions raise {
  let data : @model.CommandData = @json.from_json(@json.parse(fixture))
  @interaction.CommandOptions::from_data(data)
}

///|
fn setup_args() -> @interaction.Args[(String, String?, Int64)] {
  @interaction.Args::map3(
    @interaction.arg_user(name="user", description="Target user"),
    @interaction.arg_string(name="note", description="Optional note").optional(),
    @interaction.arg_int(
      name="days",
      description="Number of days",
      min=0L,
      max=7L,
    ).with_default(0L),
    (user, note, days) => (user.to_string(), note, days),
  )
}

///|
fn[A] assert_suggest_preserved(args : @interaction.Args[A]) -> Unit raise {
  let definitions = args.definitions()
  inspect(definitions.length(), content="1")
  assert_true(definitions[0].autocomplete is Some(true))
  let suggestions = args.suggestions()
  inspect(suggestions.length(), content="1")
  inspect(suggestions[0].name(), content="query")
}

///|
test "typed suggestions set autocomplete and survive Arg combinators" {
  let base = @interaction.arg_string(name="query", description="Search query", suggest=(
    _,
    value,
  ) => [@interaction.string_choice(value, value)])
  json_inspect(@interaction.Args::of(base).definitions(), content=[
    {
      "type": 3,
      "name": "query",
      "description": "Search query",
      "required": true,
      "autocomplete": true,
    },
  ])
  assert_suggest_preserved(@interaction.Args::of(base))
  assert_suggest_preserved(@interaction.Args::of(base.optional()))
  assert_suggest_preserved(@interaction.Args::of(base.with_default("all")))
  assert_suggest_preserved(@interaction.Args::of(base.validate(_ => None)))
  assert_suggest_preserved(
    @interaction.Args::of(base.map(value => value.length())),
  )
}

///|
test "typed args definitions are the command registration payload" {
  json_inspect(setup_args().definitions(), content=[
    {
      "type": 6,
      "name": "user",
      "description": "Target user",
      "required": true,
    },
    {
      "type": 3,
      "name": "note",
      "description": "Optional note",
      "required": false,
    },
    {
      "type": 4,
      "name": "days",
      "description": "Number of days",
      "required": false,
      "min_value": 0,
      "max_value": 7,
    },
  ])
}

///|
test "every typed arg builder preserves localizations" {
  let name_localizations = { "ja": "ローカライズ名" }
  let description_localizations = { "ja": "ローカライズ説明" }
  let definitions = [
    @interaction.Args::of(
      @interaction.arg_string(
        name="string",
        description="String",
        name_localizations~,
        description_localizations~,
      ),
    ).definitions()[0],
    @interaction.Args::of(
      @interaction.arg_int(
        name="integer",
        description="Integer",
        name_localizations~,
        description_localizations~,
      ),
    ).definitions()[0],
    @interaction.Args::of(
      @interaction.arg_number(
        name="number",
        description="Number",
        name_localizations~,
        description_localizations~,
      ),
    ).definitions()[0],
    @interaction.Args::of(
      @interaction.arg_bool(
        name="boolean",
        description="Boolean",
        name_localizations~,
        description_localizations~,
      ),
    ).definitions()[0],
    @interaction.Args::of(
      @interaction.arg_user(
        name="user",
        description="User",
        name_localizations~,
        description_localizations~,
      ),
    ).definitions()[0],
    @interaction.Args::of(
      @interaction.arg_channel(
        name="channel",
        description="Channel",
        name_localizations~,
        description_localizations~,
      ),
    ).definitions()[0],
    @interaction.Args::of(
      @interaction.arg_role(
        name="role",
        description="Role",
        name_localizations~,
        description_localizations~,
      ),
    ).definitions()[0],
    @interaction.Args::of(
      @interaction.arg_mentionable(
        name="mentionable",
        description="Mentionable",
        name_localizations~,
        description_localizations~,
      ),
    ).definitions()[0],
    @interaction.Args::of(
      @interaction.arg_attachment(
        name="attachment",
        description="Attachment",
        name_localizations~,
        description_localizations~,
      ),
    ).definitions()[0],
  ]
  for definition in definitions {
    guard definition.name_localizations is Some(Value(names)) &&
      definition.description_localizations is Some(Value(descriptions)) else {
      fail("expected localized option definition")
    }
    assert_true(names.get("ja") == Some("ローカライズ名"))
    assert_true(descriptions.get("ja") == Some("ローカライズ説明"))
  }
}

///|
test "typed args decode present optional and defaulted values" {
  let fixture =
    #|{
    #|  "id": "107000000000000101",
    #|  "name": "schedule",
    #|  "type": 1,
    #|  "options": [
    #|    {"name": "user", "type": 6, "value": "80351110224678912"},
    #|    {"name": "note", "type": 3, "value": "hello"},
    #|    {"name": "days", "type": 4, "value": 5}
    #|  ]
    #|}
  debug_inspect(
    setup_args().decode(typed_options(fixture)),
    content=(
      #|("80351110224678912", Some("hello"), 5)
    ),
  )
}

///|
test "typed args decode missing optional and defaulted values" {
  let fixture =
    #|{
    #|  "id": "107000000000000102",
    #|  "name": "schedule",
    #|  "type": 1,
    #|  "options": [
    #|    {"name": "user", "type": 6, "value": "80351110224678912"}
    #|  ]
    #|}
  debug_inspect(
    setup_args().decode(typed_options(fixture)),
    content=(
      #|("80351110224678912", None, 0)
    ),
  )
}

///|
test "typed arg validation reports its option name and message" {
  let fixture =
    #|{
    #|  "id": "107000000000000103",
    #|  "name": "rate",
    #|  "type": 1,
    #|  "options": [
    #|    {"name": "level", "type": 4, "value": 9}
    #|  ]
    #|}
  let args = @interaction.Args::of(
    @interaction.arg_int(name="level", description="Level").validate(value => {
      if value <= 7L {
        None
      } else {
        Some("must be at most 7")
      }
    }),
  )
  try args.decode(typed_options(fixture)) catch {
    err =>
      debug_inspect(
        err,
        content=(
          #|Validation(name="level", message="must be at most 7")
        ),
      )
  } noraise {
    _ => fail("expected validation to fail")
  }
}

///|
test "unit and custom args support zero-option and escape-hatch commands" {
  let fixture =
    #|{
    #|  "id": "107000000000000104",
    #|  "name": "ping",
    #|  "type": 1,
    #|  "options": [{"name": "text", "type": 3, "value": "pong"}]
    #|}
  let options = typed_options(fixture)
  let unit = @interaction.Args::unit()
  inspect(unit.definitions().length(), content="0")
  debug_inspect(unit.decode(options), content="()")
  let custom = @interaction.Args::custom(
    definitions=[
      @interaction.string_option("text", "Response text", required=true),
    ],
    decode=options => options.string("text").length(),
  )
  json_inspect(custom.definitions(), content=[
    {
      "type": 3,
      "name": "text",
      "description": "Response text",
      "required": true,
    },
  ])
  inspect(custom.decode(options), content="4")
}

///|
test "zip and map compose nine arguments" {
  let fixture =
    #|{
    #|  "id": "107000000000000105",
    #|  "name": "sum",
    #|  "type": 1,
    #|  "options": [
    #|    {"name": "n1", "type": 4, "value": 1},
    #|    {"name": "n2", "type": 4, "value": 2},
    #|    {"name": "n3", "type": 4, "value": 3},
    #|    {"name": "n4", "type": 4, "value": 4},
    #|    {"name": "n5", "type": 4, "value": 5},
    #|    {"name": "n6", "type": 4, "value": 6},
    #|    {"name": "n7", "type": 4, "value": 7},
    #|    {"name": "n8", "type": 4, "value": 8},
    #|    {"name": "n9", "type": 4, "value": 9}
    #|  ]
    #|}
  let first_eight = @interaction.Args::map8(
    @interaction.arg_int(name="n1", description="n1"),
    @interaction.arg_int(name="n2", description="n2"),
    @interaction.arg_int(name="n3", description="n3"),
    @interaction.arg_int(name="n4", description="n4"),
    @interaction.arg_int(name="n5", description="n5"),
    @interaction.arg_int(name="n6", description="n6"),
    @interaction.arg_int(name="n7", description="n7"),
    @interaction.arg_int(name="n8", description="n8"),
    (a, b, c, d, e, f, g, h) => a + b + c + d + e + f + g + h,
  )
  let all_nine = first_eight
    .zip(
      @interaction.Args::of(@interaction.arg_int(name="n9", description="n9")),
    )
    .map(pair => pair.0 + pair.1)
  inspect(all_nine.definitions().length(), content="9")
  inspect(all_nine.decode(typed_options(fixture)), content="45")
}
