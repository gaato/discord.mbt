///|
/// The limits Discord documents for an application command declaration
/// (<https://docs.discord.com/developers/interactions/application-commands>):
///
/// - command and option names are 1 to 32 units, and CHAT_INPUT command and
///   option names follow the naming rule (lowercase where a lowercase variant
///   exists, no spaces or punctuation other than `-` and `_`);
/// - CHAT_INPUT descriptions and option descriptions are 1 to 100 units;
/// - localizations follow the rules of the field they localize;
/// - each options array holds at most 25 entries with unique names;
/// - an option has at most 25 choices, whose names are 1 to 100 units and
///   whose string values are at most 100 units;
/// - `min_length` is 0 to 6000 and `max_length` is 1 to 6000;
/// - a CHAT_INPUT command's names, descriptions, and string choice values
///   total at most 8000 units, counting only the longest localization of
///   each field.
///
/// The naming rule is checked for ASCII characters only: a non-ASCII
/// character is never reported, so every reported name is certainly invalid.
pub fn command_limit_violations(
  typ~ : ApplicationCommandType,
  name~ : String,
  name_localizations~ : Map[String, String]?,
  description~ : String,
  description_localizations~ : Map[String, String]?,
  options~ : Array[CommandOption],
) -> Array[LimitViolation] {
  let checker = LimitChecker::new()
  let chat_input = typ == ChatInput
  checker.command_name("name", name, chat_input~)
  if name_localizations is Some(localized) {
    for locale, value in localized {
      checker.command_name("name_localizations.\{locale}", value, chat_input~)
    }
  }
  if chat_input {
    checker.text("description", Some(description), min=1, max=100)
    if description_localizations is Some(localized) {
      for locale, value in localized {
        checker.text(
          "description_localizations.\{locale}",
          Some(value),
          min=1,
          max=100,
        )
      }
    }
    checker.command_options("options", options)
    let total = longest_localized(name, name_localizations) +
      longest_localized(description, description_localizations) +
      options.fold(init=0, (sum, option) => sum + option_text_units(option))
    if total > 8000 {
      checker.report(
        "name",
        "\{total} units of names, descriptions, and choice values (at most 8000)",
      )
    }
  }
  checker.violations
}

///|
/// Report a command or option name outside 1 to 32 units, or one that breaks
/// the CHAT_INPUT naming rule in its ASCII characters.
fn LimitChecker::command_name(
  self : LimitChecker,
  path : String,
  name : String,
  chat_input~ : Bool,
) -> Unit {
  self.text(path, Some(name), min=1, max=32)
  guard chat_input else { return }
  for char in name {
    if char.is_whitespace() ||
      char.is_ascii_uppercase() ||
      (char.to_int() < 0x80 && !(char is ('a'..='z' | '0'..='9' | '-' | '_'))) {
      self.report(
        path,
        "\{repr_char(char)} is not allowed (lowercase letters, digits, `-`, and `_`)",
      )
      return
    }
  }
}

///|
fn repr_char(char : Char) -> String {
  if char == ' ' {
    "a space"
  } else {
    "`\{char}`"
  }
}

///|
fn nullable_map(map : Nullable[Map[String, String]]?) -> Map[String, String]? {
  match map {
    Some(Value(map)) => Some(map)
    Some(Null) | None => None
  }
}

///|
fn LimitChecker::command_options(
  self : LimitChecker,
  path : String,
  options : Array[CommandOption],
) -> Unit {
  self.count(path, Some(options.length()), min=0, max=25)
  let seen : Set[String] = Set([])
  for index, option in options {
    let option_path = "\{path}[\{index}]"
    if seen.contains(option.name) {
      self.report(
        "\{option_path}.name",
        "`\{option.name}` repeats an earlier option name",
      )
    }
    seen.add(option.name)
    self.command_name("\{option_path}.name", option.name, chat_input=true)
    if nullable_map(option.name_localizations) is Some(localized) {
      for locale, value in localized {
        self.command_name(
          "\{option_path}.name_localizations.\{locale}",
          value,
          chat_input=true,
        )
      }
    }
    self.text(
      "\{option_path}.description",
      Some(option.description),
      min=1,
      max=100,
    )
    if nullable_map(option.description_localizations) is Some(localized) {
      for locale, value in localized {
        self.text(
          "\{option_path}.description_localizations.\{locale}",
          Some(value),
          min=1,
          max=100,
        )
      }
    }
    if option.choices is Some(choices) {
      self.count(
        "\{option_path}.choices",
        Some(choices.length()),
        min=0,
        max=25,
      )
      for choice_index, choice in choices {
        let choice_path = "\{option_path}.choices[\{choice_index}]"
        self.text("\{choice_path}.name", Some(choice.name), min=1, max=100)
        if nullable_map(choice.name_localizations) is Some(localized) {
          for locale, value in localized {
            self.text(
              "\{choice_path}.name_localizations.\{locale}",
              Some(value),
              min=1,
              max=100,
            )
          }
        }
        if choice.value is String(value) {
          self.text("\{choice_path}.value", Some(value), max=100)
        }
      }
    }
    self.count("\{option_path}.min_length", option.min_length, min=0, max=6000)
    self.count("\{option_path}.max_length", option.max_length, min=1, max=6000)
    if option.options is Some(children) {
      self.command_options("\{option_path}.options", children)
    }
  }
}

///|
/// A field's contribution to the 8000-unit command total: the longest of
/// the default value and its localizations.
fn longest_localized(value : String, localized : Map[String, String]?) -> Int {
  let mut longest = value.length()
  if localized is Some(localized) {
    for _, text in localized {
      if text.length() > longest {
        longest = text.length()
      }
    }
  }
  longest
}

///|
fn option_text_units(option : CommandOption) -> Int {
  let mut total = longest_localized(
      option.name,
      nullable_map(option.name_localizations),
    ) +
    longest_localized(
      option.description,
      nullable_map(option.description_localizations),
    )
  if option.choices is Some(choices) {
    for choice in choices {
      total += longest_localized(
        choice.name,
        nullable_map(choice.name_localizations),
      )
      if choice.value is String(value) {
        total += value.length()
      }
    }
  }
  if option.options is Some(children) {
    for child in children {
      total += option_text_units(child)
    }
  }
  total
}
