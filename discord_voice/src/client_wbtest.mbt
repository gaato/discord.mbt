///|
priv struct PendingVoiceTransport {
  incoming : @aqueue.Queue[VoiceFrame]
  outgoing : @aqueue.Queue[Json]
  recv_started : @aqueue.Queue[Unit]
  close_calls : Ref[Int32]
}

///|
fn PendingVoiceTransport::new() -> PendingVoiceTransport {
  {
    incoming: Queue(kind=Unbounded),
    outgoing: Queue(kind=Unbounded),
    recv_started: Queue(kind=Unbounded),
    close_calls: Ref(0),
  }
}

///|
impl VoiceTransport for PendingVoiceTransport with fn recv(self) {
  self.recv_started.put(())
  self.incoming.get()
}

///|
impl VoiceTransport for PendingVoiceTransport with fn send_text(self, text) {
  self.outgoing.put(@json.parse(text))
}

///|
impl VoiceTransport for PendingVoiceTransport with fn send_binary(_self, _bytes) {

}

///|
impl VoiceTransport for PendingVoiceTransport with fn close(self, code~) {
  self.close_calls.val += 1
  self.incoming.close(
    error=VoiceTransportClosed(code=Some(code), reason="client close"),
  )
}

///|
fn test_credentials() -> VoiceCredentials {
  {
    server_id: "guild",
    session_id: "session",
    token: "token",
    endpoint: "voice.example",
  }
}

///|
fn[X] pending_connection(
  group : @async.TaskGroup[X],
  transport : PendingVoiceTransport,
  leave_calls : Ref[Int32],
) -> VoiceConnection raise {
  VoiceConnection::start(
    group,
    test_credentials(),
    user_id="100",
    channel_id=7UL,
    leave=() => leave_calls.val += 1,
    rejoin=() => test_credentials(),
    connector=_ => (transport : &VoiceTransport),
    receive=false,
  )
}

///|
async test "voice ready timeout disconnects the pending connection" {
  let transport = PendingVoiceTransport::new()
  let leave_calls = Ref(0)
  @async.with_task_group(group => {
    let connection = pending_connection(group, transport, leave_calls)
    transport.recv_started.get()
    try wait_ready_or_disconnect(connection, 10) catch {
      VoiceError::JoinTimeout => ()
      error => fail("unexpected ready-wait error: \{Repr(error)}")
    } noraise {
      _ => fail("voice ready wait unexpectedly succeeded")
    }
    assert_eq(leave_calls.val, 1)
    assert_eq(transport.close_calls.val, 1)
    assert_eq(connection.state(), Closed(code=None))
  })
}

///|
async test "voice ready cancellation disconnects the pending connection" {
  let transport = PendingVoiceTransport::new()
  let leave_calls = Ref(0)
  @async.with_task_group(group => {
    let connection = pending_connection(group, transport, leave_calls)
    transport.recv_started.get()
    let started : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
    let waiting = group.spawn(no_wait=true, allow_failure=true, () => {
      started.put(())
      wait_ready_or_disconnect(connection, 60_000)
    })
    started.get()
    waiting.cancel()
    try waiting.wait() catch {
      @async.WaitedTaskAlreadyCancelled => ()
      error => fail("unexpected ready-wait cancellation error: \{Repr(error)}")
    } noraise {
      _ => fail("cancelled voice ready wait unexpectedly completed")
    }
    assert_eq(leave_calls.val, 1)
    assert_eq(transport.close_calls.val, 1)
    assert_eq(connection.state(), Closed(code=None))
  })
}

///|
/// One expected event of the fake port; resolved once, like the bot's.
priv struct FakeExpectation[T] {
  predicate : (T) -> Bool
  queue : @aqueue.Queue[T]
}

///|
priv suberror FakeSendFailed

///|
/// A `VoiceGatewayPort` without a gateway: it records each opcode 4, can
/// fail sending it, and delivers voice events to the expectations it holds.
priv struct FakeVoicePort {
  intents : @model.Intents
  states : Array[FakeExpectation[@model.VoiceState]]
  servers : Array[FakeExpectation[@model.VoiceServerUpdateEvent]]
  sent : Array[@model.UpdateVoiceState]
  fail_send : Ref[Bool]
  // Expectations registered when the last opcode 4 was sent.
  expected_at_send : Ref[(Int32, Int32)]
  // While set, an opcode 4 that leaves waits for a value from it.
  leave_gate : Ref[@aqueue.Queue[Unit]?]
}

