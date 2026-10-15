///|
/// Whether this backend can inflate Discord's `zlib-stream` transport
/// compression. False here: leave `compress` off.
pub fn zlib_stream_supported() -> Bool {
  false
}

///|
fn new_zlib_stream_inflater() -> &Inflater raise {
  raise InflateError::Unsupported
}
