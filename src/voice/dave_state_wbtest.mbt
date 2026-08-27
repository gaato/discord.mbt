///|
struct FakeProposalCall {
  payload : Bytes
  recognized_user_ids : Array[UInt64]
} derive(Debug, Eq)

///|
struct FakeWelcomeCall {
  payload : Bytes
  recognized_user_ids : Array[UInt64]
} derive(Debug, Eq)

///|
struct FakePreparedRemote {
  user_id : UInt64
  protocol_version : Int
} derive(Debug, Eq)

///|
struct FakeEncryptedOpus {
  ssrc : UInt
  frame : Bytes
} derive(Debug, Eq)

///|
struct FakeDecryptedOpus {
  user_id : UInt64
  frame : Bytes
} derive(Debug, Eq)

///|
struct FakeDaveBackend {
  mut session_version : Int
  mut active_version : Int
  reinitialized : Array[Int]
  mut reset_calls : Int
  external_senders : Array[Bytes]
  mut key_package_calls : Int
  proposal_calls : Array[FakeProposalCall]
  commits : Array[Bytes]
  welcome_calls : Array[FakeWelcomeCall]
  prepared_remotes : Array[FakePreparedRemote]
  removed_remotes : Array[UInt64]
  activated_self : Array[Int]
  encrypted_opus : Array[FakeEncryptedOpus]
  decrypted_opus : Array[FakeDecryptedOpus]
  remote_users : Set[UInt64]
  proposal_result : Bytes
  mut commit_outcome : DaveCommitOutcome
  mut welcome_outcome : DaveWelcomeOutcome
}

///|
fn FakeDaveBackend::new() -> FakeDaveBackend {
  {
    session_version: 1,
    active_version: 0,
    reinitialized: [],
    reset_calls: 0,
    external_senders: [],
    key_package_calls: 0,
    proposal_calls: [],
    commits: [],
    welcome_calls: [],
    prepared_remotes: [],
    removed_remotes: [],
    activated_self: [],
    encrypted_opus: [],
    decrypted_opus: [],
    remote_users: Set([]),
    proposal_result: b"commit-and-welcome",
    commit_outcome: CommitIgnored,
    welcome_outcome: WelcomeApplied(changes=[]),
  }
}

///|
impl DaveBackend for FakeDaveBackend with fn protocol_version(self) {
  self.session_version
}

///|
impl DaveBackend for FakeDaveBackend with fn reinitialize(
  self,
  protocol_version~,
) {
  self.session_version = protocol_version
  self.reinitialized.push(protocol_version)
}

///|
impl DaveBackend for FakeDaveBackend with fn reset(self) {
  self.reset_calls += 1
}

///|
impl DaveBackend for FakeDaveBackend with fn set_external_sender(self, payload) {
  self.external_senders.push(payload)
}

///|
impl DaveBackend for FakeDaveBackend with fn key_package(self) {
  self.key_package_calls += 1
  b"key-package"
}

///|
impl DaveBackend for FakeDaveBackend with fn process_proposals(
  self,
  payload,
  recognized_user_ids~,
) {
  self.proposal_calls.push({
    payload,
    recognized_user_ids: recognized_user_ids.copy(),
  })
  self.proposal_result
}

///|
impl DaveBackend for FakeDaveBackend with fn process_commit(self, payload) {
  self.commits.push(payload)
  self.commit_outcome
}

///|
impl DaveBackend for FakeDaveBackend with fn process_welcome(
  self,
  payload,
  recognized_user_ids~,
) {
  self.welcome_calls.push({
    payload,
    recognized_user_ids: recognized_user_ids.copy(),
  })
  self.welcome_outcome
}

///|
impl DaveBackend for FakeDaveBackend with fn prepare_remote_ratchet(
  self,
  user_id~,
  protocol_version~,
) {
  self.prepared_remotes.push({ user_id, protocol_version })
  self.remote_users.add(user_id)
}