///|
fn FakeVoicePort::new(
  intents~ : @model.Intents = @model.Intents::guild_voice_states(),
) -> FakeVoicePort {
  {
    intents,
    states: [],
    servers: [],
    sent: [],
    fail_send: Ref(false),
    expected_at_send: Ref((0, 0)),
    leave_gate: Ref(None),
  }
}

///|
fn[T] expect_in(
  expectations : Array[FakeExpectation[T]],
  predicate : (T) -> Bool,
) -> PendingVoiceEvent[T] {
  let expectation = { predicate, queue: Queue(kind=Unbounded), }
  expectations.push(expectation)
  let cancel = () => {
    for index, pending in expectations {
      if physical_equal(pending, expectation) {
        expectations.remove(index) |> ignore
        return
      }
    }
  }
  {
    wait: timeout_ms => {
      defer cancel()
      match timeout_ms {
        Some(ms) => @async.with_timeout_opt(ms, () => expectation.queue.get())
        None => Some(expectation.queue.get())
      }
    },
    cancel,
  }
}

///|
async fn[T] deliver_to(
  expectations : Array[FakeExpectation[T]],
  event : T,
) -> Unit {
  let matched = expectations.filter(pending => (pending.predicate)(event))
  for pending in matched {
    for index, candidate in expectations {
      if physical_equal(candidate, pending) {
        expectations.remove(index) |> ignore
        break
      }
    }
    pending.queue.put(event)
  }
}

///|
fn FakeVoicePort::port(self : FakeVoicePort) -> VoiceGatewayPort {
  {
    user_id: Id(1UL),
    intents: self.intents,
    expect_voice_state: predicate => expect_in(self.states, predicate),
    expect_voice_server: predicate => expect_in(self.servers, predicate),
    update_voice_state: state => {
      self.expected_at_send.val = (self.states.length(), self.servers.length())
      if self.fail_send.val {
        raise FakeSendFailed
      }
      if state.channel_id is None && self.leave_gate.val is Some(gate) {
        gate.get()
      }
      self.sent.push(state)
    },
  }
}

///|
fn voice_state(session_id : String) -> @model.VoiceState raise {
  @json.from_json(
    @json.parse(
      (
        #|{"guild_id":"100","channel_id":"200","user_id":"1","session_id":"SESSION","deaf":false,"mute":false,"self_deaf":false,"self_mute":false,"suppress":false,"request_to_speak_timestamp":null}
      ).replace(old="SESSION", new=session_id),
    ),
  )
}

///|
fn voice_server(
  endpoint : String?,
  token : String,
) -> @model.VoiceServerUpdateEvent {
  {
    guild_id: Id(100UL),
    token,
    endpoint: match endpoint {
      Some(value) => Value(value)
      None => Null
    },
  }
}

///|
/// Run `body` with `client` running, then stop the client.
async fn with_running_client(
  client : VoiceClient,
  body : async (@async.TaskGroup[Unit]) -> Unit,
) -> Unit {
  @async.with_task_group(group => {
    let running = group.spawn(no_wait=true, allow_failure=true, () => {
      client.run()
    })
    body(group)
    running.cancel()
  })
}

///|
async test "join reuses its per-guild connection" {
  if !shim_available() {
    return
  }
  let client = VoiceClient()
  let fake = FakeVoicePort::new()
  with_running_client(client, group => {
    let voice_transport = PendingVoiceTransport::new()
    let connection = pending_connection(group, voice_transport, Ref(0))
    voice_transport.incoming.put(
      Text("{\"op\":8,\"d\":{\"heartbeat_interval\":60000}}"),
    )
    voice_transport.outgoing.get() |> ignore
    voice_transport.incoming.put(
      Text(
        "{\"op\":4,\"d\":{\"mode\":\"aead_aes256_gcm_rtpsize\",\"secret_key\":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\"dave_protocol_version\":0}}",
      ),
    )
    assert_eq(connection.next_event(), ConnectionReady)
    let guild_id : @model.GuildId = Id(100UL)
    client.connections[guild_id] = connection
    assert_true(
      physical_equal(
        client.join_via(fake.port(), guild_id, Id(200UL)),
        connection,
      ),
    )
    // The gate leaves with the last join for the guild.
    assert_true(client.join_gates.is_empty())
    assert_true(
      physical_equal(
        client.join_via(fake.port(), guild_id, Id(200UL)),
        connection,
      ),
    )
    assert_true(client.join_gates.is_empty())
    assert_eq(fake.sent.length(), 0)
    connection.disconnect()
  })
}

