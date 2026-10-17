///|
/// `state.advance(sent~, pace_ms~)` as a comparable row.
fn advance_row(
  sequence : UInt16,
  timestamp : UInt32,
  deadline : Int64,
  sent : Bool,
  pace_ms : Int32,
) -> (UInt16, UInt32, Int64) {
  let next = SendLoopState::{ sequence, timestamp, deadline, }.advance(
    sent~,
    pace_ms~,
  )
  (next.sequence, next.timestamp, next.deadline)
}

///|
test "SendLoopState::advance steps sequence only for sent packets" {
  assert_eq(advance_row(0, 0, 1000, true, 20), (1, 960, 1020))
  // A dropped packet leaves a gap in time but not in the sequence.
  assert_eq(advance_row(7, 0, 1000, false, 20), (7, 960, 1020))
}

///|
test "SendLoopState::advance wraps both RTP counters" {
  assert_eq(advance_row(65535, 0, 0, true, 20), (0, 960, 20))
  assert_eq(advance_row(0, 0xFFFFFE00, 0, false, 20), (0, 448, 20))
}

///|
test "SendLoopState::advance keeps RTP ticks fixed whatever the pacing" {
  assert_eq(advance_row(3, 960, 1000, true, 0), (4, 1920, 1000))
  assert_eq(advance_row(3, 960, 1000, true, 60), (4, 1920, 1060))
}
