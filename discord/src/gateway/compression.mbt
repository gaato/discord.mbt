///|
/// Transport compression for a Gateway connection. Discord compresses what it
/// sends; what the shard sends stays plain.
#non_exhaustive
pub(all) enum GatewayCompression {
  /// `compress=zlib-stream`: one zlib context per connection, and every
  /// message ends with a `Z_SYNC_FLUSH`.
  ZlibStream
  /// `compress=zstd-stream`: one zstd frame per connection, and every
  /// WebSocket message is one Gateway message flushed to a block boundary.
  ZstdStream
} derive(Eq, Debug)

///|
pub extend GatewayCompression with Eq::{equal, not_equal}

///|
/// The `compress` query value Discord expects.
fn GatewayCompression::query_value(self : GatewayCompression) -> String {
  match self {
    ZlibStream => "zlib-stream"
    ZstdStream => "zstd-stream"
  }
}

///|
/// A fresh decoder for one connection's `compression`.
fn default_inflater(
  compression : GatewayCompression,
  max_bytes~ : Int32,
) -> &Inflater {
  match compression {
    ZlibStream => (ZlibStreamInflater(max_bytes~) : &Inflater)
    ZstdStream => (ZstdStreamInflater(max_bytes~) : &Inflater)
  }
}

///|
priv struct ZlibStreamInflater {
  decoder : @zlib.Decoder
  pending : Array[Byte]
  // Reused across messages; grows to the largest message seen.
  mut out : FixedArray[Byte]
  // The most bytes one message may take, compressed or inflated.
  max_bytes : Int32
}

///|
fn ZlibStreamInflater::ZlibStreamInflater(
  max_bytes~ : Int32 = DEFAULT_MAX_MESSAGE_BYTES,
) -> ZlibStreamInflater {
  {
    decoder: @zlib.Decoder(),
    pending: [],
    out: FixedArray::make(16384, 0),
    max_bytes,
  }
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
/// Inflate one sync-flushed message. One decoder step accepts at most 64 KiB
/// of input and emits every byte up to the flush point, so `NeedMoreInput`
/// with no input left means the message is complete.
fn ZlibStreamInflater::inflate(
  self : ZlibStreamInflater,
  compressed : Bytes,
) -> Bytes raise InflateError {
  let mut input = compressed[:]
  let mut len = 0
  while true {
    if len == self.out.length() {
      let grown = FixedArray::make(len * 2, b'\x00')
      self.out.blit_to(grown, len~)
      self.out = grown
    }
    let status = self.decoder.step(input, self.out.mut_view(start=len)) catch {
      ZlibError(_, message) => raise Malformed(message~)
    }
    len += self.decoder.last_produced()
    if len > self.max_bytes {
      raise TooLarge(limit=self.max_bytes)
    }
    input = input[self.decoder.last_consumed():]
    match status {
      NeedMoreInput => if input.length() == 0 { break }
      NeedMoreOutput => continue
      Done => raise Malformed(message="zlib-stream ended")
    }
  }
  Bytes::from_array(self.out[:len])
}

///|
impl Inflater for ZlibStreamInflater with fn push(self, bytes) {
  if self.pending.length() + bytes.length() > self.max_bytes {
    self.pending.clear()
    raise TooLarge(limit=self.max_bytes)
  }
  for byte in bytes {
    self.pending.push(byte)
  }
  if !has_sync_flush_suffix(self.pending) {
    return None
  }
  let compressed = Bytes::from_array(self.pending)
  self.pending.clear()
  let plain = self.inflate(compressed)
  Some(@utf8.decode(plain) catch { _ => raise InflateError::InvalidUtf8 })
}

///|
priv struct ZstdStreamInflater {
  decoder : @zstd.Decoder
  // Reused across messages; grows to the largest message seen.
  mut out : FixedArray[Byte]
  // The most bytes one message may take, compressed or inflated.
  max_bytes : Int32
}

///|
/// The decoder keeps the default window limit (2^27 bytes): Discord picks the
/// window, and a frame that declares a larger one ends the connection.
fn ZstdStreamInflater::ZstdStreamInflater(
  max_bytes~ : Int32 = DEFAULT_MAX_MESSAGE_BYTES,
) -> ZstdStreamInflater {
  { decoder: @zstd.Decoder(), out: FixedArray::make(16384, 0), max_bytes, }
}

///|
/// Every WebSocket message is a whole Gateway message: Discord flushes the
/// frame it never ends, so once the input is used up the decoder has handed
/// out every byte of the message.
impl Inflater for ZstdStreamInflater with fn push(self, bytes) {
  if bytes.length() > self.max_bytes {
    raise TooLarge(limit=self.max_bytes)
  }
  let mut input = bytes[:]
  let mut len = 0
  while true {
    if len == self.out.length() {
      let grown = FixedArray::make(len * 2, b'\x00')
      self.out.blit_to(grown, len~)
      self.out = grown
    }
    let status = self.decoder.step(input, self.out.mut_view(start=len)) catch {
      @zstd.ZstdError(_, message) => raise Malformed(message~)
    }
    len += self.decoder.last_produced()
    if len > self.max_bytes {
      raise TooLarge(limit=self.max_bytes)
    }
    input = input[self.decoder.last_consumed():]
    match status {
      NeedMoreInput => if input.length() == 0 { break }
      NeedMoreOutput => continue
      Done => raise Malformed(message="zstd-stream ended")
    }
  }
  Some(
    @utf8.decode(Bytes::from_array(self.out[:len])) catch {
      _ => raise InflateError::InvalidUtf8
    },
  )
}
