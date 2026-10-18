///|
/// A gate whose response deadline and token lifetime the test sets directly.
fn scripted_gate(remaining : Ref[Int32?], token : Ref[Int32]) -> AdmissionGate {
  {
    remaining_ms: () => remaining.val,
    token_remaining_ms: () => token.val,
    is_pending: () => false,
    defer_now: _ => (),
  }
}

///|
fn scripted_admission(
  permits : Int32,
  clock~ : @simclock.VirtualClock = @simclock.VirtualClock(),
) -> Admission {
  {
    limiter: @async.Semaphore(permits),
    pending: 0,
    max_pending: 4,
    wait_limit_ms: 5000,
    clock,
    refusing: false,
    intake: HandlerIntake(),
  }
}

///|
async fn admit_scripted(
  admission : Admission,
  gate : AdmissionGate,
  plan : AckPlan,
  warnings : Array[AppWarning],
  ran : Ref[Bool],
) -> Unit {
  run_admitted(
    admission,
    gate,
    plan,
    warning => warnings.push(warning),
    "command:scripted",
    () => fail("refused as busy"),
    () => ran.val = true,
  )
}

///|
async test "a closed response window is not run even with a free permit" {
  let admission = scripted_admission(1)
  let warnings = []
  let ran = Ref(false)
  admit_scripted(
    admission,
    scripted_gate(Ref(Some(0)), Ref(60000)),
    Respond,
    warnings,
    ran,
  )
  assert_false(ran.val)
  assert_true(warnings is [InteractionDropped(target="command:scripted")])
  assert_true(admission.limiter.try_acquire())
}

///|
async test "an expired token is not run even with a free permit" {
  let admission = scripted_admission(1)
  let warnings = []
  let ran = Ref(false)
  admit_scripted(
    admission,
    scripted_gate(Ref(Some(0)), Ref(0)),
    DeferMessage(ephemeral=false),
    warnings,
    ran,
  )
  assert_false(ran.val)
  assert_true(
    warnings is [DeferredInteractionExpired(target="command:scripted")],
  )
  assert_eq(admission.pending, 0)
  assert_true(admission.limiter.try_acquire())
}

///|
async test "a permit handed over after the window closed is given back" {
  for plan in [Respond, DeferMessage(ephemeral=false)] {
    let clock = @simclock.VirtualClock()
    let admission = scripted_admission(1, clock~)
    admission.limiter.acquire()
    let remaining = Ref(Some(5000))
    let token = Ref(60000)
    let warnings = []
    let ran = Ref(false)
    @async.with_task_group(group => {
      group.spawn_bg(() => {
        admit_scripted(
          admission,
          scripted_gate(remaining, token),
          plan,
          warnings,
          ran,
        )
      })
      clock.settle()
      // Both windows close while the interaction waits; then the permit it
      // was waiting for is released to it.
      remaining.val = Some(0)
      token.val = 0
      admission.limiter.release()
    })
    assert_false(ran.val)
    match plan {
      Respond =>
        assert_true(warnings is [InteractionDropped(target="command:scripted")])
      _ =>
        assert_true(
          warnings is [DeferredInteractionExpired(target="command:scripted")],
        )
    }
    assert_eq(admission.pending, 0)
    assert_true(admission.limiter.try_acquire())
  }
}

///|
async test "an open window runs on a free permit and returns it" {
  for plan in [Respond, DeferMessage(ephemeral=false)] {
    let admission = scripted_admission(1)
    let warnings = []
    let ran = Ref(false)
    admit_scripted(
      admission,
      scripted_gate(Ref(Some(5000)), Ref(60000)),
      plan,
      warnings,
      ran,
    )
    assert_true(ran.val)
    assert_true(warnings is [])
    assert_true(admission.limiter.try_acquire())
  }
}

///|
fn step_label(step : AdmissionStep) -> String {
  match step {
    Stopping => "stopping"
    Refuse => "refuse"
    Deferred(wait_ms~) => "deferred: wait \{wait_ms}"
    Direct(wait_ms=Some(ms)) => "direct: wait \{ms}"
    Direct(wait_ms=None) => "direct: unbounded"
  }
}

