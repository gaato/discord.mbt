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
/// The production clock: `now_ms` and the event loop's timers. Components
/// take a `clock?` defaulting to this so tests can substitute virtual time.
pub fn default_clock() -> &@hclock.Clock {
  RealClock::{ }
}
