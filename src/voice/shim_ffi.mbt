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
/// Whether a compatible ABI v1 voice shim is available in this process.
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
