///|
test "heartbeat measures latency from the outstanding beat" {
  let heartbeat = Heartbeat::new()
  assert_false(heartbeat.awaiting_ack())
  heartbeat.beat(100)
  assert_true(heartbeat.awaiting_ack())
  assert_eq(heartbeat.ack(130), Some(30L))
  assert_false(heartbeat.awaiting_ack())
}

///|
test "heartbeat ack without an outstanding beat measures nothing" {
  let heartbeat = Heartbeat::new()
  assert_eq(heartbeat.ack(500), None)
  heartbeat.beat(100)
  assert_eq(heartbeat.ack(130), Some(30L))
  assert_eq(heartbeat.ack(160), None)
  assert_false(heartbeat.awaiting_ack())
}

///|
test "heartbeat beat before the ack restarts the clock" {
  let heartbeat = Heartbeat::new()
  heartbeat.beat(100)
  heartbeat.beat(200)
  assert_true(heartbeat.awaiting_ack())
  assert_eq(heartbeat.ack(250), Some(50L))
}
