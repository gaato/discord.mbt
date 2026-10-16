///|
/// Raised when a compressed Gateway stream cannot be decoded.
pub(all) suberror InflateError {
  /// The zlib-stream bytes are corrupt or end the stream early.
  Malformed(message~ : String)
  InvalidUtf8
} derive(Debug)

///|
/// Stateful decoder seam for Gateway compression. Implementations retain one
/// inflate context across messages. `None` means the Z_SYNC_FLUSH suffix has
/// not arrived yet.
pub(open) trait Inflater {
  fn push(Self, Bytes) -> String? raise
}
