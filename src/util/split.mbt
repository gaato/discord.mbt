///|
/// Split message content into chunks of at most `limit` UTF-16 code units.
///
/// Discord limits bot message content to 2000 UTF-16 code units, which is the
/// default limit. The effective limit is clamped to at least 2. Empty content
/// produces no chunks.
///
/// Splits prefer the position immediately after the last newline in the
/// current window, then the position after the last ASCII space, and finally
/// a hard cut. A hard cut moves back one code unit rather than splitting a
/// surrogate pair or CRLF sequence. No content is discarded, so
/// `chunks.join("") == content` always holds.
///
/// ```mbt check
/// test "split and restore message content" {
///   let content = "hello world"
///   let chunks = @util.split_content(content, limit=6)
///   debug_inspect(
///     chunks,
///     content=(
///       #|["hello ", "world"]
///     ),
///   )
///   assert_eq(chunks.join(""), content)
/// }
/// ```
pub fn split_content(content : String, limit? : Int = 2000) -> Array[String] {
  if content.is_empty() {
    return []
  }
  let limit = if limit < 2 { 2 } else { limit }
  let chunks = []
  let length = content.length()
  let mut start = 0
  while start < length {
    if length - start <= limit {
      chunks.push(content.unsafe_substring(start~, end=length))
      break
    }
    let window_end = start + limit
    let mut last_newline = None
    let mut last_space = None
    for i in start..<window_end {
      if content[i] == '\n' {
        last_newline = Some(i + 1)
      } else if content[i] == ' ' {
        last_space = Some(i + 1)
      }
    }
    let mut cut = match last_newline {
      Some(index) => index
      None => last_space.unwrap_or(window_end)
    }
    if cut == window_end {
      if content[cut - 1].is_leading_surrogate() &&
        content[cut].is_trailing_surrogate() {
        cut -= 1
      } else if content[cut - 1] == '\r' && content[cut] == '\n' {
        cut -= 1
      }
    }
    chunks.push(content.unsafe_substring(start~, end=cut))
    start = cut
  }
  chunks
}
