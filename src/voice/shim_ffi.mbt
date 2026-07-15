///|
extern "c" fn voice_shim_status() -> Int = "discord_voice_shim_status"

///|
extern "c" fn voice_shim_unavailable_reason_bytes() -> Bytes = "discord_voice_shim_unavailable_reason"

///|
extern "c" fn voice_shim_last_status() -> Int = "discord_voice_shim_last_status"

///|
extern "c" fn voice_shim_last_error_bytes() -> Bytes = "discord_voice_shim_last_error"

///|
#borrow(key, nonce, aad, plaintext)
extern "c" fn voice_shim_aead_seal(
  mode : Int,
  key : Bytes,
  nonce : Bytes,
  aad : Bytes,
  plaintext : Bytes,
) -> Bytes = "discord_voice_shim_aead_seal"

///|
#borrow(key, nonce, aad, ciphertext)
extern "c" fn voice_shim_aead_open(
  mode : Int,
  key : Bytes,
  nonce : Bytes,
  aad : Bytes,
  ciphertext : Bytes,
) -> Bytes = "discord_voice_shim_aead_open"

///|
type DaveSession

///|
extern "c" fn voice_shim_dave_max_protocol_version() -> Int = "discord_voice_dave_max_protocol_version"

///|
#borrow(user_id)
extern "c" fn voice_shim_dave_session_create(
  protocol_version : Int,
  user_id : Bytes,
  channel_id : UInt64,
) -> DaveSession = "discord_voice_dave_session_create"

///|
#borrow(session)
extern "c" fn voice_shim_dave_session_reinit(
  session : DaveSession,
  protocol_version : Int,
) -> Int = "discord_voice_dave_session_reinit"

///|
#borrow(session, payload)
extern "c" fn voice_shim_dave_set_external_sender(
  session : DaveSession,
  payload : Bytes,
) -> Int = "discord_voice_dave_set_external_sender"

///|
#borrow(session)
extern "c" fn voice_shim_dave_get_key_package(session : DaveSession) -> Bytes = "discord_voice_dave_get_key_package"

///|
/// The C ABI borrows a contiguous reference array. Each MoonBit `Bytes` value
/// is runtime-NUL-terminated so the shim can read each entry as a C string.
#borrow(session, payload, recognized_user_ids)
extern "c" fn voice_shim_dave_process_proposals(
  session : DaveSession,
  op_type : Int,
  payload : Bytes,
  recognized_user_ids : FixedArray[Bytes],
) -> FixedArray[Bytes] = "discord_voice_dave_process_proposals"

///|
#borrow(session, payload)
extern "c" fn voice_shim_dave_process_commit(
  session : DaveSession,
  payload : Bytes,
) -> Int = "discord_voice_dave_process_commit"

///|
#borrow(session, payload)
extern "c" fn voice_shim_dave_process_welcome(
  session : DaveSession,
  payload : Bytes,
) -> Int = "discord_voice_dave_process_welcome"

///|
#borrow(session, frame)
extern "c" fn voice_shim_dave_encrypt_opus(
  session : DaveSession,
  frame : Bytes,
) -> Bytes = "discord_voice_dave_encrypt_opus"

///|
#borrow(session, user_id, frame)
extern "c" fn voice_shim_dave_decrypt(
  session : DaveSession,
  user_id : Bytes,
  frame : Bytes,
) -> Bytes = "discord_voice_dave_decrypt"

///|
#borrow(session)
extern "c" fn voice_shim_dave_session_status(session : DaveSession) -> Int = "discord_voice_dave_session_status"

///|
#borrow(session, user_id)
extern "c" fn voice_shim_dave_get_verification_code(
  session : DaveSession,
  user_id : Bytes,
) -> Bytes = "discord_voice_dave_get_verification_code"

///|
/// Whether a compatible ABI v2 voice shim is available in this process.
pub fn shim_available() -> Bool {
  voice_shim_status() == 0
}

///|
/// Explain why the native voice shim could not be loaded.
pub fn shim_unavailable_reason() -> String? {
  if voice_shim_status() == 0 {
    None
  } else {
    Some(@utf8.decode_lossy(voice_shim_unavailable_reason_bytes()))
  }
}

///|
fn voice_shim_error_message() -> String {
  @utf8.decode_lossy(voice_shim_last_error_bytes())
}
