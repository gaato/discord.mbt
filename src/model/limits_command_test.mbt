///|
/// Limits from
/// <https://docs.discord.com/developers/interactions/application-commands>.
fn command_option(json : Json) -> @model.CommandOption raise {
  @json.from_json(json)
}

///|
fn string_option(name : String) -> @model.CommandOption raise {
  command_option({ "type": 3, "name": name, "description": "Text" })
}

///|
fn slash_violations(
  name? : String = "echo",
  description? : String = "Echo text",
  name_localizations? : Map[String, String],
  options? : Array[@model.CommandOption] = [],
) -> Array[String] {
  @model.command_limit_violations(
    typ=ChatInput,
    name~,
    name_localizations~,
    description~,
    description_localizations=None,
    options~,
  ).map(violation => violation.message())
}

///|
test "valid slash, user, and localized declarations pass" {
  assert_eq(
    slash_violations(
      name="x".repeat(32),
      description="d".repeat(100),
      options=Array::makei(25, index => string_option("o\{index}")),
    ),
    [],
  )
  // Non-ASCII letters and digits are allowed and never reported.
  assert_eq(
    slash_violations(name="日本語", name_localizations={
      "ja": "こんにちは",
    }),
    [],
  )
  // Context menu commands may be mixed case with spaces and no description.
  assert_eq(
    @model.command_limit_violations(
      typ=User,
      name="Inspect user",
      name_localizations=None,
      description="",
      description_localizations=None,
      options=[],
    ),
    [],
  )
}

///|
test "command names follow the length and naming rules" {
  assert_eq(slash_violations(name=""), ["name: 0 units (1 to 32)"])
  assert_eq(slash_violations(name="x".repeat(33)), ["name: 33 units (1 to 32)"])
  assert_eq(slash_violations(name="Echo"), [
    "name: `E` is not allowed (lowercase letters, digits, `-`, and `_`)",
  ])
  assert_eq(slash_violations(name="two words"), [
    "name: a space is not allowed (lowercase letters, digits, `-`, and `_`)",
  ])
  assert_eq(slash_violations(name_localizations={ "fr": "Écho!" }), [
    "name_localizations.fr: `!` is not allowed (lowercase letters, digits, `-`, and `_`)",
  ])
  assert_eq(slash_violations(description=""), [
    "description: 0 units (1 to 100)",
  ])
}

///|
test "options, choices, and lengths stay within their documented limits" {
  assert_eq(
    slash_violations(
      options=Array::makei(26, index => string_option("o\{index}")),
    ),
    ["options: 26 (0 to 25)"],
  )
  assert_eq(
    slash_violations(options=[string_option("text"), string_option("text")]),
    ["options[1].name: `text` repeats an earlier option name"],
  )
  let choices : Array[Json] = Array::makei(26, index => {
    "name": "c\{index}",
    "value": "v\{index}",
  })
  assert_eq(
    slash_violations(options=[
      command_option({
        "type": 3,
        "name": "pick",
        "description": "Pick one",
        "choices": Json::array(choices),
      }),
    ]),
    ["options[0].choices: 26 (0 to 25)"],
  )
  assert_eq(
    slash_violations(options=[
      command_option({
        "type": 3,
        "name": "pick",
        "description": "Pick one",
        "choices": [{ "name": "", "value": "v".repeat(101) }],
        "min_length": 6001,
        "max_length": 0,
      }),
    ]),
    [
      "options[0].choices[0].name: 0 units (1 to 100)", "options[0].choices[0].value: 101 units (at most 100)",
      "options[0].min_length: 6001 (0 to 6000)", "options[0].max_length: 0 (1 to 6000)",
    ],
  )
  // Nested subcommand options are checked with their full path.
  assert_eq(
    slash_violations(options=[
      command_option({
        "type": 1,
        "name": "run",
        "description": "Run it",
        "options": [{ "type": 3, "name": "Bad", "description": "Text" }],
      }),
    ]),
    [
      "options[0].options[0].name: `B` is not allowed (lowercase letters, digits, `-`, and `_`)",
    ],
  )
}

///|
test "a command totals at most 8000 units, counting its longest localization" {
  let wide = (index : Int) => {
    command_option({
      "type": 1,
      "name": "s\{index}",
      "description": "d".repeat(100),
      "options": Json::array(
        Array::makei(25, option => {
          "type": 3,
          "name": "o\{option}",
          "description": "d".repeat(99),
          "description_localizations": { "de": "d".repeat(100) },
        }),
      ),
    })
  }
  let violations = slash_violations(options=Array::makei(4, wide))
  assert_eq(violations.length(), 1)
  assert_true(violations[0].has_prefix("name: 10"))
  assert_true(
    violations[0].has_suffix(
      "units of names, descriptions, and choice values (at most 8000)",
    ),
  )
  assert_eq(slash_violations(options=Array::makei(2, wide)), [])
}

///|
test "localized descriptions, option names, and choice names are checked" {
  let option = command_option({
    "type": 3,
    "name": "topic",
    "description": "Topic",
    "name_localizations": { "de": "Thema Name" },
    "description_localizations": { "de": "" },
    "choices": [
      {
        "name": "Soup",
        "value": "soup",
        "name_localizations": { "de": "s".repeat(101) },
      },
    ],
  })
  let violations = @model.command_limit_violations(
    typ=ChatInput,
    name="menu",
    name_localizations=None,
    description="Menu",
    description_localizations=Some({ "de": "d".repeat(101) }),
    options=[option],
  ).map(violation => violation.message())
  debug_inspect(
    violations,
    content=(
      #|[
      #|  "description_localizations.de: 101 units (1 to 100)",
      #|  "options[0].name_localizations.de: `T` is not allowed (lowercase letters, digits, `-`, and `_`)",
      #|  "options[0].description_localizations.de: 0 units (1 to 100)",
      #|  "options[0].choices[0].name_localizations.de: 101 units (1 to 100)",
      #|]
    ),
  )
}
