///|
/// A value outside a limit Discord documents for an outgoing embed, message
/// component, or modal. Discord rejects the whole request with 400 Invalid
/// Form Body, so the send paths report it before any request is made.
///
/// `path` locates the value from the checked argument, such as
/// `embeds[0].fields[2].value` or `components[1].components[0].label`.
/// `custom_id` is the nearest component custom id, when there is one.
/// Lengths are `text_length` characters, like every other length check in
/// this library.
pub(all) struct LimitViolation {
  path : String
  custom_id : String?
  reason : String
} derive(Eq, Debug)

///|
/// The violation as one line: `path: reason`.
pub fn LimitViolation::message(self : LimitViolation) -> String {
  "\{self.path}: \{self.reason}"
}

///|
/// The length Discord applies its documented text limits to: Unicode code
/// points. An emoji outside the Basic Multilingual Plane is one character
/// here, though it is two UTF-16 units in a MoonBit `String`. Verified live
/// for message content, embed fields and totals, component custom ids and
/// labels, command descriptions, role names, and audit log reasons.
pub fn text_length(text : String) -> Int32 {
  text.char_length()
}

///|
/// How a limit measures text. `Utf16Units` is for a field whose counting has
/// not been verified against Discord: it never undercounts `Characters`.
priv enum TextMeasure {
  Characters
  Utf16Units
}

///|
fn TextMeasure::length(self : TextMeasure, text : String) -> Int32 {
  match self {
    Characters => text_length(text)
    Utf16Units => text.length()
  }
}

///|
fn TextMeasure::unit(self : TextMeasure) -> String {
  match self {
    Characters => "characters"
    Utf16Units => "UTF-16 units"
  }
}

///|
/// Accumulates violations while a limit table walks a value.
priv struct LimitChecker {
  violations : Array[LimitViolation]
}

///|
fn LimitChecker::new() -> LimitChecker {
  { violations: [], }
}

///|
fn LimitChecker::report(
  self : LimitChecker,
  path : String,
  reason : String,
  custom_id? : String,
) -> Unit {
  self.violations.push({ path, custom_id, reason, })
}

///|
/// Report `text` when its length under `measure` is outside `min..=max`. A
/// missing value is never a violation; check required fields by passing
/// `Some`.
fn LimitChecker::text(
  self : LimitChecker,
  path : String,
  text : String?,
  min~ : Int32 = 0,
  max~ : Int32,
  custom_id? : String,
  measure~ : TextMeasure = Characters,
) -> Unit {
  guard text is Some(text) else { return }
  let length = measure.length(text)
  if length < min || length > max {
    let bounds = if min > 0 { "\{min} to \{max}" } else { "at most \{max}" }
    self.report(path, "\{length} \{measure.unit()} (\{bounds})", custom_id?)
  }
}

///|
/// Report `count` when it is outside `min..=max`.
fn LimitChecker::count(
  self : LimitChecker,
  path : String,
  count : Int32?,
  min~ : Int32,
  max~ : Int32,
  custom_id? : String,
) -> Unit {
  if count is Some(count) && (count < min || count > max) {
    self.report(path, "\{count} (\{min} to \{max})", custom_id?)
  }
}

///|
/// Report a `min_*` that exceeds its `max_*`. `path` names the `min_*` field.
fn LimitChecker::ordered(
  self : LimitChecker,
  path : String,
  min : Int32?,
  max : Int32?,
  custom_id? : String,
) -> Unit {
  if min is Some(min) && max is Some(max) && min > max {
    self.report(path, "\{min} exceeds the maximum \{max}", custom_id?)
  }
}
