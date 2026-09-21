///|
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

///|
fn copy_request(
  request : @http.PreparedHttpRequest,
) -> @http.PreparedHttpRequest {
  {
    ..request,
    headers: request.headers.copy(),
    body: request.body.map(copy_json),
    files: request.files.map(files => files.copy()),
  }
}

///|
fn copy_response(
  value : @framework.CapturedResponse,
) -> @framework.CapturedResponse {
  {
    response: try! @json.from_json(copy_json(value.response.to_json())),
    files: value.files.map(files => files.copy()),
  }
}
