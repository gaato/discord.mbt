///|
/// A Discord snowflake ID, tagged with a phantom marker type so that IDs of
/// different resources cannot be mixed up (`Id[UserMarker]` vs `Id[GuildMarker]`).
///
/// Wire format: Discord serializes snowflakes as decimal strings (and
/// historically as integers in a few places). We accept both on decode and
/// always emit a string, going through the string representation so values
/// above 2^53 never pass through a `Double`.
#warnings("-unused_type_variable")
pub(all) struct Id[M](UInt64)

///|
pub fn[M] Id::value(self : Id[M]) -> UInt64 {
  self.0
}

///|
/// Re-tag an ID with a different marker, for the few places where Discord
/// aliases ID domains (e.g. the `@everyone` role ID equals the guild ID).
pub fn[M, N] Id::cast(self : Id[M]) -> Id[N] {
  Id(self.0)
}

///|
/// Milliseconds since the Unix epoch encoded in the snowflake.
pub fn[M] Id::timestamp_ms(self : Id[M]) -> Int64 {
  (self.0 >> 22).reinterpret_as_int64() + 1420070400000L
}

///|
pub fn[M] Id::parse(s : StringView) -> Id[M] raise {
  Id(@string.parse_uint64(s))
}

///|
pub impl[M] Eq for Id[M] with fn equal(a, b) {
  a.0 == b.0
}

///|
pub impl[M] Compare for Id[M] with fn compare(a, b) {
  a.0.compare(b.0)
}

///|
pub impl[M] Hash for Id[M] with fn hash_combine(self, hasher) {
  self.0.hash_combine(hasher)
}

///|
pub impl[M] Show for Id[M] with fn output(self, logger) {
  logger.write_string(self.0.to_string())
}

///|
pub impl[M] Debug for Id[M] with fn to_repr(self) {
  to_repr(self.0)
}

///|
pub impl[M] ToJson for Id[M] with fn to_json(self) {
  Json::string(self.0.to_string())
}

///|
pub impl[M] @json.FromJson for Id[M] with fn from_json(json, path) {
  match json {
    String(s) =>
      Id(
        @string.parse_uint64(s) catch {
          _ =>
            raise JsonDecodeError(
              (path, "expected a snowflake (decimal string), got \{s}"),
            )
        },
      )
    Number(_, repr=Some(r)) =>
      // integer form: parse the original decimal text, not the Double,
      // so values above 2^53 keep full precision
      Id(
        @string.parse_uint64(r.to_string()) catch {
          _ =>
            raise JsonDecodeError(
              (path, "expected a snowflake (integer), got \{r}"),
            )
        },
      )
    Number(n, repr=None) => Id(n.to_uint64())
    _ => raise JsonDecodeError((path, "expected a snowflake"))
  }
}
