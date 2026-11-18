///|
/// Whether the bundled native libdave runtime is available to this process.
pub fn available() -> Bool {
  @ffi.available()
}

///|
/// Explain why native libdave support is unavailable, if it is unavailable.
pub fn unavailable_reason() -> String? {
  if available() {
    None
  } else {
    let reason = @ffi.unavailable_reason()
    Some(if reason == "" { "libdave is unavailable" } else { reason })
  }
}

///|
/// Return the maximum DAVE protocol version supported by the loaded libdave.
///
/// This returns zero when the native library is unavailable. It does not
/// identify the libdave ABI or release version.
pub fn max_supported_protocol_version() -> UInt16 {
  @ffi.max_supported_protocol_version()
}

///|
fn require_available(operation : String) -> Unit raise DaveError {
  if !available() {
    let reason = unavailable_reason().unwrap_or("libdave is unavailable")
    raise LibraryUnavailable(reason="\{reason} (required by \{operation})")
  }
}

///|
fn validate_protocol_version(
  operation : String,
  protocol_version : UInt16,
) -> Unit raise DaveError {
  require_available(operation)
  let maximum = max_supported_protocol_version()
  if protocol_version > maximum {
    raise InvalidArgument(
      operation~,
      reason="protocol_version \{protocol_version} exceeds the supported maximum " +
        maximum.to_string(),
    )
  }
}

///|
fn validate_initial_protocol_version(
  operation : String,
  protocol_version : UInt16,
) -> Unit raise DaveError {
  if protocol_version == 0 {
    raise InvalidArgument(
      operation~,
      reason="protocol_version must be greater than zero",
    )
  }
  validate_protocol_version(operation, protocol_version)
}

///|
/// A stateful MLS session.
///
/// The native handle is owned by this value and released by a finalizer. A
/// copied `Session` aliases the same mutable native session, so calls on the
/// same session must be serialized by the application.
pub struct Session {
  priv raw : @ffi.RawSession
  priv self_user_id : Ref[UInt64]
  priv has_group_context : Ref[Bool]
  priv has_external_sender : Ref[Bool]
}

///|
/// A key ratchet derived from an established MLS session.
///
/// Installing a ratchet into an encryptor or decryptor copies its native key
/// state. The `KeyRatchet` therefore remains independently owned and may be
/// collected after installation.
pub struct KeyRatchet {
  priv raw : @ffi.RawKeyRatchet
}

///|
fn Session::failure_detail(
  self : Session,
  fallback_reason : String,
) -> MlsFailure {
  let (source, reason) = self.raw.last_failure()
  MlsFailure::{
    source: if source == "" {
      "libdave"
    } else {
      source
    },
    reason: if reason == "" {
      fallback_reason
    } else {
      reason
    },
  }
}

///|
fn Session::callback_failure(self : Session) -> MlsFailure? {
  let (source, reason) = self.raw.last_failure()
  if source == "" && reason == "" {
    None
  } else {
    Some(MlsFailure::{
      source: if source == "" {
        "libdave"
      } else {
        source
      },
      reason: if reason == "" {
        "libdave reported an unspecified MLS failure"
      } else {
        reason
      },
    })
  }
}

///|
fn Session::check_native_status(
  self : Session,
  operation : String,
) -> Unit raise DaveError {
  let status = self.raw.last_status()
  if status != 0 {
    let fallback_reason = "native status \{status}"
    let failure = self.failure_detail(fallback_reason)
    if status > 0 {
      raise MlsOperationFailed(operation~, failure~)
    }
    raise NativeFailure(operation~, reason=failure.reason)
  }
}

///|
fn Session::check_operation(
  self : Session,
  operation : String,
) -> Unit raise DaveError {
  self.check_native_status(operation)
  match self.callback_failure() {
    Some(failure) => raise MlsOperationFailed(operation~, failure~)
    None => ()
  }
}

