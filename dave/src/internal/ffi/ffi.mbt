///|
/// A GC-owned wrapper around an official libdave session handle.
pub type RawSession

///|
/// A GC-owned wrapper around a key-ratchet snapshot returned by libdave.
pub type RawKeyRatchet

///|
/// A GC-owned wrapper around an official libdave media encryptor.
pub type RawEncryptor

///|
/// A GC-owned wrapper around an official libdave media decryptor.
pub type RawDecryptor

///|
extern "c" fn loader_status() -> Int32 = "mbt_dave_loader_status"

///|
extern "c" fn loader_reason_bytes() -> Bytes = "mbt_dave_loader_reason"

///|
extern "c" fn max_protocol_version_raw() -> UInt16 = "mbt_dave_max_supported_protocol_version"

///|
#borrow(auth_session_id)
extern "c" fn raw_session_new(
  auth_session_id : Bytes,
  has_auth_session_id : Int32,
) -> RawSession = "mbt_dave_session_new"

///|
#borrow(session)
extern "c" fn raw_session_is_valid(session : RawSession) -> Int32 = "mbt_dave_session_is_valid"

///|
#borrow(session)
extern "c" fn raw_session_init(
  session : RawSession,
  protocol_version : UInt16,
  group_id : UInt64,
  self_user_id : UInt64,
) -> Unit = "mbt_dave_session_init"

///|
#borrow(session)
extern "c" fn raw_session_reset(session : RawSession) -> Unit = "mbt_dave_session_reset"

///|
#borrow(session)
extern "c" fn raw_session_protocol_version(session : RawSession) -> UInt16 = "mbt_dave_session_protocol_version"

///|
#borrow(session)
extern "c" fn raw_session_set_protocol_version(
  session : RawSession,
  protocol_version : UInt16,
) -> Unit = "mbt_dave_session_set_protocol_version"

///|
#borrow(session)
extern "c" fn raw_session_last_epoch_authenticator(
  session : RawSession,
) -> Bytes = "mbt_dave_session_last_epoch_authenticator"

///|
#borrow(session, external_sender)
extern "c" fn raw_session_set_external_sender(
  session : RawSession,
  external_sender : Bytes,
) -> Unit = "mbt_dave_session_set_external_sender"

///|
#borrow(session)
extern "c" fn raw_session_key_package(session : RawSession) -> Bytes = "mbt_dave_session_key_package"

///|
#borrow(session, proposals, recognized_user_ids)
extern "c" fn raw_session_process_proposals(
  session : RawSession,
  proposals : Bytes,
  recognized_user_ids : FixedArray[UInt64],
) -> Bytes = "mbt_dave_session_process_proposals"

///|
#borrow(session, commit)
extern "c" fn raw_session_process_commit(
  session : RawSession,
  commit : Bytes,
) -> FixedArray[Bytes] = "mbt_dave_session_process_commit"

///|
#borrow(session, welcome, recognized_user_ids)
extern "c" fn raw_session_process_welcome(
  session : RawSession,
  welcome : Bytes,
  recognized_user_ids : FixedArray[UInt64],
) -> FixedArray[Bytes] = "mbt_dave_session_process_welcome"

///|
#borrow(session)
extern "c" fn raw_session_key_ratchet(
  session : RawSession,
  user_id : UInt64,
) -> RawKeyRatchet = "mbt_dave_session_key_ratchet"

///|
#borrow(session)
extern "c" fn raw_session_pairwise_fingerprint(
  session : RawSession,
  user_id : UInt64,
  fingerprint_version : UInt16,
) -> Bytes = "mbt_dave_session_pairwise_fingerprint"

///|
#borrow(session)
extern "c" fn raw_session_last_status(session : RawSession) -> Int32 = "mbt_dave_session_last_status"

///|
#borrow(session)
extern "c" fn raw_session_failure_source(session : RawSession) -> Bytes = "mbt_dave_session_failure_source"

///|
#borrow(session)
extern "c" fn raw_session_failure_reason(session : RawSession) -> Bytes = "mbt_dave_session_failure_reason"

///|
#borrow(key_ratchet)
extern "c" fn raw_key_ratchet_is_valid(key_ratchet : RawKeyRatchet) -> Int32 = "mbt_dave_key_ratchet_is_valid"

///|
extern "c" fn raw_encryptor_new() -> RawEncryptor = "mbt_dave_encryptor_new"

///|
#borrow(encryptor)
extern "c" fn raw_encryptor_is_valid(encryptor : RawEncryptor) -> Int32 = "mbt_dave_encryptor_is_valid"

///|
#borrow(encryptor, key_ratchet)
extern "c" fn raw_encryptor_set_key_ratchet(
  encryptor : RawEncryptor,
  key_ratchet : RawKeyRatchet,
) -> Unit = "mbt_dave_encryptor_set_key_ratchet"

