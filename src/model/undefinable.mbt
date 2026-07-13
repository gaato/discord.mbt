///|
/// A field that is always present on the wire but may be JSON `null`.
///
/// Use as a struct field type: `Nullable[T]` for "present, maybe null",
/// `Nullable[T]?` for "maybe absent, maybe null" (composes with the derived
/// `FromJson`/`ToJson` optional-field handling).
pub(all) enum Nullable[T] {
  Null
  Value(T)
} derive(Eq, Debug)

///|
pub fn[T] Nullable::to_option(self : Nullable[T]) -> T? {
  match self {
    Null => None
    Value(v) => Some(v)
  }
}

///|
pub fn[T] Nullable::from_option(opt : T?) -> Nullable[T] {
  match opt {
    None => Null
    Some(v) => Value(v)
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
    Null => Nullable::Null
    v => Nullable::Value(@json.from_json(v, path~))
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
    Null => Undefinable::Null
    v => Undefinable::Value(@json.from_json(v, path~))
  }
}
