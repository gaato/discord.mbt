///|
/// A value outside a limit Discord documents for an outgoing embed, message
/// component, or modal. Discord rejects the whole request with 400 Invalid
/// Form Body, so the send paths report it before any request is made.
///
/// `path` locates the value from the checked argument, such as
/// `embeds[0].fields[2].value` or `components[1].components[0].label`.
/// `custom_id` is the nearest component custom id, when there is one.
/// Lengths are UTF-16 units, like every other length check in this library.
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
/// Report `text` when its UTF-16 length is outside `min..=max`. A missing
/// value is never a violation; check required fields by passing `Some`.
fn LimitChecker::text(
  self : LimitChecker,
  path : String,
  text : String?,
  min? : Int = 0,
  max~ : Int,
  custom_id? : String,
) -> Unit {
  guard text is Some(text) else { return }
  let length = text.length()
  if length < min || length > max {
    let bounds = if min > 0 { "\{min} to \{max}" } else { "at most \{max}" }
    self.report(path, "\{length} units (\{bounds})", custom_id?)
  }
}

///|
/// Report `count` when it is outside `min..=max`.
fn LimitChecker::count(
  self : LimitChecker,
  path : String,
  count : Int?,
  min~ : Int,
  max~ : Int,
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
  min : Int?,
  max : Int?,
  custom_id? : String,
) -> Unit {
  if min is Some(min) && max is Some(max) && min > max {
    self.report(path, "\{min} exceeds the maximum \{max}", custom_id?)
  }
}
