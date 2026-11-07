///|
/// A change to the P-256 signature-public-key roster returned by an applied
/// MLS commit or Welcome.
#derive(Debug, Eq)
pub(all) enum RosterChange {
  Upsert(user_id~ : UInt64, signature_key~ : Bytes)
  Remove(user_id~ : UInt64)
}

///|
/// The protocol outcome of processing an MLS commit.
#derive(Debug, Eq)
pub(all) enum CommitResult {
  Applied(changes~ : Array[RosterChange])
  Ignored
  Failed(failure~ : MlsFailure)
}

///|
/// The protocol outcome of processing an MLS Welcome.
#derive(Debug, Eq)
pub(all) enum WelcomeResult {
  Applied(changes~ : Array[RosterChange])
  Failed(failure~ : MlsFailure)
}

///|
/// Why media-frame encryption failed.
#derive(Debug, Eq)
#non_exhaustive
pub(all) enum EncryptFailure {
  EncryptionFailure
  MissingKeyRatchet
  MissingCryptor
  TooManyAttempts
  Unknown(code~ : Int32)
}

///|
/// Why media-frame decryption failed.
#derive(Debug, Eq)
#non_exhaustive
pub(all) enum DecryptFailure {
  DecryptionFailure
  MissingKeyRatchet
  InvalidNonce
  MissingCryptor
  Unknown(code~ : Int32)
}

///|
/// The kind of media carried by a DAVE frame.
#derive(Debug, Eq)
pub(all) enum MediaType {
  Audio
  Video
}

///|
/// A codec supported by libdave's frame processors.
///
/// libdave's `Unknown` codec is deliberately omitted because it cannot safely
/// be used for encryption.
#derive(Debug, Eq)
pub(all) enum Codec {
  Opus
  Vp8
  Vp9
  H264
  H265
  Av1
}
