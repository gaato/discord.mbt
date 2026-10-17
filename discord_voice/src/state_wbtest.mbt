///|
test "reconnect_delay_limit doubles per attempt up to 30 seconds" {
  let table = [
    (1, 2000),
    (2, 4000),
    (4, 16000),
    (5, 30000),
    (6, 30000),
    (1000, 30000),
  ]
  for row in table {
    let (attempts, limit) = row
    assert_eq(reconnect_delay_limit(attempts), limit)
  }
}

///|
/// `close_outcome(code, closing, has_session, attempts)` as a comparable row.
fn close_row(
  code : Int32?,
  closing : Bool,
  has_session : Bool,
  attempts : Int32,
) -> (VoiceGatewayState, VoiceGatewayEvent, Int32, Bool) {
  let outcome = close_outcome(code, closing~, has_session~, attempts~)
  (outcome.state, outcome.event, outcome.attempts, outcome.stop)
}

///|
test "close_outcome stops cleanly on a local shutdown whatever the code" {
  assert_eq(
    close_row(Some(4014), true, true, 2),
    (
      Disconnected(reconnect_attempts=0),
      Disconnected(code=Some(4014), resuming=false),
      2,
      true,
    ),
  )
  assert_eq(
    close_row(None, true, false, 0),
    (
      Disconnected(reconnect_attempts=0),
      Disconnected(code=None, resuming=false),
      0,
      true,
    ),
  )
}

///|
test "close_outcome maps each reconnect policy to state, event, and backoff" {
  // Fatal keeps the failure count and stops.
  assert_eq(
    close_row(Some(4014), false, true, 2),
    (FatallyClosed(code=4014), FatallyClosed(code=4014), 2, true),
  )
  // Rejoin counts the failure and hands control back to the main gateway.
  assert_eq(
    close_row(Some(4006), false, true, 0),
    (Disconnected(reconnect_attempts=1), NeedsRejoin(code=Some(4006)), 1, true),
  )
  // Resume counts the failure and keeps looping.
  assert_eq(
    close_row(Some(4015), false, true, 3),
    (
      Disconnected(reconnect_attempts=4),
      Disconnected(code=Some(4015), resuming=true),
      4,
      false,
    ),
  )
  assert_eq(
    close_row(None, false, true, 0),
    (
      Disconnected(reconnect_attempts=1),
      Disconnected(code=None, resuming=true),
      1,
      false,
    ),
  )
  // Without a session there is nothing to resume, so it rejoins.
  assert_eq(
    close_row(Some(4015), false, false, 3),
    (Disconnected(reconnect_attempts=4), NeedsRejoin(code=Some(4015)), 4, true),
  )
  assert_eq(
    close_row(None, false, false, 0),
    (Disconnected(reconnect_attempts=1), NeedsRejoin(code=None), 1, true),
  )
}
