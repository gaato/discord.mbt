///|
test "libdave shim creates, resets, and generates key packages" {
  if !@voice.shim_available() {
    return
  }
  let provider = @voice.new_dave_provider(
    protocol_version=1,
    user_id="100",
    channel_id=42UL,
  )
  assert_eq(provider.status(), 0)
  let first = provider.key_package()
  assert_true(first.length() > 0)
  provider.reinit(protocol_version=1)
  let second = provider.key_package()
  assert_true(second.length() > 0)
  assert_true(first != second)
}

///|
test "libdave shim rejects media before an MLS group is active" {
  if !@voice.shim_available() {
    return
  }
  let provider = @voice.new_dave_provider(
    protocol_version=1,
    user_id="100",
    channel_id=42UL,
  )
  try provider.encrypt_frame(b"opus") catch {
    @voice.DaveError::DaveInternal(status=-4, ..) => ()
    error => fail("unexpected encrypt error: \{error}")
  } noraise {
    _ => fail("expected inactive DAVE encryption to fail")
  }
  try provider.decrypt_frame(user_id="200", b"encrypted") catch {
    @voice.DaveError::DaveInternal(status=-4, ..) => ()
    error => fail("unexpected decrypt error: \{error}")
  } noraise {
    _ => fail("expected inactive DAVE decryption to fail")
  }
}

///|
test "libdave shim accepts recognized user IDs across the C array boundary" {
  if !@voice.shim_available() {
    return
  }
  let provider = @voice.new_dave_provider(
    protocol_version=1,
    user_id="100",
    channel_id=42UL,
  )
  try
    provider.process_proposals(op_type=0, b"not-an-mls-proposal", recognized=[
      "100", "200",
    ])
    |> ignore
  catch {
    @voice.DaveError::DaveInternal(..) => ()
    error => fail("unexpected proposals error: \{error}")
  } noraise {
    _ => fail("expected malformed proposals to fail")
  }
}