///|
test "admission step for each plan and budget" {
  let defer_message = AckPlan::DeferMessage(ephemeral=false)
  for
    row in [
      // Responding routes are never refused and wait while the window is open.
      (false, Respond, 0, 4, Some(2000), 900000, "direct: wait 2000"),
      (false, Respond, 0, 4, None, 900000, "direct: unbounded"),
      (false, Respond, 4, 4, Some(2000), 900000, "direct: wait 2000"),
      // Deferring routes are refused once `max_pending` already wait.
      (false, defer_message, 4, 4, Some(2500), 900000, "refuse"),
      (false, defer_message, 5, 4, Some(2500), 900000, "refuse"),
      (false, defer_message, 0, 0, Some(2500), 900000, "refuse"),
      (false, DeferUpdate, 4, 4, Some(2500), 900000, "refuse"),
      // Deferring routes under the limit are admitted with a bounded wait.
      (false, defer_message, 0, 4, Some(2500), 900000, "deferred: wait 5000"),
      (false, DeferUpdate, 0, 4, None, 900000, "deferred: wait 5000"),
      // The permit wait never outlives the token.
      (false, defer_message, 0, 4, Some(2500), 3000, "deferred: wait 3000"),
      (false, defer_message, 0, 4, Some(2500), 0, "deferred: wait 0"),
      // Nothing starts once the intake has closed, whatever the budget.
      (true, Respond, 0, 4, Some(2000), 900000, "stopping"),
      (true, defer_message, 4, 4, Some(2500), 900000, "stopping"),
      (true, DeferUpdate, 0, 4, None, 0, "stopping"),
    ] {
    let (stopping, plan, pending, max_pending, remaining_ms, token_left_ms, step
    ) = row
    assert_eq(
      step_label(
        admission_step(
          plan,
          stopping~,
          pending~,
          max_pending~,
          wait_limit_ms=5000,
          remaining_ms~,
          token_left_ms~,
        ),
      ),
      step,
    )
  }
}

///|
test "auto-defer waits until the margin of the window is left" {
  for
    row in [
      (Some(2500), 1500),
      (Some(1001), 1),
      (Some(1000), 0),
      (Some(0), 0),
      (None, 0),
    ] {
    let (remaining_ms, delay) = row
    assert_eq(auto_defer_delay(remaining_ms), delay)
  }
}

///|
test "an interaction that did not start is reported by why" {
  for
    row in [
      (false, false, "dropped"),
      (false, true, "expired"),
      (true, false, "stopping"),
      (true, true, "stopping"),
    ] {
    let (stopping, deferred, expected) = row
    let label = match not_started_warning("command:x", stopping~, deferred~) {
      InteractionDropped(target="command:x") => "dropped"
      DeferredInteractionExpired(target="command:x") => "expired"
      InteractionDroppedWhileStopping(target="command:x") => "stopping"
      _ => "other"
    }
    assert_eq(label, expected)
  }
}

///|
async test "nothing starts once the intake has closed" {
  for plan in [Respond, DeferMessage(ephemeral=false)] {
    let admission = scripted_admission(1)
    admission.intake.close()
    let warnings = []
    let ran = Ref(false)
    admit_scripted(
      admission,
      scripted_gate(Ref(Some(5000)), Ref(60000)),
      plan,
      warnings,
      ran,
    )
    assert_false(ran.val)
    assert_true(
      warnings is [InteractionDroppedWhileStopping(target="command:scripted")],
    )
    assert_eq(admission.pending, 0)
    assert_true(admission.limiter.try_acquire())
  }
}

///|
async test "closing the intake drops waiting interactions at once" {
  for plan in [Respond, DeferMessage(ephemeral=false)] {
    let clock = @simclock.VirtualClock()
    let admission = scripted_admission(1, clock~)
    admission.limiter.acquire()
    let warnings = []
    let ran = Ref(false)
    let at = Ref(0L)
    @async.with_task_group(group => {
      group.spawn_bg(() => {
        admit_scripted(
          admission,
          scripted_gate(Ref(Some(5000)), Ref(60000)),
          plan,
          warnings,
          ran,
        )
        at.val = clock.now_unix_ms()
      })
      clock.settle()
      clock.advance(100)
      admission.intake.close()
      clock.settle()
      // The permit it waited for comes free only now.
      admission.limiter.release()
    })
    assert_false(ran.val)
    assert_eq(at.val, clock.now_unix_ms())
    assert_true(
      warnings is [InteractionDroppedWhileStopping(target="command:scripted")],
    )
    assert_eq(admission.pending, 0)
    assert_true(admission.limiter.try_acquire())
    assert_eq(clock.pending(), [])
  }
}
