///|
/// Errors reported while coordinating Discord's DAVE protocol.
pub(all) suberror DaveError {
  DaveInvalid(reason~ : String)
  DaveUnavailable(reason~ : String)
  DaveInternal(reason~ : String)
} derive(Debug, Eq)

///|
/// Side effects requested by the DAVE gateway/MLS orchestration state machine.
pub(all) enum DaveAction {
  SendJson(Json)
  SendBinary(op~ : Int, payload~ : Bytes)
  SwitchMediaContext(protocol_version~ : Int)
} derive(Debug, Eq)

///|
enum DaveRosterChange {
  UpsertDaveMember(user_id~ : UInt64)
  RemoveDaveMember(user_id~ : UInt64)
} derive(Debug, Eq)

///|
enum DaveCommitOutcome {
  CommitApplied(changes~ : Array[DaveRosterChange])
  CommitIgnored
  CommitFailed(reason~ : String)
} derive(Debug, Eq)

///|
enum DaveWelcomeOutcome {
  WelcomeApplied(changes~ : Array[DaveRosterChange])
  WelcomeFailed(reason~ : String)
} derive(Debug, Eq)

///|
/// The private seam between gateway orchestration and the official libdave
/// wrapper. Keeping this package-private lets white-box tests model protocol
/// outcomes without making an alternate crypto provider part of the API.
trait DaveBackend {
  fn protocol_version(Self) -> Int
  fn reinitialize(Self, protocol_version~ : Int) -> Unit raise DaveError
  fn reset(Self) -> Unit raise DaveError
  fn set_external_sender(Self, Bytes) -> Unit raise DaveError
  fn key_package(Self) -> Bytes raise DaveError
  fn process_proposals(Self, Bytes, recognized_user_ids~ : Array[UInt64]) -> Bytes raise DaveError
  fn process_commit(Self, Bytes) -> DaveCommitOutcome raise DaveError
  fn process_welcome(Self, Bytes, recognized_user_ids~ : Array[UInt64]) -> DaveWelcomeOutcome raise DaveError
  fn prepare_remote_ratchet(Self, user_id~ : UInt64, protocol_version~ : Int) -> Unit raise DaveError
  fn has_remote(Self, user_id~ : UInt64) -> Bool
  fn remove_remote(Self, user_id~ : UInt64) -> Unit
  fn activate_self_ratchet(Self, protocol_version~ : Int) -> Unit raise DaveError
  fn active_protocol_version(Self) -> Int
  fn encrypt_opus(Self, ssrc~ : UInt, Bytes) -> Bytes raise DaveError
  fn decrypt_opus(Self, user_id~ : UInt64, Bytes) -> Bytes raise DaveError
}

///|
priv struct LibdaveBackend {
  session : @dave.Session
  encryptor : @dave.Encryptor
  self_user_id : UInt64
  group_id : UInt64
  decryptors : Map[UInt64, @dave.Decryptor]
  assigned_opus_ssrcs : Set[UInt]
}

///|
fn[T] with_libdave(
  operation : String,
  action : () -> T raise,
) -> T raise DaveError {
  action() catch {
    @dave.DaveError::LibraryUnavailable(reason~) =>
      raise DaveUnavailable(reason~)
    @dave.DaveError::InvalidArgument(operation=dave_operation, reason~) =>
      raise DaveInvalid(reason="\{dave_operation}: \{reason}")
    @dave.DaveError::InvalidState(operation=dave_operation, reason~) =>
      raise DaveInvalid(reason="\{dave_operation}: \{reason}")
    error => raise DaveInternal(reason="\{operation}: \{Repr(error)}")
  }
}

///|
fn checked_protocol_version(
  protocol_version : Int,
  allow_disabled~ : Bool,
) -> UInt16 raise DaveError {
  if protocol_version < 0 || protocol_version > 65535 {
    raise DaveInvalid(
      reason="protocol_version must fit in an unsigned 16-bit integer",
    )
  }
  if !allow_disabled && protocol_version == 0 {
    raise DaveInvalid(reason="protocol_version must be greater than zero")
  }
  protocol_version.to_uint16()
}

