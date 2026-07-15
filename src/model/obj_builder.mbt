///|
/// Incremental JSON object builder for request bodies.
///
/// Field emission rules match Discord's PATCH semantics:
/// - `field`: always emitted
/// - `opt`: emitted only when `Some`
/// - `und`: `Missing` omitted, `Null` emitted as JSON `null`, `Value` emitted
///
/// ```mbt check
/// test "build a PATCH object with omitted and cleared fields" {
///   let nickname : String? = None
///   let avatar : @model.Undefinable[String] = Null
///   json_inspect(
///     @model.ObjBuilder()
///     .field("name", "discord.mbt")
///     .opt("nickname", nickname)
///     .und("avatar", avatar)
///     .build(),
///     content={ "name": "discord.mbt", "avatar": null },
///   )
/// }
/// ```
pub struct ObjBuilder {
  priv fields : Map[String, Json]
}

///|
/// Create an empty builder.
pub fn ObjBuilder::ObjBuilder() -> ObjBuilder {
  { fields: Map([]) }
}

///|
/// Set `key` to `value` unconditionally.
pub fn[T : ToJson] ObjBuilder::field(
  self : ObjBuilder,
  key : String,
  value : T,
) -> ObjBuilder {
  self.fields[key] = value.to_json()
  self
}

///|
/// Set `key` when `value` is present; omit the field otherwise.
pub fn[T : ToJson] ObjBuilder::opt(
  self : ObjBuilder,
  key : String,
  value : T?,
) -> ObjBuilder {
  if value is Some(v) {
    self.fields[key] = v.to_json()
  }
  self
}

///|
/// Set `key` from an `Undefinable`: a value, an explicit JSON `null`, or
/// omitted entirely when `Missing`.
pub fn[T : ToJson] ObjBuilder::und(
  self : ObjBuilder,
  key : String,
  value : Undefinable[T],
) -> ObjBuilder {
  match value {
    Missing => ()
    Null => self.fields[key] = Json::null()
    Value(v) => self.fields[key] = v.to_json()
  }
  self
}

///|
/// The accumulated JSON object.
pub fn ObjBuilder::build(self : ObjBuilder) -> Json {
  Json::object(self.fields)
}
