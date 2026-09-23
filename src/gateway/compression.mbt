///|
priv type ZlibHandle

///|
extern "C" fn zlib_new() -> ZlibHandle = "discord_gateway_zlib_new"

///|
#borrow(handle)
extern "C" fn zlib_status(handle : ZlibHandle) -> Int = "discord_gateway_zlib_status"

///|
#borrow(handle, input)
extern "C" fn zlib_inflate(handle : ZlibHandle, input : Bytes) -> Bytes = "discord_gateway_zlib_inflate"

///|
priv struct ZlibStreamInflater {
  handle : ZlibHandle
  pending : Array[Byte]
}

///|
fn ZlibStreamInflater::ZlibStreamInflater() -> ZlibStreamInflater raise InflateError {
  let handle = zlib_new()
  let status = zlib_status(handle)
  if status != 0 {
    raise InflateError(status~)
  }
  { handle, pending: [], }
}

///|
fn has_sync_flush_suffix(bytes : Array[Byte]) -> Bool {
  let len = bytes.length()
  len >= 4 &&
  bytes[len - 4] == 0x00 &&
  bytes[len - 3] == 0x00 &&
  bytes[len - 2] == 0xff &&
  bytes[len - 1] == 0xff
}

///|
impl Inflater for ZlibStreamInflater with fn push(self, bytes) {
  for byte in bytes {
    self.pending.push(byte)
  }
  if !has_sync_flush_suffix(self.pending) {
    return None
  }
  let compressed = Bytes::from_array(self.pending)
  self.pending.clear()
  let plain = zlib_inflate(self.handle, compressed)
  let status = zlib_status(self.handle)
  if status != 0 {
    raise InflateError(status~)
  }
  Some(@utf8.decode(plain) catch { _ => raise InflateError::InvalidUtf8 })
}

///|
fn new_zlib_stream_inflater() -> &Inflater raise {
  ZlibStreamInflater()
}

///|
/// Whether this backend can inflate Discord's `zlib-stream` transport
/// compression. True on native (zlib is loaded at runtime).
pub fn zlib_stream_supported() -> Bool {
  true
}
