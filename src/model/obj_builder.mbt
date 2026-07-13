///|
/// Incremental JSON object builder for request bodies.
///
/// Field emission rules match Discord's PATCH semantics:
/// - `field`: always emitted
/// - `opt`: emitted only when `Some`
/// - `und`: `Missing` omitted, `Null` emitted as JSON `null`, `Value` emitted
pub struct ObjBuilder(Map[String, Json])

///|
pub fn ObjBuilder::new() -> ObjBuilder {
  ObjBuilder({})
}

///|
pub fn[T : ToJson] ObjBuilder::field(
  self : ObjBuilder,
  key : String,
  value : T,
) -> ObjBuilder {
  self.0[key] = value.to_json()
  self
}

///|
pub fn[T : ToJson] ObjBuilder::opt(
  self : ObjBuilder,
  key : String,
  value : T?,
) -> ObjBuilder {
  if value is Some(v) {
    self.0[key] = v.to_json()
  }
  self
}

///|
pub fn[T : ToJson] ObjBuilder::und(
  self : ObjBuilder,
  key : String,
  value : Undefinable[T],
) -> ObjBuilder {
  match value {
    Missing => ()
    Null => self.0[key] = Json::null()
    Value(v) => self.0[key] = v.to_json()
  }
  self
}

///|
pub fn ObjBuilder::build(self : ObjBuilder) -> Json {
  Json::object(self.0)
}