///|
/// Create and initialize an MLS session.
///
/// The official libdave prebuilt C ABI has persistent keys disabled, so each
/// `Session` receives a new transient signing identity. Persisted native
/// authentication-session IDs are intentionally not exposed by this v0.1 API.
pub fn Session::new(
  protocol_version~ : UInt16,
  group_id~ : UInt64,
  self_user_id~ : UInt64,
) -> Session raise DaveError {
  let operation = "Session::new"
  validate_initial_protocol_version(operation, protocol_version)
  let raw = @ffi.RawSession::new()
  let session = Session::{
    raw,
    self_user_id: Ref(self_user_id),
    has_group_context: Ref(false),
    has_external_sender: Ref(false),
  }
  if !raw.is_valid() {
    raise NativeFailure(
      operation~,
      reason=session.failure_detail("failed to create a DAVE session").reason,
    )
  }
  raw.init(protocol_version~, group_id~, self_user_id~)
  session.check_operation(operation)
  session.has_group_context.val = true
  session
}

///|
/// Reset and initialize this session for a new group context.
///
/// This invokes libdave's session initialization again on the same native
/// handle. libdave retains a configured external sender and uses it to create
/// the new pending group state, and the recognized users. The official prebuilt
/// C ABI also generates a new transient signing identity on every
/// reinitialization, so verification state from the previous group must not be
/// carried forward.
pub fn Session::reinitialize(
  self : Session,
  protocol_version~ : UInt16,
  group_id~ : UInt64,
  self_user_id~ : UInt64,
) -> Unit raise DaveError {
  let operation = "Session::reinitialize"
  validate_initial_protocol_version(operation, protocol_version)
  // libdave begins Init by resetting its pending and established group state.
  // Clear the mirror first so a later initialization failure cannot leave a
  // stale readiness flag in this wrapper.
  self.has_group_context.val = false
  self.raw.init(protocol_version~, group_id~, self_user_id~)
  self.check_operation(operation)
  self.self_user_id.val = self_user_id
  self.has_group_context.val = true
}

///|
/// Clear this session's MLS group state and group context.
///
/// libdave retains a configured external sender and the recognized users, so a
/// later `reinitialize` can create pending group state without setting them
/// again.
pub fn Session::reset(self : Session) -> Unit raise DaveError {
  self.has_group_context.val = false
  self.raw.reset()
  self.check_operation("Session::reset")
}

///|
/// Return the session's current protocol version.
pub fn Session::protocol_version(self : Session) -> UInt16 {
  self.raw.protocol_version()
}

///|
/// Set the protocol version recorded by this session. Zero selects the
/// unencrypted protocol state; higher values must not exceed the loaded
/// library's supported maximum.
pub fn Session::set_protocol_version(
  self : Session,
  protocol_version~ : UInt16,
) -> Unit raise DaveError {
  let operation = "Session::set_protocol_version"
  validate_protocol_version(operation, protocol_version)
  self.raw.set_protocol_version(protocol_version~)
  self.check_operation(operation)
}

///|
/// Return the authenticator of the established MLS epoch, if one exists.
pub fn Session::last_epoch_authenticator(
  self : Session,
) -> Bytes? raise DaveError {
  let result = self.raw.last_epoch_authenticator()
  self.check_operation("Session::last_epoch_authenticator")
  if result.length() == 0 {
    None
  } else {
    Some(result)
  }
}

///|
/// Configure the serialized MLS external sender package.
///
/// The sender may only be changed while there is no pending or established
/// MLS group state. Call `reset` first when replacing a sender, then
/// `reinitialize` to create the new pending group state.
pub fn Session::set_external_sender(
  self : Session,
  external_sender : Bytes,
) -> Unit raise DaveError {
  let operation = "Session::set_external_sender"
  if self.has_group_context.val && self.has_external_sender.val {
    raise InvalidState(
      operation~,
      reason="the external sender cannot be changed after MLS group state exists",
    )
  }
  if external_sender.length() == 0 {
    raise InvalidArgument(
      operation~,
      reason="external_sender must not be empty",
    )
  }
  self.raw.set_external_sender(external_sender)
  self.check_operation(operation)
  self.has_external_sender.val = true
}

///|
/// Create a fresh, single-use marshalled MLS key package.
pub fn Session::key_package(self : Session) -> Bytes raise DaveError {
  let result = self.raw.key_package()
  self.check_operation("Session::key_package")
  if result.length() == 0 {
    raise MlsOperationFailed(
      operation="Session::key_package",
      failure=self.failure_detail("libdave returned an empty key package"),
    )
  }
  result
}

