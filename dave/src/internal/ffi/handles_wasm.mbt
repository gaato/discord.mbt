///|
// These inert handles never refer to host memory. The public facade checks
// available() before construction; Wasm does not load or call native libdave.
pub struct RawSession(Unit)

///|
pub struct RawKeyRatchet(Unit)

///|
pub struct RawEncryptor(Unit)

///|
pub struct RawDecryptor(Unit)

///|
fn raw_session_stub_new() -> RawSession {
  RawSession(())
}

///|
fn raw_key_ratchet_stub_new() -> RawKeyRatchet {
  RawKeyRatchet(())
}

///|
fn raw_encryptor_stub_new() -> RawEncryptor {
  RawEncryptor(())
}

///|
fn raw_decryptor_stub_new() -> RawDecryptor {
  RawDecryptor(())
}

///|
pub fn unavailable_reason() -> String {
  "libdave is unavailable on the Wasm backend"
}
