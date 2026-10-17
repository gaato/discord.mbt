///|
/// A reader that yields `total` bytes of `b'x'`, `step` at a time.
fn chunked_reader(
  total : Int32,
  step : Int32,
) -> async (FixedArray[Byte]) -> Int32 {
  let left = Ref(total)
  fn(chunk) {
    let mut n = if left.val < step { left.val } else { step }
    if chunk.length() < n {
      n = chunk.length()
    }
    for i in 0..<n {
      chunk[i] = b'x'
    }
    left.val -= n
    n
  }
}

///|
async test "a voice message is read up to the size limit and no further" {
  guard read_bounded(chunked_reader(100, 7), 100) is Some(data) else {
    fail("a message at the limit was refused")
  }
  assert_eq(data.length(), 100)
  assert_true(read_bounded(chunked_reader(101, 7), 100) is None)
  // A reader that never ends is cut off once it passes the limit.
  assert_true(read_bounded(_ => 65536, 1_000_000) is None)
}