///|
/// Recognize `user_id` as a member of the call, allowing it in the MLS group.
///
/// libdave accepts an add proposal, a commit that applies one, or a Welcome
/// only for recognized users. In Discord voice, recognize each user that
/// clients_connect (op 11) announces and stop recognizing one on
/// client_disconnect (op 13). This session's own user is always recognized.
/// Recognized users persist across `reinitialize` and `reset`. Recognizing a
/// user twice has no further effect.
pub fn Session::add_recognized_user(
  self : Session,
  user_id~ : UInt64,
) -> Unit raise DaveError {
  self.raw.add_recognized_user(user_id~)
  self.check_native_status("Session::add_recognized_user")
}

///|
/// Stop recognizing `user_id`, so later proposals, commits, and Welcomes that
/// add it are rejected. Removing a user that is not recognized has no effect.
pub fn Session::remove_recognized_user(
  self : Session,
  user_id~ : UInt64,
) -> Unit raise DaveError {
  self.raw.remove_recognized_user(user_id~)
  self.check_native_status("Session::remove_recognized_user")
}

///|
/// Recognize the users a caller still passes as the deprecated
/// `recognized_user_ids` argument.
fn Session::recognize_all(
  self : Session,
  user_ids : ArrayView[UInt64]?,
) -> Unit raise DaveError {
  guard user_ids is Some(user_ids) else { return }
  for user_id in user_ids {
    self.add_recognized_user(user_id~)
  }
}

///|
fn require_nonempty_payload(
  operation : String,
  payload : Bytes,
) -> Unit raise DaveError {
  if payload.length() == 0 {
    raise InvalidArgument(operation~, reason="payload must not be empty")
  }
}

///|
/// Process a complete libdave proposals payload.
///
/// The nonempty payload includes its leading revoke/append byte. Processing
/// requires pending or established MLS group state, normally created by
/// `set_external_sender` after initialization. libdave validates the whole
/// batch before queueing any of it, and refuses it when an add proposal names
/// a user that is not recognized (see `add_recognized_user`).
///
/// On success this returns one serialized commit followed by an optional
/// serialized Welcome, or `None` when no proposal is left queued, as after a
/// revoke that withdraws every queued proposal: there is nothing to commit
/// and nothing to send.
///
/// `recognized_user_ids` is deprecated and will be removed in the next minor
/// release: each listed user is recognized with `add_recognized_user` before
/// the proposals are processed, and none is removed.
#label_migration(recognized_user_ids, fill=false, msg="call `add_recognized_user` and `remove_recognized_user` instead")
pub fn Session::process_proposals(
  self : Session,
  proposals : Bytes,
  recognized_user_ids? : ArrayView[UInt64],
) -> Bytes? raise DaveError {
  let operation = "Session::process_proposals"
  require_nonempty_payload(operation, proposals)
  self.recognize_all(recognized_user_ids)
  if !self.has_group_context.val || !self.has_external_sender.val {
    raise InvalidState(
      operation~,
      reason="proposals require pending or established MLS group state",
    )
  }
  let result = self.raw.process_proposals(proposals)
  // libdave reports every refusal through the failure callback, which
  // check_operation raises; an empty result without one is an empty queue.
  self.check_operation(operation)
  if result.length() == 0 {
    None
  } else {
    Some(result)
  }
}

///|
fn decode_roster_change(
  record : Bytes,
  operation : String,
) -> RosterChange raise DaveError {
  match record {
    [u64be(user_id)] => Remove(user_id~)
    [u64be(user_id), .. signature_key] =>
      Upsert(user_id~, signature_key=signature_key.to_owned())
    _ =>
      raise NativeFailure(
        operation~,
        reason="roster-change record is shorter than its 8-byte user ID",
      )
  }
}

///|
fn result_tag(
  raw : FixedArray[Bytes],
  operation : String,
) -> Byte raise DaveError {
  if raw.length() == 0 || raw[0].length() != 1 {
    raise NativeFailure(operation~, reason="invalid native result tag")
  }
  raw[0][0]
}

///|
fn decode_commit_result(
  raw : FixedArray[Bytes],
  failure : MlsFailure,
) -> CommitResult raise DaveError {
  let operation = "Session::process_commit"
  match result_tag(raw, operation) {
    0 => {
      let changes = []
      for index in 1..<raw.length() {
        changes.push(decode_roster_change(raw[index], operation))
      }
      Applied(changes~)
    }
    1 => {
      if raw.length() != 1 {
        raise NativeFailure(
          operation~,
          reason="Ignored commit carried roster data",
        )
      }
      Ignored
    }
    2 => {
      if raw.length() != 1 {
        raise NativeFailure(
          operation~,
          reason="Failed commit carried roster data",
        )
      }
      Failed(failure~)
    }
    tag =>
      raise NativeFailure(
        operation~,
        reason="unknown native commit result tag \{tag}",
      )
  }
}

