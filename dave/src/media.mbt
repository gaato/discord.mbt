///|
fn media_type_code(media_type : MediaType) -> Int32 {
  match media_type {
    Audio => 0
    Video => 1
  }
}

///|
fn codec_code(codec : Codec) -> Int32 {
  match codec {
    Opus => 1
    Vp8 => 2
    Vp9 => 3
    H264 => 4
    H265 => 5
    Av1 => 6
  }
}

///|
fn Codec::media_type(self : Codec) -> MediaType {
  match self {
    Opus => Audio
    Vp8 | Vp9 | H264 | H265 | Av1 => Video
  }
}

///|
fn encrypt_failure(code : Int32) -> EncryptFailure {
  match code {
    1 => EncryptionFailure
    2 => MissingKeyRatchet
    3 => MissingCryptor
    4 => TooManyAttempts
    _ => EncryptFailure::Unknown(code~)
  }
}

///|
fn decrypt_failure(code : Int32) -> DecryptFailure {
  match code {
    1 => DecryptionFailure
    2 => MissingKeyRatchet
    3 => InvalidNonce
    4 => MissingCryptor
    _ => DecryptFailure::Unknown(code~)
  }
}

///|
fn check_media_configuration_status(
  operation : String,
  status : Int32,
) -> Unit raise DaveError {
  if status != 0 {
    raise NativeFailure(operation~, reason="native status \{status}")
  }
}

///|
/// A stateful media-frame encryptor.
///
/// Assign each SSRC to its codec before encrypting frames for that SSRC. The
/// native handle is released by a finalizer; copied `Encryptor` values alias
/// the same mutable state and must not be used concurrently.
pub struct Encryptor {
  priv raw : @ffi.RawEncryptor
  priv codecs : Map[UInt32, Codec]
}

///|
/// Create a media-frame encryptor.
pub fn Encryptor::new() -> Encryptor raise DaveError {
  let operation = "Encryptor::new"
  require_available(operation)
  let raw = @ffi.RawEncryptor::new()
  if !raw.is_valid() {
    raise NativeFailure(operation~, reason="failed to create a DAVE encryptor")
  }
  Encryptor::{ raw, codecs: Map([]), }
}

///|
/// Install a copy of `key_ratchet` for outbound media.
pub fn Encryptor::set_key_ratchet(
  self : Encryptor,
  key_ratchet : KeyRatchet,
) -> Unit raise DaveError {
  self.raw.set_key_ratchet(key_ratchet.raw)
  check_media_configuration_status(
    "Encryptor::set_key_ratchet",
    self.raw.last_status(),
  )
}

///|
/// Enable or disable unencrypted passthrough.
pub fn Encryptor::set_passthrough_mode(
  self : Encryptor,
  enabled~ : Bool,
) -> Unit raise DaveError {
  self.raw.set_passthrough(enabled~)
  check_media_configuration_status(
    "Encryptor::set_passthrough_mode",
    self.raw.last_status(),
  )
}

///|
/// Associate an RTP SSRC with its media codec.
pub fn Encryptor::assign_ssrc_to_codec(
  self : Encryptor,
  ssrc~ : UInt32,
  codec~ : Codec,
) -> Unit raise DaveError {
  self.raw.assign_ssrc(ssrc~, codec=codec_code(codec))
  check_media_configuration_status(
    "Encryptor::assign_ssrc_to_codec",
    self.raw.last_status(),
  )
  self.codecs[ssrc] = codec
}

///|
/// Return the protocol version selected by the active outbound ratchet.
pub fn Encryptor::protocol_version(self : Encryptor) -> UInt16 {
  self.raw.protocol_version()
}

///|
/// Whether an outbound key ratchet has been installed.
pub fn Encryptor::has_key_ratchet(self : Encryptor) -> Bool {
  self.raw.has_key()
}

///|
/// Whether outbound media is currently passed through unencrypted.
pub fn Encryptor::is_passthrough_mode(self : Encryptor) -> Bool {
  self.raw.is_passthrough()
}

///|
/// Encrypt one media frame and return a new MoonBit-owned byte string.
///
/// SSRC/codec assignment is required while encryption is active. Native
/// passthrough mode accepts frames without an assignment, matching libdave.
pub fn Encryptor::encrypt(
  self : Encryptor,
  media_type~ : MediaType,
  ssrc~ : UInt32,
  frame : Bytes,
) -> Bytes raise DaveError {
  if !self.raw.is_passthrough() {
    guard self.codecs.get(ssrc) is Some(codec) else {
      raise InvalidState(
        operation="Encryptor::encrypt",
        reason="SSRC \{ssrc} has no assigned codec",
      )
    }
    if codec.media_type() != media_type {
      raise InvalidArgument(
        operation="Encryptor::encrypt",
        reason="the assigned codec does not match the requested media type",
      )
    }
  }
  let result = self.raw.encrypt(
    media_type=media_type_code(media_type),
    ssrc~,
    frame,
  )
  let status = self.raw.last_status()
  if status < 0 {
    raise NativeFailure(
      operation="Encryptor::encrypt",
      reason="native status \{status}",
    )
  }
  if status > 0 {
    raise EncryptFailed(reason=encrypt_failure(status))
  }
  result
}

///|
/// A stateful media-frame decryptor.
///
/// Applications normally keep one decryptor per remote participant. The
/// native handle is released by a finalizer; copied `Decryptor` values alias
/// the same mutable state and must not be used concurrently.
pub struct Decryptor {
  priv raw : @ffi.RawDecryptor
}

///|
/// Create a media-frame decryptor.
pub fn Decryptor::new() -> Decryptor raise DaveError {
  let operation = "Decryptor::new"
  require_available(operation)
  let raw = @ffi.RawDecryptor::new()
  if !raw.is_valid() {
    raise NativeFailure(operation~, reason="failed to create a DAVE decryptor")
  }
  Decryptor::{ raw, }
}

///|
/// Begin libdave's transition to a copy of `key_ratchet`.
///
/// libdave retains old decryption keys for its built-in transition window.
pub fn Decryptor::transition_to_key_ratchet(
  self : Decryptor,
  key_ratchet : KeyRatchet,
) -> Unit raise DaveError {
  self.raw.transition_to_key_ratchet(key_ratchet.raw)
  check_media_configuration_status(
    "Decryptor::transition_to_key_ratchet",
    self.raw.last_status(),
  )
}

///|
/// Transition to or from unencrypted passthrough.
pub fn Decryptor::transition_to_passthrough_mode(
  self : Decryptor,
  enabled~ : Bool,
) -> Unit raise DaveError {
  self.raw.transition_to_passthrough(enabled~)
  check_media_configuration_status(
    "Decryptor::transition_to_passthrough_mode",
    self.raw.last_status(),
  )
}

///|
/// Decrypt one media frame and return a new MoonBit-owned byte string.
pub fn Decryptor::decrypt(
  self : Decryptor,
  media_type~ : MediaType,
  encrypted_frame : Bytes,
) -> Bytes raise DaveError {
  let result = self.raw.decrypt(
    media_type=media_type_code(media_type),
    encrypted_frame,
  )
  let status = self.raw.last_status()
  if status < 0 {
    raise NativeFailure(
      operation="Decryptor::decrypt",
      reason="native status \{status}",
    )
  }
  if status > 0 {
    raise DecryptFailed(reason=decrypt_failure(status))
  }
  result
}
