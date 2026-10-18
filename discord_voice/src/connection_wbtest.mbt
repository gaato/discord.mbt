///|
async test "a closing connection records no state but Closed" {
  let transport = DaveConnectionTransport()
  let leaving : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
  let left : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
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
      leave=() => {
        leaving.put(())
        left.get()
      },
      rejoin=() => fail("unexpected rejoin"),
      connector=_ => (transport : &VoiceTransport),
      receive=false,
    )
    group.spawn_bg(() => connection.disconnect())
    leaving.get()
    // A worker that was waiting when teardown began reports what it saw.
    let states : Array[VoiceConnectionState] = [
      Ready,
      Reconnecting,
      Rejoining,
      Connecting,
    ]
    for state in states {
      connection.set_state(state)
      assert_eq(connection.state(), Closed(code=None))
    }
    connection.set_state(Closed(code=Some(4014)))
    assert_eq(connection.state(), Closed(code=Some(4014)))
    left.put(())
  })
}