///|
impl DaveBackend for FakeDaveBackend with fn has_remote(self, user_id~) {
  self.remote_users.contains(user_id)
}

///|
impl DaveBackend for FakeDaveBackend with fn remove_remote(self, user_id~) {
  self.removed_remotes.push(user_id)
  self.remote_users.remove(user_id)
}

///|
impl DaveBackend for FakeDaveBackend with fn activate_self_ratchet(
  self,
  protocol_version~,
) {
  self.active_version = protocol_version
  self.activated_self.push(protocol_version)
}

///|
impl DaveBackend for FakeDaveBackend with fn active_protocol_version(self) {
  self.active_version
}

///|
impl DaveBackend for FakeDaveBackend with fn encrypt_opus(self, ssrc~, frame) {
  self.encrypted_opus.push({ ssrc, frame })
  b"encrypted-opus"
}

///|
impl DaveBackend for FakeDaveBackend with fn decrypt_opus(self, user_id~, frame) {
  self.decrypted_opus.push({ user_id, frame })
  b"decrypted-opus"
}

///|
/// Private constructor compiled only with the white-box state tests. Keeping
/// the seam here prevents alternate crypto backends from entering the package
/// API or the production build.
fn DaveMachine::new_with_backend(
  backend : &DaveBackend,
  self_user_id~ : UInt64,
  roster? : Array[UInt64] = [],
) -> DaveMachine {
  let connected_roster = Set(roster)
  connected_roster.remove(self_user_id)
  {
    backend,
    self_user_id,
    connected_roster,
    mls_roster: Set([]),
    pending: Map([]),
    latest_prepared_version: 0,
  }
}

///|
fn fake_machine(
  fake : FakeDaveBackend,
  roster? : Array[UInt64] = [],
) -> DaveMachine {
  DaveMachine::new_with_backend(
    (fake : &DaveBackend),
    self_user_id=100UL,
    roster~,
  )
}

///|
fn session_description(version : Int) -> VoiceMessage {
  SessionDescription(
    mode="aead_aes256_gcm_rtpsize",
    secret_key=Bytes::new(32),
    dave_protocol_version=version,
  )
}

///|
fn establish(fake : FakeDaveBackend, machine : DaveMachine) -> Unit raise {
  assert_eq(machine.handle(session_description(1)), [
    SendBinary(op=26, payload=b"key-package"),
  ])
  fake.reinitialized.clear()
  fake.key_package_calls = 0
}

///|
test "DAVE Session Description reinitializes before publishing a key package" {
  let fake = FakeDaveBackend::new()
  let machine = fake_machine(fake)
  assert_eq(machine.handle(session_description(1)), [
    SendBinary(op=26, payload=b"key-package"),
  ])
  assert_eq(fake.reinitialized, [1])
  assert_eq(fake.key_package_calls, 1)
  assert_eq(machine.active_protocol_version(), 0)
}

///|
test "DAVE Prepare Epoch reinitializes only epoch one" {
  let fake = FakeDaveBackend::new()
  let machine = fake_machine(fake)
  assert_eq(machine.handle(DavePrepareEpoch(epoch=2, protocol_version=1)), [])
  assert_eq(machine.handle(DavePrepareEpoch(epoch=1, protocol_version=1)), [
    SendBinary(op=26, payload=b"key-package"),
  ])
  assert_eq(fake.reinitialized, [1])
  assert_eq(fake.key_package_calls, 1)
}

///|
test "DAVE retains the external sender while upgrading an initial v0 session" {
  let fake = FakeDaveBackend::new()
  let machine = fake_machine(fake)
  assert_eq(machine.handle(session_description(0)), [
    SwitchMediaContext(protocol_version=0),
  ])
  assert_eq(machine.active_protocol_version(), 0)
  assert_eq(machine.handle(DaveMlsExternalSender(payload=b"external-sender")), [])
  assert_eq(machine.handle(DavePrepareEpoch(epoch=1, protocol_version=1)), [
    SendBinary(op=26, payload=b"key-package"),
  ])
  assert_eq(fake.external_senders, [b"external-sender"])
  assert_eq(fake.reinitialized, [1])
  assert_eq(fake.key_package_calls, 1)
}

