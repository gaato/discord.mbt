///|
/// Deep copy so a fixture never shares mutable JSON with the value it was
/// built from.
fn copy_json(value : Json) -> Json {
  match value {
    Array(values) => Json::array(values.map(copy_json))
    Object(fields) => {
      let copy = Map([])
      for key, value in fields {
        copy[key] = copy_json(value)
      }
      Json::object(copy)
    }
    _ => value
  }
}
