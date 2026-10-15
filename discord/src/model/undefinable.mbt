///|
/// A field that is always present on the wire but may be JSON `null`.
///
/// Use as a struct field type: `Nullable[T]` for "present, maybe null",
/// `Nullable[T]?` for "maybe absent, maybe null" (composes with the derived
/// `FromJson`/`ToJson` optional-field handling).
///
/// ```mbt check
/// test "convert nullable and PATCH values to options" {
///   let nickname = @model.Nullable::from_option(Some("Moon"))
///   debug_inspect(
///     nickname.to_option(),
///     content=(
///       #|Some("Moon")
///     ),
///   )
///   let missing : @model.Undefinable[String] = Missing
///   let cleared : @model.Undefinable[String] = Null
///   assert_true(missing.to_option() is None)
///   assert_true(cleared.to_option() is None)
/// }
/// ```
pub(all) enum Nullable[T] {
  Null
  Value(T)
} derive(Eq, Debug)

///|
/// `Some` for a value, `None` for JSON `null`.
pub fn[T] Nullable::to_option(self : Nullable[T]) -> T? {
  match self {
    Null => None
    Value(v) => Some(v)
  }
}

///|
/// `Value` for `Some`, `Null` for `None`.
pub fn[T] Nullable::from_option(opt : T?) -> Nullable[T] {
  match opt {
    None => Null
    Some(v) => Value(v)
  }
}

///|
/// Collapse an optional nullable field to a plain option: `None` for both an
/// absent key and JSON `null`, `Some(v)` for a present value.
///
/// This is a lossy view. Do not use it when the distinction between a missing
/// key and JSON `null` matters, such as when building PATCH bodies or merging
/// cache updates.
///
/// ```mbt check
/// test "flatten optional nullable fields" {
///   let absent : @model.Nullable[String]? = None
///   let null_value : @model.Nullable[String]? = Some(Null)
///   let present : @model.Nullable[String]? = Some(Value("Moon"))
///   debug_inspect(
///     [
///       @model.flatten(absent),
///       @model.flatten(null_value),
///       @model.flatten(present),
///     ],
///     content=(
///       #|[None, None, Some("Moon")]
///     ),
///   )
/// }
/// ```
pub fn[T] flatten(field : Nullable[T]?) -> T? {
  match field {
    Some(Value(v)) => Some(v)
    _ => None
  }
}

///|
pub impl[T : ToJson] ToJson for Nullable[T] with fn to_json(self) {
  match self {
    Null => Json::null()
    Value(v) => v.to_json()
  }
}

///|
pub impl[T : @json.FromJson] @json.FromJson for Nullable[T] with fn from_json(
  json,
  path,
) {
  match json {
    Null => Null
    v => Value(@json.from_json(v, path~))
  }
}

///|
/// Tri-state value for PATCH-style requests: leave a field untouched
/// (`Missing`, omitted from the payload), clear it (`Null`, an explicit JSON
/// `null`), or set it (`Value`).
///
/// This is an *input* type for request builders (see `ObjBuilder::und`); it is
/// not meant to appear in received models. Decoding never produces `Missing`.
pub(all) enum Undefinable[T] {
  Missing
  Null
  Value(T)
} derive(Eq, Debug)

///|
/// `Some` for a value; `None` for both JSON `null` and an absent field.
pub fn[T] Undefinable::to_option(self : Undefinable[T]) -> T? {
  match self {
    Value(v) => Some(v)
    _ => None
  }
}

///|
pub impl[T : ToJson] ToJson for Undefinable[T] with fn to_json(self) {
  match self {
    // Missing should have been omitted by the caller; encode as null as the
    // least-wrong fallback.
    Missing | Null => Json::null()
    Value(v) => v.to_json()
  }
}

///|
pub impl[T : @json.FromJson] @json.FromJson for Undefinable[T] with fn from_json(
  json,
  path,
) {
  match json {
    Null => Null
    v => Value(@json.from_json(v, path~))
  }
}
