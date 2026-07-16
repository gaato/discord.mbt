///|
/// Raises `Validation` when an optional string's UTF-16 length falls outside
/// `min..=max`. Pass `Some(value)` to validate a required string.
fn validate_length(
  field : String,
  value : String?,
  min? : Int = 0,
  max~ : Int,
) -> Unit raise DiscordHttpError {
  if value is Some(v) && (v.length() < min || v.length() > max) {
    if min > 0 {
      raise Validation(
        message="\{field} must be between \{min} and \{max} characters",
      )
    } else {
      raise Validation(message="\{field} exceeds \{max} characters")
    }
  }
}

///|
/// Raises `Validation` when an optional integer falls outside `min..=max`.
fn validate_range(
  field : String,
  value : Int?,
  min~ : Int,
  max~ : Int,
) -> Unit raise DiscordHttpError {
  if value is Some(v) && (v < min || v > max) {
    raise Validation(message="\{field} must be between \{min} and \{max}")
  }
}

///|
/// Bots may send at most 2000 UTF-16 units of message content;
/// the 4000-character limit only applies to Nitro users.
fn validate_content(content : String?) -> Unit raise DiscordHttpError {
  validate_length("content", content, max=2000)
}
