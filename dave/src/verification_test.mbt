///|
test "verification code uses nine zero-padded five-digit groups" {
  let fingerprint : Array[Byte] = []
  for value in 1..<=9 {
    fingerprint.push(0)
    fingerprint.push(0)
    fingerprint.push(0)
    fingerprint.push(0)
    fingerprint.push(value.to_byte())
  }
  assert_eq(
    @dave.pairwise_verification_code(Bytes::from_array(fingerprint)),
    "000010000200003000040000500006000070000800009",
  )
}

///|
test "verification code ignores bytes after the standard 45-byte input" {
  assert_eq(
    @dave.pairwise_verification_code(Bytes::make(64, 0)),
    "000000000000000000000000000000000000000000000",
  )
}

///|
test "verification code reads each group as a big-endian 40-bit integer" {
  let fingerprint : Array[Byte] = []
  for _ in 0..<9 {
    fingerprint.push(1)
    fingerprint.push(2)
    fingerprint.push(3)
    fingerprint.push(4)
    fingerprint.push(5)
  }
  assert_eq(
    @dave.pairwise_verification_code(Bytes::from_array(fingerprint)),
    "193651936519365193651936519365193651936519365",
  )
}

///|
test "verification code rejects a short fingerprint" {
  try @dave.pairwise_verification_code(Bytes::make(44, 0)) catch {
    @dave.DaveError::InvalidArgument(operation="pairwise_verification_code", ..) =>
      ()
    _ => fail("unexpected verification error")
  } noraise {
    _ => fail("expected a short fingerprint to fail")
  }
}
