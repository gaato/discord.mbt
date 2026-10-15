///|
fn pinned_v1_external_sender_for_bridge_smoke() -> Bytes {
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
test "pinned v1.2.0 native bridge establishes a single-member group" {
  if !@dave.available() {
    if @env.get_env_var("MBT_DAVE_REQUIRE_NATIVE") == Some("1") {
      fail(@dave.unavailable_reason().unwrap_or("libdave is unavailable"))
    }
    return
  }
  let user_id = 1234123412341234UL
  let session = @dave.Session::new(
    protocol_version=1,
    group_id=1234567890UL,
    self_user_id=user_id,
  )
  session.set_external_sender(pinned_v1_external_sender_for_bridge_smoke())
  // In libdave v1.2.0, append followed by an empty MLSMessage vector is 00 00.
  // It drives a pinned single-member success path without an external-sender
  // private key. This is a C-bridge smoke test, not Discord DAVE conformance:
  // a valid Discord commit has at least one server-signed proposal reference,
  // and only an Add proposal can produce the Welcome path.
  let commit = session.process_proposals(b"\x00\x00", recognized_user_ids=[
    user_id,
  ])
  guard session.process_commit(commit) is @dave.CommitResult::Applied(changes~) else {
    fail("self commit was not applied")
  }
  guard changes is [@dave.RosterChange::Upsert(user_id=id, signature_key~)] else {
    fail("unexpected single-member roster delta")
  }
  assert_eq(id, user_id)
  assert_true(signature_key.length() > 0)
  guard session.last_epoch_authenticator() is Some(authenticator) else {
    fail("missing epoch authenticator")
  }
  assert_eq(authenticator.length(), 32)

  guard session.key_ratchet(user_id~) is Some(outbound) else {
    fail("missing outbound key ratchet")
  }
  guard session.key_ratchet(user_id~) is Some(inbound) else {
    fail("missing inbound key ratchet")
  }
  let encryptor = @dave.Encryptor::new()
  encryptor.assign_ssrc_to_codec(ssrc=7U, codec=Opus)
  encryptor.set_key_ratchet(outbound)
  assert_true(encryptor.has_key_ratchet())
  assert_eq(encryptor.protocol_version(), 1)
  let decryptor = @dave.Decryptor::new()
  decryptor.transition_to_key_ratchet(inbound)
  let frame = b"\x0d\xc5\xae\xdd\x5b\xdc\x3f\x20\xbe\x56\x97\xe5\x4d\xd1\xf4\x37"
  let encrypted = encryptor.encrypt(media_type=Audio, ssrc=7U, frame)
  assert_true(encrypted != frame)
  assert_eq(decryptor.decrypt(media_type=Audio, encrypted), frame)
}
