///|
/// An ISO 8601 timestamp, kept as the raw string for lossless round-tripping.
/// Discord sends e.g. `2021-03-11T18:15:37.907000+00:00`.
pub(all) struct Timestamp(String) derive(Eq)

///|
pub fn Timestamp::to_string(self : Timestamp) -> String {
  self.0
}

///|
pub impl Debug for Timestamp with fn to_repr(self) {
  to_repr(self.0)
}

///|
pub impl ToJson for Timestamp with fn to_json(self) {
  Json::string(self.0)
}

///|
pub impl @json.FromJson for Timestamp with fn from_json(json, path) {
  match json {
    String(s) => Timestamp(s)
    _ => raise JsonDecodeError((path, "expected an ISO8601 timestamp"))
  }
}

///|
pub suberror TimestampError {
  InvalidTimestamp(String)
} derive(Debug)

///|
/// Parse the timestamp into milliseconds since the Unix epoch.
///
/// Supports the shapes Discord emits: `YYYY-MM-DDTHH:MM:SS[.f...](Z|±HH:MM)`.
pub fn Timestamp::unix_ms(self : Timestamp) -> Int64 raise TimestampError {
  let s = self.0
  let len = s.length()
  fn digit(i : Int) -> Int raise TimestampError {
    guard i < len && s[i] >= '0' && s[i] <= '9' else {
      raise InvalidTimestamp(s)
    }
    s[i].to_int() - 48
  }

  fn two(i : Int) -> Int raise TimestampError {
    digit(i) * 10 + digit(i + 1)
  }

  fn sep(i : Int, c : Char) -> Unit raise TimestampError {
    guard i < len && s[i].to_int() == c.to_int() else {
      raise InvalidTimestamp(s)
    }
  }

  // YYYY-MM-DDTHH:MM:SS
  guard len >= 19 else { raise InvalidTimestamp(s) }
  let year = digit(0) * 1000 + digit(1) * 100 + digit(2) * 10 + digit(3)
  sep(4, '-')
  let month = two(5)
  sep(7, '-')
  let day = two(8)
  sep(10, 'T')
  let hour = two(11)
  sep(13, ':')
  let minute = two(14)
  sep(16, ':')
  let second = two(17)

  // optional fractional seconds, scaled to milliseconds
  let mut pos = 19
  let mut millis = 0
  if pos < len && s[pos] == '.' {
    pos += 1
    let frac_start = pos
    let mut scale = 100
    while pos < len && s[pos] >= '0' && s[pos] <= '9' {
      if scale > 0 {
        millis += digit(pos) * scale
        scale /= 10
      }
      pos += 1
    }
    guard pos > frac_start else { raise InvalidTimestamp(s) }
  }

  // timezone: Z, ±HH:MM, or absent (treated as UTC)
  let offset_minutes = if pos == len {
    0
  } else if s[pos] == 'Z' || s[pos] == 'z' {
    guard pos + 1 == len else { raise InvalidTimestamp(s) }
    0
  } else if s[pos] == '+' || s[pos] == '-' {
    guard pos + 6 == len else { raise InvalidTimestamp(s) }
    sep(pos + 3, ':')
    let total = two(pos + 1) * 60 + two(pos + 4)
    if s[pos] == '-' {
      -total
    } else {
      total
    }
  } else {
    raise InvalidTimestamp(s)
  }

  // days from civil (Howard Hinnant's algorithm), all in Int
  let y = if month <= 2 { year - 1 } else { year }
  let era = (if y >= 0 { y } else { y - 399 }) / 400
  let yoe = y - era * 400
  let mp = (month + 9) % 12
  let doy = (153 * mp + 2) / 5 + day - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  let days = era * 146097 + doe - 719468
  (
    (days.to_int64() * 24L + hour.to_int64()) * 60L +
    minute.to_int64() -
    offset_minutes.to_int64()
  ) *
  60000L +
  second.to_int64() * 1000L +
  millis.to_int64()
}

///|
/// A guild/user avatar or icon hash, kept raw (e.g. `a_1269e74af4df7417b13759eae50c83dc`).
pub(all) struct ImageHash(String) derive(Eq)

///|
pub fn ImageHash::to_string(self : ImageHash) -> String {
  self.0
}

///|
/// Animated assets (GIF avatars etc.) are prefixed with `a_`.
pub fn ImageHash::is_animated(self : ImageHash) -> Bool {
  self.0 is [.. "a_", ..]
}

///|
pub impl Debug for ImageHash with fn to_repr(self) {
  to_repr(self.0)
}

///|
pub impl ToJson for ImageHash with fn to_json(self) {
  Json::string(self.0)
}

///|
pub impl @json.FromJson for ImageHash with fn from_json(json, path) {
  match json {
    String(s) => ImageHash(s)
    _ => raise JsonDecodeError((path, "expected an image hash"))
  }
}