///|
test "DAVE reinitializes a same-version Session Description after v0 reset" {
  let fake = FakeDaveBackend::new()
  let machine = fake_machine(fake)
  machine.handle(session_description(0)) |> ignore
  machine.handle(DaveMlsExternalSender(payload=b"external-sender")) |> ignore
  fake.reinitialized.clear()
  assert_eq(machine.handle(session_description(1)), [
    SendBinary(op=26, payload=b"key-package"),
  ])
  assert_eq(fake.reinitialized, [1])
  assert_eq(fake.external_senders, [b"external-sender"])
}

///|
test "DAVE forwards complete proposals and only the connected roster" {
  let fake = FakeDaveBackend::new()
  let machine = fake_machine(fake, roster=[200UL])
  machine.handle(ClientsConnect(user_ids=["300"])) |> ignore
  machine.handle(ClientDisconnect(user_id="200")) |> ignore
  assert_eq(machine.handle(DaveMlsProposals(payload=b"\x01revoke")), [
    SendBinary(op=28, payload=b"commit-and-welcome"),
  ])
  assert_eq(fake.proposal_calls, [
    { payload: b"\x01revoke", recognized_user_ids: [300UL] },
  ])
}

///|
test "DAVE rejects an empty proposals payload" {
  let fake = FakeDaveBackend::new()
  let machine = fake_machine(fake)
  try machine.handle(DaveMlsProposals(payload=b"")) |> ignore catch {
    DaveInvalid(..) => ()
    error => fail("unexpected empty-proposals error: \{Repr(error)}")
  } noraise {
    _ => fail("expected an empty-proposals error")
  }
}

///|
test "DAVE ignored commit emits no Ready and changes no ratchets" {
  let fake = FakeDaveBackend::new()
  fake.commit_outcome = CommitIgnored
  let machine = fake_machine(fake, roster=[200UL])
  establish(fake, machine)
  assert_eq(
    machine.handle(
      DaveMlsAnnounceCommitTransition(transition_id=7, commit=b"ignored"),
    ),
    [],
  )
  assert_eq(fake.commits, [b"ignored"])
  assert_eq(fake.prepared_remotes, [])
  assert_eq(fake.activated_self, [])
  assert_eq(machine.handle(DaveExecuteTransition(transition_id=7)), [])
}

///|
test "DAVE initial commit transition activates self immediately" {
  let fake = FakeDaveBackend::new()
  let machine = fake_machine(fake)
  fake.commit_outcome = CommitApplied(changes=[UpsertDaveMember(user_id=100UL)])
  assert_eq(
    machine.handle(
      DaveMlsAnnounceCommitTransition(transition_id=0, commit=b"initial"),
    ),
    [SwitchMediaContext(protocol_version=1)],
  )
  assert_eq(fake.activated_self, [1])
  assert_eq(machine.active_protocol_version(), 1)
  assert_eq(machine.handle(DaveExecuteTransition(transition_id=0)), [])
}

