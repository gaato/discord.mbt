///|
/// The result of attempting to start a cooldown window.
pub(all) enum CooldownDecision {
  Acquired
  Active(retry_after_ms~ : Int64)
} derive(Debug, Eq)

///|
/// Storage for command cooldown windows. Implementations own their clock.
pub(open) trait CooldownStore {
  /// Atomically start a window for `key`, or report the time remaining in the
  /// existing window. An active window is not extended by another attempt.
  async fn try_acquire(Self, key : String, window_ms~ : Int64) -> CooldownDecision
}

///|
/// In-process fixed windows with lazy cleanup of expired keys.
pub struct InMemoryCooldownStore {
  priv now_ : () -> Int64
  priv cooldowns_ : Map[String, Int64]
  priv mut cooldown_cleanup_after_ : Int64
}

///|
/// Create an empty store, optionally supplying a clock for deterministic tests.
///
/// ```mbt check
/// async test {
///   let store = @cooldown.InMemoryCooldownStore(now=() => 1_000L)
///   assert_eq(store.try_acquire("1:ping|global", window_ms=10_000L), Acquired)
///   assert_eq(
///     store.try_acquire("1:ping|global", window_ms=10_000L),
///     Active(retry_after_ms=10_000L),
///   )
/// }
/// ```
pub fn InMemoryCooldownStore::InMemoryCooldownStore(
  now? : () -> Int64 = @clock.now_ms,
) -> InMemoryCooldownStore {
  { now_: now, cooldowns_: Map([]), cooldown_cleanup_after_: 0L, }
}

///|
pub extend InMemoryCooldownStore with CooldownStore::{try_acquire}

///|
pub impl CooldownStore for InMemoryCooldownStore with fn try_acquire(
  self,
  key,
  window_ms~,
) {
  let now_ms = (self.now_)()
  if now_ms >= self.cooldown_cleanup_after_ {
    let expired : Array[String] = []
    for pending_key, expires_at in self.cooldowns_ {
      if expires_at <= now_ms {
        expired.push(pending_key)
      }
    }
    for pending_key in expired {
      self.cooldowns_.remove(pending_key) |> ignore
    }
    self.cooldown_cleanup_after_ = now_ms + window_ms
  }
  match self.cooldowns_.get(key) {
    Some(expires_at) if expires_at > now_ms =>
      Active(retry_after_ms=expires_at - now_ms)
    _ => {
      self.cooldowns_[key] = now_ms + window_ms
      Acquired
    }
  }
}