///|
fn decode_welcome_result(
  raw : FixedArray[Bytes],
  failure : MlsFailure,
) -> WelcomeResult raise DaveError {
  let operation = "Session::process_welcome"
  match result_tag(raw, operation) {
    0 => {
      let changes = []
      for index in 1..<raw.length() {
        changes.push(decode_roster_change(raw[index], operation))
      }
      WelcomeResult::Applied(changes~)
    }
    2 => {
      if raw.length() != 1 {
        raise NativeFailure(
          operation~,
          reason="Failed Welcome carried roster data",
        )
      }
      WelcomeResult::Failed(failure~)
    }
    tag =>
      raise NativeFailure(
        operation~,
        reason="unknown native Welcome result tag \{tag}",
      )
  }
}

///|
/// Process an incoming MLS commit without collapsing its protocol outcome
/// into an exception. An empty serialized commit is rejected before FFI.
pub fn Session::process_commit(
  self : Session,
  commit : Bytes,
) -> CommitResult raise DaveError {
  let operation = "Session::process_commit"
  require_nonempty_payload(operation, commit)
  let raw = self.raw.process_commit(commit)
  self.check_native_status(operation)
  decode_commit_result(
    raw,
    self.failure_detail("libdave rejected the MLS commit"),
  )
}

///|
/// Process an incoming MLS Welcome without collapsing protocol rejection into
/// an exception. An applied result carries a roster delta: an `Upsert` has a
/// signature key and a `Remove` represents an empty native signature.
/// libdave fails a Welcome whose group lists a user that is not recognized
/// (see `add_recognized_user`). An empty serialized Welcome is rejected before
/// FFI.
///
/// `recognized_user_ids` is deprecated and will be removed in the next minor
/// release: each listed user is recognized with `add_recognized_user` before
/// the Welcome is processed, and none is removed.
#label_migration(recognized_user_ids, fill=false, msg="call `add_recognized_user` and `remove_recognized_user` instead")
pub fn Session::process_welcome(
  self : Session,
  welcome : Bytes,
  recognized_user_ids? : ArrayView[UInt64],
) -> WelcomeResult raise DaveError {
  let operation = "Session::process_welcome"
  require_nonempty_payload(operation, welcome)
  self.recognize_all(recognized_user_ids)
  let raw = self.raw.process_welcome(welcome)
  self.check_native_status(operation)
  decode_welcome_result(
    raw,
    self.failure_detail("libdave rejected the MLS Welcome"),
  )
}

///|
/// Derive a media key ratchet for `user_id` from the established MLS epoch.
pub fn Session::key_ratchet(
  self : Session,
  user_id~ : UInt64,
) -> KeyRatchet? raise DaveError {
  let raw = self.raw.key_ratchet(user_id~)
  self.check_operation("Session::key_ratchet")
  if raw.is_valid() {
    Some(KeyRatchet::{ raw, })
  } else {
    None
  }
}

///|
/// Compute a pairwise fingerprint for the currently established MLS group.
///
/// This proves only that the two signing keys in the current group produce the
/// same comparison value. With the official prebuilt C ABI, signing
/// identities differ between concurrent `Session` values and rotate on every
/// `reinitialize`, so this is not persistent identity verification or DAVE
/// identity continuity. Discard the result when the session is reinitialized
/// or replaced. The DAVE fingerprint-format version is fixed to zero by this
/// API, as required by the canonical protocol.
///
/// The operation is deliberately synchronous and may block for an expensive
/// scrypt computation. Do not call it on a latency-sensitive cooperative event
/// loop.
pub fn Session::current_group_pairwise_fingerprint_blocking(
  self : Session,
  user_id~ : UInt64,
) -> Bytes raise DaveError {
  let result = self.raw.pairwise_fingerprint(user_id~, fingerprint_version=0)
  let status = self.raw.last_status()
  if status != 0 || result.length() == 0 {
    let failure = self.failure_detail("libdave returned an empty fingerprint")
    raise FingerprintFailed(user_id~, reason=failure.reason)
  }
  result
}
