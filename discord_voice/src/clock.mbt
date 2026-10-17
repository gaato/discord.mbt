///|
/// The production clock: wall-clock time and the event loop's timers.
/// `VoiceGateway::start` and `VoiceConnection::start` take a `clock?`
/// defaulting to this so tests can substitute virtual time.
priv struct RealClock {}

///|
impl @hclock.Clock for RealClock with fn sleep(_, milliseconds) {
  @async.sleep(milliseconds)
}

///|
impl @hclock.Clock for RealClock with fn now_unix_ms(_) {
  @env.now().reinterpret_as_int64()
}

///|
fn default_clock() -> &@hclock.Clock {
  RealClock::{ }
}

///|
/// Run `f`, giving up after `milliseconds` on `clock`: `None` when the time
/// runs out first, in which case `f` is cancelled. The clock-driven form of
/// `@async.with_timeout_opt`.
async fn[X] timeout_opt(
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
