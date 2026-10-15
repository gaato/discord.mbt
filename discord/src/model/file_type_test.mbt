///|
test "file type filters reject nonstrings with their decode path" {
  for fixture in [Json::null(), Json::number(1), Json::object(Map([]))] {
    try {
      let _ : Array[@model.FileTypeFilter] = @json.from_json([fixture])
    } catch {
      @json.JsonDecodeError((path, message)) => {
        assert_eq(path.to_string(), "/0")
        assert_eq(message, "expected a file type filter (string)")
      }
    } noraise {
      _ => fail("expected a file type decode error")
    }
  }
}
