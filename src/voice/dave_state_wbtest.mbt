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
  mut fail_external_sender : Bool
  mut fail_reinitialize : Bool
  mut fail_encrypt : Bool
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
    fail_external_sender: false,
    fail_reinitialize: false,
    fail_encrypt: false,
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
  if self.fail_reinitialize {
    raise DaveInternal(reason="fake reinitialize failure")
  }
  self.session_version = protocol_version
  self.reinitialized.push(protocol_version)
}

///|
impl DaveBackend for FakeDaveBackend with fn reset(self) {
  self.reset_calls += 1
}

///|
impl DaveBackend for FakeDaveBackend with fn set_external_sender(self, payload) {
  if self.fail_external_sender {
    raise DaveInvalid(reason="fake external sender failure")
  }
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
  self.prepared_remotes.push({ user_id, protocol_version, })
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
  if self.fail_encrypt {
    raise DaveInvalid(reason="fake encrypt failure")
  }
  self.encrypted_opus.push({ ssrc, frame, })
  b"encrypted-opus"
}

///|
impl DaveBackend for FakeDaveBackend with fn decrypt_opus(self, user_id~, frame) {
  self.decrypted_opus.push({ user_id, frame, })
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
    { payload: b"\x01revoke", recognized_user_ids: [300UL], },
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
    { user_id: 200UL, protocol_version: 1, },
    { user_id: 400UL, protocol_version: 1, },
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
  assert_eq(fake.prepared_remotes, [{ user_id: 200UL, protocol_version: 1, }])
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
  assert_eq(fake.prepared_remotes, [{ user_id: 200UL, protocol_version: 1, }])
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
  assert_eq(fake.prepared_remotes, [{ user_id: 200UL, protocol_version: 1, }])
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
  assert_eq(fake.prepared_remotes, [{ user_id: 200UL, protocol_version: 0, }])
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
  assert_eq(fake.prepared_remotes, [{ user_id: 200UL, protocol_version: 1, }])
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
  assert_eq(fake.prepared_remotes, [{ user_id: 200UL, protocol_version: 1, }])
}

///|
test "DAVE media always delegates with the actual SSRC and parsed user ID" {
  let fake = FakeDaveBackend::new()
  let machine = fake_machine(fake)
  assert_eq(
    machine.encrypt_opus_frame(ssrc=0x12345678U, b"opus"),
    b"encrypted-opus",
  )
  assert_eq(fake.encrypted_opus, [{ ssrc: 0x12345678U, frame: b"opus", }])
  assert_eq(
    machine.decrypt_opus_frame(user_id="200", b"ciphertext"),
    b"decrypted-opus",
  )
  assert_eq(fake.decrypted_opus, [{ user_id: 200UL, frame: b"ciphertext", }])
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

///|
struct DaveConnectionTransport {
  incoming : @aqueue.Queue[VoiceFrame]
  text : @aqueue.Queue[Json]
  binary : @aqueue.Queue[Bytes]
}

///|
fn DaveConnectionTransport::DaveConnectionTransport() -> DaveConnectionTransport {
  {
    incoming: Queue(kind=Unbounded),
    text: Queue(kind=Unbounded),
    binary: Queue(kind=Unbounded),
  }
}

///|
impl VoiceTransport for DaveConnectionTransport with fn recv(self) {
  self.incoming.get()
}

///|
impl VoiceTransport for DaveConnectionTransport with fn send_text(self, text) {
  self.text.put(@json.parse(text))
}

///|
impl VoiceTransport for DaveConnectionTransport with fn send_binary(self, bytes) {
  self.binary.put(bytes)
}

///|
impl VoiceTransport for DaveConnectionTransport with fn close(self, code~) {
  self.incoming.close(
    error=VoiceTransportClosed(code=Some(code), reason="closed"),
  )
}

///|
fn[X] dave_test_connection(
  group : @async.TaskGroup[X],
  transport : DaveConnectionTransport,
  telemetry : Array[VoiceTelemetry],
) -> VoiceConnection {
  let parked : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
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
    telemetry=event => telemetry.push(event),
    sleeper=_ => parked.get(),
  )
}

///|
async fn identify_dave_test_connection(
  transport : DaveConnectionTransport,
) -> Unit {
  transport.incoming.put(
    Text("{\"op\":8,\"d\":{\"heartbeat_interval\":60000}}"),
  )
  guard! transport.text.get() is { "op": Number(0, ..), .. }
}