///|
fn LibdaveBackend::new(
  protocol_version~ : Int,
  self_user_id~ : UInt64,
  channel_id~ : UInt64,
) -> LibdaveBackend raise DaveError {
  let version = checked_protocol_version(protocol_version, allow_disabled=false)
  let session = with_libdave("create MLS session", () => {
    @dave.Session::new(
      protocol_version=version,
      group_id=channel_id,
      self_user_id~,
    )
  })
  let encryptor = with_libdave("create media encryptor", () => {
    @dave.Encryptor::new()
  })
  with_libdave("enable initial media passthrough", () => {
    encryptor.set_passthrough_mode(enabled=true)
  })
  {
    session,
    encryptor,
    self_user_id,
    group_id: channel_id,
    decryptors: Map([]),
    assigned_opus_ssrcs: Set([]),
  }
}

///|
impl DaveBackend for LibdaveBackend with fn protocol_version(self) {
  self.session.protocol_version().to_int()
}

///|
impl DaveBackend for LibdaveBackend with fn reinitialize(
  self,
  protocol_version~,
) {
  let version = checked_protocol_version(protocol_version, allow_disabled=false)
  with_libdave("reinitialize MLS session", () => {
    self.session.reinitialize(
      protocol_version=version,
      group_id=self.group_id,
      self_user_id=self.self_user_id,
    )
  })
}

///|
impl DaveBackend for LibdaveBackend with fn reset(self) {
  with_libdave("reset MLS session", () => self.session.reset())
}

///|
impl DaveBackend for LibdaveBackend with fn set_external_sender(self, payload) {
  with_libdave("set MLS external sender", () => {
    self.session.set_external_sender(payload)
  })
}

///|
impl DaveBackend for LibdaveBackend with fn key_package(self) {
  with_libdave("create MLS key package", () => self.session.key_package())
}

///|
impl DaveBackend for LibdaveBackend with fn process_proposals(
  self,
  payload,
  recognized_user_ids~,
) {
  with_libdave("process MLS proposals", () => {
    self.session.process_proposals(payload, recognized_user_ids~)
  })
}

///|
impl DaveBackend for LibdaveBackend with fn process_commit(self, payload) {
  let result = with_libdave("process MLS commit", () => {
    self.session.process_commit(payload)
  })
  match result {
    Applied(changes~) => {
      let mapped = []
      for change in changes {
        match change {
          Upsert(user_id~, ..) => mapped.push(UpsertDaveMember(user_id~))
          Remove(user_id~) => mapped.push(RemoveDaveMember(user_id~))
        }
      }
      CommitApplied(changes=mapped)
    }
    Ignored => CommitIgnored
    Failed(failure~) =>
      CommitFailed(reason="\{failure.source}: \{failure.reason}")
  }
}

///|
impl DaveBackend for LibdaveBackend with fn process_welcome(
  self,
  payload,
  recognized_user_ids~,
) {
  let result = with_libdave("process MLS Welcome", () => {
    self.session.process_welcome(payload, recognized_user_ids~)
  })
  match result {
    Applied(changes~) => {
      let mapped = []
      for change in changes {
        match change {
          Upsert(user_id~, ..) => mapped.push(UpsertDaveMember(user_id~))
          Remove(user_id~) => mapped.push(RemoveDaveMember(user_id~))
        }
      }
      WelcomeApplied(changes=mapped)
    }
    Failed(failure~) =>
      WelcomeFailed(reason="\{failure.source}: \{failure.reason}")
  }
}

///|
fn LibdaveBackend::remote_decryptor(
  self : LibdaveBackend,
  user_id : UInt64,
) -> @dave.Decryptor raise DaveError {
  match self.decryptors.get(user_id) {
    Some(decryptor) => decryptor
    None => {
      let decryptor = with_libdave("create media decryptor", () => {
        @dave.Decryptor::new()
      })
      self.decryptors[user_id] = decryptor
      decryptor
    }
  }
}

