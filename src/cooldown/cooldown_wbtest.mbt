///|
extend InMemoryCooldownStore with CooldownStore::{try_acquire}

///|
async test "expired keys are swept lazily" {
  let clock = Ref(1_000L)
  let store = InMemoryCooldownStore(now=() => clock.val)
  assert_eq(store.try_acquire("long", window_ms=10_000L), Acquired)
  assert_eq(store.try_acquire("short", window_ms=1_000L), Acquired)
  clock.val = 5_000L
  assert_eq(store.try_acquire("other", window_ms=20_000L), Acquired)
  assert_true(store.cooldowns_.contains("short"))
  clock.val = 11_000L
  assert_true(store.cooldowns_.contains("long"))
  assert_eq(store.try_acquire("new", window_ms=10_000L), Acquired)
  assert_false(store.cooldowns_.contains("long"))
  assert_false(store.cooldowns_.contains("short"))
  assert_eq(store.cooldowns_.length(), 2)
  assert_eq(
    store.try_acquire("other", window_ms=20_000L),
    Active(retry_after_ms=14_000L),
  )
}
