///|
test "backlog warns once per overload" {
  let backlog = Backlog::new()
  backlog.queued()
  backlog.queued()
  assert_true(backlog.dropped())
  assert_false(backlog.dropped())
  backlog.taken()
  // still behind: the same overload keeps dropping silently
  assert_false(backlog.dropped())
  backlog.taken()
  // drained: the next overload warns again
  assert_true(backlog.dropped())
}

///|
test "backlog that never dropped stays quiet while draining" {
  let backlog = Backlog::new()
  backlog.queued()
  backlog.taken()
  assert_eq(backlog.queued, 0)
  assert_false(backlog.dropping)
  backlog.queued()
  assert_true(backlog.dropped())
}