///|
impl DaveBackend for LibdaveBackend with fn prepare_remote_ratchet(
  self,
  user_id~,
  protocol_version~,
) {
  checked_protocol_version(protocol_version, allow_disabled=true) |> ignore
  if protocol_version == 0 {
    let decryptor = self.remote_decryptor(user_id)
    with_libdave("prepare remote media passthrough", () => {
      decryptor.transition_to_passthrough_mode(enabled=true)
    })
    return
  }
  let ratchet = with_libdave("derive remote media ratchet", () => {
    self.session.key_ratchet(user_id~)
  })
  guard ratchet is Some(ratchet) else {
    self.decryptors.remove(user_id)
    raise DaveInvalid(reason="MLS has no key ratchet for user \{user_id}")
  }
  let decryptor = self.remote_decryptor(user_id)
  with_libdave("prepare remote media ratchet", () => {
    decryptor.transition_to_key_ratchet(ratchet)
  })
}

///|
impl DaveBackend for LibdaveBackend with fn remove_remote(self, user_id~) {
  self.decryptors.remove(user_id)
}

///|
impl DaveBackend for LibdaveBackend with fn has_remote(self, user_id~) {
  self.decryptors.contains(user_id)
}

///|
impl DaveBackend for LibdaveBackend with fn activate_self_ratchet(
  self,
  protocol_version~,
) {
  checked_protocol_version(protocol_version, allow_disabled=true) |> ignore
  if protocol_version == 0 {
    with_libdave("activate outbound media passthrough", () => {
      self.encryptor.set_passthrough_mode(enabled=true)
    })
    return
  }
  let ratchet = with_libdave("derive outbound media ratchet", () => {
    self.session.key_ratchet(user_id=self.self_user_id)
  })
  guard ratchet is Some(ratchet) else {
    raise DaveInvalid(reason="MLS has no key ratchet for the local user")
  }
  with_libdave("activate outbound media ratchet", () => {
    self.encryptor.set_key_ratchet(ratchet)
    self.encryptor.set_passthrough_mode(enabled=false)
  })
}

///|
impl DaveBackend for LibdaveBackend with fn active_protocol_version(self) {
  if self.encryptor.is_passthrough_mode() {
    0
  } else {
    self.encryptor.protocol_version().to_int()
  }
}

///|
impl DaveBackend for LibdaveBackend with fn encrypt_opus(self, ssrc~, frame) {
  if !self.assigned_opus_ssrcs.contains(ssrc) {
    with_libdave("assign outbound Opus SSRC", () => {
      self.encryptor.assign_ssrc_to_codec(ssrc~, codec=Opus)
    })
    self.assigned_opus_ssrcs.add(ssrc)
  }
  with_libdave("encrypt Opus frame", () => {
    self.encryptor.encrypt(media_type=Audio, ssrc~, frame)
  })
}

///|
impl DaveBackend for LibdaveBackend with fn decrypt_opus(self, user_id~, frame) {
  guard self.decryptors.get(user_id) is Some(decryptor) else {
    raise DaveInvalid(reason="no DAVE decryptor for user \{user_id}")
  }
  with_libdave("decrypt Opus frame", () => {
    decryptor.decrypt(media_type=Audio, frame)
  })
}

///|
/// DAVE gateway/MLS orchestration. Networking remains outside this type.
pub struct DaveMachine {
  priv backend : &DaveBackend
  priv self_user_id : UInt64
  priv connected_roster : Set[UInt64]
  priv mls_roster : Set[UInt64]
  priv pending : Map[Int, Int]
  priv mut latest_prepared_version : Int
}

///|
fn parse_snowflake(value : String, field : String) -> UInt64 raise DaveError {
  @string.parse_uint64(value) catch {
    _ => raise DaveInvalid(reason="\{field} is not a valid Discord snowflake")
  }
}

///|
fn parse_roster(roster : Array[String]) -> Set[UInt64] raise DaveError {
  let parsed : Set[UInt64] = Set([])
  for user_id in roster {
    parsed.add(parse_snowflake(user_id, "roster user ID"))
  }
  parsed
}