///|
test "DAVE commit applies a roster delta and activates self only on Execute" {
  let fake = FakeDaveBackend::new()
  let machine = fake_machine(fake, roster=[200UL, 300UL])
  fake.welcome_outcome = WelcomeApplied(changes=[
    UpsertDaveMember(user_id=100UL),
    UpsertDaveMember(user_id=200UL),
    UpsertDaveMember(user_id=300UL),
  ])
  machine.handle(DaveMlsWelcome(transition_id=0, welcome=b"initial")) |> ignore
  fake.prepared_remotes.clear()
  fake.removed_remotes.clear()
  fake.activated_self.clear()
  machine.handle(ClientsConnect(user_ids=["400"])) |> ignore
  fake.commit_outcome = CommitApplied(changes=[
    RemoveDaveMember(user_id=300UL),
    UpsertDaveMember(user_id=400UL),
  ])
  assert_eq(
    machine.handle(
      DaveMlsAnnounceCommitTransition(transition_id=7, commit=b"delta"),
    ),
    [SendJson(encode_transition_ready(transition_id=7))],
  )
  assert_eq(fake.removed_remotes, [300UL])
  assert_eq(fake.prepared_remotes, [
    { user_id: 200UL, protocol_version: 1 },
    { user_id: 400UL, protocol_version: 1 },
  ])
  assert_eq(fake.activated_self, [])
  assert_eq(machine.handle(DaveExecuteTransition(transition_id=7)), [
    SwitchMediaContext(protocol_version=1),
  ])
  assert_eq(fake.activated_self, [1])
}

///|
test "DAVE Welcome applies a roster delta" {
  let fake = FakeDaveBackend::new()
  let machine = fake_machine(fake, roster=[200UL, 300UL])
  fake.welcome_outcome = WelcomeApplied(changes=[
    UpsertDaveMember(user_id=100UL),
    UpsertDaveMember(user_id=200UL),
    UpsertDaveMember(user_id=300UL),
  ])
  machine.handle(DaveMlsWelcome(transition_id=0, welcome=b"first")) |> ignore
  fake.prepared_remotes.clear()
  fake.removed_remotes.clear()
  fake.welcome_outcome = WelcomeApplied(changes=[
    RemoveDaveMember(user_id=300UL),
  ])
  assert_eq(
    machine.handle(DaveMlsWelcome(transition_id=8, welcome=b"replacement")),
    [SendJson(encode_transition_ready(transition_id=8))],
  )
  assert_eq(fake.welcome_calls[1], {
    payload: b"replacement",
    recognized_user_ids: [200UL, 300UL],
  })
  assert_eq(fake.removed_remotes, [300UL])
  assert_eq(fake.prepared_remotes, [{ user_id: 200UL, protocol_version: 1 }])
}

///|
test "DAVE empty Welcome delta preserves the current MLS roster" {
  let fake = FakeDaveBackend::new()
  let machine = fake_machine(fake, roster=[200UL])
  fake.welcome_outcome = WelcomeApplied(changes=[
    UpsertDaveMember(user_id=100UL),
    UpsertDaveMember(user_id=200UL),
  ])
  machine.handle(DaveMlsWelcome(transition_id=0, welcome=b"initial")) |> ignore
  fake.prepared_remotes.clear()
  fake.removed_remotes.clear()
  fake.welcome_outcome = WelcomeApplied(changes=[])
  assert_eq(
    machine.handle(DaveMlsWelcome(transition_id=8, welcome=b"same-roster")),
    [SendJson(encode_transition_ready(transition_id=8))],
  )
  assert_eq(fake.removed_remotes, [])
  assert_eq(fake.prepared_remotes, [{ user_id: 200UL, protocol_version: 1 }])
}

///|
test "DAVE failed commit reinitializes and invalidates only that transition" {
  let fake = FakeDaveBackend::new()
  let machine = fake_machine(fake)
  establish(fake, machine)
  machine.handle(DavePrepareTransition(transition_id=13, protocol_version=0))
  |> ignore
  fake.commit_outcome = CommitFailed(reason="bad commit")
  assert_eq(
    machine.handle(
      DaveMlsAnnounceCommitTransition(transition_id=13, commit=b"invalid"),
    ),
    [
      SendJson(encode_invalid_commit_welcome(transition_id=13)),
      SendBinary(op=26, payload=b"key-package"),
    ],
  )
  assert_eq(fake.reinitialized, [1])
  assert_eq(fake.key_package_calls, 1)
  assert_eq(machine.handle(DaveExecuteTransition(transition_id=13)), [])
}

