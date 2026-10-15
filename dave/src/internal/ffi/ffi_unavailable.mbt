///|
// Shared unavailable implementation for JS and Wasm. The public safe facade
// rejects construction with LibraryUnavailable before any raw handle is used.
pub fn available() -> Bool {
  false
}

///|
pub fn max_supported_protocol_version() -> UInt16 {
  0
}

///|
pub fn RawSession::new(auth_session_id? : String) -> RawSession {
  ignore(auth_session_id)
  raw_session_stub_new()
}

///|
pub fn RawSession::is_valid(self : Self) -> Bool {
  ignore(self)
  false
}

///|
pub fn RawSession::init(
  self : Self,
  protocol_version~ : UInt16,
  group_id~ : UInt64,
  self_user_id~ : UInt64,
) -> Unit {
  ignore(self)
  ignore(protocol_version)
  ignore(group_id)
  ignore(self_user_id)
}

///|
pub fn RawSession::reset(self : Self) -> Unit {
  ignore(self)
}

///|
pub fn RawSession::protocol_version(self : Self) -> UInt16 {
  ignore(self)
  0
}

///|
pub fn RawSession::set_protocol_version(
  self : Self,
  protocol_version~ : UInt16,
) -> Unit {
  ignore(self)
  ignore(protocol_version)
}

///|
pub fn RawSession::last_epoch_authenticator(self : Self) -> Bytes {
  ignore(self)
  b""
}

///|
pub fn RawSession::set_external_sender(
  self : Self,
  external_sender : Bytes,
) -> Unit {
  ignore(self)
  ignore(external_sender)
}

///|
pub fn RawSession::key_package(self : Self) -> Bytes {
  ignore(self)
  b""
}

///|
pub fn RawSession::process_proposals(
  self : Self,
  proposals : Bytes,
  recognized_user_ids : Array[UInt64],
) -> Bytes {
  ignore(self)
  ignore(proposals)
  ignore(recognized_user_ids)
  b""
}

///|
pub fn RawSession::process_commit(
  self : Self,
  commit : Bytes,
) -> FixedArray[Bytes] {
  ignore(self)
  ignore(commit)
  [b"\x02"]
}

///|
pub fn RawSession::process_welcome(
  self : Self,
  welcome : Bytes,
  recognized_user_ids : Array[UInt64],
) -> FixedArray[Bytes] {
  ignore(self)
  ignore(welcome)
  ignore(recognized_user_ids)
  [b"\x02"]
}

///|
pub fn RawSession::key_ratchet(self : Self, user_id~ : UInt64) -> RawKeyRatchet {
  ignore(self)
  ignore(user_id)
  raw_key_ratchet_stub_new()
}

///|
pub fn RawSession::pairwise_fingerprint(
  self : Self,
  user_id~ : UInt64,
  fingerprint_version~ : UInt16,
) -> Bytes {
  ignore(self)
  ignore(user_id)
  ignore(fingerprint_version)
  b""
}

///|
pub fn RawSession::last_status(self : Self) -> Int32 {
  ignore(self)
  -100
}

///|
pub fn RawSession::last_failure(self : Self) -> (String, String) {
  ignore(self)
  ("loader", unavailable_reason())
}

///|
pub fn RawKeyRatchet::is_valid(self : Self) -> Bool {
  ignore(self)
  false
}

///|
pub fn RawEncryptor::new() -> RawEncryptor {
  raw_encryptor_stub_new()
}

///|
pub fn RawEncryptor::is_valid(self : Self) -> Bool {
  ignore(self)
  false
}

///|
pub fn RawEncryptor::set_key_ratchet(
  self : Self,
  key_ratchet : RawKeyRatchet,
) -> Unit {
  ignore(self)
  ignore(key_ratchet)
}

///|
pub fn RawEncryptor::set_passthrough(self : Self, enabled~ : Bool) -> Unit {
  ignore(self)
  ignore(enabled)
}

///|
pub fn RawEncryptor::assign_ssrc(
  self : Self,
  ssrc~ : UInt32,
  codec~ : Int32,
) -> Unit {
  ignore(self)
  ignore(ssrc)
  ignore(codec)
}

///|
pub fn RawEncryptor::protocol_version(self : Self) -> UInt16 {
  ignore(self)
  0
}

///|
pub fn RawEncryptor::has_key(self : Self) -> Bool {
  ignore(self)
  false
}

///|
pub fn RawEncryptor::is_passthrough(self : Self) -> Bool {
  ignore(self)
  false
}

///|
pub fn RawEncryptor::encrypt(
  self : Self,
  media_type~ : Int32,
  ssrc~ : UInt32,
  frame : Bytes,
) -> Bytes {
  ignore(self)
  ignore(media_type)
  ignore(ssrc)
  ignore(frame)
  b""
}

///|
pub fn RawEncryptor::last_status(self : Self) -> Int32 {
  ignore(self)
  -100
}

///|
pub fn RawDecryptor::new() -> RawDecryptor {
  raw_decryptor_stub_new()
}

///|
pub fn RawDecryptor::is_valid(self : Self) -> Bool {
  ignore(self)
  false
}

///|
pub fn RawDecryptor::transition_to_key_ratchet(
  self : Self,
  key_ratchet : RawKeyRatchet,
) -> Unit {
  ignore(self)
  ignore(key_ratchet)
}

///|
pub fn RawDecryptor::transition_to_passthrough(
  self : Self,
  enabled~ : Bool,
) -> Unit {
  ignore(self)
  ignore(enabled)
}

///|
pub fn RawDecryptor::decrypt(
  self : Self,
  media_type~ : Int32,
  frame : Bytes,
) -> Bytes {
  ignore(self)
  ignore(media_type)
  ignore(frame)
  b""
}

///|
pub fn RawDecryptor::last_status(self : Self) -> Int32 {
  ignore(self)
  -100
}