///|
/// Create the production DAVE state machine backed by the official libdave
/// wrapper. `protocol_version` is the version selected by the voice gateway.
pub fn DaveMachine::new(
  protocol_version~ : Int,
  self_user_id~ : String,
  channel_id~ : UInt64,
  roster? : Array[String] = [],
) -> DaveMachine raise DaveError {
  let local_user = parse_snowflake(self_user_id, "self user ID")
  let connected_roster = parse_roster(roster)
  connected_roster.remove(local_user)
  let backend = LibdaveBackend::new(
    protocol_version~,
    self_user_id=local_user,
    channel_id~,
  )
  {
    backend: (backend : &DaveBackend),
    self_user_id: local_user,
    connected_roster,
    mls_roster: Set([]),
    pending: Map([]),
    latest_prepared_version: 0,
  }
}

///|
fn DaveMachine::recognized_users(self : DaveMachine) -> Array[UInt64] {
  self.connected_roster.to_array()
}

///|
fn DaveMachine::remove_nonmembers(self : DaveMachine) -> Unit {
  for user_id in self.connected_roster {
    if !self.mls_roster.contains(user_id) {
      self.backend.remove_remote(user_id~)
    }
  }
}

///|
fn DaveMachine::prepare_remote_members(
  self : DaveMachine,
  protocol_version : Int,
) -> Unit raise DaveError {
  for user_id in self.connected_roster {
    if self.mls_roster.contains(user_id) {
      self.backend.prepare_remote_ratchet(user_id~, protocol_version~)
    }
  }
}

///|
fn DaveMachine::prepare_transition(
  self : DaveMachine,
  transition_id : Int,
  protocol_version : Int,
) -> Array[DaveAction] raise DaveError {
  checked_protocol_version(protocol_version, allow_disabled=true) |> ignore
  self.prepare_remote_members(protocol_version)
  self.latest_prepared_version = protocol_version
  if transition_id == 0 {
    self.pending.remove(transition_id)
    self.backend.activate_self_ratchet(protocol_version~)
    if protocol_version == 0 {
      self.backend.reset()
    }
    [SwitchMediaContext(protocol_version~)]
  } else {
    self.pending[transition_id] = protocol_version
    [SendJson(encode_transition_ready(transition_id~))]
  }
}

///|
fn DaveMachine::recover_invalid_group(
  self : DaveMachine,
  transition_id : Int,
) -> Array[DaveAction] raise DaveError {
  self.pending.remove(transition_id)
  let protocol_version = self.backend.protocol_version()
  self.backend.reinitialize(protocol_version~)
  [
    SendJson(encode_invalid_commit_welcome(transition_id~)),
    SendBinary(op=26, payload=self.backend.key_package()),
  ]
}

///|
fn DaveMachine::handle_commit(
  self : DaveMachine,
  transition_id : Int,
  commit : Bytes,
) -> Array[DaveAction] raise DaveError {
  match self.backend.process_commit(commit) {
    CommitIgnored => []
    CommitFailed(..) => self.recover_invalid_group(transition_id)
    CommitApplied(changes~) => {
      for change in changes {
        match change {
          UpsertDaveMember(user_id~) => self.mls_roster.add(user_id)
          RemoveDaveMember(user_id~) => self.mls_roster.remove(user_id)
        }
      }
      self.remove_nonmembers()
      self.prepare_transition(transition_id, self.backend.protocol_version())
    }
  }
}

///|
fn DaveMachine::handle_welcome(
  self : DaveMachine,
  transition_id : Int,
  welcome : Bytes,
) -> Array[DaveAction] raise DaveError {
  match
    self.backend.process_welcome(
      welcome,
      recognized_user_ids=self.recognized_users(),
    ) {
    WelcomeFailed(..) => self.recover_invalid_group(transition_id)
    WelcomeApplied(changes~) => {
      for change in changes {
        match change {
          UpsertDaveMember(user_id~) => self.mls_roster.add(user_id)
          RemoveDaveMember(user_id~) => self.mls_roster.remove(user_id)
        }
      }
      self.remove_nonmembers()
      self.prepare_transition(transition_id, self.backend.protocol_version())
    }
  }
}

