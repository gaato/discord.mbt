///|
async test "timeout_opt runs on the given clock" {
  let clock = @simclock.VirtualClock()
  let release : @aqueue.Queue[Int32] = Queue(kind=Unbounded)
  @async.with_task_group(group => {
    let late = group.spawn(() => {
      @clock.timeout_opt(clock, 100, () => release.get())
    })
    let early = group.spawn(() => @clock.timeout_opt(clock, 100, () => 7))
    clock.advance(99)
    assert_eq(early.wait(), Some(7))
    clock.advance(1)
    assert_eq(late.wait(), None)
  })
}
