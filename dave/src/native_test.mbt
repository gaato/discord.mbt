///|
test "native availability can be required by CI" {
  let require_native = @env.get_env_var("MBT_DAVE_REQUIRE_NATIVE") == Some("1")
  if require_native && !@dave.available() {
    fail(@dave.unavailable_reason().unwrap_or("libdave is unavailable"))
  }
  if @dave.available() {
    assert_eq(@dave.unavailable_reason(), None)
    assert_true(@dave.max_supported_protocol_version() > 0)
  } else {
    assert_true(@dave.unavailable_reason() is Some(_))
    assert_eq(@dave.max_supported_protocol_version(), 0)
  }
}

///|
test "Session validates protocol version zero before native creation" {
  try
    @dave.Session::new(protocol_version=0, group_id=42UL, self_user_id=100UL)
  catch {
    @dave.DaveError::InvalidArgument(operation="Session::new", ..) => ()
    _ => fail("unexpected Session error")
  } noraise {
    _ => fail("expected protocol version zero to fail")
  }
}

///|
fn fixed_external_sender() -> Bytes {
  [
    0x40, 0x41, 0x04, 0x6b, 0x17, 0xd1, 0xf2, 0xe1, 0x2c, 0x42, 0x47, 0xf8, 0xbc,
    0xe6, 0xe5, 0x63, 0xa4, 0x40, 0xf2, 0x77, 0x03, 0x7d, 0x81, 0x2d, 0xeb, 0x33,
    0xa0, 0xf4, 0xa1, 0x39, 0x45, 0xd8, 0x98, 0xc2, 0x96, 0x4f, 0xe3, 0x42, 0xe2,
    0xfe, 0x1a, 0x7f, 0x9b, 0x8e, 0xe7, 0xeb, 0x4a, 0x7c, 0x0f, 0x9e, 0x16, 0x2b,
    0xce, 0x33, 0x57, 0x6b, 0x31, 0x5e, 0xce, 0xcb, 0xb6, 0x40, 0x68, 0x37, 0xbf,
    0x51, 0xf5, 0x00, 0x01, 0x04, 0x00, 0x01, 0x01, 0x00,
  ]
}

///|
test "native Session and passthrough media lifecycle" {
  if !@dave.available() {
    return
  }
  let session = @dave.Session::new(
    protocol_version=1,
    group_id=42UL,
    self_user_id=100UL,
  )
  assert_eq(session.protocol_version(), 1)
  session.reset()
  assert_eq(session.protocol_version(), 0)
  session.reinitialize(protocol_version=1, group_id=42UL, self_user_id=100UL)
  assert_eq(session.protocol_version(), 1)
  session.set_protocol_version(protocol_version=0)
  assert_eq(session.protocol_version(), 0)
  session.set_protocol_version(protocol_version=1)
  assert_true(session.key_package().length() > 0)

  let encryptor = @dave.Encryptor::new()
  try encryptor.encrypt(media_type=Audio, ssrc=7U, b"opus") catch {
    @dave.DaveError::InvalidState(operation="Encryptor::encrypt", ..) => ()
    _ => fail("unexpected unassigned-SSRC error")
  } noraise {
    _ => fail("expected encryption without a codec assignment to fail")
  }
  let frame = b"opus"
  encryptor.set_passthrough_mode(enabled=true)
  assert_eq(encryptor.encrypt(media_type=Audio, ssrc=999U, frame), frame)
  encryptor.set_passthrough_mode(enabled=false)
  encryptor.assign_ssrc_to_codec(ssrc=7U, codec=Opus)
  try encryptor.encrypt(media_type=Video, ssrc=7U, b"opus") catch {
    @dave.DaveError::InvalidArgument(operation="Encryptor::encrypt", ..) => ()
    _ => fail("unexpected codec/media mismatch error")
  } noraise {
    _ => fail("expected a codec/media mismatch to fail")
  }
  encryptor.set_passthrough_mode(enabled=true)
  assert_eq(encryptor.encrypt(media_type=Audio, ssrc=7U, frame), frame)

  let decryptor = @dave.Decryptor::new()
  decryptor.transition_to_passthrough_mode(enabled=true)
  assert_eq(decryptor.decrypt(media_type=Audio, frame), frame)
}

///|
test "current-group fingerprint requires an established MLS group" {
  if !@dave.available() {
    return
  }
  let session = @dave.Session::new(
    protocol_version=1,
    group_id=42UL,
    self_user_id=100UL,
  )
  try session.current_group_pairwise_fingerprint_blocking(user_id=200UL) catch {
    @dave.DaveError::FingerprintFailed(user_id=200UL, ..) => ()
    _ => fail("unexpected current-group fingerprint error")
  } noraise {
    _ => fail("expected fingerprinting without an established group to fail")
  }
}

