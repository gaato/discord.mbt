///|
/// Errors reported by the DAVE MLS and media-encryption layer.
pub(all) suberror DaveError {
  DaveInvalid(reason~ : String)
  DaveStale(reason~ : String)
  DaveUnavailable(reason~ : String)
  DaveInternal(status~ : Int, reason~ : String)
} derive(Debug, Eq)

///|
/// Testable seam over a DAVE session implementation.
pub(open) trait DaveProvider {
  fn max_protocol_version(Self) -> Int
  fn reinit(Self, protocol_version~ : Int) -> Unit raise
  fn set_external_sender(Self, Bytes) -> Unit raise
  fn key_package(Self) -> Bytes raise
  fn process_proposals(
    Self,
    op_type~ : Int,
    payload : Bytes,
    recognized~ : Array[String],
  ) -> (Bytes?, Bytes?) raise
  fn process_commit(Self, Bytes) -> Unit raise
  fn process_welcome(Self, Bytes) -> Unit raise
  fn encrypt_frame(Self, Bytes) -> Bytes raise
  fn decrypt_frame(Self, user_id~ : String, Bytes) -> Bytes raise
  fn status(Self) -> Int
}

///|
/// Runtime-loaded Rust-shim implementation of `DaveProvider`.
pub struct LibdaveProvider {
  priv session : DaveSession
}

///|
fn raise_dave_status(status : Int) -> Unit raise DaveError {
  let reason = voice_shim_error_message()
  match status {
    -20 => raise DaveInvalid(reason~)
    -21 => raise DaveStale(reason~)
    -100 | -101 | -102 => raise DaveUnavailable(reason~)
    _ => raise DaveInternal(status~, reason~)
  }
}

///|
fn check_dave_status(status : Int) -> Unit raise DaveError {
  if status != 0 {
    raise_dave_status(status)
  }
}

///|
impl DaveProvider for LibdaveProvider with fn max_protocol_version(_self) {
  voice_shim_dave_max_protocol_version()
}

///|
impl DaveProvider for LibdaveProvider with fn reinit(self, protocol_version~) {
  check_dave_status(
    voice_shim_dave_session_reinit(self.session, protocol_version),
  )
}

///|
impl DaveProvider for LibdaveProvider with fn set_external_sender(self, payload) {
  check_dave_status(voice_shim_dave_set_external_sender(self.session, payload))
}

///|
impl DaveProvider for LibdaveProvider with fn key_package(self) {
  let result = voice_shim_dave_get_key_package(self.session)
  check_dave_status(voice_shim_last_status())
  result
}

///|
impl DaveProvider for LibdaveProvider with fn process_proposals(
  self,
  op_type~,
  payload,
  recognized~,
) {
  let recognized_bytes = recognized.map(user_id => @utf8.encode(user_id))
  let result = voice_shim_dave_process_proposals(
    self.session,
    op_type,
    payload,
    recognized_bytes,
  )
  check_dave_status(voice_shim_last_status())
  guard result is [commit, welcome] else {
    raise DaveInternal(status=-22, reason="invalid proposals result shape")
  }
  (
    if commit.length() == 0 {
      None
    } else {
      Some(commit)
    },
    if welcome.length() == 0 {
      None
    } else {
      Some(welcome)
    },
  )
}

///|
impl DaveProvider for LibdaveProvider with fn process_commit(self, payload) {
  check_dave_status(voice_shim_dave_process_commit(self.session, payload))
}

///|
impl DaveProvider for LibdaveProvider with fn process_welcome(self, payload) {
  check_dave_status(voice_shim_dave_process_welcome(self.session, payload))
}

///|
impl DaveProvider for LibdaveProvider with fn encrypt_frame(self, frame) {
  let result = voice_shim_dave_encrypt_opus(self.session, frame)
  check_dave_status(voice_shim_last_status())
  result
}

///|
impl DaveProvider for LibdaveProvider with fn decrypt_frame(
  self,
  user_id~,
  frame,
) {
  let result = voice_shim_dave_decrypt(
    self.session,
    @utf8.encode(user_id),
    frame,
  )
  check_dave_status(voice_shim_last_status())
  result
}

///|
impl DaveProvider for LibdaveProvider with fn status(self) {
  voice_shim_dave_session_status(self.session)
}

///|
/// Return the displayable pairwise DAVE verification code for a user.
pub fn LibdaveProvider::verification_code(
  self : LibdaveProvider,
  user_id~ : String,
) -> String raise DaveError {
  let result = voice_shim_dave_get_verification_code(
    self.session,
    @utf8.encode(user_id),
  )
  check_dave_status(voice_shim_last_status())
  @utf8.decode_lossy(result)
}

///|
/// Create a DAVE provider backed by the runtime-loaded voice shim.
pub fn new_dave_provider(
  protocol_version~ : Int,
  user_id~ : String,
  channel_id~ : UInt64,
) -> &DaveProvider raise DaveError {
  if !shim_available() {
    raise DaveUnavailable(
      reason=shim_unavailable_reason().unwrap_or("voice shim unavailable"),
    )
  }
  if protocol_version <= 0 || protocol_version > 65535 {
    raise DaveInternal(
      status=-1,
      reason="protocol_version must be in the range 1..65535",
    )
  }
  let session = voice_shim_dave_session_create(
    protocol_version,
    @utf8.encode(user_id),
    channel_id,
  )
  check_dave_status(voice_shim_last_status())
  LibdaveProvider::{ session, }
}

///|
/// Side effects requested by the pure DAVE orchestration state machine.
pub(all) enum DaveAction {
  SendJson(Json)
  SendBinary(op~ : Int, payload~ : Bytes)
  SwitchMediaContext(protocol_version~ : Int)
} derive(Debug, Eq)