///|
test "DAVE failed Welcome reinitializes while retaining the MLS roster" {
  let fake = FakeDaveBackend::new()
  let machine = fake_machine(fake, roster=[200UL])
  establish(fake, machine)
  fake.welcome_outcome = WelcomeApplied(changes=[
    UpsertDaveMember(user_id=100UL),
    UpsertDaveMember(user_id=200UL),
  ])
  machine.handle(DaveMlsWelcome(transition_id=0, welcome=b"initial")) |> ignore
  fake.reinitialized.clear()
  machine.handle(DavePrepareTransition(transition_id=14, protocol_version=1))
  |> ignore
  fake.welcome_outcome = WelcomeFailed(reason="bad Welcome")
  assert_eq(
    machine.handle(DaveMlsWelcome(transition_id=14, welcome=b"invalid")),
    [
      SendJson(encode_invalid_commit_welcome(transition_id=14)),
      SendBinary(op=26, payload=b"key-package"),
    ],
  )
  assert_eq(fake.reinitialized, [1])
  assert_eq(fake.key_package_calls, 1)
  assert_eq(machine.handle(DaveExecuteTransition(transition_id=14)), [])
  machine.handle(ClientDisconnect(user_id="200")) |> ignore
  fake.prepared_remotes.clear()
  machine.handle(ClientsConnect(user_ids=["200"])) |> ignore
  assert_eq(fake.prepared_remotes, [{ user_id: 200UL, protocol_version: 1 }])
  fake.welcome_outcome = WelcomeApplied(changes=[
    RemoveDaveMember(user_id=200UL),
  ])
  machine.handle(DaveMlsWelcome(transition_id=0, welcome=b"remove")) |> ignore
  assert_false(machine.has_remote_decryptor(user_id="200"))
}

///|
test "DAVE transition zero prepares remotes and switches self immediately" {
  let fake = FakeDaveBackend::new()
  let machine = fake_machine(fake, roster=[200UL])
  fake.welcome_outcome = WelcomeApplied(changes=[
    UpsertDaveMember(user_id=100UL),
    UpsertDaveMember(user_id=200UL),
  ])
  machine.handle(DaveMlsWelcome(transition_id=0, welcome=b"initial")) |> ignore
  fake.prepared_remotes.clear()
  fake.activated_self.clear()
  fake.reset_calls = 0
  assert_eq(
    machine.handle(DavePrepareTransition(transition_id=0, protocol_version=0)),
    [SwitchMediaContext(protocol_version=0)],
  )
  assert_eq(fake.prepared_remotes, [{ user_id: 200UL, protocol_version: 0 }])
  assert_eq(fake.activated_self, [0])
  assert_eq(fake.reset_calls, 1)
  assert_eq(machine.active_protocol_version(), 0)
  machine.handle(DavePrepareEpoch(epoch=1, protocol_version=1)) |> ignore
  fake.welcome_outcome = WelcomeApplied(changes=[
    RemoveDaveMember(user_id=200UL),
  ])
  machine.handle(DaveMlsWelcome(transition_id=0, welcome=b"remove")) |> ignore
  assert_false(machine.has_remote_decryptor(user_id="200"))
}

///|
test "DAVE tracks multiple pending transitions independently" {
  let fake = FakeDaveBackend::new()
  let machine = fake_machine(fake)
  assert_eq(
    machine.handle(DavePrepareTransition(transition_id=20, protocol_version=0)),
    [SendJson(encode_transition_ready(transition_id=20))],
  )
  assert_eq(
    machine.handle(DavePrepareTransition(transition_id=21, protocol_version=1)),
    [SendJson(encode_transition_ready(transition_id=21))],
  )
  assert_eq(fake.activated_self, [])
  assert_eq(machine.handle(DaveExecuteTransition(transition_id=21)), [
    SwitchMediaContext(protocol_version=1),
  ])
  assert_eq(machine.handle(DaveExecuteTransition(transition_id=20)), [
    SwitchMediaContext(protocol_version=0),
  ])
  assert_eq(fake.activated_self, [1, 0])
  assert_eq(fake.reset_calls, 1)
  assert_eq(machine.handle(DaveExecuteTransition(transition_id=21)), [])
}

