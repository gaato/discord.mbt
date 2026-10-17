///|
/// A reader that hands out `data` in pieces of at most `step` bytes.
fn pieces(data : Bytes, step : Int32) -> async (FixedArray[Byte]) -> Int32 {
  let at = Ref(0)
  fn(chunk) {
    let mut n = data.length() - at.val
    if n > step {
      n = step
    }
    if n > chunk.length() {
      n = chunk.length()
    }
    for i in 0..<n {
      chunk[i] = data[at.val + i]
    }
    at.val += n
    n
  }
}

///|
async test "line reader splits lines, keeps the rest, and drops a tail" {
  let read = pieces(b"{\"op\":\"ping\"}\n{\"a\":1}\npartial", 5)
  let reader = LineReader::new()
  assert_true(reader.next(read) is Line("{\"op\":\"ping\"}"))
  assert_true(reader.has_pending())
  assert_true(reader.next(read) is Line("{\"a\":1}"))
  assert_true(reader.next(read) is Ended)
}

///|
async test "line reader refuses a line past the limit" {
  let at_limit = Bytes::make(MAX_LINE_BYTES, b'x') + b"\n"
  assert_true(
    LineReader::new().next(pieces(at_limit, 4096)) is Line(line) &&
    line.length() == MAX_LINE_BYTES,
  )
  // One byte over, with the newline arriving in a later read.
  let over = Bytes::make(MAX_LINE_BYTES + 1, b'x') + b"\n"
  assert_true(LineReader::new().next(pieces(over, 4096)) is TooLong)
  // A peer that streams without a newline is cut off instead of buffered.
  let endless : async (FixedArray[Byte]) -> Int32 = chunk => {
    chunk.fill(b'x')
    chunk.length()
  }
  assert_true(LineReader::new().next(endless) is TooLong)
}
