///|
/// A gate whose response deadline and token lifetime the test sets directly.
fn scripted_gate(remaining : Ref[Int?], token : Ref[Int]) -> AdmissionGate {
  {
    remaining_ms: () => remaining.val,
    token_remaining_ms: () => token.val,
    is_pending: () => false,
    defer_now: _ => (),
  }
}

///|
fn scripted_admission(permits : Int) -> Admission {
  {
    limiter: @async.Semaphore(permits),
    pending: 0,
    max_pending: 4,
    wait_limit_ms: 5000,
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
    let admission = scripted_admission(1)
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
      @async.sleep(10)
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