///|
async test "join evicts closed connections and drops its gate after send failure" {
  let client = VoiceClient()
  let fake = FakeVoicePort::new()
  with_running_client(client, group => {
    let connection = pending_connection(
      group,
      PendingVoiceTransport::new(),
      Ref(0),
    )
    connection.disconnect()
    let guild_id : @model.GuildId = Id(100UL)
    client.connections[guild_id] = connection
    fake.fail_send.val = true
    try client.join_via(fake.port(), guild_id, Id(200UL)) |> ignore catch {
      FakeSendFailed => ()
      error => fail("unexpected join error: \{Repr(error)}")
    } noraise {
      _ => fail("expected the join send to fail")
    }
    assert_eq(client.connections.length(), 0)
    assert_eq(fake.states.length(), 0)
    assert_eq(fake.servers.length(), 0)
    // A failed join leaves no gate behind either.
    assert_true(client.join_gates.is_empty())
  })
}

///|
async test "a session reset forgets the roster" {
  let client = VoiceClient()
  with_running_client(client, group => {
    let connection = pending_connection(
      group,
      PendingVoiceTransport::new(),
      Ref(0),
    )
    connection.handle_message(ClientsConnect(user_ids=["1", "2"]))
    connection.handle_message(ClientDisconnect(user_id="1"))
    assert_eq(connection.roster.to_array(), ["2"])
    connection.reset_session()
    assert_true(connection.roster.is_empty())
    connection.disconnect()
  })
}

///|
async test "a failed voice server watch stops watching and keeps the connection" {
  if !shim_available() {
    return
  }
  let client = VoiceClient()
  let fake = FakeVoicePort::new()
  let clock = @simclock.VirtualClock()
  fake_connects(client, clock) |> ignore
  with_running_client(client, group => {
    let connection = join_ready(client, fake, clock, group)
    assert_eq(fake.servers.length(), 1)
    fake.servers[0].queue.close(error=VoiceError::Disconnected)
    clock.settle()
    assert_eq(fake.servers.length(), 0)
    assert_eq(connection.state(), Ready)
    connection.disconnect()
  })
}

///|
async test "voice credentials register both expectations before opcode 4" {
  let fake = FakeVoicePort::new()
  @async.with_task_group(group => {
    let credentials = group.spawn(no_wait=true, () => {
      request_voice_credentials(
        fake.port(),
        Id(100UL),
        Id(200UL),
        false,
        true,
        500,
      )
    })
    @async.pause()
    assert_eq(fake.expected_at_send.val, (1, 1))
    debug_inspect(
      fake.sent,
      content=(
        #|[
        #|  {
        #|    guild_id: 100,
        #|    channel_id: Some(200),
        #|    self_mute: false,
        #|    self_deaf: true,
        #|  },
        #|]
      ),
    )
    // A null endpoint must not consume the server expectation.
    deliver_to(fake.servers, voice_server(None, "stale-token"))
    deliver_to(fake.states, voice_state("voice-session"))
    deliver_to(fake.servers, voice_server(Some("voice.example"), "voice-token"))
    debug_inspect(
      credentials.wait(),
      content=(
        #|{
        #|  server_id: "100",
        #|  session_id: "voice-session",
        #|  token: "voice-token",
        #|  endpoint: "voice.example",
        #|}
      ),
    )
  })
}

///|
async test "join fails before opcode 4 without the guild voice states intent" {
  let client = VoiceClient()
  let fake = FakeVoicePort::new(intents=@model.Intents::none())
  with_running_client(client, _ => {
    try client.join_via(fake.port(), Id(100UL), Id(200UL)) |> ignore catch {
      MissingIntent(intent~) => inspect(intent, content="GUILD_VOICE_STATES")
      error => fail("unexpected voice join error: \{Repr(error)}")
    } noraise {
      _ => fail("join unexpectedly succeeded")
    }
    assert_eq(fake.sent.length(), 0)
  })
}

