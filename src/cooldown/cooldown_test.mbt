///|
async test "fixed window reports remaining time and recovers at expiry" {
  let clock = Ref(1_000L)
  let store = @cooldown.InMemoryCooldownStore(now=() => clock.val)
  assert_eq(store.try_acquire("user:1", window_ms=10_000L), Acquired)
  assert_eq(
    store.try_acquire("user:1", window_ms=10_000L),
    Active(retry_after_ms=10_000L),
  )
  clock.val = 5_000L
  assert_eq(
    store.try_acquire("user:1", window_ms=10_000L),
    Active(retry_after_ms=6_000L),
  )
  clock.val = 11_000L
  assert_eq(store.try_acquire("user:1", window_ms=10_000L), Acquired)
}

///|
async test "different keys have independent windows" {
  let store = @cooldown.InMemoryCooldownStore(now=() => 1_000L)
  assert_eq(store.try_acquire("guild:1", window_ms=10_000L), Acquired)
  assert_eq(store.try_acquire("global", window_ms=10_000L), Acquired)
  assert_eq(
    store.try_acquire("guild:1", window_ms=10_000L),
    Active(retry_after_ms=10_000L),
  )
  assert_eq(
    store.try_acquire("global", window_ms=10_000L),
    Active(retry_after_ms=10_000L),
  )
}

///|
async test "the default clock starts a window" {
  let store = @cooldown.InMemoryCooldownStore()
  assert_eq(store.try_acquire("global", window_ms=10_000L), Acquired)
}