///|
#borrow(encryptor)
extern "c" fn raw_encryptor_set_passthrough(
  encryptor : RawEncryptor,
  enabled : Int32,
) -> Unit = "mbt_dave_encryptor_set_passthrough"

///|
#borrow(encryptor)
extern "c" fn raw_encryptor_assign_ssrc(
  encryptor : RawEncryptor,
  ssrc : UInt32,
  codec : Int32,
) -> Unit = "mbt_dave_encryptor_assign_ssrc"

///|
#borrow(encryptor)
extern "c" fn raw_encryptor_protocol_version(
  encryptor : RawEncryptor,
) -> UInt16 = "mbt_dave_encryptor_protocol_version"

///|
#borrow(encryptor)
extern "c" fn raw_encryptor_has_key(encryptor : RawEncryptor) -> Int32 = "mbt_dave_encryptor_has_key"

///|
#borrow(encryptor)
extern "c" fn raw_encryptor_is_passthrough(encryptor : RawEncryptor) -> Int32 = "mbt_dave_encryptor_is_passthrough"

///|
#borrow(encryptor, frame)
extern "c" fn raw_encryptor_encrypt(
  encryptor : RawEncryptor,
  media_type : Int32,
  ssrc : UInt32,
  frame : Bytes,
) -> Bytes = "mbt_dave_encryptor_encrypt"

///|
#borrow(encryptor)
extern "c" fn raw_encryptor_last_status(encryptor : RawEncryptor) -> Int32 = "mbt_dave_encryptor_last_status"

///|
extern "c" fn raw_decryptor_new() -> RawDecryptor = "mbt_dave_decryptor_new"

///|
#borrow(decryptor)
extern "c" fn raw_decryptor_is_valid(decryptor : RawDecryptor) -> Int32 = "mbt_dave_decryptor_is_valid"

///|
#borrow(decryptor, key_ratchet)
extern "c" fn raw_decryptor_transition_to_key_ratchet(
  decryptor : RawDecryptor,
  key_ratchet : RawKeyRatchet,
) -> Unit = "mbt_dave_decryptor_transition_to_key_ratchet"

///|
#borrow(decryptor)
extern "c" fn raw_decryptor_transition_to_passthrough(
  decryptor : RawDecryptor,
  enabled : Int32,
) -> Unit = "mbt_dave_decryptor_transition_to_passthrough"

///|
#borrow(decryptor, frame)
extern "c" fn raw_decryptor_decrypt(
  decryptor : RawDecryptor,
  media_type : Int32,
  frame : Bytes,
) -> Bytes = "mbt_dave_decryptor_decrypt"

///|
#borrow(decryptor)
extern "c" fn raw_decryptor_last_status(decryptor : RawDecryptor) -> Int32 = "mbt_dave_decryptor_last_status"

///|
fn recognized_ids_to_fixed(
  recognized_user_ids : Array[UInt64],
) -> FixedArray[UInt64] {
  let result = FixedArray::make(recognized_user_ids.length(), 0UL)
  for index = 0; index < recognized_user_ids.length(); index = index + 1 {
    result[index] = recognized_user_ids[index]
  }
  result
}

///|
/// Whether official libdave v1.2.0's required C API is loadable.
pub fn available() -> Bool {
  loader_status() == 0
}

///|
/// Why libdave could not be loaded, or an empty string while it is available.
pub fn unavailable_reason() -> String {
  @utf8.decode_lossy(loader_reason_bytes())
}

///|
/// The newest DAVE protocol version supported by the loaded libdave.
pub fn max_supported_protocol_version() -> UInt16 {
  max_protocol_version_raw()
}

///|
pub fn RawSession::new(auth_session_id? : String) -> RawSession {
  match auth_session_id {
    Some(value) => raw_session_new(@utf8.encode(value), 1)
    None => raw_session_new(b"", 0)
  }
}

///|
pub fn RawSession::is_valid(self : Self) -> Bool {
  raw_session_is_valid(self) != 0
}

///|
pub fn RawSession::init(
  self : Self,
  protocol_version~ : UInt16,
  group_id~ : UInt64,
  self_user_id~ : UInt64,
) -> Unit {
  raw_session_init(self, protocol_version, group_id, self_user_id)
}

///|
pub fn RawSession::reset(self : Self) -> Unit {
  raw_session_reset(self)
}

///|
pub fn RawSession::protocol_version(self : Self) -> UInt16 {
  raw_session_protocol_version(self)
}

///|
pub fn RawSession::set_protocol_version(
  self : Self,
  protocol_version~ : UInt16,
) -> Unit {
  raw_session_set_protocol_version(self, protocol_version)
}

///|
pub fn RawSession::last_epoch_authenticator(self : Self) -> Bytes {
  raw_session_last_epoch_authenticator(self)
}

///|
pub fn RawSession::set_external_sender(
  self : Self,
  external_sender : Bytes,
) -> Unit {
  raw_session_set_external_sender(self, external_sender)
}