///|
async test "join waits for run and reports a client that never runs" {
  let fake = FakeVoicePort::new()
  let clock = @simclock.VirtualClock()
  let idle = VoiceClient(clock~)
  @async.with_task_group(group => {
    let joining = group.spawn(no_wait=true, allow_failure=true, () => {
      idle.join_via(fake.port(), Id(100UL), Id(200UL), timeout_ms=10000)
    })
    clock.settle()
    assert_eq(clock.pending(), [10000])
    clock.advance(10000)
    try joining.wait() |> ignore catch {
      ClientNotRunning => ()
      error => fail("unexpected voice join error: \{Repr(error)}")
    } noraise {
      _ => fail("join unexpectedly succeeded")
    }
  })
  assert_eq(fake.sent.length(), 0)
  let client = VoiceClient()
  @async.with_task_group(group => {
    let joining = group.spawn(no_wait=true, allow_failure=true, () => {
      client.join_via(fake.port(), Id(100UL), Id(200UL), timeout_ms=1000)
    })
    @async.pause()
    assert_eq(fake.sent.length(), 0)
    let running = group.spawn(no_wait=true, allow_failure=true, () => {
      client.run()
    })
    // The join proceeds once the client runs: it sends opcode 4 and waits
    // for the voice events.
    @async.with_timeout(1000, () => {
      while fake.sent.length() == 0 {
        @async.pause()
      }
    })
    joining.cancel()
    running.cancel()
  })
}

///|
async test "voice credentials time out on a missing state or server update" {
  let fake = FakeVoicePort::new()
  try
    request_voice_credentials(
      fake.port(),
      Id(100UL),
      Id(200UL),
      false,
      false,
      10,
    )
    |> ignore
  catch {
    JoinTimeout => ()
    error => fail("unexpected error without a state update: \{Repr(error)}")
  } noraise {
    _ => fail("credentials unexpectedly arrived")
  }
  assert_eq(fake.states.length(), 0)
  assert_eq(fake.servers.length(), 0)
  @async.with_task_group(group => {
    let credentials = group.spawn(no_wait=true, allow_failure=true, () => {
      request_voice_credentials(
        fake.port(),
        Id(100UL),
        Id(200UL),
        false,
        false,
        50,
      )
    })
    @async.pause()
    deliver_to(fake.states, voice_state("voice-session"))
    try credentials.wait() |> ignore catch {
      JoinTimeout => ()
      error => fail("unexpected error without a server update: \{Repr(error)}")
    } noraise {
      _ => fail("credentials unexpectedly arrived")
    }
  })
  assert_eq(fake.servers.length(), 0)
}

///|
test "a client holds no connection until a join and attaches as a service" {
  let client = VoiceClient()
  assert_true(client.connection(Id(100UL)) is None)
  let builder = @bot.BotBuilder(@app.AppBuilder().build(), token="test-token")
  client.attach(builder)
}

///|
/// The voice transports a client's connections opened, in order.
priv struct FakeConnects {
  urls : Array[String]
  transports : Array[PendingVoiceTransport]
}

///|
/// Give `client` a virtual clock and a connector whose every transport says
/// Hello and describes a session, so each voice connection reaches Ready.
fn fake_connects(
  client : VoiceClient,
  clock : @simclock.VirtualClock,
) -> FakeConnects {
  let connects = { urls: [], transports: [], }
  client.clock_.val = clock
  client.connector_.val = url => {
    let transport = PendingVoiceTransport::new()
    transport.incoming.put(
      Text("{\"op\":8,\"d\":{\"heartbeat_interval\":60000}}"),
    )
    transport.incoming.put(
      Text(
        "{\"op\":4,\"d\":{\"mode\":\"aead_aes256_gcm_rtpsize\",\"secret_key\":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\"dave_protocol_version\":0}}",
      ),
    )
    connects.urls.push(url)
    connects.transports.push(transport)
    transport
  }
  connects
}

///|
/// Join guild 100 through `fake`, answering opcode 4 with both voice events.
async fn join_ready(
  client : VoiceClient,
  fake : FakeVoicePort,
  clock : @simclock.VirtualClock,
  group : @async.TaskGroup[Unit],
) -> VoiceConnection {
  let joining = group.spawn(no_wait=true, () => {
    client.join_via(fake.port(), Id(100UL), Id(200UL))
  })
  clock.settle()
  deliver_to(fake.states, voice_state("voice-session"))
  deliver_to(fake.servers, voice_server(Some("voice.example"), "voice-token"))
  joining.wait()
}

