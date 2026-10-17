///|
/// Current wall-clock time in milliseconds since the Unix epoch, as a signed
/// integer so deadline arithmetic such as `deadline - now_ms()` can go
/// negative without wrapping.
pub fn now_ms() -> Int64 {
  @env.now().reinterpret_as_int64()
}

///|
priv struct RealClock {}

///|
impl @hclock.Clock for RealClock with fn sleep(_, milliseconds) {
  @async.sleep(milliseconds)
}

///|
impl @hclock.Clock for RealClock with fn now_unix_ms(_) {
  now_ms()
}

///|
/// Run `f`, giving up after `milliseconds` on `clock`: `None` when the time
/// runs out first, in which case `f` is cancelled. The clock-driven form of
/// `@async.with_timeout_opt`.
pub async fn[X] timeout_opt(
  clock : &@hclock.Clock,
  milliseconds : Int32,
  f : async () -> X,
) -> X? {
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, () => {
      clock.sleep(milliseconds)
      group.return_immediately(None)
    })
    Some(f())
  })
}

///|
/// The production clock: `now_ms` and the event loop's timers. Components
/// take a `clock?` defaulting to this so tests can substitute virtual time.
pub fn default_clock() -> &@hclock.Clock {
  RealClock::{ }
}
