///|
/// Details captured from libdave's MLS failure callback.
pub(all) struct MlsFailure {
  source : String
  reason : String
} derive(Debug, Eq)

///|
/// Errors reported by the safe DAVE wrapper.
///
/// Protocol-level commit and Welcome rejection is returned as
/// `CommitResult::Failed` or `WelcomeResult::Failed`, rather than raised as an
/// error. Raised errors represent invalid wrapper use, unavailable native
/// support, or an operation that could not produce a protocol result.
pub(all) suberror DaveError {
  LibraryUnavailable(reason~ : String)
  InvalidArgument(operation~ : String, reason~ : String)
  InvalidState(operation~ : String, reason~ : String)
  MlsOperationFailed(operation~ : String, failure~ : MlsFailure)
  FingerprintFailed(user_id~ : UInt64, reason~ : String)
  EncryptFailed(reason~ : EncryptFailure)
  DecryptFailed(reason~ : DecryptFailure)
  NativeFailure(operation~ : String, reason~ : String)
} derive(Debug, Eq)
