///|
test "ms until a deadline clamps at zero and the largest Int32" {
  let now = 1_700_000_000_000L
  for
    row in [
      (100L, 40L, 60),
      (100L, 100L, 0),
      (100L, 150L, 0),
      (now + 2147483646L, now, 2147483646),
      (now + 2147483647L, now, 2147483647),
      (now + 2147483648L, now, 2147483647),
    ] {
    let (deadline, at, left) = row
    assert_eq(ms_until(deadline, at), left)
  }
}
