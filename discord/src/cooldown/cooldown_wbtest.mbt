///|
async test "a long window does not hold back sweeping short ones" {
  let clock = Ref(0L)
  let store = InMemoryCooldownStore(now=() => clock.val)
  assert_eq(store.try_acquire("daily", window_ms=86_400_000L), Acquired)
  let mut largest = 0
  for i in 0..<10_000 {
    clock.val += 100L
    assert_eq(store.try_acquire("user:\{i}", window_ms=1_000L), Acquired)
    largest = largest.max(store.cooldowns_.length())
  }
  // About ten short windows are live at any time, plus the daily one.
  assert_true(largest <= 128, msg="largest=\{largest}")
  assert_true(store.cooldowns_.contains("daily"))
  assert_eq(
    store.try_acquire("daily", window_ms=86_400_000L),
    Active(retry_after_ms=86_400_000L - 1_000_000L),
  )
}

///|
async test "a burst's expired keys go once traffic settles on one key" {
  let clock = Ref(0L)
  let store = InMemoryCooldownStore(now=() => clock.val)
  for i in 0..<100 {
    assert_eq(store.try_acquire("user:\{i}", window_ms=1_000L), Acquired)
  }
  // The doubling sweep at 64 kept the live keys, so the next one waits for
  // 128 entries, which traffic on one key never reaches.
  assert_true(store.cooldowns_.length() >= 64)
  for _ in 0..<70 {
    clock.val += 1_000L
    store.try_acquire("steady", window_ms=1_000L) |> ignore
  }
  assert_eq(store.cooldowns_.length(), 1)
}
