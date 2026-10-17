///|
/// The longest request or response line either side reads. Requests carry a
/// bucket key and a few headers, responses a lease or a duration, so a longer
/// line is a broken or hostile peer, and reading on would buffer without
/// bound.
const MAX_LINE_BYTES : Int32 = 65_536

///|
/// Newline-delimited reading with a length limit. Bytes read past one line
/// stay for the next.
priv struct LineReader {
  pending : Array[Byte]
  chunk : FixedArray[Byte]
}

///|
priv enum LineRead {
  Line(String)
  /// The stream ended; an unterminated tail is dropped.
  Ended
  /// No newline within `MAX_LINE_BYTES`.
  TooLong
}

///|
fn LineReader::new() -> LineReader {
  { pending: [], chunk: FixedArray::make(4096, b'\x00'), }
}

///|
/// Whether bytes past the last line have been read.
fn LineReader::has_pending(self : LineReader) -> Bool {
  !self.pending.is_empty()
}

///|
async fn LineReader::next(
  self : LineReader,
  read : async (FixedArray[Byte]) -> Int32,
) -> LineRead {
  let mut scanned = 0
  for ;; {
    for i in scanned..<self.pending.length() {
      if self.pending[i] == b'\n' {
        // A read can carry the newline past the limit; the line still is.
        if i > MAX_LINE_BYTES {
          return TooLong
        }
        let line = Bytes::from_array(self.pending[:i])
        let rest = self.pending[i + 1:].to_owned()
        self.pending.clear()
        self.pending.append(rest)
        return Line(@utf8.decode_lossy(line))
      }
    }
    if self.pending.length() > MAX_LINE_BYTES {
      return TooLong
    }
    scanned = self.pending.length()
    let n = read(self.chunk)
    if n <= 0 {
      return Ended
    }
    for i in 0..<n {
      self.pending.push(self.chunk[i])
    }
  }
}