///|
async test "a connection's voice server watch ends with the connection" {
  if !shim_available() {
    return
  }
  for ending in ["disconnect", "fatal close"] {
    let client = VoiceClient()
    let fake = FakeVoicePort::new()
    let clock = @simclock.VirtualClock()
    let connects = fake_connects(client, clock)
    with_running_client(client, group => {
      let connection = join_ready(client, fake, clock, group)
      assert_eq(connection.state(), Ready)
      assert_eq(fake.servers.length(), 1)
      match ending {
        "disconnect" => connection.disconnect()
        _ =>
          connects.transports[0].incoming.close(
            error=VoiceTransportClosed(code=Some(4014), reason="disconnected"),
          )
      }
      clock.settle()
      assert_true(connection.state() is Closed(..))
      assert_true(client.connection(Id(100UL)) is None)
      // Nothing waits for a VOICE_SERVER_UPDATE on behalf of the old
      // connection, so nothing holds it.
      assert_eq(fake.servers.length(), 0)
    })
  }
}

///|
async test "a rejoin starts with no watch left from the previous connection" {
  if !shim_available() {
    return
  }
  let client = VoiceClient()
  let fake = FakeVoicePort::new()
  let clock = @simclock.VirtualClock()
  fake_connects(client, clock) |> ignore
  with_running_client(client, group => {
    let first = join_ready(client, fake, clock, group)
    first.disconnect()
    clock.settle()
    let second = join_ready(client, fake, clock, group)
    // The rejoin's opcode 4 went out with only its own two expectations.
    assert_eq(fake.expected_at_send.val, (1, 1))
    assert_true(!physical_equal(first, second))
    assert_eq(fake.servers.length(), 1)
  })
}

///|
async test "a voice server update moves the connection in place" {
  if !shim_available() {
    return
  }
  let client = VoiceClient()
  let fake = FakeVoicePort::new()
  let clock = @simclock.VirtualClock()
  let connects = fake_connects(client, clock)
  with_running_client(client, group => {
    let connection = join_ready(client, fake, clock, group)
    // A server that went away is not a move; the next update says where to.
    deliver_to(fake.servers, voice_server(None, "stale-token"))
    clock.settle()
    assert_eq(connects.urls.length(), 1)
    deliver_to(
      fake.servers,
      voice_server(Some("voice-new.example"), "new-token"),
    )
    clock.settle()
    assert_eq(connects.urls, [
      "wss://voice.example/?v=8", "wss://voice-new.example/?v=8",
    ])
    // The same connection identifies on the new server with the new token
    // and the session it already has; the bot never leaves the channel.
    let identify = connects.transports[1].outgoing.get()
    assert_true(
      identify
      is {
        "op": 0,
        "d": { "token": "new-token", "session_id": "voice-session", .. },
        ..
      },
    )
    assert_eq(connection.state(), Ready)
    assert_true(
      client.connection(Id(100UL)) is Some(current) &&
      physical_equal(current, connection),
    )
    assert_eq(fake.sent.length(), 1)
    // It keeps watching for the next move.
    assert_eq(fake.servers.length(), 1)
    connection.disconnect()
  })
}

///|
async test "a rejoin waits for the closed connection's leave" {
  if !shim_available() {
    return
  }
  let client = VoiceClient()
  let fake = FakeVoicePort::new()
  let clock = @simclock.VirtualClock()
  let connects = fake_connects(client, clock)
  with_running_client(client, group => {
    let first = join_ready(client, fake, clock, group)
    let gate : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
    fake.leave_gate.val = Some(gate)
    connects.transports[0].incoming.close(
      error=VoiceTransportClosed(code=Some(4014), reason="disconnected"),
    )
    clock.settle()
    assert_true(first.state() is Closed(..))
    let joining = group.spawn(no_wait=true, () => {
      client.join_via(fake.port(), Id(100UL), Id(200UL))
    })
    clock.settle()
    fake.leave_gate.val = None
    gate.put(())
    clock.settle()
    deliver_to(fake.states, voice_state("voice-session-2"))
    deliver_to(fake.servers, voice_server(Some("voice.example"), "voice-token"))
    let second = joining.wait()
    // The old connection's leave went out before the new join, not after it,
    // where it would take the bot out of the channel it just joined.
    assert_eq(fake.sent.map(state => state.channel_id), [
      Some(Id(200UL)),
      None,
      Some(Id(200UL)),
    ])
    assert_true(
      client.connection(Id(100UL)) is Some(current) &&
      physical_equal(current, second),
    )
    second.disconnect()
  })
}