///|
async test "voice connection DAVE controls preserve roster events and report failed control sends" {
  let transport = DaveConnectionTransport()
  let telemetry : Array[VoiceTelemetry] = []
  let fake = FakeDaveBackend::new()
  @async.with_task_group(group => {
    let connection = dave_test_connection(group, transport, telemetry)
    connection.dave = Some(fake_machine(fake))
    identify_dave_test_connection(transport)
    connection.handle_message(ClientsConnect(user_ids=["200"]))
    assert_eq(connection.next_event(), UserConnected(user_id="200"))
    assert_true(connection.roster.contains("200"))
    connection.handle_message(ClientDisconnect(user_id="200"))
    assert_eq(connection.next_event(), UserDisconnected(user_id="200"))
    assert_false(connection.roster.contains("200"))
    connection.handle_message(
      DavePrepareTransition(transition_id=7, protocol_version=0),
    )
    assert_eq(transport.text.get(), encode_transition_ready(transition_id=7))
    connection.handle_message(DaveMlsProposals(payload=b""))
    assert_true(
      telemetry.any(event => {
        event is PacketDropped(reason~) && reason.has_prefix("DAVE control:")
      }),
    )
    transport.text.close(
      error=VoiceTransportClosed(code=None, reason="fake send failure"),
    )
    connection.handle_message(
      DavePrepareTransition(transition_id=8, protocol_version=0),
    )
    assert_true(
      telemetry.any(event => {
        event is PacketDropped(reason~) && reason.has_prefix("DAVE send:")
      }),
    )
    connection.disconnect()
  })
}

///|
async test "voice connection DAVE session failures close the connection with the backend reason" {
  if !shim_available() {
    return
  }
  for external_sender in [false, true] {
    let transport = DaveConnectionTransport()
    let telemetry : Array[VoiceTelemetry] = []
    let fake = FakeDaveBackend::new()
    @async.with_task_group(group => {
      let connection = dave_test_connection(group, transport, telemetry)
      connection.dave = Some(fake_machine(fake))
      identify_dave_test_connection(transport)
      if external_sender {
        fake.fail_external_sender = true
        connection.pending_dave_external_sender = Some(b"external")
      } else {
        fake.fail_reinitialize = true
      }
      connection.establish_session("aead_aes256_gcm_rtpsize", Bytes::new(32), 1)
      assert_eq(connection.state(), Closed(code=None))
      try connection.wait_ready() catch {
        VoiceError::ShimUnavailable(reason~) =>
          assert_eq(
            reason,
            if external_sender {
              "DAVE: fake external sender failure"
            } else {
              "DAVE: fake reinitialize failure"
            },
          )
        error => fail("unexpected DAVE session failure: \{Repr(error)}")
      } noraise {
        _ => fail("expected failed DAVE session")
      }
      connection.disconnect()
    })
  }
}

///|
async test "voice connection reports initial DAVE key package send failure" {
  if !shim_available() {
    return
  }
  let transport = DaveConnectionTransport()
  let telemetry : Array[VoiceTelemetry] = []
  @async.with_task_group(group => {
    let connection = dave_test_connection(group, transport, telemetry)
    connection.dave = Some(fake_machine(FakeDaveBackend::new()))
    identify_dave_test_connection(transport)
    transport.binary.close(
      error=VoiceTransportClosed(code=None, reason="fake binary failure"),
    )
    connection.establish_session("aead_aes256_gcm_rtpsize", Bytes::new(32), 1)
    assert_eq(connection.next_event(), ConnectionReady)
    assert_true(
      telemetry.any(event => {
        event is PacketDropped(reason~) && reason.has_prefix("DAVE send:")
      }),
    )
    connection.disconnect()
  })
}

///|
async test "voice connection removes a subscription whose queue has failed" {
  let transport = DaveConnectionTransport()
  @async.with_task_group(group => {
    let connection = dave_test_connection(group, transport, [])
    let subscription = connection.subscribe(user_id="200")
    subscription.queue.close(error=VoiceError::Disconnected)
    let event = VoiceEvent::OpusReceived(
      user_id=Some("200"),
      ssrc=42U,
      sequence=1,
      timestamp=960U,
      opus=b"opus",
    )
    connection.emit(event)
    assert_eq(connection.next_event(), event)
    assert_eq(connection.subscriptions.length(), 0)
    connection.disconnect()
  })
}

