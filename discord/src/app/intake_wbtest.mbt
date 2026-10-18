///|
async test "a spawner starts nothing once its intake has closed" {
  let intake = HandlerIntake()
  let limiter = @async.Semaphore(1)
  let started : Array[String] = []
  let release : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  @async.with_task_group(group => {
    let spawner = bounded_spawner(group, limiter, intake)
    spawner(() => {
      started.push("running")
      release.get()
    })
    @async.pause()
    // Waits for the permit `running` holds.
    let waiting = group.spawn(() => spawner(() => started.push("waiting")))
    @async.pause()
    intake.close()
    waiting.wait()
    // Spawning after the close returns at once, without spawning.
    spawner(() => started.push("late"))
    release.put(())
  })
  assert_eq(started, ["running"])
  assert_true(limiter.try_acquire())
}

///|
async test "a spawned task that has not started yet does not run its body" {
  let intake = HandlerIntake()
  let limiter = @async.Semaphore(1)
  let started = Ref(false)
  @async.with_task_group(group => {
    let spawner = bounded_spawner(group, limiter, intake)
    // The permit is free, so the task is spawned; it runs only after this
    // task suspends, by which time the intake has closed.
    spawner(() => started.val = true)
    intake.close()
  })
  assert_false(started.val)
  assert_true(limiter.try_acquire())
}

///|
async test "a closed intake hands no permit, and closing twice is harmless" {
  let intake = HandlerIntake()
  assert_true(intake.is_open())
  intake.close()
  intake.close()
  assert_false(intake.is_open())
  let limiter = @async.Semaphore(1)
  assert_false(intake.acquire(limiter))
  assert_true(limiter.try_acquire())
}

///|
async test "a permit handed over as the intake closes is kept and reported" {
  let intake = HandlerIntake()
  let limiter = @async.Semaphore(1)
  limiter.acquire()
  let acquired : Ref[Bool?] = Ref(None)
  @async.with_task_group(group => {
    group.spawn_bg(() => acquired.val = Some(intake.acquire(limiter)))
    @async.pause()
    // In one step: the permit goes to the waiter, then the intake closes.
    limiter.release()
    intake.close()
  })
  // Either outcome is fine as long as the result says whether a permit is
  // held: every permit is accounted for.
  match acquired.val {
    Some(true) => limiter.release()
    Some(false) => ()
    None => fail("acquire never returned")
  }
  assert_true(limiter.try_acquire())
}
