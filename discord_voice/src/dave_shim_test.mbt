///|
test "official libdave backend creates a key package and starts in passthrough" {
  if !@dave.available() {
    if @env.get_env_var("MBT_DAVE_REQUIRE_NATIVE") == Some("1") {
      fail(@dave.unavailable_reason().unwrap_or("libdave is unavailable"))
    }
    return
  }
  let machine = @voice.DaveMachine::new(
    protocol_version=1,
    self_user_id="100",
    channel_id=42UL,
  )
  let actions = machine.handle(
    SessionDescription(
      mode="aead_aes256_gcm_rtpsize",
      secret_key=Bytes::new(32),
      dave_protocol_version=1,
    ),
  )
  match actions {
    [SendBinary(op=26, payload~)] => assert_true(payload.length() > 0)
    _ => fail("unexpected DAVE initialization actions: \{Repr(actions)}")
  }
  assert_eq(machine.active_protocol_version(), 0)
  assert_eq(
    machine.encrypt_opus_frame(ssrc=0x12345678U, b"plain-opus"),
    b"plain-opus",
  )
}

///|
test "official libdave backend rejects invalid constructor inputs" {
  try
    @voice.DaveMachine::new(
      protocol_version=65536,
      self_user_id="100",
      channel_id=42UL,
    )
    |> ignore
  catch {
    DaveInvalid(..) => ()
    error => fail("unexpected protocol-version error: \{Repr(error)}")
  } noraise {
    _ => fail("expected an invalid protocol-version error")
  }
  try
    @voice.DaveMachine::new(
      protocol_version=1,
      self_user_id="not-a-snowflake",
      channel_id=42UL,
    )
    |> ignore
  catch {
    DaveInvalid(..) => ()
    error => fail("unexpected user-ID error: \{Repr(error)}")
  } noraise {
    _ => fail("expected an invalid user-ID error")
  }
}