///|
pub fn RawSession::key_package(self : Self) -> Bytes {
  raw_session_key_package(self)
}

///|
pub fn RawSession::process_proposals(
  self : Self,
  proposals : Bytes,
  recognized_user_ids : Array[UInt64],
) -> Bytes {
  raw_session_process_proposals(
    self,
    proposals,
    recognized_ids_to_fixed(recognized_user_ids),
  )
}

///|
/// The first byte array is an outcome tag: 0 applied, 1 ignored, 2 failed.
pub fn RawSession::process_commit(
  self : Self,
  commit : Bytes,
) -> FixedArray[Bytes] {
  raw_session_process_commit(self, commit)
}

///|
/// The first byte array is an outcome tag: 0 applied, 1 ignored, 2 failed.
pub fn RawSession::process_welcome(
  self : Self,
  welcome : Bytes,
  recognized_user_ids : Array[UInt64],
) -> FixedArray[Bytes] {
  raw_session_process_welcome(
    self,
    welcome,
    recognized_ids_to_fixed(recognized_user_ids),
  )
}

///|
pub fn RawSession::key_ratchet(self : Self, user_id~ : UInt64) -> RawKeyRatchet {
  raw_session_key_ratchet(self, user_id)
}

///|
pub fn RawSession::pairwise_fingerprint(
  self : Self,
  user_id~ : UInt64,
  fingerprint_version~ : UInt16,
) -> Bytes {
  raw_session_pairwise_fingerprint(self, user_id, fingerprint_version)
}

///|
/// Zero means the libdave call completed. Media operations preserve libdave's
/// exact result codes; negative values are binding or loader failures.
pub fn RawSession::last_status(self : Self) -> Int32 {
  raw_session_last_status(self)
}

///|
/// The most recent MLS failure callback's source and reason.
pub fn RawSession::last_failure(self : Self) -> (String, String) {
  (
    @utf8.decode_lossy(raw_session_failure_source(self)),
    @utf8.decode_lossy(raw_session_failure_reason(self)),
  )
}

///|
pub fn RawKeyRatchet::is_valid(self : Self) -> Bool {
  raw_key_ratchet_is_valid(self) != 0
}

///|
pub fn RawEncryptor::new() -> RawEncryptor {
  raw_encryptor_new()
}

///|
pub fn RawEncryptor::is_valid(self : Self) -> Bool {
  raw_encryptor_is_valid(self) != 0
}

///|
pub fn RawEncryptor::set_key_ratchet(
  self : Self,
  key_ratchet : RawKeyRatchet,
) -> Unit {
  raw_encryptor_set_key_ratchet(self, key_ratchet)
}

///|
pub fn RawEncryptor::set_passthrough(self : Self, enabled~ : Bool) -> Unit {
  raw_encryptor_set_passthrough(self, if enabled { 1 } else { 0 })
}

///|
pub fn RawEncryptor::assign_ssrc(
  self : Self,
  ssrc~ : UInt32,
  codec~ : Int32,
) -> Unit {
  raw_encryptor_assign_ssrc(self, ssrc, codec)
}

///|
pub fn RawEncryptor::protocol_version(self : Self) -> UInt16 {
  raw_encryptor_protocol_version(self)
}

///|
pub fn RawEncryptor::has_key(self : Self) -> Bool {
  raw_encryptor_has_key(self) != 0
}

///|
pub fn RawEncryptor::is_passthrough(self : Self) -> Bool {
  raw_encryptor_is_passthrough(self) != 0
}

///|
pub fn RawEncryptor::encrypt(
  self : Self,
  media_type~ : Int32,
  ssrc~ : UInt32,
  frame : Bytes,
) -> Bytes {
  raw_encryptor_encrypt(self, media_type, ssrc, frame)
}

///|
pub fn RawEncryptor::last_status(self : Self) -> Int32 {
  raw_encryptor_last_status(self)
}

///|
pub fn RawDecryptor::new() -> RawDecryptor {
  raw_decryptor_new()
}

///|
pub fn RawDecryptor::is_valid(self : Self) -> Bool {
  raw_decryptor_is_valid(self) != 0
}

///|
pub fn RawDecryptor::transition_to_key_ratchet(
  self : Self,
  key_ratchet : RawKeyRatchet,
) -> Unit {
  raw_decryptor_transition_to_key_ratchet(self, key_ratchet)
}

///|
pub fn RawDecryptor::transition_to_passthrough(
  self : Self,
  enabled~ : Bool,
) -> Unit {
  raw_decryptor_transition_to_passthrough(self, if enabled { 1 } else { 0 })
}

///|
pub fn RawDecryptor::decrypt(
  self : Self,
  media_type~ : Int32,
  frame : Bytes,
) -> Bytes {
  raw_decryptor_decrypt(self, media_type, frame)
}

///|
pub fn RawDecryptor::last_status(self : Self) -> Int32 {
  raw_decryptor_last_status(self)
}
