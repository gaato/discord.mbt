///|
/// Exercises the full wire-width instead of QuickCheck's size-bounded
/// built-in UInt64 generator. Sizes 0 through 7 are fixed boundary cases;
/// later sizes draw from the full UInt64 range.
priv struct WireUInt64(UInt64) derive(Debug)

///|
impl @qc.Arbitrary for WireUInt64 with fn arbitrary(size, state) {
  WireUInt64(
    match size {
      0 => 0UL
      1 => 1UL
      2 => 9007199254740991UL
      3 => 9007199254740992UL
      4 => 9007199254740993UL
      5 => 9223372036854775807UL
      6 => 9223372036854775808UL
      7 => 18446744073709551615UL
      _ => state.next_uint64()
    },
  )
}

///|
impl @qc.Shrink for WireUInt64 with fn shrink(self) {
  let WireUInt64(value) = self
  @qc.Shrink::shrink(value).map(value => WireUInt64(value))
}

///|
test "quickcheck snowflake codecs preserve the full uint64 wire value" {
  @qc.check(
    (input : WireUInt64) => {
      let WireUInt64(bits) = input
      let decimal = bits.to_string()
      let parsed : @model.UserId = @model.Id::parse(decimal)
      let from_string : @model.UserId = @json.from_json(Json::string(decimal))
      let from_number : @model.UserId = @json.from_json(@json.parse(decimal))
      let encoded_is_decimal_string = match ToJson::to_json(parsed) {
        String(value) => value == decimal
        _ => false
      }
      parsed.value() == bits &&
      from_string.value() == bits &&
      from_number.value() == bits &&
      encoded_is_decimal_string
    },
    count=256,
    max_size=255,
    max_shrinks=128,
    seed=0xD15C0D01UL,
  )
}

///|
test "quickcheck permissions preserve arbitrary bits and bit laws" {
  @qc.check(
    (input : (WireUInt64, WireUInt64)) => {
      let (WireUInt64(left_bits), WireUInt64(right_bits)) = input
      let left = @model.Permissions::from_bits(left_bits)
      let right = @model.Permissions::from_bits(right_bits)
      let encoded = ToJson::to_json(left)
      let decoded : @model.Permissions = @json.from_json(encoded)
      let encoded_is_decimal_string = match encoded {
        String(value) => value == left_bits.to_string()
        _ => false
      }
      let union = left | right
      let intersection = left & right
      left.bits() == left_bits &&
      decoded.bits() == left_bits &&
      encoded_is_decimal_string &&
      union.bits() == (left_bits | right_bits) &&
      intersection.bits() == (left_bits & right_bits) &&
      left.contains(right) == ((left_bits & right_bits) == right_bits)
    },
    count=256,
    max_size=255,
    max_shrinks=128,
    seed=0xD15C0D02UL,
  )
}
