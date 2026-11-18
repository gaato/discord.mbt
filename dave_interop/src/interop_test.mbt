///|
const GROUP : UInt64 = 42

///|
const ALICE : UInt64 = 1001

///|
const BOB : UInt64 = 2002

///|
/// A session joined to `server`'s external sender. The interop tests run only
/// where libdave loads, so an unavailable library fails instead of skipping.
fn joined(
  server : @dave_interop.VoiceServer,
  user_id : UInt64,
) -> @dave.Session raise {
  if @dave.unavailable_reason() is Some(reason) {
    fail(reason)
  }
  let session = @dave.Session::new(
    protocol_version=1,
    group_id=GROUP,
    self_user_id=user_id,
  )
  session.set_external_sender(server.external_sender())
  session
}

///|
fn upserts(changes : Array[@dave.RosterChange]) -> Array[UInt64] {
  let ids = []
  for change in changes {
    if change is Upsert(user_id~, ..) {
      ids.push(user_id)
    }
  }
  ids
}

///|
test "a recognized user joins, shares media keys, and is removed" {
  let server = @dave_interop.VoiceServer::new(group_id=GROUP)
  let alice = joined(server, ALICE)
  let bob = joined(server, BOB)
  alice.add_recognized_user(user_id=BOB)
  bob.add_recognized_user(user_id=ALICE)

  let add = server.add(epoch=0, bob.key_package())
  guard alice.process_proposals(@dave_interop.append([add])) is Some(output) else {
    fail("an Add produced no commit")
  }
  let (commit, welcome) = @dave_interop.split_commit(output)
  guard alice.process_commit(commit) is Applied(changes~) else {
    fail("alice did not apply her commit")
  }
  assert_true(upserts(changes).contains(BOB))
  guard bob.process_welcome(welcome) is Applied(changes~) else {
    fail("bob did not join through the Welcome")
  }
  assert_true(upserts(changes).contains(ALICE))
  guard alice.last_epoch_authenticator() is Some(authenticator) else {
    fail("alice has no epoch authenticator")
  }
  assert_eq(bob.last_epoch_authenticator(), Some(authenticator))

  // Alice's media key, derived on both sides, carries a frame from her to Bob.
  guard alice.key_ratchet(user_id=ALICE) is Some(outbound) else {
    fail("alice has no media key")
  }
  guard bob.key_ratchet(user_id=ALICE) is Some(inbound) else {
    fail("bob has no media key for alice")
  }
  let encryptor = @dave.Encryptor::new()
  encryptor.assign_ssrc_to_codec(ssrc=7U, codec=Opus)
  encryptor.set_key_ratchet(outbound)
  let decryptor = @dave.Decryptor::new()
  decryptor.transition_to_key_ratchet(inbound)
  let frame = b"\x0d\xc5\xae\xdd\x5b\xdc\x3f\x20\xbe\x56\x97\xe5\x4d\xd1\xf4\x37"
  let encrypted = encryptor.encrypt(media_type=Audio, ssrc=7U, frame)
  assert_true(encrypted != frame)
  assert_eq(decryptor.decrypt(media_type=Audio, encrypted), frame)

  // Bob joined at leaf 1, after Alice who created the group.
  let remove = server.remove(epoch=1, leaf_index=1)
  guard alice.process_proposals(@dave_interop.append([remove])) is Some(commit) else {
    fail("a Remove produced no commit")
  }
  guard alice.process_commit(commit) is Applied(changes~) else {
    fail("alice did not apply the removal")
  }
  assert_eq(changes, [Remove(user_id=BOB)])
}

///|
test "proposals that add an unrecognized user are refused as a whole" {
  let server = @dave_interop.VoiceServer::new(group_id=GROUP)
  let alice = joined(server, ALICE)
  let bob = joined(server, BOB)
  let proposals = @dave_interop.append([server.add(epoch=0, bob.key_package())])
  try alice.process_proposals(proposals) catch {
    MlsOperationFailed(operation="Session::process_proposals", ..) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the Add for an unrecognized user to be refused")
  }
  // The refused batch left nothing queued, so the same batch now goes through.
  alice.add_recognized_user(user_id=BOB)
  assert_true(alice.process_proposals(proposals) is Some(_))
}

///|
test "a commit is refused once its added user is no longer recognized" {
  let server = @dave_interop.VoiceServer::new(group_id=GROUP)
  let alice = joined(server, ALICE)
  let bob = joined(server, BOB)
  alice.add_recognized_user(user_id=BOB)
  let add = server.add(epoch=0, bob.key_package())
  guard alice.process_proposals(@dave_interop.append([add])) is Some(output) else {
    fail("an Add produced no commit")
  }
  let (commit, _) = @dave_interop.split_commit(output)
  alice.remove_recognized_user(user_id=BOB)
  assert_true(alice.process_commit(commit) is Failed(_))
}

///|
test "a Welcome that lists an unrecognized member fails" {
  let server = @dave_interop.VoiceServer::new(group_id=GROUP)
  let alice = joined(server, ALICE)
  let bob = joined(server, BOB)
  alice.add_recognized_user(user_id=BOB)
  let add = server.add(epoch=0, bob.key_package())
  guard alice.process_proposals(@dave_interop.append([add])) is Some(output) else {
    fail("an Add produced no commit")
  }
  let (_, welcome) = @dave_interop.split_commit(output)
  assert_true(bob.process_welcome(welcome) is Failed(_))
}

///|
test "recognized users survive reinitialization" {
  let server = @dave_interop.VoiceServer::new(group_id=GROUP)
  let alice = joined(server, ALICE)
  let bob = joined(server, BOB)
  alice.add_recognized_user(user_id=BOB)
  alice.reinitialize(protocol_version=1, group_id=GROUP, self_user_id=ALICE)
  let proposals = @dave_interop.append([server.add(epoch=0, bob.key_package())])
  assert_true(alice.process_proposals(proposals) is Some(_))
}

///|
test "revoking every queued proposal leaves nothing to commit" {
  let server = @dave_interop.VoiceServer::new(group_id=GROUP)
  let alice = joined(server, ALICE)
  let bob = joined(server, BOB)
  alice.add_recognized_user(user_id=BOB)
  let add = server.add(epoch=0, bob.key_package())
  assert_true(alice.process_proposals(@dave_interop.append([add])) is Some(_))
  assert_eq(alice.process_proposals(@dave_interop.revoke([add])), None)
}

///|
/// Old calls compile with a warning until the argument goes in the next minor
/// release; this one checks they still behave.
#warnings("-deprecated")
test "the deprecated recognized_user_ids argument still recognizes users" {
  let server = @dave_interop.VoiceServer::new(group_id=GROUP)
  let alice = joined(server, ALICE)
  let bob = joined(server, BOB)
  let add = server.add(epoch=0, bob.key_package())
  guard alice.process_proposals(@dave_interop.append([add]), recognized_user_ids=[
      BOB,
    ])
    is Some(output) else {
    fail("an Add produced no commit")
  }
  let (_, welcome) = @dave_interop.split_commit(output)
  assert_true(
    bob.process_welcome(welcome, recognized_user_ids=[ALICE]) is Applied(_),
  )
}
