///|
test "gateway capabilities preserve unknown bits through bit operations and JSON" {
  let known = @model.GatewayCapabilities::channel_obfuscation()
  let unknown = @model.GatewayCapabilities::from_bits(1U << 31)
  let combined = known | unknown
  assert_eq(combined.bits(), 2147516416U)
  assert_true(combined.contains(known))
  assert_true(combined.contains(unknown))
  assert_true(combined.contains(@model.GatewayCapabilities::none()))
  assert_false(known.contains(unknown))
  assert_eq(combined & known, known)
  assert_eq(known & unknown, @model.GatewayCapabilities::none())
  let bits : UInt = @json.from_json(combined.to_json())
  assert_eq(@model.GatewayCapabilities::from_bits(bits), combined)
  debug_inspect(combined, content="2147516416")
}