///|
struct DaveConnectionUdp {
  sent : @aqueue.Queue[Bytes]
}

///|
impl VoiceUdp for DaveConnectionUdp with fn send(self, bytes) {
  self.sent.put(bytes)
}

///|
impl VoiceUdp for DaveConnectionUdp with fn recv(_self, _buffer) {
  fail("unexpected receive")
}

///|
impl VoiceUdp for DaveConnectionUdp with fn close(_self) {
  ()
}

///|
struct DaveConnectionAudio {
  requests : @aqueue.Queue[Unit]
  frames : @aqueue.Queue[Bytes?]
}

///|
fn DaveConnectionAudio::DaveConnectionAudio() -> DaveConnectionAudio {
  { requests: Queue(kind=Unbounded), frames: Queue(kind=Unbounded), }
}

///|
impl AudioSource for DaveConnectionAudio with fn next_frame(self) {
  self.requests.put(())
  self.frames.get()
}

///|
async test "voice playback reports DAVE drops and source failures and replaces stopped sources" {
  if !shim_available() {
    return
  }
  let transport = DaveConnectionTransport()
  let fake = FakeDaveBackend::new()
  let dropped : @aqueue.Queue[VoiceTelemetry] = Queue(kind=Unbounded)
  let udp = DaveConnectionUdp::{ sent: Queue(kind=Unbounded), }
  let first = DaveConnectionAudio()
  let replacement = DaveConnectionAudio()
  let parked : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
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
      leave=() => (),
      rejoin=() => fail("unexpected rejoin"),
      connector=_ => (transport : &VoiceTransport),
      receive=false,
      sleeper=_ => parked.get(),
      telemetry=event => try! (dropped.try_put(event) |> ignore),
    )
    identify_dave_test_connection(transport)
    connection.dave = Some(fake_machine(fake))
    connection.establish_session("aead_aes256_gcm_rtpsize", Bytes::new(32), 0)
    assert_eq(connection.next_event(), ConnectionReady)
    connection.udp = Some(udp)
    connection.ssrc = Some(42U)
    connection.play(first)
    guard! transport.text.get() is { "op": Number(5, ..), .. }
    first.requests.get()
    fake.fail_encrypt = true
    first.frames.put(Some(b"opus"))
    for event = dropped.get(); ; event = dropped.get() {
      if event is DaveEncryptDropped(reason~) {
        assert_eq(reason, "fake encrypt failure")
        break
      }
    }
    first.requests.get()
    let stop = connection.playback_stop.unwrap()
    connection.play(replacement)
    assert_true(stop.val)
    first.frames.close(error=VoiceError::Disconnected)
    for event = dropped.get(); ; event = dropped.get() {
      if event is PacketDropped(reason~) {
        assert_true(reason.has_prefix("send loop:"))
        break
      }
    }
    guard! transport.text.get() is { "op": Number(5, ..), .. }
    replacement.requests.get()
    let replacement_stop = connection.playback_stop.unwrap()
    connection.reset_session()
    assert_true(replacement_stop.val)
    let stopping = group.spawn(no_wait=true, () => connection.stop())
    @async.pause()
    replacement.frames.close(error=VoiceError::Disconnected)
    stopping.wait()
    assert_true(connection.playback_stop is None)
    connection.disconnect()
  })
}

///|
async test "voice playback discards sources superseded in the queue and during setup" {
  if !shim_available() {
    return
  }
  let transport = DaveConnectionTransport()
  let discarded = DaveConnectionAudio()
  let waiting = DaveConnectionAudio()
  let current = DaveConnectionAudio()
  let udp = DaveConnectionUdp::{ sent: Queue(kind=Unbounded), }
  @async.with_task_group(group => {
    let connection = dave_test_connection(group, transport, [])
    identify_dave_test_connection(transport)
    connection.play(discarded)
    connection.play(waiting)
    @async.pause()
    connection.stop()
    connection.dave = Some(fake_machine(FakeDaveBackend::new()))
    connection.establish_session("aead_aes256_gcm_rtpsize", Bytes::new(32), 0)
    connection.udp = Some(udp)
    connection.ssrc = Some(42U)
    connection.play(current)
    current.requests.get()
    assert_eq(discarded.requests.try_get(), None)
    assert_eq(waiting.requests.try_get(), None)
    connection.disconnect()
  })
}
