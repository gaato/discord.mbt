///|
enum FakeDaveFailure {
  FakeDaveOk
  FakeDaveInvalid
  FakeDaveStale
}

///|
struct FakeProposalCall {
  op_type : Int
  payload : Bytes
  recognized : Array[String]
} derive(Debug, Eq)

///|
struct FakeDave {
  reinit_versions : Array[Int]
  external_senders : Array[Bytes]
  proposal_calls : Array[FakeProposalCall]
  commits : Array[Bytes]
  welcomes : Array[Bytes]
  encrypted_frames : Array[Bytes]
  mut key_package_calls : Int
  mut proposal_commit : Bytes?
  mut proposal_welcome : Bytes?
  mut commit_failure : FakeDaveFailure
  welcome_failure : FakeDaveFailure
}

///|
fn FakeDave::new() -> FakeDave {
  {
    reinit_versions: [],
    external_senders: [],
    proposal_calls: [],
    commits: [],
    welcomes: [],
    encrypted_frames: [],
    key_package_calls: 0,
    proposal_commit: Some(b"commit"),
    proposal_welcome: Some(b"welcome"),
    commit_failure: FakeDaveOk,
    welcome_failure: FakeDaveOk,
  }
}

///|
impl @voice.DaveProvider for FakeDave with fn max_protocol_version(_self) {
  1
}

///|
impl @voice.DaveProvider for FakeDave with fn reinit(self, protocol_version~) {
  self.reinit_versions.push(protocol_version)
}

///|
impl @voice.DaveProvider for FakeDave with fn set_external_sender(self, payload) {
  self.external_senders.push(payload)
}

///|
impl @voice.DaveProvider for FakeDave with fn key_package(self) {
  self.key_package_calls += 1
  b"key-package"
}

///|
impl @voice.DaveProvider for FakeDave with fn process_proposals(
  self,
  op_type~,
  payload,
  recognized~,
) {
  self.proposal_calls.push({ op_type, payload, recognized: recognized.copy() })
  (self.proposal_commit, self.proposal_welcome)
}

///|
impl @voice.DaveProvider for FakeDave with fn process_commit(self, commit) {
  self.commits.push(commit)
  match self.commit_failure {
    FakeDaveOk => ()
    FakeDaveInvalid =>
      raise @voice.DaveError::DaveInvalid(reason="invalid commit")
    FakeDaveStale => raise @voice.DaveError::DaveStale(reason="stale commit")
  }
}

///|
impl @voice.DaveProvider for FakeDave with fn process_welcome(self, welcome) {
  self.welcomes.push(welcome)
  match self.welcome_failure {
    FakeDaveOk => ()
    FakeDaveInvalid =>
      raise @voice.DaveError::DaveInvalid(reason="invalid welcome")
    FakeDaveStale => raise @voice.DaveError::DaveStale(reason="stale welcome")
  }
}

///|
impl @voice.DaveProvider for FakeDave with fn encrypt_frame(self, frame) {
  self.encrypted_frames.push(frame)
  b"dave:" + frame
}

///|
impl @voice.DaveProvider for FakeDave with fn decrypt_frame(
  _self,
  user_id~,
  frame,
) {
  @utf8.encode(user_id) + b":" + frame
}

///|
impl @voice.DaveProvider for FakeDave with fn status(_self) {
  0
}

///|
fn fake_machine(fake : FakeDave) -> @voice.DaveMachine {
  @voice.DaveMachine::new((fake : &@voice.DaveProvider), self_user_id="100")
}

///|
fn establish_dave(machine : @voice.DaveMachine) -> Unit raise {
  assert_eq(
    machine.handle(
      SessionDescription(
        mode="aead_aes256_gcm_rtpsize",
        secret_key=Bytes::new(32),
        dave_protocol_version=1,
      ),
    ),
    [],
  )
}

///|
test "DAVE fresh-call flow creates and executes the pending epoch" {
  let fake = FakeDave::new()
  let machine = fake_machine(fake)
  assert_eq(machine.handle(DaveMlsExternalSender(payload=b"external")), [])
  assert_eq(fake.external_senders, [b"external"])
  assert_eq(machine.handle(DavePrepareEpoch(epoch=2, protocol_version=1)), [])
  assert_eq(machine.handle(DavePrepareEpoch(epoch=1, protocol_version=1)), [
    SendBinary(op=26, payload=b"key-package"),
  ])
  assert_eq(fake.reinit_versions, [1])
  assert_eq(fake.key_package_calls, 1)
  assert_eq(machine.handle(DaveMlsProposals(payload=b"\x00proposals")), [
    SendBinary(op=28, payload=b"commitwelcome"),
  ])
  assert_eq(
    machine.handle(
      DaveMlsAnnounceCommitTransition(transition_id=7, commit=b"commit"),
    ),
    [SendJson(@voice.encode_transition_ready(transition_id=7))],
  )
  assert_eq(machine.handle(DaveExecuteTransition(transition_id=7)), [
    SwitchMediaContext(protocol_version=1),
  ])
  assert_eq(machine.encrypt_opus_frame(b"opus"), b"dave:opus")
}

