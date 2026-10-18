///|
/// A clock that runs `hook` in the same scheduler step as the first sleep of
/// `ms` wakes, before the sleeper resumes: a frame that arrives as a timeout
/// fires.
priv struct HookedClock {
  inner : @simclock.VirtualClock
  ms : Int32
  mut hook : (() -> Unit)?
}

///|
impl @hclock.Clock for HookedClock with fn sleep(self, milliseconds) {
  (self.inner : &@hclock.Clock).sleep(milliseconds)
  if milliseconds == self.ms && self.hook is Some(hook) {
    self.hook = None
    hook()
  }
}

///|
impl @hclock.Clock for HookedClock with fn now_unix_ms(self) {
  self.inner.now_unix_ms()
}

///|
fn silence_test_frame(sequence : Int32) -> ReceivedAudio {
  Opus(sequence~, timestamp=0U, opus=b"\xf8\xff\xfe")
}

///|
async fn with_silence_stream(
  body : async (VoiceReceiveStream, HookedClock) -> Unit,
) -> Unit {
  let clock = @simclock.VirtualClock()
  let hooked = HookedClock::{ inner: clock, ms: 200, hook: None, }
  let transport = DaveConnectionTransport()
  @async.with_task_group(group => {
    let connection = VoiceConnection::start(
      group,
      {
        server_id: "1",
        session_id: "session",
        token: "token",
        endpoint: "voice.example",
      },
      user_id="100",
      channel_id=7UL,
      leave=() => (),
      rejoin=() => fail("unexpected rejoin"),
      connector=_ => (transport : &VoiceTransport),
      receive=false,
      clock=hooked,
    )
    let stream = connection.subscribe(
      user_id="200",
      end_after_silence_ms=Some(200),
    )
    // The silence timeout runs once the first frame has been read.
    stream.deliver(silence_test_frame(1))
    assert_eq(stream.next_packet(), Some(silence_test_frame(1)))
    body(stream, hooked)
    connection.disconnect()
  })
}

///|
async test "a frame that arrives as the silence timeout fires is delivered" {
  with_silence_stream((stream, hooked) => {
    hooked.hook = Some(() => {
      stream.deliver(silence_test_frame(2)) catch {
        _ => abort("deliver failed")
      }
    })
    let reading = @async.with_task_group(group => {
      let task = group.spawn(() => stream.next_packet())
      hooked.inner.settle()
      hooked.inner.advance(200)
      task.wait()
    })
    assert_eq(reading, Some(silence_test_frame(2)))
    assert_false(stream.closed)
  })
}

///|
async test "silence with no frame still ends the stream" {
  with_silence_stream((stream, hooked) => {
    let reading = @async.with_task_group(group => {
      let task = group.spawn(() => stream.next_packet())
      hooked.inner.settle()
      hooked.inner.advance(200)
      task.wait()
    })
    assert_eq(reading, None)
    assert_true(stream.closed)
  })
}
