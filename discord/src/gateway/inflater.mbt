///|
/// Raised when a compressed Gateway stream cannot be decoded.
pub(all) suberror InflateError {
  /// The compressed stream is corrupt or ends early.
  Malformed(message~ : String)
  InvalidUtf8
  /// One message, compressed or inflated, exceeded `limit` bytes.
  TooLarge(limit~ : Int32)
} derive(Debug)

///|
/// Stateful decoder seam for Gateway compression. Implementations retain one
/// inflate context across messages. `None` means the message is not complete
/// yet (zlib-stream: its Z_SYNC_FLUSH suffix has not arrived).
pub(open) trait Inflater {
  fn push(Self, Bytes) -> String? raise
}
