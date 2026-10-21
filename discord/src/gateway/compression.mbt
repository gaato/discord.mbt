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
/// Inflates one Gateway message at a time out of a stream that never ends:
/// zlib-stream and zstd-stream differ only in their decoder and in how a
/// message's end is found.
priv struct MessageInflater {
  decoder : &@codec_bytes.Decode
  // What the stream is called in errors: "zlib-stream" or "zstd-stream".
  name : String
  // Reused across messages; grows to the largest message seen.
  mut out : FixedArray[Byte]
  // The most bytes one message may take, compressed or inflated.
  max_bytes : Int32
}

///|
/// `decoder` is made with `until=EndOfMember`, so that a stream that ends,
/// which a Gateway stream never does, answers `Done` at once; under the
/// default it would wait for what follows.
fn MessageInflater::new(
  decoder : &@codec_bytes.Decode,
  name : String,
  max_bytes : Int32,
) -> MessageInflater {
  { decoder, name, out: FixedArray::make(16384, 0), max_bytes, }
}

///|
/// Inflates `message`, all of one Gateway message. The stream does not end
/// after it, so `NeedMoreInput` with the message consumed means every byte
/// it holds is out (gaato/codec_bytes' first rule).
fn MessageInflater::inflate(
  self : MessageInflater,
  message : BytesView,
) -> Bytes raise InflateError {
  let mut input = message
  let mut len = 0
  while true {
    if len == self.out.length() {
      let grown = FixedArray::make(len * 2, b'\x00')
      self.out.blit_to(grown, len~)
      self.out = grown
    }
    let status = self.decoder.step(
      input,
      self.out.mut_view(start=len),
      end=false,
    ) catch {
      CodecError(_, message) => raise Malformed(message~)
    }
    len += self.decoder.last_produced()
    if len > self.max_bytes {
      raise TooLarge(limit=self.max_bytes)
    }
    input = input[self.decoder.last_consumed():]
    match status {
      NeedMoreInput => break
      NeedMoreOutput => continue
      Done => raise Malformed(message="\{self.name} ended")
    }
  }
  Bytes::from_array(self.out[:len])
}

///|
fn utf8_message(plain : Bytes) -> String raise InflateError {
  @utf8.decode(plain) catch {
    _ => raise InflateError::InvalidUtf8
  }
}

///|
/// zlib-stream: a message may come in several WebSocket messages, and ends
/// with the `00 00 ff ff` of a sync flush.
priv struct ZlibStreamInflater {
  message : MessageInflater
  pending : Array[Byte]
}

///|
fn ZlibStreamInflater::ZlibStreamInflater(
  max_bytes~ : Int32 = DEFAULT_MAX_MESSAGE_BYTES,
) -> ZlibStreamInflater {
  {
    message: MessageInflater::new(
      @zlib.Decoder(until=EndOfMember),
      "zlib-stream",
      max_bytes,
    ),
    pending: [],
  }
}

///|
fn has_sync_flush_suffix(bytes : Array[Byte]) -> Bool {
  bytes is [.., 0x00, 0x00, 0xff, 0xff]
}

///|
impl Inflater for ZlibStreamInflater with fn push(self, bytes) {
  let max_bytes = self.message.max_bytes
  if self.pending.length() + bytes.length() > max_bytes {
    self.pending.clear()
    raise TooLarge(limit=max_bytes)
  }
  for byte in bytes {
    self.pending.push(byte)
  }
  if !has_sync_flush_suffix(self.pending) {
    return None
  }
  let compressed = Bytes::from_array(self.pending)
  self.pending.clear()
  Some(utf8_message(self.message.inflate(compressed)))
}

///|
/// zstd-stream: every WebSocket message is a whole Gateway message, flushed
/// to a block boundary of the one frame the connection never ends.
priv struct ZstdStreamInflater {
  message : MessageInflater
}

///|
/// The decoder keeps the default window limit (2^27 bytes): Discord picks the
/// window, and a frame that declares a larger one ends the connection.
fn ZstdStreamInflater::ZstdStreamInflater(
  max_bytes~ : Int32 = DEFAULT_MAX_MESSAGE_BYTES,
) -> ZstdStreamInflater {
  {
    message: MessageInflater::new(
      @zstd.Decoder(until=EndOfMember),
      "zstd-stream",
      max_bytes,
    ),
  }
}

///|
impl Inflater for ZstdStreamInflater with fn push(self, bytes) {
  if bytes.length() > self.message.max_bytes {
    raise TooLarge(limit=self.message.max_bytes)
  }
  Some(utf8_message(self.message.inflate(bytes)))
}
