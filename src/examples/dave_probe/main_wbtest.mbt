///|
test "only pre-mapping DAVE drops are classified as transient" {
  assert_true(is_transient_unmapped_sender("DAVE frame has no mapped sender"))
  assert_false(is_transient_unmapped_sender("DAVE frame has no decryptor"))
  assert_false(
    is_transient_unmapped_sender(
      "DAVE media is active but sender has no decryptor",
    ),
  )
}

///|
test "Opus frame size statistics do not inspect content" {
  assert_eq(opus_frame_size_stats([b"abc", b"12345", b"1234567"]), (3, 5, 7))
  assert_eq(opus_frame_size_stats([]), (0, 0, 0))
}

///|
test "unmapped drops correlate to the later speaking SSRC without logging it" {
  let correlation = correlate_unmapped_drops(
    [
      UnmappedDropSample::{ ssrc: 7U, at_ms: 100L, },
      UnmappedDropSample::{ ssrc: 9U, at_ms: 104L, },
      UnmappedDropSample::{ ssrc: 7U, at_ms: 108L, },
    ],
    peer_ssrc=7U,
    speaking_at_ms=112L,
  )
  assert_eq(correlation.matching, 2)
  assert_eq(correlation.other, 1)
  assert_eq(correlation.first_lead_ms, 12L)
  assert_eq(correlation.last_lead_ms, 4L)
}
