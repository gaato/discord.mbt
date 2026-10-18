///|
priv struct CountingCooldownStore {
  calls : Array[(String, Int64)]
}

///|
impl @cooldown.CooldownStore for CountingCooldownStore with fn try_acquire(
  self,
  key,
  window_ms~,
) {
  self.calls.push((key, window_ms))
  @cooldown.Acquired
}

///|
async test "two commands sharing one store do not collide" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let store = @cooldown.InMemoryCooldownStore(now=() => 1_000L)
  let app = AppBuilder(cooldown_store=store)
  let handled : Array[String] = []
  let retries = Ref(0)
  app.error_policy((_, error) => {
    match error {
      HandlerError::OnCooldown(retry_after_ms~) => {
        assert_eq(retry_after_ms, 10_000L)
        retries.val += 1
      }
      _ => fail("unexpected error: \{Repr(error)}")
    }
  })
  for name in ["first", "second"] {
    app.command(
      slash(
        name~,
        description="Independent command",
        args=@interaction.Args::unit(),
        handler=Raw(_ => handled.push(name)),
      ).cooldown(seconds=10, bucket=Global),
    )
  }
  let framework = middleware_test_framework(app.build(), client)
  for name in ["first", "second", "first", "second"] {
    dispatch_guard_interaction(
      framework,
      guard_dm_interaction(name, "500000000000000020"),
    )
  }
  assert_eq(handled, ["first", "second"])
  assert_eq(retries.val, 2)
}

///|
async test "commands without a cooldown never touch the store" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let store = CountingCooldownStore::{ calls: [], }
  let app = AppBuilder(cooldown_store=store)
  let handled = Ref(0)
  app.command(
    slash(
      name="unlimited",
      description="No cooldown",
      args=@interaction.Args::unit(),
      handler=Raw(_ => handled.val += 1),
    ),
  )
  let framework = middleware_test_framework(app.build(), client)
  dispatch_guard_interaction(
    framework,
    guard_dm_interaction("unlimited", "500000000000000020"),
  )
  assert_eq(handled.val, 1)
  assert_eq(store.calls.length(), 0)
}

///|
async test "cooldown store is called only after every check passes" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let store = CountingCooldownStore::{ calls: [], }
  let app = AppBuilder(cooldown_store=store)
  let allowed = Ref(false)
  let handled = Ref(0)
  app.error_policy((_, error) => {
    guard error is HandlerError::CheckFailed else {
      fail("unexpected error: \{Repr(error)}")
    }
  })
  app.command(
    slash(
      name="checked",
      description="Check before cooldown",
      args=@interaction.Args::unit(),
      handler=Raw(_ => handled.val += 1),
    )
    .check(_ => true)
    .check(_ => {
      @async.pause()
      assert_eq(store.calls.length(), 0)
      allowed.val
    })
    .cooldown(seconds=10, bucket=User),
  )
  let framework = middleware_test_framework(app.build(), client)
  dispatch_guard_interaction(
    framework,
    guard_dm_interaction("checked", "500000000000000020"),
  )
  assert_eq(store.calls.length(), 0)
  allowed.val = true
  dispatch_guard_interaction(
    framework,
    guard_dm_interaction("checked", "500000000000000021"),
  )
  assert_eq(handled.val, 1)
  assert_eq(store.calls, [("1:checked|user:200000000000000001", 10_000L)])
}

///|
async test "Apps sharing a cooldown store observe the same command window" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let store = @cooldown.InMemoryCooldownStore(now=() => 1_000L)
  let handled = Ref(0)
  let denied = Ref(0)
  for _ in 0..<2 {
    let app = AppBuilder(cooldown_store=store)
    app.command(
      slash(
        name="shared",
        description="Shared across Apps",
        args=@interaction.Args::unit(),
        handler=Raw(_ => handled.val += 1),
      ).cooldown(seconds=10, bucket=Global),
    )
    app.error_policy((_, error) => {
      guard error is HandlerError::OnCooldown(..) else {
        fail("unexpected error: \{Repr(error)}")
      }
      denied.val += 1
    })
    let framework = middleware_test_framework(app.build(), client)
    dispatch_guard_interaction(
      framework,
      guard_dm_interaction("shared", "500000000000000020"),
    )
  }
  assert_eq(handled.val, 1)
  assert_eq(denied.val, 1)
}

