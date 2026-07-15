///|
fn hex_nibble(code : UInt16) -> Byte? {
  if code >= '0' && code <= '9' {
    Some((code - '0').to_byte())
  } else if code >= 'a' && code <= 'f' {
    Some((code - 'a' + 10).to_byte())
  } else if code >= 'A' && code <= 'F' {
    Some((code - 'A' + 10).to_byte())
  } else {
    None
  }
}

///|
#warnings("-unused_value")
fn decode_hex(input : String) -> Bytes? {
  guard input.length() % 2 == 0 else { return None }
  let decoded = Array::make(input.length() / 2, b'\x00')
  for i in 0..<decoded.length() {
    guard hex_nibble(input[i * 2]) is Some(high) else { return None }
    guard hex_nibble(input[i * 2 + 1]) is Some(low) else { return None }
    decoded[i] = (high << 4) | low
  }
  Some(Bytes::from_array(decoded))
}
