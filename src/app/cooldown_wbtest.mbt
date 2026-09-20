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
  let app = App(cooldown_store=store)
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
  let framework = middleware_test_framework(app, client)
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
  let app = App(cooldown_store=store)
  let handled = Ref(0)
  app.command(
    slash(
      name="unlimited",
      description="No cooldown",
      args=@interaction.Args::unit(),
      handler=Raw(_ => handled.val += 1),
    ),
  )
  let framework = middleware_test_framework(app, client)
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
  let app = App(cooldown_store=store)
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
      @async.sleep(1)
      assert_eq(store.calls.length(), 0)
      allowed.val
    })
    .cooldown(seconds=10, bucket=User),
  )
  let framework = middleware_test_framework(app, client)
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
    let app = App(cooldown_store=store)
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
    let framework = middleware_test_framework(app, client)
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
  let app = App(cooldown_store=store)
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
  let framework = middleware_test_framework(app, client)
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
