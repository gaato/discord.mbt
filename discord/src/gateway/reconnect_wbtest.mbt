///|
test "backoff_cap_ms doubles from one second up to thirty" {
  let rows : Array[(Int32, Int32)] = [
    (0, 1000),
    (1, 2000),
    (2, 4000),
    (4, 16000),
    (5, 30000),
    (9, 30000),
  ]
  for row in rows {
    let (attempts, cap) = row
    assert_eq(backoff_cap_ms(attempts), cap, msg="attempts=\{attempts}")
  }
}

///|
test "reconnect delays sample within their bounds" {
  let rand = @random.Rand::chacha8()
  for _ in 0..<1000 {
    let backoff = ReconnectDelay::Backoff(cap_ms=2000).sample_ms(rand)
    assert_true(backoff >= 250 && backoff < 2250, msg="backoff=\{backoff}")
    let invalid = ReconnectDelay::InvalidSession.sample_ms(rand)
    assert_true(invalid >= 1000 && invalid < 5000, msg="invalid=\{invalid}")
  }
}

///|
fn code_label(code : Int32?) -> String {
  match code {
    Some(code) => code.to_string()
    None => "none"
  }
}

///|
fn delay_label(delay : ReconnectDelay?) -> String {
  match delay {
    Some(Backoff(cap_ms~)) => "backoff \{cap_ms}"
    Some(InvalidSession) => "invalid session"
    None => "none"
  }
}

///|
fn after_label(after : AfterClose) -> String {
  match after {
    Stop(code~) => "stop \{code_label(code)}"
    Fatal(code~) => "fatal \{code_label(code)}"
    Reconnect(code~, resuming~, clear_session~) =>
      "reconnect \{code_label(code)}, resuming=\{resuming}, clear_session=\{clear_session}"
  }
}

///|
/// One `after_close` call from a reconnect state with `attempts`, and the
/// state it leaves.
fn after_close_row(
  ended : ConnectionEnded,
  attempts~ : Int32 = 0,
  closing~ : Bool = false,
  was_active~ : Bool = false,
  has_session~ : Bool = true,
) -> (String, Int32, String) {
  let reconnect = Reconnect::new()
  reconnect.attempts = attempts
  let after = reconnect.after_close(ended, closing~, was_active~, has_session~)
  (after_label(after), reconnect.attempts, delay_label(reconnect.delay))
}

///|
test "after_close stops a closing shard and gives up on fatal codes" {
  let closed = ConnectionEnded(code=Some(4000), reason="")
  assert_eq(
    after_close_row(closed, attempts=2, closing=true),
    ("stop 4000", 2, "none"),
  )
  assert_eq(
    after_close_row(ConnectionEnded(code=Some(4004), reason="")),
    ("fatal 4004", 0, "none"),
  )
  assert_eq(
    after_close_row(ConnectionEnded(code=Some(4014), reason="")),
    ("fatal 4014", 0, "none"),
  )
}

///|
test "after_close resumes or re-identifies with a backoff" {
  let resumable = ConnectionEnded(code=Some(4000), reason="")
  assert_eq(
    after_close_row(resumable, attempts=3, was_active=true),
    ("reconnect 4000, resuming=true, clear_session=false", 1, "backoff 2000"),
  )
  assert_eq(
    after_close_row(resumable, attempts=2),
    ("reconnect 4000, resuming=true, clear_session=false", 3, "backoff 8000"),
  )
  assert_eq(
    after_close_row(resumable, has_session=false),
    ("reconnect 4000, resuming=false, clear_session=true", 1, "backoff 2000"),
  )
  for code in [4009, 1000] {
    assert_eq(
      after_close_row(ConnectionEnded(code=Some(code), reason="")),
      (
        "reconnect \{code}, resuming=false, clear_session=true",
        1,
        "backoff 2000",
      ),
      msg="code=\{code}",
    )
  }
  assert_eq(
    after_close_row(ConnectionEnded(code=None, reason="")),
    ("reconnect none, resuming=true, clear_session=false", 1, "backoff 2000"),
  )
}

///|
test "after_close waits once after a non-resumable invalid session" {
  assert_eq(
    after_close_row(InvalidSession(resumable=true)),
    ("reconnect none, resuming=true, clear_session=false", 1, "backoff 2000"),
  )
  assert_eq(
    after_close_row(InvalidSession(resumable=false), attempts=1),
    ("reconnect none, resuming=false, clear_session=true", 2, "invalid session"),
  )
}

///|
test "three consecutive connector failures drop a stale resume url" {
  let reconnect = Reconnect::new()
  assert_false(reconnect.on_connector_failure(has_session=true))
  assert_false(reconnect.on_connector_failure(has_session=true))
  assert_false(reconnect.on_connector_failure(has_session=false))
  assert_true(reconnect.on_connector_failure(has_session=true))
  assert_eq(reconnect.attempts, 4)
  assert_eq(delay_label(reconnect.delay), "backoff 16000")
  reconnect.on_connected()
  assert_false(reconnect.on_connector_failure(has_session=true))
  assert_false(reconnect.on_connector_failure(has_session=true))
  assert_true(reconnect.on_connector_failure(has_session=true))
}
