///|
test "dynamic profile payload helper preserves nonobject fallbacks" {
  for payload in [Json::null(), Json::string("future"), Json::array([])] {
    assert_eq(application_identity_dynamic_field_payload(payload, 1), payload)
  }
}
