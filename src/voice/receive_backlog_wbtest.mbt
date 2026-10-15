///|
fn backlog_test_opus(sequence : Int32) -> ReceivedAudio {
  Opus(
    sequence~,
    timestamp=(sequence * 960).reinterpret_as_uint(),
    opus=b"opus",
  )
}

///|
async test "a full receive stream drops new frames and reports them as Lost" {
  let transport = DaveConnectionTransport()
  let telemetry : Array[VoiceTelemetry] = []
  @async.with_task_group(group => {
    let connection = dave_test_connection(group, transport, telemetry)
    let stream = connection.subscribe(user_id="200", backlog=2)
    for sequence in 1..<=5 {
      connection.deliver_audio("200", backlog_test_opus(sequence))
    }
    assert_eq(
      telemetry.filter(event => event is ReceiveDropped(..)),
      Array::make(3, ReceiveDropped(user_id="200", backlog=2)),
    )
    assert_eq(stream.next_packet(), Some(backlog_test_opus(1)))
    assert_eq(stream.next_packet(), Some(backlog_test_opus(2)))
    // a reorder-buffer gap folds into the pending count
    connection.deliver_audio("200", Lost(count=2))
    connection.deliver_audio("200", backlog_test_opus(8))
    assert_eq(stream.next_packet(), Some(Lost(count=5)))
    assert_eq(stream.next_packet(), Some(backlog_test_opus(8)))
    connection.disconnect()
  })
}

///|
async test "a receive stream nobody reads stays within its backlog" {
  let transport = DaveConnectionTransport()
  let telemetry : Array[VoiceTelemetry] = []
  @async.with_task_group(group => {
    let connection = dave_test_connection(group, transport, telemetry)
    let stream = connection.subscribe(user_id="200")
    for sequence in 0..<10000 {
      connection.deliver_audio("200", backlog_test_opus(sequence))
    }
    let dropped = 10000 - DEFAULT_RECEIVE_BACKLOG
    assert_eq(
      telemetry.filter(event => event is ReceiveDropped(..)).length(),
      dropped,
    )
    for sequence in 0..<DEFAULT_RECEIVE_BACKLOG {
      assert_eq(stream.next_packet(), Some(backlog_test_opus(sequence)))
    }
    connection.deliver_audio("200", backlog_test_opus(10000))
    assert_eq(stream.next_packet(), Some(Lost(count=dropped)))
    assert_eq(stream.next_packet(), Some(backlog_test_opus(10000)))
    connection.disconnect()
  })
}

///|
async test "unread voice events keep only the newest backlog" {
  let transport = DaveConnectionTransport()
  let telemetry : Array[VoiceTelemetry] = []
  @async.with_task_group(group => {
    let connection = dave_test_connection(group, transport, telemetry)
    for index in 0..<(DEFAULT_VOICE_EVENT_BACKLOG + 10) {
      connection.emit(UserConnected(user_id=index.to_string()))
    }
    assert_eq(
      telemetry.filter(event => event is EventDropped(..)),
      Array::make(10, EventDropped(backlog=DEFAULT_VOICE_EVENT_BACKLOG)),
    )
    assert_eq(connection.next_event(), UserConnected(user_id="10"))
    connection.disconnect()
  })
}

///|
async test "voice backlogs below one are rejected" {
  let transport = DaveConnectionTransport()
  @async.with_task_group(group => {
    let connection = dave_test_connection(group, transport, [])
    for backlog in [0, -1] {
      try connection.subscribe(user_id="200", backlog~) catch {
        InvalidBacklog(value~) => assert_eq(value, backlog)
        error => fail("unexpected error: \{Repr(error)}")
      } noraise {
        _ => fail("expected InvalidBacklog")
      }
    }
    assert_eq(connection.subscriptions.length(), 0)
    try
      VoiceConnection::start(
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
        event_backlog=0,
      )
    catch {
      InvalidBacklog(value=0) => ()
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected InvalidBacklog")
    }
    connection.disconnect()
  })
}

///|
async test "next_frame skips loss markers and a late subscription ends at once" {
  let transport = DaveConnectionTransport()
  @async.with_task_group(group => {
    let connection = dave_test_connection(group, transport, [])
    let stream = connection.subscribe(user_id="200")
    connection.deliver_audio("200", Lost(count=3))
    connection.deliver_audio("200", backlog_test_opus(4))
    assert_eq(stream.next_frame(), Some(b"opus"))
    connection.disconnect()
    let late = connection.subscribe(user_id="200")
    assert_eq(late.next_packet(), None)
    assert_eq(connection.subscriptions.length(), 0)
  })
}

///|
async test "resubscribing never replays packets buffered for an earlier stream" {
  if !shim_available() {
    return
  }
  let transport = DaveConnectionTransport()
  @async.with_task_group(group => {
    let connection = dave_test_connection(group, transport, [])
    let pipeline = connection.receiver
    pipeline.handle_gateway_message(Speaking(ssrc=77U, user_id="200", flags=1))
    |> ignore
    let cipher = TransportCipher::new(AeadAes256GcmRtpsize, Bytes::new(32))
    let receive = (sequence : Int32) => {
      let header = build_rtp_header(
        sequence=sequence.to_uint16(),
        timestamp=(sequence * 960).reinterpret_as_uint(),
        ssrc=77U,
      )
      pipeline.process_udp_packet(
        cipher.seal(header~, b"opus"),
        cipher,
        None,
        arrival_ms=0L,
        wants=user_id => connection.is_subscribed(user_id),
      )
    }
    let first = connection.subscribe(user_id="200")
    assert_eq(receive(100).length(), 1)
    // 102 waits behind the missing 101
    assert_eq(receive(102), [])
    first.close()
    connection.subscribe(user_id="200") |> ignore
    assert_eq(receive(101), [
      ("200", Opus(sequence=101, timestamp=96960U, opus=b"opus")),
    ])
    connection.disconnect()
  })
}
