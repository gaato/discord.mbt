///|
/// Percent-encode a free-form value for one URL path segment or query value:
/// every byte outside RFC 3986 "unreserved" is escaped.
fn percent_encode(value : String) -> String {
  let builder = StringBuilder(size_hint=value.length())
  for byte in @utf8.encode(value).iter() {
    let value = byte.to_int()
    let unreserved = (value >= 65 && value <= 90) ||
      (value >= 97 && value <= 122) ||
      (value >= 48 && value <= 57) ||
      value == 45 ||
      value == 46 ||
      value == 95 ||
      value == 126
    if unreserved {
      builder.write_char(byte.to_char())
    } else {
      builder.write_char('%')
      builder.write_string(byte.to_hex().to_upper())
    }
  }
  builder.to_string()
}
