///|
fn is_ascii_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn chars_have_prefix(
  chars : Array[Char],
  start : Int,
  expected : String,
) -> Bool {
  let pattern = expected.to_array()
  if start + pattern.length() > chars.length() {
    return false
  }
  for i, c in pattern {
    if chars[start + i] != c {
      return false
    }
  }
  true
}

///|
/// Escape Discord mentions by inserting U+200B after the triggering `@`.
///
/// This neutralizes `@everyone`, `@here`, and user or role snowflake
/// mentions while leaving channel mentions unchanged.
///
/// ```mbt check
/// test "escape an everyone mention" {
///   inspect(@util.escape_mentions("@everyone"), content="@​everyone")
/// }
/// ```
pub fn escape_mentions(text : String) -> String {
  let chars = text.to_array()
  let out = StringBuilder()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    out <+ "\{c}"
    if c == '@' {
      if chars_have_prefix(chars, i + 1, "everyone") {
        out <+ "​"
      } else if chars_have_prefix(chars, i + 1, "here") {
        out <+ "​"
      } else {
        let mut cursor = i + 1
        if cursor < chars.length() &&
          (chars[cursor] == '!' || chars[cursor] == '&') {
          cursor += 1
        }
        let digits_start = cursor
        while cursor < chars.length() && is_ascii_digit(chars[cursor]) {
          cursor += 1
        }
        let digits = cursor - digits_start
        if digits >= 17 && digits <= 20 {
          out <+ "​"
        }
      }
    }
    i += 1
  }
  out.to_string()
}

///|
fn is_url_start(chars : Array[Char], index : Int) -> Bool {
  chars_have_prefix(chars, index, "http://") ||
  chars_have_prefix(chars, index, "https://") ||
  chars_have_prefix(chars, index, "steam://")
}

///|
fn is_url_end(c : Char) -> Bool {
  c == ' ' || c == '\n' || c == '\r' || c == '\t' || c == '<'
}

///|
/// Escape Discord markdown while preserving URLs and markdown links.
///
/// Backslashes, underscores, tildes, pipes, asterisks, backticks, and
/// line-leading quote markers are escaped. `http`, `https`, and `steam` URLs
/// are copied unchanged. Pycord's `as_needed` and `ignore_links` equivalent
/// parameters are not implemented.
///
/// ```mbt check
/// test "escape markdown outside URLs" {
///   inspect(
///     @util.escape_markdown("**bold** https://example.test/a_b"),
///     content="\\*\\*bold\\*\\* https://example.test/a_b",
///   )
/// }
/// ```
pub fn escape_markdown(text : String) -> String {
  let chars = text.to_array()
  let out = StringBuilder()
  let mut i = 0
  let mut line_start = true
  while i < chars.length() {
    if is_url_start(chars, i) {
      while i < chars.length() && !is_url_end(chars[i]) {
        out <+ "\{chars[i]}"
        i += 1
      }
      continue
    }
    if chars[i] == '[' {
      let mut close_text = i + 1
      while close_text < chars.length() && chars[close_text] != ']' {
        close_text += 1
      }
      if close_text + 1 < chars.length() && chars[close_text + 1] == '(' {
        let mut close_target = close_text + 2
        while close_target < chars.length() && chars[close_target] != ')' {
          close_target += 1
        }
        if close_target < chars.length() {
          out <+ "\\"
          while i <= close_target {
            out <+ "\{chars[i]}"
            i += 1
          }
          line_start = false
          continue
        }
      }
    }
    let c = chars[i]
    if line_start && c == '>' {
      let is_quote = i + 1 < chars.length() && chars[i + 1] == ' '
      let is_block_quote = i + 3 < chars.length() &&
        chars[i + 1] == '>' &&
        chars[i + 2] == '>' &&
        chars[i + 3] == ' '
      if is_quote || is_block_quote {
        out <+ "\\"
      }
    }
    if c == '_' || c == '\\' || c == '~' || c == '|' || c == '*' || c == '`' {
      out <+ "\\"
    }
    out <+ "\{c}"
    line_start = c == '\n'
    i += 1
  }
  out.to_string()
}