///|
/// Handle one decoded voice-gateway message and return transport actions.
pub fn DaveMachine::handle(
  self : DaveMachine,
  message : VoiceMessage,
) -> Array[DaveAction] raise DaveError {
  match message {
    SessionDescription(dave_protocol_version~, ..) =>
      if dave_protocol_version >= 1 {
        self.backend.reinitialize(protocol_version=dave_protocol_version)
        [SendBinary(op=26, payload=self.backend.key_package())]
      } else {
        self.prepare_transition(0, 0)
      }
    DaveMlsExternalSender(payload~) => {
      self.backend.set_external_sender(payload)
      []
    }
    DavePrepareEpoch(epoch~, protocol_version~) =>
      if epoch == 1 {
        self.backend.reinitialize(protocol_version~)
        [SendBinary(op=26, payload=self.backend.key_package())]
      } else {
        []
      }
    DaveMlsProposals(payload~) => {
      if payload.length() == 0 {
        raise DaveInvalid(reason="proposals payload is empty")
      }
      let commit_welcome = self.backend.process_proposals(
        payload,
        recognized_user_ids=self.recognized_users(),
      )
      [SendBinary(op=28, payload=commit_welcome)]
    }
    DaveMlsAnnounceCommitTransition(transition_id~, commit~) =>
      self.handle_commit(transition_id, commit)
    DaveMlsWelcome(transition_id~, welcome~) =>
      self.handle_welcome(transition_id, welcome)
    DavePrepareTransition(transition_id~, protocol_version~) =>
      self.prepare_transition(transition_id, protocol_version)
    DaveExecuteTransition(transition_id~) =>
      match self.pending.get(transition_id) {
        Some(protocol_version) => {
          self.pending.remove(transition_id)
          self.backend.activate_self_ratchet(protocol_version~)
          if protocol_version == 0 {
            self.backend.reset()
          }
          [SwitchMediaContext(protocol_version~)]
        }
        None => []
      }
    ClientsConnect(user_ids~) => {
      let parsed = []
      for user_id in user_ids {
        parsed.push(parse_snowflake(user_id, "connected user ID"))
      }
      for user_id in parsed {
        if user_id != self.self_user_id {
          self.connected_roster.add(user_id)
          if self.mls_roster.contains(user_id) {
            self.backend.prepare_remote_ratchet(
              user_id~,
              protocol_version=self.latest_prepared_version,
            )
          }
        }
      }
      []
    }
    ClientDisconnect(user_id~) => {
      let parsed = parse_snowflake(user_id, "disconnected user ID")
      self.connected_roster.remove(parsed)
      self.backend.remove_remote(user_id=parsed)
      []
    }
    _ => []
  }
}

///|
/// Return the protocol version currently selected for outbound media.
pub fn DaveMachine::active_protocol_version(self : DaveMachine) -> Int {
  self.backend.active_protocol_version()
}

///|
/// Whether a remote participant currently has a libdave decryptor. Receive
/// routing uses this independently of the active outbound protocol so that
/// libdave, not the caller, owns its old/new-key transition window.
fn DaveMachine::has_remote_decryptor(
  self : DaveMachine,
  user_id~ : String,
) -> Bool raise DaveError {
  self.backend.has_remote(
    user_id=parse_snowflake(user_id, "DAVE sender user ID"),
  )
}

///|
/// Encrypt one Opus frame. Passthrough is delegated to libdave as well, so
/// the encryptor remains the sole owner of media-transition state.
pub fn DaveMachine::encrypt_opus_frame(
  self : DaveMachine,
  ssrc~ : UInt,
  frame : Bytes,
) -> Bytes raise DaveError {
  self.backend.encrypt_opus(ssrc~, frame)
}

///|
/// Decrypt one Opus frame for its Discord user ID.
fn DaveMachine::decrypt_opus_frame(
  self : DaveMachine,
  user_id~ : String,
  frame : Bytes,
) -> Bytes raise DaveError {
  self.backend.decrypt_opus(
    user_id=parse_snowflake(user_id, "DAVE sender user ID"),
    frame,
  )
}
