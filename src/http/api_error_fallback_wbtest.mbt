///|
/// A non-JSON error body (proxy HTML, empty reply) is carried through as a
/// JSON string by the transport layer; the Api error keeps its content
/// verbatim instead of collapsing it to `null`.
async test "non-json error bodies surface verbatim in the Api error" {
  let client = Client("test-token")
  defer client.close()
  client.perform_override_.val = Some((_route, _path, _headers, _body, _files) => {
    status: 502,
    headers: Map([]),
    body: Json::string("<html>bad gateway</html>"),
  })
  try client.get_gateway() catch {
    Api(status~, error~) => {
      inspect(status, content="502")
      inspect(error.code, content="0")
      inspect(error.message, content="HTTP 502: <html>bad gateway</html>")
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected an Api error")
  }
}

///|
/// A JSON error body that is not shaped like Discord's ApiError still
/// classifies as Api with the body stringified into the message.
async test "unshaped json error bodies fall back to a stringified message" {
  let client = Client("test-token")
  defer client.close()
  client.perform_override_.val = Some((_route, _path, _headers, _body, _files) => {
    status: 400,
    headers: Map([]),
    body: Json::null(),
  })
  try client.get_gateway() catch {
    Api(status~, error~) => {
      inspect(status, content="400")
      inspect(error.message, content="HTTP 400: null")
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected an Api error")
  }
}
