///|
/// Discord voice transport encryption modes supported by this package.
pub(all) enum EncryptionMode {
  AeadAes256GcmRtpsize
  AeadXChaCha20Poly1305Rtpsize
} derive(Debug, Eq)

///|
/// Errors raised by transport-mode negotiation and packet encryption.
pub(all) suberror VoiceCryptoError {
  NoCompatibleMode(modes~ : Array[String])
  ShimUnavailable(reason~ : String)
  InvalidSecretKey(length~ : Int)
  InvalidEncryptedPacket(reason~ : String)
  AuthenticationFailed(reason~ : String)
  AeadFailed(status~ : Int, reason~ : String)
} derive(Debug, Eq)

///|
/// Select the preferred common Discord transport encryption mode.
pub fn EncryptionMode::negotiate(
  modes : Array[String],
) -> EncryptionMode raise VoiceCryptoError {
  if modes.contains("aead_aes256_gcm_rtpsize") {
    AeadAes256GcmRtpsize
  } else if modes.contains("aead_xchacha20_poly1305_rtpsize") {
    AeadXChaCha20Poly1305Rtpsize
  } else {
    raise NoCompatibleMode(modes~)
  }
}

///|
fn EncryptionMode::code(self : EncryptionMode) -> Int {
  match self {
    AeadAes256GcmRtpsize => 0
    AeadXChaCha20Poly1305Rtpsize => 1
  }
}

///|
fn EncryptionMode::nonce_length(self : EncryptionMode) -> Int {
  match self {
    AeadAes256GcmRtpsize => 12
    AeadXChaCha20Poly1305Rtpsize => 24
  }
}

///|
fn raise_voice_shim_status(status : Int) -> Unit raise VoiceCryptoError {
  let reason = voice_shim_error_message()
  match status {
    -100 | -101 | -102 => raise ShimUnavailable(reason~)
    -3 => raise AuthenticationFailed(reason~)
    _ => raise AeadFailed(status~, reason~)
  }
}

///|
fn aead_seal_raw(
  mode : EncryptionMode,
  key : Bytes,
  nonce : Bytes,
  aad : Bytes,
  plaintext : Bytes,
) -> Bytes raise VoiceCryptoError {
  let result = voice_shim_aead_seal(mode.code(), key, nonce, aad, plaintext)
  let status = voice_shim_last_status()
  if status != 0 {
    raise_voice_shim_status(status)
  }
  result
}

///|
fn aead_open_raw(
  mode : EncryptionMode,
  key : Bytes,
  nonce : Bytes,
  aad : Bytes,
  ciphertext : Bytes,
) -> Bytes raise VoiceCryptoError {
  let result = voice_shim_aead_open(mode.code(), key, nonce, aad, ciphertext)
  let status = voice_shim_last_status()
  if status != 0 {
    raise_voice_shim_status(status)
  }
  result
}

///|
fn nonce_suffix(counter : UInt) -> Bytes {
  Bytes::from_array([
    (counter >> 24).to_byte(),
    (counter >> 16).to_byte(),
    (counter >> 8).to_byte(),
    counter.to_byte(),
  ])
}

///|
fn make_nonce(mode : EncryptionMode, suffix : Bytes) -> Bytes {
  let bytes : Array[Byte] = []
  for byte in suffix {
    bytes.push(byte)
  }
  for _ in suffix.length()..<mode.nonce_length() {
    bytes.push(0)
  }
  Bytes::from_array(bytes)
}

///|
/// Stateful voice transport cipher. The sender counter wraps modulo 2^32;
/// receivers reconstruct nonces from the packet suffix and need no counter.
pub struct TransportCipher {
  priv mode : EncryptionMode
  priv secret_key : Bytes
  priv mut counter : UInt
}

///|
/// Create a cipher for `mode` from the 32-byte session `secret_key`
/// delivered by the voice gateway.
pub fn TransportCipher::new(
  mode : EncryptionMode,
  secret_key : Bytes,
) -> TransportCipher raise VoiceCryptoError {
  if secret_key.length() != 32 {
    raise InvalidSecretKey(length=secret_key.length())
  }
  if !shim_available() {
    raise ShimUnavailable(
      reason=shim_unavailable_reason().unwrap_or("voice shim unavailable"),
    )
  }
  { mode, secret_key, counter: 0, }
}

///|
/// Encrypt an RTP payload and append the four-byte nonce suffix.
pub fn TransportCipher::seal(
  self : TransportCipher,
  header~ : Bytes,
  plaintext : Bytes,
) -> Bytes raise VoiceCryptoError {
  let suffix = nonce_suffix(self.counter)
  let nonce = make_nonce(self.mode, suffix)
  let encrypted = aead_seal_raw(
    self.mode,
    self.secret_key,
    nonce,
    header,
    plaintext,
  )
  self.counter += 1
  header + encrypted + suffix
}

///|
/// Authenticate and decrypt a packet, returning `header || plaintext`.
pub fn TransportCipher::open(
  self : TransportCipher,
  packet : Bytes,
  header_len~ : Int,
) -> Bytes raise VoiceCryptoError {
  if header_len < 0 || header_len > packet.length() {
    raise InvalidEncryptedPacket(reason="invalid RTP header length")
  }
  if packet.length() < header_len + 20 {
    raise InvalidEncryptedPacket(
      reason="packet is shorter than authentication tag and nonce suffix",
    )
  }
  let suffix = packet[packet.length() - 4:].to_owned()
  let nonce = make_nonce(self.mode, suffix)
  let header = packet[:header_len].to_owned()
  let ciphertext = packet[header_len:packet.length() - 4].to_owned()
  let plaintext = aead_open_raw(
    self.mode,
    self.secret_key,
    nonce,
    header,
    ciphertext,
  )
  header + plaintext
}