///|
test "DAVE connected MLS member receives the latest prepared ratchet" {
  let fake = FakeDaveBackend::new()
  let machine = fake_machine(fake)
  fake.welcome_outcome = WelcomeApplied(changes=[
    UpsertDaveMember(user_id=100UL),
    UpsertDaveMember(user_id=200UL),
  ])
  machine.handle(DaveMlsWelcome(transition_id=0, welcome=b"roster")) |> ignore
  machine.handle(DavePrepareTransition(transition_id=22, protocol_version=1))
  |> ignore
  fake.prepared_remotes.clear()
  machine.handle(ClientsConnect(user_ids=["200"])) |> ignore
  assert_eq(fake.prepared_remotes, [{ user_id: 200UL, protocol_version: 1 }])
  assert_true(machine.has_remote_decryptor(user_id="200"))
}

///|
test "DAVE disconnect destroys the remote decryptor but keeps MLS membership" {
  let fake = FakeDaveBackend::new()
  let machine = fake_machine(fake, roster=[200UL])
  fake.welcome_outcome = WelcomeApplied(changes=[
    UpsertDaveMember(user_id=100UL),
    UpsertDaveMember(user_id=200UL),
  ])
  machine.handle(DaveMlsWelcome(transition_id=0, welcome=b"roster")) |> ignore
  assert_true(machine.has_remote_decryptor(user_id="200"))
  machine.handle(ClientDisconnect(user_id="200")) |> ignore
  assert_eq(fake.removed_remotes, [200UL])
  assert_false(machine.has_remote_decryptor(user_id="200"))
  fake.prepared_remotes.clear()
  machine.handle(ClientsConnect(user_ids=["200"])) |> ignore
  assert_eq(fake.prepared_remotes, [{ user_id: 200UL, protocol_version: 1 }])
}

///|
test "DAVE media always delegates with the actual SSRC and parsed user ID" {
  let fake = FakeDaveBackend::new()
  let machine = fake_machine(fake)
  assert_eq(
    machine.encrypt_opus_frame(ssrc=0x12345678U, b"opus"),
    b"encrypted-opus",
  )
  assert_eq(fake.encrypted_opus, [{ ssrc: 0x12345678U, frame: b"opus" }])
  assert_eq(
    machine.decrypt_opus_frame(user_id="200", b"ciphertext"),
    b"decrypted-opus",
  )
  assert_eq(fake.decrypted_opus, [{ user_id: 200UL, frame: b"ciphertext" }])
}

///|
test "DAVE rejects non-snowflake gateway user IDs before mutating the roster" {
  let fake = FakeDaveBackend::new()
  let machine = fake_machine(fake)
  try
    machine.handle(ClientsConnect(user_ids=["200", "not-a-snowflake"]))
    |> ignore
  catch {
    DaveInvalid(..) => ()
    error => fail("unexpected invalid-snowflake error: \{Repr(error)}")
  } noraise {
    _ => fail("expected an invalid-snowflake error")
  }
  machine.handle(DaveMlsProposals(payload=b"\x00proposal")) |> ignore
  assert_eq(fake.proposal_calls[0].recognized_user_ids, [])
}

///|
test "DAVE forwards the external sender package unchanged" {
  let fake = FakeDaveBackend::new()
  let machine = fake_machine(fake)
  assert_eq(machine.handle(DaveMlsExternalSender(payload=b"external")), [])
  assert_eq(fake.external_senders, [b"external"])
}