///|
async test "command type separates cooldown keys even with the same name" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let store = CountingCooldownStore::{ calls: [], }
  let app = AppBuilder(cooldown_store=store)
  let handled = Ref(0)
  app.command(
    slash(
      name="shared",
      description="Slash command",
      args=@interaction.Args::unit(),
      handler=Raw(_ => handled.val += 1),
    ).cooldown(seconds=10, bucket=Global),
  )
  app.command(
    user_command(name="shared", handler=Raw(_ => handled.val += 1)).cooldown(
      seconds=10,
      bucket=Global,
    ),
  )
  let framework = middleware_test_framework(app.build(), client)
  let slash_interaction = guard_dm_interaction("shared", "500000000000000020")
  guard slash_interaction.data is Some(Command(data)) else {
    fail("expected command data")
  }
  let user = slash_interaction.user.unwrap()
  let user_interaction = {
    ..slash_interaction,
    data: Some(
      Command({
        ..data,
        typ: User,
        target_id: Some(@model.Id::parse(user.id.to_string())),
        resolved: Some({
          users: Some(Map([(user.id.to_string(), user)])),
          members: None,
          roles: None,
          channels: None,
          messages: None,
          attachments: None,
        }),
      }),
    ),
  }
  dispatch_guard_interaction(framework, slash_interaction)
  dispatch_guard_interaction(framework, user_interaction)
  assert_eq(handled.val, 2)
  assert_eq(store.calls, [
    ("1:shared|global", 10_000L),
    ("2:shared|global", 10_000L),
  ])
}

///|
test "an outage starts on the first unanswered attempt and ends on an answer" {
  let cooldowns : Cooldowns = { store: None, outage: Allow, down: false, }
  let rows : Array[(Bool, Bool)] = [
    (true, false),
    (false, true),
    (false, false),
    (true, false),
    (false, true),
  ]
  for i, row in rows {
    let (answered, starts) = row
    assert_eq(cooldowns.observe(answered~), starts, msg="attempt \{i}")
  }
}

///|
/// Answers from a script; an exhausted script answers `Acquired`.
priv struct ScriptedCooldownStore {
  answers : Array[@cooldown.CooldownDecision]
}

///|
impl @cooldown.CooldownStore for ScriptedCooldownStore with fn try_acquire(
  self,
  _key,
  window_ms~,
) {
  ignore(window_ms)
  if self.answers.is_empty() {
    @cooldown.Acquired
  } else {
    self.answers.remove(0)
  }
}

///|
async test "cooldown outages follow the App's policy and warn once each" {
  for outage in [CooldownOutage::Allow, Refuse] {
    let client = @dhttp.Client("test-token")
    defer client.close()
    let store = ScriptedCooldownStore::{
      answers: [
        Unavailable(reason="down"),
        Unavailable(reason="still down"),
        Acquired,
        Unavailable(reason="down again"),
      ],
    }
    let app = AppBuilder(cooldown_store=store, cooldown_outage=outage)
    let warnings : Array[String] = []
    app.on_warn(warning => warnings.push(warning.to_string()))
    let refused : Array[Int64] = []
    app.error_policy((_, error) => {
      match error {
        HandlerError::OnCooldown(retry_after_ms~) =>
          refused.push(retry_after_ms)
        _ => fail("unexpected error: \{Repr(error)}")
      }
    })
    let handled = Ref(0)
    app.command(
      slash(
        name="limited",
        description="Shared cooldown",
        args=@interaction.Args::unit(),
        handler=Raw(_ => handled.val += 1),
      ).cooldown(seconds=10, bucket=Global),
    )
    let framework = middleware_test_framework(app.build(), client)
    for _ in 0..<4 {
      dispatch_guard_interaction(
        framework,
        guard_dm_interaction("limited", "500000000000000020"),
      )
    }
    match outage {
      Allow => {
        assert_eq(handled.val, 4)
        assert_eq(refused, [])
      }
      Refuse => {
        assert_eq(handled.val, 1)
        assert_eq(refused, [10_000L, 10_000L, 10_000L])
      }
    }
    let effect = match outage {
      Allow => "commands run without cooldowns"
      Refuse => "commands with a cooldown are refused"
    }
    assert_eq(warnings, [
      "cooldown store unavailable (down): \{effect} until it answers again",
      "cooldown store unavailable (down again): \{effect} until it answers again",
    ])
  }
}

///|
async test "the default cooldown store runs on the executor's clock" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let app = AppBuilder()
  let handled = Ref(0)
  let retries : Array[Int64] = []
  app.error_policy((_, error) => {
    match error {
      HandlerError::OnCooldown(retry_after_ms~) => retries.push(retry_after_ms)
      _ => fail("unexpected error: \{Repr(error)}")
    }
  })
  app.command(
    slash(
      name="ping",
      description="Cooled command",
      args=@interaction.Args::unit(),
      handler=Raw(_ => handled.val += 1),
    ).cooldown(seconds=10, bucket=Global),
  )
  let clock = @simclock.VirtualClock()
  @async.with_task_group(group => {
    let endpoint = app
      .build()
      .serve(
        group,
        access=Client(client),
        application_id=@model.Id::parse("400000000000000001"),
        clock~,
      )
    let ping = (id : String) => {
      endpoint.handle_interaction(wbtest_command("ping", id), deadline_ms=3000)
      |> ignore
      clock.settle()
    }
    ping("500000000000000981")
    clock.advance(4_000)
    ping("500000000000000982")
    clock.advance(6_000)
    ping("500000000000000983")
  })
  assert_eq(handled.val, 2)
  assert_eq(retries, [6_000L])
}
