///|
/// A change to the P-256 signature-public-key roster returned by an applied
/// MLS commit or Welcome.
pub(all) enum RosterChange {
  Upsert(user_id~ : UInt64, signature_key~ : Bytes)
  Remove(user_id~ : UInt64)
} derive(Debug, Eq)

///|
/// The protocol outcome of processing an MLS commit.
pub(all) enum CommitResult {
  Applied(changes~ : Array[RosterChange])
  Ignored
  Failed(failure~ : MlsFailure)
} derive(Debug, Eq)

///|
/// The protocol outcome of processing an MLS Welcome.
pub(all) enum WelcomeResult {
  Applied(changes~ : Array[RosterChange])
  Failed(failure~ : MlsFailure)
} derive(Debug, Eq)

///|
/// Why media-frame encryption failed.
pub(all) enum EncryptFailure {
  EncryptionFailure
  MissingKeyRatchet
  MissingCryptor
  TooManyAttempts
  Unknown(code~ : Int32)
} derive(Debug, Eq)

///|
/// Why media-frame decryption failed.
pub(all) enum DecryptFailure {
  DecryptionFailure
  MissingKeyRatchet
  InvalidNonce
  MissingCryptor
  Unknown(code~ : Int32)
} derive(Debug, Eq)

///|
/// The kind of media carried by a DAVE frame.
pub(all) enum MediaType {
  Audio
  Video
} derive(Debug, Eq)

///|
/// A codec supported by libdave's frame processors.
///
/// libdave's `Unknown` codec is deliberately omitted because it cannot safely
/// be used for encryption.
pub(all) enum Codec {
  Opus
  Vp8
  Vp9
  H264
  H265
  Av1
} derive(Debug, Eq)
