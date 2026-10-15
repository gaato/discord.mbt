///|
test "split content handles empty, under-limit, and exact-limit input" {
  debug_inspect(@util.split_content("", limit=4), content="[]")
  debug_inspect(
    @util.split_content("abc", limit=4),
    content=(
      #|["abc"]
    ),
  )
  debug_inspect(
    @util.split_content("abcd", limit=4),
    content=(
      #|["abcd"]
    ),
  )
}

///|
test "split content counts code points and preserves surrogate pairs and CRLF" {
  debug_inspect(
    @util.split_content("abc😀def", limit=4),
    content=(
      #|["abc😀", "def"]
    ),
  )
  // Discord accepts 2000 emoji in one message: they are 2000 characters
  let emoji = "😀".repeat(2001)
  let chunks = @util.split_content(emoji)
  assert_eq(chunks.map(chunk => chunk.char_length()), [2000, 1])
  debug_inspect(
    @util.split_content("abc\r\ndef", limit=4),
    content=(
      #|["abc", "\r\n", "def"]
    ),
  )
}

///|
test "split content prefers newlines, then ASCII spaces, then hard cuts" {
  debug_inspect(
    @util.split_content("aa\nbb ccdd", limit=8),
    content=(
      #|["aa\n", "bb ccdd"]
    ),
  )
  debug_inspect(
    @util.split_content("alpha beta", limit=7),
    content=(
      #|["alpha ", "beta"]
    ),
  )
  debug_inspect(
    @util.split_content("abcdefgh", limit=3),
    content=(
      #|["abc", "def", "gh"]
    ),
  )
  debug_inspect(
    @util.split_content("abc", limit=0),
    content=(
      #|["ab", "c"]
    ),
  )
}

///|
test "split content preserves every character" {
  for
    pair in [
      ("abc😀def", 4),
      ("abc\r\ndef", 4),
      ("aa\nbb ccdd", 8),
      ("alpha beta gamma", 7),
      ("supercalifragilistic", 5),
    ] {
    let (content, limit) = pair
    let chunks = @util.split_content(content, limit~)
    assert_eq(chunks.join(""), content)
    let effective_limit = if limit < 2 { 2 } else { limit }
    assert_true(chunks.all(chunk => chunk.char_length() <= effective_limit))
  }
}