///|
/// DAVE gateway/MLS orchestration. Networking remains outside this type.
pub struct DaveMachine {
  priv provider : &DaveProvider
  priv mut protocol_version : Int
  priv roster : Set[String]
  priv self_user_id : String
  priv pending : Map[Int, Int]
}

///|
pub fn DaveMachine::new(
  provider : &DaveProvider,
  self_user_id~ : String,
) -> DaveMachine {
  {
    provider,
    protocol_version: 0,
    roster: Set([]),
    self_user_id,
    pending: Map([]),
  }
}

///|
fn DaveMachine::set_pending(
  self : DaveMachine,
  transition_id : Int,
  protocol_version : Int,
) -> Unit {
  self.pending[transition_id] = protocol_version
}

///|
fn DaveMachine::transition_ready(
  self : DaveMachine,
  transition_id : Int,
) -> Array[DaveAction] {
  self.set_pending(transition_id, self.protocol_version)
  [SendJson(encode_transition_ready(transition_id~))]
}

///|
fn DaveMachine::recover_transition(
  self : DaveMachine,
  transition_id : Int,
) -> Array[DaveAction] raise {
  self.pending.remove(transition_id)
  self.provider.reinit(protocol_version=self.protocol_version)
  let key_package = self.provider.key_package()
  [
    SendJson(encode_invalid_commit_welcome(transition_id~)),
    SendBinary(op=26, payload=key_package),
  ]
}

///|
fn DaveMachine::handle_commit(
  self : DaveMachine,
  transition_id : Int,
  commit : Bytes,
) -> Array[DaveAction] raise {
  try {
    self.provider.process_commit(commit)
    self.transition_ready(transition_id)
  } catch {
    DaveStale(..) => self.transition_ready(transition_id)
    DaveInvalid(..) => self.recover_transition(transition_id)
    error => raise error
  }
}

///|
fn DaveMachine::handle_welcome(
  self : DaveMachine,
  transition_id : Int,
  welcome : Bytes,
) -> Array[DaveAction] raise {
  try {
    self.provider.process_welcome(welcome)
    self.transition_ready(transition_id)
  } catch {
    DaveStale(..) => self.transition_ready(transition_id)
    DaveInvalid(..) => self.recover_transition(transition_id)
    error => raise error
  }
}

///|
/// Handle one decoded voice-gateway message and return transport actions.
pub fn DaveMachine::handle(
  self : DaveMachine,
  message : VoiceMessage,
) -> Array[DaveAction] raise {
  match message {
    SessionDescription(dave_protocol_version~, ..) => {
      if dave_protocol_version >= 1 {
        self.protocol_version = dave_protocol_version
      }
      []
    }
    DaveMlsExternalSender(payload~) => {
      self.provider.set_external_sender(payload)
      []
    }
    DavePrepareEpoch(epoch~, protocol_version~) =>
      if epoch == 1 {
        self.protocol_version = protocol_version
        self.provider.reinit(protocol_version=self.protocol_version)
        [SendBinary(op=26, payload=self.provider.key_package())]
      } else {
        []
      }
    DaveMlsProposals(payload~) => {
      if payload.length() == 0 {
        raise DaveInvalid(reason="proposals payload is missing op_type")
      }
      let recognized = self.roster.to_array()
      if !recognized.contains(self.self_user_id) {
        recognized.push(self.self_user_id)
      }
      let (commit, welcome) = self.provider.process_proposals(
        op_type=payload[0].to_int(),
        payload[1:].to_owned(),
        recognized~,
      )
      match commit {
        Some(commit) =>
          [SendBinary(op=28, payload=commit + welcome.unwrap_or(b""))]
        None => []
      }
    }
    DaveMlsAnnounceCommitTransition(transition_id~, commit~) =>
      self.handle_commit(transition_id, commit)
    DaveMlsWelcome(transition_id~, welcome~) =>
      self.handle_welcome(transition_id, welcome)
    DavePrepareTransition(transition_id~, protocol_version~) =>
      if transition_id == 0 {
        self.protocol_version = protocol_version
        [SwitchMediaContext(protocol_version~)]
      } else {
        self.set_pending(transition_id, protocol_version)
        [SendJson(encode_transition_ready(transition_id~))]
      }
    DaveExecuteTransition(transition_id~) =>
      match self.pending.get(transition_id) {
        Some(protocol_version) => {
          self.protocol_version = protocol_version
          self.pending.remove(transition_id)
          [SwitchMediaContext(protocol_version=self.protocol_version)]
        }
        _ => []
      }
    ClientsConnect(user_ids~) => {
      for user_id in user_ids {
        self.roster.add(user_id)
      }
      []
    }
    ClientDisconnect(user_id~) => {
      self.roster.remove(user_id)
      []
    }
    _ => []
  }
}

///|
/// Encrypt an Opus frame only while a DAVE media context is selected.
pub fn DaveMachine::encrypt_opus_frame(
  self : DaveMachine,
  frame : Bytes,
) -> Bytes raise {
  if self.protocol_version == 0 {
    frame
  } else {
    self.provider.encrypt_frame(frame)
  }
}

///|
/// Decrypt an Opus frame only while a DAVE media context is selected.
fn DaveMachine::decrypt_opus_frame(
  self : DaveMachine,
  user_id~ : String,
  frame : Bytes,
) -> Bytes raise {
  if self.protocol_version == 0 {
    frame
  } else {
    self.provider.decrypt_frame(user_id~, frame)
  }
}
