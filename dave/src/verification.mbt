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
  guard fingerprint
    is [
      u40be(g1),
      u40be(g2),
      u40be(g3),
      u40be(g4),
      u40be(g5),
      u40be(g6),
      u40be(g7),
      u40be(g8),
      u40be(g9),
      ..,
    ] else {
    raise InvalidArgument(
      operation="pairwise_verification_code",
      reason="a verification fingerprint must contain at least 45 bytes",
    )
  }
  let output = StringBuilder()
  for group in [g1, g2, g3, g4, g5, g6, g7, g8, g9] {
    write_five_digits(output, group % 100000UL)
  }
  output.to_string()
}
