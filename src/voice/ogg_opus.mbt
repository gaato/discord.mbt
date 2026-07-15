///|
/// Errors raised while parsing Ogg pages and Opus stream headers.
pub(all) suberror OggOpusError {
  InvalidOggPage(reason~ : String)
  InvalidOpusStream(reason~ : String)
} derive(Debug, Eq)

///|
fn ogg_crc_table() -> FixedArray[UInt] {
  FixedArray::makei(256, index => {
    let mut value = index.reinterpret_as_uint() << 24
    for _ in 0..<8 {
      value = if (value & 0x80000000U) != 0 {
        (value << 1) ^ 0x04C11DB7U
      } else {
        value << 1
      }
    }
    value
  })
}

///|
fn ogg_page_crc(page : ArrayView[Byte]) -> UInt {
  let table = ogg_crc_table()
  let mut crc = 0U
  for index, byte in page {
    let value : Byte = if index >= 22 && index < 26 { 0 } else { byte }
    let table_index = ((crc >> 24) ^ value.to_uint()).reinterpret_as_int()
    crc = (crc << 8) ^ table[table_index]
  }
  crc
}

///|
fn read_array_u32_le(bytes : Array[Byte], offset : Int) -> UInt {
  bytes[offset].to_uint() |
  (bytes[offset + 1].to_uint() << 8) |
  (bytes[offset + 2].to_uint() << 16) |
  (bytes[offset + 3].to_uint() << 24)
}

///|
/// Streaming Ogg packet reassembler. Feed arbitrary chunks with `push`, then
/// pull complete packets with `next_packet`.
pub struct OggPacketReader {
  priv buffer : Array[Byte]
  priv mut cursor : Int
  priv partial_packet : Array[Byte]
  priv ready_packets : Array[Bytes]
  priv mut ready_cursor : Int
  priv mut stream_serial : UInt?
  priv mut expected_page_sequence : UInt?
}

///|
pub fn OggPacketReader::new() -> OggPacketReader {
  {
    buffer: [],
    cursor: 0,
    partial_packet: [],
    ready_packets: [],
    ready_cursor: 0,
    stream_serial: None,
    expected_page_sequence: None,
  }
}

///|
/// Add bytes to the streaming input without requiring a page boundary.
pub fn OggPacketReader::push(self : OggPacketReader, bytes : Bytes) -> Unit {
  for byte in bytes {
    self.buffer.push(byte)
  }
}

///|
fn OggPacketReader::take_ready(self : OggPacketReader) -> Bytes? {
  if self.ready_cursor >= self.ready_packets.length() {
    self.ready_packets.clear()
    self.ready_cursor = 0
    return None
  }
  let packet = self.ready_packets[self.ready_cursor]
  self.ready_cursor += 1
  Some(packet)
}

