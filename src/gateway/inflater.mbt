///|
/// Raised when a compressed Gateway stream cannot be initialized or decoded.
pub(all) suberror InflateError {
  InflateError(status~ : Int)
  InvalidUtf8
  /// This backend has no zlib-stream inflater (JavaScript and Wasm).
  Unsupported
} derive(Debug)

///|
/// Stateful decoder seam for Gateway compression. Implementations retain one
/// inflate context across messages. `None` means the Z_SYNC_FLUSH suffix has
/// not arrived yet.
pub(open) trait Inflater {
  fn push(Self, Bytes) -> String? raise
}
