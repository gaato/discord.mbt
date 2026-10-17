///|
/// The result of attempting to start a cooldown window.
pub(all) enum CooldownDecision {
  Acquired
  Active(retry_after_ms~ : Int64)
  /// The store could not answer, for example because a shared store's server
  /// is unreachable. The App decides whether the command runs (see
  /// `AppBuilder(cooldown_outage~)`) and reports the outage.
  Unavailable(reason~ : String)
} derive(Debug, Eq)

///|
/// Storage for command cooldown windows. Implementations own their clock.
pub(open) trait CooldownStore {
  /// Atomically start a window for `key`, or report the time remaining in the
  /// existing window. An active window is not extended by another attempt.
  async fn try_acquire(Self, key : String, window_ms~ : Int64) -> CooldownDecision
}

///|
/// In-process fixed windows. Expired keys are swept each time the map has
/// doubled since the last sweep, so memory follows the live windows however
/// long or short they are.
pub struct InMemoryCooldownStore {
  priv now_ : () -> Int64
  priv cooldowns_ : Map[String, Int64]
  priv mut sweep_at_ : Int32
}

///|
/// The fewest keys at which a sweep runs.
let cooldown_sweep_floor : Int32 = 64

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
  now~ : () -> Int64 = @clock.now_ms,
) -> InMemoryCooldownStore {
  { now_: now, cooldowns_: Map([]), sweep_at_: cooldown_sweep_floor, }
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
  if self.cooldowns_.length() >= self.sweep_at_ {
    let expired : Array[String] = []
    for pending_key, expires_at in self.cooldowns_ {
      if expires_at <= now_ms {
        expired.push(pending_key)
      }
    }
    for pending_key in expired {
      self.cooldowns_.remove(pending_key) |> ignore
    }
    self.sweep_at_ = (self.cooldowns_.length() * 2).max(cooldown_sweep_floor)
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