///|
fn OggPacketReader::parse_page(
  self : OggPacketReader,
) -> Bool raise OggOpusError {
  let available = self.buffer.length() - self.cursor
  if available < 27 {
    return false
  }
  let start = self.cursor
  if self.buffer[start] != b'O' ||
    self.buffer[start + 1] != b'g' ||
    self.buffer[start + 2] != b'g' ||
    self.buffer[start + 3] != b'S' {
    raise InvalidOggPage(reason="missing OggS capture pattern")
  }
  if self.buffer[start + 4] != 0 {
    raise InvalidOggPage(reason="unsupported Ogg bitstream version")
  }
  let segment_count = self.buffer[start + 26].to_int()
  if available < 27 + segment_count {
    return false
  }
  let mut body_length = 0
  for index in 0..<segment_count {
    body_length += self.buffer[start + 27 + index].to_int()
  }
  let page_length = 27 + segment_count + body_length
  if available < page_length {
    return false
  }
  let page = self.buffer[start:start + page_length]
  let expected_crc = read_array_u32_le(self.buffer, start + 22)
  if ogg_page_crc(page) != expected_crc {
    raise InvalidOggPage(reason="Ogg page CRC mismatch")
  }

  let serial = read_array_u32_le(self.buffer, start + 14)
  let page_sequence = read_array_u32_le(self.buffer, start + 18)
  match self.stream_serial {
    None => self.stream_serial = Some(serial)
    Some(expected) if expected != serial =>
      raise InvalidOggPage(
        reason="multiple logical Ogg streams are unsupported",
      )
    Some(_) => ()
  }
  match self.expected_page_sequence {
    None => ()
    Some(expected) if expected != page_sequence =>
      raise InvalidOggPage(reason="non-contiguous Ogg page sequence")
    Some(_) => ()
  }
  self.expected_page_sequence = Some(page_sequence + 1)

  let continued = (self.buffer[start + 5].to_int() & 0x01) != 0
  if continued && self.partial_packet.is_empty() {
    raise InvalidOggPage(reason="continued page has no preceding packet")
  }
  if !continued && !self.partial_packet.is_empty() {
    raise InvalidOggPage(reason="continued packet is missing its page flag")
  }
  let mut body_cursor = start + 27 + segment_count
  for index in 0..<segment_count {
    let lace = self.buffer[start + 27 + index].to_int()
    for offset in 0..<lace {
      self.partial_packet.push(self.buffer[body_cursor + offset])
    }
    body_cursor += lace
    if lace < 255 {
      self.ready_packets.push(Bytes::from_array(self.partial_packet))
      self.partial_packet.clear()
    }
  }
  self.cursor += page_length
  if self.cursor == self.buffer.length() {
    self.buffer.clear()
    self.cursor = 0
  }
  true
}

///|
/// Return the next complete Ogg packet, or `None` when more input is needed.
pub fn OggPacketReader::next_packet(
  self : OggPacketReader,
) -> Bytes? raise OggOpusError {
  if self.take_ready() is Some(packet) {
    return Some(packet)
  }
  while self.parse_page() {
    if self.take_ready() is Some(packet) {
      return Some(packet)
    }
  }
  None
}

///|
fn has_magic(bytes : Bytes, magic : Bytes) -> Bool {
  bytes.length() >= magic.length() && bytes[:magic.length()] == magic[:]
}

///|
/// In-memory Ogg/Opus source. Opus packets must already represent 20 ms audio
/// frames; this demuxer does not decode or resample them.
pub struct OggOpusSource {
  priv reader : OggPacketReader
  priv channels_ : Int
  priv pre_skip_ : Int
}

///|
pub fn OggOpusSource::from_bytes(
  bytes : Bytes,
) -> OggOpusSource raise OggOpusError {
  let reader = OggPacketReader::new()
  reader.push(bytes)
  guard reader.next_packet() is Some(head) else {
    raise InvalidOpusStream(reason="missing OpusHead packet")
  }
  if !has_magic(head, b"OpusHead") || head.length() < 19 {
    raise InvalidOpusStream(reason="invalid OpusHead packet")
  }
  if head[8] != 1 {
    raise InvalidOpusStream(reason="unsupported OpusHead version")
  }
  let channels = head[9].to_int()
  if channels == 0 {
    raise InvalidOpusStream(reason="OpusHead channel count is zero")
  }
  let pre_skip = head[10].to_int() | (head[11].to_int() << 8)
  guard reader.next_packet() is Some(tags) else {
    raise InvalidOpusStream(reason="missing OpusTags packet")
  }
  if !has_magic(tags, b"OpusTags") {
    raise InvalidOpusStream(reason="invalid OpusTags packet")
  }
  { reader, channels_: channels, pre_skip_: pre_skip }
}

///|
pub fn OggOpusSource::channels(self : OggOpusSource) -> Int {
  self.channels_
}

///|
pub fn OggOpusSource::pre_skip(self : OggOpusSource) -> Int {
  self.pre_skip_
}

///|
pub impl AudioSource for OggOpusSource with fn next_frame(self) {
  self.reader.next_packet()
}
