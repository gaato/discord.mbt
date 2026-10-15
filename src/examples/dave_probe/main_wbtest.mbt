///|
test "Opus frame size statistics do not inspect content" {
  assert_eq(opus_frame_size_stats([b"abc", b"12345", b"1234567"]), (3, 5, 7))
  assert_eq(opus_frame_size_stats([]), (0, 0, 0))
}
