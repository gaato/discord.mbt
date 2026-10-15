///|
pub type RawSession

///|
pub type RawKeyRatchet

///|
pub type RawEncryptor

///|
pub type RawDecryptor

///|
extern "js" fn raw_session_stub_new() -> RawSession = "() => ({})"

///|
extern "js" fn raw_key_ratchet_stub_new() -> RawKeyRatchet = "() => ({})"

///|
extern "js" fn raw_encryptor_stub_new() -> RawEncryptor = "() => ({})"

///|
extern "js" fn raw_decryptor_stub_new() -> RawDecryptor = "() => ({})"

///|
pub fn unavailable_reason() -> String {
  "libdave is unavailable on the JavaScript backend"
}