///|
test "Session rejects an empty external sender before calling libdave" {
  if !@dave.available() {
    return
  }
  let session = @dave.Session::new(
    protocol_version=1,
    group_id=42UL,
    self_user_id=100UL,
  )
  try session.set_external_sender(b"") catch {
    @dave.DaveError::InvalidArgument(
      operation="Session::set_external_sender",
      ..
    ) => ()
    _ => fail("unexpected empty external-sender error")
  } noraise {
    _ => fail("expected an empty external sender to fail")
  }
}

///|
test "Session surfaces an external-sender MLS failure callback" {
  if !@dave.available() {
    return
  }
  let session = @dave.Session::new(
    protocol_version=1,
    group_id=42UL,
    self_user_id=100UL,
  )
  try session.set_external_sender(b"\x00") catch {
    @dave.DaveError::MlsOperationFailed(
      operation="Session::set_external_sender",
      ..
    ) => ()
    _ => fail("unexpected malformed external-sender error")
  } noraise {
    _ => fail("expected malformed external sender MLS failure")
  }
}

///|
test "Session rejects an empty proposals payload before FFI" {
  if !@dave.available() {
    return
  }
  let session = @dave.Session::new(
    protocol_version=1,
    group_id=42UL,
    self_user_id=100UL,
  )
  try session.process_proposals(b"", recognized_user_ids=[]) catch {
    @dave.DaveError::InvalidArgument(operation="Session::process_proposals", ..) =>
      ()
    _ => fail("unexpected empty proposals error")
  } noraise {
    _ => fail("expected an empty proposals payload to fail")
  }
}

///|
test "Session rejects proposals before MLS group state exists" {
  if !@dave.available() {
    return
  }
  let session = @dave.Session::new(
    protocol_version=1,
    group_id=42UL,
    self_user_id=100UL,
  )
  try session.process_proposals(b"\x00", recognized_user_ids=[]) catch {
    @dave.DaveError::InvalidState(operation="Session::process_proposals", ..) =>
      ()
    _ => fail("unexpected proposals state error")
  } noraise {
    _ => fail("expected proposals without MLS group state to fail")
  }
}

///|
test "Session rejects replacing an external sender after MLS state exists" {
  if !@dave.available() {
    return
  }
  let session = @dave.Session::new(
    protocol_version=1,
    group_id=7UL,
    self_user_id=100UL,
  )
  session.set_external_sender(fixed_external_sender())
  try session.set_external_sender(fixed_external_sender()) catch {
    @dave.DaveError::InvalidState(operation="Session::set_external_sender", ..) =>
      ()
    _ => fail("unexpected external-sender state error")
  } noraise {
    _ => fail("expected replacement after MLS state creation to fail")
  }

  session.reset()
  try session.process_proposals(b"\x00", recognized_user_ids=[]) catch {
    @dave.DaveError::InvalidState(operation="Session::process_proposals", ..) =>
      ()
    _ => fail("unexpected reset proposals state error")
  } noraise {
    _ => fail("expected proposals before reinitialization to fail")
  }
  session.set_external_sender(fixed_external_sender())
  session.reinitialize(protocol_version=1, group_id=7UL, self_user_id=100UL)
  assert_true(session.key_package().length() > 0)
}

///|
test "Session rejects an empty commit payload before FFI" {
  if !@dave.available() {
    return
  }
  let session = @dave.Session::new(
    protocol_version=1,
    group_id=42UL,
    self_user_id=100UL,
  )
  try session.process_commit(b"") catch {
    @dave.DaveError::InvalidArgument(operation="Session::process_commit", ..) =>
      ()
    _ => fail("unexpected empty commit error")
  } noraise {
    _ => fail("expected an empty commit payload to fail")
  }
}

///|
test "Session rejects an empty Welcome payload before FFI" {
  if !@dave.available() {
    return
  }
  let session = @dave.Session::new(
    protocol_version=1,
    group_id=42UL,
    self_user_id=100UL,
  )
  try session.process_welcome(b"", recognized_user_ids=[]) catch {
    @dave.DaveError::InvalidArgument(operation="Session::process_welcome", ..) =>
      ()
    _ => fail("unexpected empty Welcome error")
  } noraise {
    _ => fail("expected an empty Welcome payload to fail")
  }
}
