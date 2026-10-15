///|
fn write_five_digits(output : StringBuilder, value : UInt64) -> Unit {
  let digits = value.to_string()
  for _ in 0..<(5 - digits.length()) {
    output.write_char('0')
  }
  output.write_string(digits)
}

///|
/// Convert a pairwise fingerprint into DAVE's standard 45-digit verification
/// code.
///
/// The input must contain at least 45 bytes. Additional fingerprint bytes are
/// intentionally ignored by the standard display-code algorithm. This
/// function only formats bytes; it does not establish their session provenance
/// or make a current-group fingerprint persistent across a session replacement
/// or reinitialization.
pub fn pairwise_verification_code(
  fingerprint : Bytes,
) -> String raise DaveError {
  if fingerprint.length() < 45 {
    raise InvalidArgument(
      operation="pairwise_verification_code",
      reason="a verification fingerprint must contain at least 45 bytes",
    )
  }
  let output = StringBuilder()
  for group in 0..<9 {
    let offset = group * 5
    let value = (fingerprint[offset].to_uint64() << 32) |
      (fingerprint[offset + 1].to_uint64() << 24) |
      (fingerprint[offset + 2].to_uint64() << 16) |
      (fingerprint[offset + 3].to_uint64() << 8) |
      fingerprint[offset + 4].to_uint64()
    write_five_digits(output, value % 100000UL)
  }
  output.to_string()
}
