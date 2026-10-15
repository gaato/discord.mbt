///|
test "dynamic profile fields preserve absent and nonnumeric discriminators" {
  for
    fixture in [
      ({ "name": "future", "value": [1, 2] } : Json),
      { "type": "future", "value": { "enabled": true } },
      { "type": null },
    ] {
    let field : @model.ApplicationIdentityDynamicField = @json.from_json(
      fixture,
    )
    guard field is Unknown(raw) else { fail("expected an unknown field") }
    assert_eq(raw, fixture)
    let encoded = field.to_json()
    assert_eq(encoded, fixture)
    let again : @model.ApplicationIdentityDynamicField = @json.from_json(
      encoded,
    )
    assert_eq(again.to_json(), fixture)
  }
}

///|
test "dynamic profile fields reject nonobjects with their decode path" {
  for fixture in [Json::null(), Json::string("field"), Json::array([])] {
    try {
      let _ : Array[@model.ApplicationIdentityDynamicField] = @json.from_json([
        fixture,
      ])
    } catch {
      @json.JsonDecodeError((path, message)) => {
        assert_eq(path.to_string(), "/0")
        assert_eq(message, "expected a dynamic profile field (object)")
      }
    } noraise {
      _ => fail("expected a dynamic field decode error")
    }
  }
}