///|
test "DAVE joiner accepts Welcome and acknowledges the transition" {
  let fake = FakeDave::new()
  let machine = fake_machine(fake)
  establish_dave(machine)
  machine.handle(DaveMlsExternalSender(payload=b"external")) |> ignore
  assert_eq(
    machine.handle(DaveMlsWelcome(transition_id=11, welcome=b"joiner-welcome")),
    [SendJson(@voice.encode_transition_ready(transition_id=11))],
  )
  assert_eq(fake.welcomes, [b"joiner-welcome"])
}

///|
test "DAVE downgrade switches media only on Execute Transition" {
  let fake = FakeDave::new()
  let machine = fake_machine(fake)
  establish_dave(machine)
  assert_eq(machine.encrypt_opus_frame(b"before"), b"dave:before")
  assert_eq(
    machine.handle(DavePrepareTransition(transition_id=12, protocol_version=0)),
    [SendJson(@voice.encode_transition_ready(transition_id=12))],
  )
  assert_eq(machine.encrypt_opus_frame(b"pending"), b"dave:pending")
  assert_eq(machine.handle(DaveExecuteTransition(transition_id=12)), [
    SwitchMediaContext(protocol_version=0),
  ])
  assert_eq(machine.encrypt_opus_frame(b"plain"), b"plain")
}

///|
test "DAVE transition ID zero executes immediately without transition ready" {
  let fake = FakeDave::new()
  let machine = fake_machine(fake)
  establish_dave(machine)
  assert_eq(
    machine.handle(DavePrepareTransition(transition_id=0, protocol_version=0)),
    [SwitchMediaContext(protocol_version=0)],
  )
  assert_eq(machine.encrypt_opus_frame(b"plain"), b"plain")
  assert_eq(machine.handle(DaveExecuteTransition(transition_id=0)), [])
}

///|
test "DAVE tracks and executes multiple pending transitions independently" {
  let fake = FakeDave::new()
  let machine = fake_machine(fake)
  establish_dave(machine)
  assert_eq(
    machine.handle(DavePrepareTransition(transition_id=20, protocol_version=0)),
    [SendJson(@voice.encode_transition_ready(transition_id=20))],
  )
  assert_eq(
    machine.handle(DavePrepareTransition(transition_id=21, protocol_version=1)),
    [SendJson(@voice.encode_transition_ready(transition_id=21))],
  )
  assert_eq(machine.handle(DaveExecuteTransition(transition_id=21)), [
    SwitchMediaContext(protocol_version=1),
  ])
  assert_eq(machine.handle(DaveExecuteTransition(transition_id=20)), [
    SwitchMediaContext(protocol_version=0),
  ])
  assert_eq(machine.handle(DaveExecuteTransition(transition_id=21)), [])
}

///|
test "DAVE invalid commit requests recovery and publishes a new key package" {
  let fake = FakeDave::new()
  fake.commit_failure = FakeDaveInvalid
  let machine = fake_machine(fake)
  establish_dave(machine)
  machine.handle(DavePrepareTransition(transition_id=13, protocol_version=0))
  |> ignore
  assert_eq(
    machine.handle(
      DaveMlsAnnounceCommitTransition(transition_id=13, commit=b"invalid"),
    ),
    [
      SendJson(@voice.encode_invalid_commit_welcome(transition_id=13)),
      SendBinary(op=26, payload=b"key-package"),
    ],
  )
  assert_eq(fake.reinit_versions, [1])
  assert_eq(fake.key_package_calls, 1)
  assert_eq(machine.handle(DaveExecuteTransition(transition_id=13)), [])
}

///|
test "DAVE stale commit is acknowledged without invalid-transition recovery" {
  let fake = FakeDave::new()
  fake.commit_failure = FakeDaveStale
  let machine = fake_machine(fake)
  establish_dave(machine)
  assert_eq(
    machine.handle(
      DaveMlsAnnounceCommitTransition(transition_id=14, commit=b"stale"),
    ),
    [SendJson(@voice.encode_transition_ready(transition_id=14))],
  )
  assert_eq(fake.reinit_versions, [])
  assert_eq(fake.key_package_calls, 0)
}

///|
test "DAVE proposals receive the current roster plus the local user" {
  let fake = FakeDave::new()
  fake.proposal_commit = None
  fake.proposal_welcome = None
  let machine = fake_machine(fake)
  establish_dave(machine)
  machine.handle(ClientsConnect(user_ids=["200", "300"])) |> ignore
  machine.handle(ClientDisconnect(user_id="200")) |> ignore
  assert_eq(machine.handle(DaveMlsProposals(payload=b"\x01revoke")), [])
  assert_eq(fake.proposal_calls, [
    { op_type: 1, payload: b"revoke", recognized: ["300", "100"] },
  ])
}
