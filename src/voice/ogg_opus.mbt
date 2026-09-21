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
/// Create an empty reader; feed it Ogg data with `push` and drain packets
/// with `next_packet`.
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
fn OggPacketReader::has_incomplete_input(self : OggPacketReader) -> Bool {
  self.cursor < self.buffer.length() || !self.partial_packet.is_empty()
}

///|
fn has_magic(bytes : Bytes, magic : Bytes) -> Bool {
  bytes.length() >= magic.length() && bytes[:magic.length()] == magic
}

///|
/// In-memory Ogg/Opus source. Opus packets must already represent 20 ms audio
/// frames; this demuxer does not decode or resample them.
pub struct OggOpusSource {
  priv reader : OggPacketReader
  priv input : &@io.Reader?
  priv channels_ : Int
  priv pre_skip_ : Int
}

///|
fn validate_opus_headers(
  head : Bytes?,
  tags : Bytes?,
) -> (Int, Int) raise OggOpusError {
  guard head is Some(head) else {
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
  guard tags is Some(tags) else {
    raise InvalidOpusStream(reason="missing OpusTags packet")
  }
  if !has_magic(tags, b"OpusTags") {
    raise InvalidOpusStream(reason="invalid OpusTags packet")
  }
  (channels, pre_skip)
}

///|
/// Parse a complete in-memory Ogg Opus file into an audio source, validating
/// its `OpusHead`/`OpusTags` headers.
pub fn OggOpusSource::from_bytes(
  bytes : Bytes,
) -> OggOpusSource raise OggOpusError {
  let reader = OggPacketReader::new()
  reader.push(bytes)
  let head = reader.next_packet()
  let tags = reader.next_packet()
  let (channels, pre_skip) = validate_opus_headers(head, tags)
  { reader, input: None, channels_: channels, pre_skip_: pre_skip, }
}

///|
/// Open an Ogg/Opus source backed by an asynchronous reader. The constructor
/// consumes and validates the `OpusHead` and `OpusTags` packets; audio packets
/// are read lazily by `AudioSource::next_frame`.
///
/// # Example
/// ```mbt nocheck
/// async test {
///   let file = @fs.open("voice.ogg")
///   defer file.close()
///   let source = @voice.OggOpusSource::from_reader(file)
///   let audio : &@voice.AudioSource = source
///   while audio.next_frame() is Some(frame) {
///     play_opus_frame(frame)
///   }
/// }
/// ```
pub async fn OggOpusSource::from_reader(input : &@io.Reader) -> OggOpusSource {
  let reader = OggPacketReader::new()
  let mut head : Bytes? = None
  let mut tags : Bytes? = None
  for ;; {
    while reader.next_packet() is Some(packet) {
      if head is None {
        head = Some(packet)
      } else {
        tags = Some(packet)
        break
      }
    }
    if tags is Some(_) {
      break
    }
    match input.read_some(max_len=8192) {
      Some(chunk) => reader.push(chunk)
      None => break
    }
  }
  let (channels, pre_skip) = validate_opus_headers(head, tags)
  { reader, input: Some(input), channels_: channels, pre_skip_: pre_skip, }
}

///|
/// The channel count declared by the stream's `OpusHead` header.
pub fn OggOpusSource::channels(self : OggOpusSource) -> Int {
  self.channels_
}

///|
/// Samples (at 48 kHz) to drop before playback, from the `OpusHead` header.
pub fn OggOpusSource::pre_skip(self : OggOpusSource) -> Int {
  self.pre_skip_
}

///|
pub extend OggOpusSource with AudioSource::{next_frame}

///|
/// Yield the next raw Opus packet, pulling more input on demand for
/// streaming sources; `None` at end of stream.
pub impl AudioSource for OggOpusSource with fn next_frame(self) {
  for ;; {
    if self.reader.next_packet() is Some(packet) {
      return Some(packet)
    }
    guard self.input is Some(input) else { return None }
    match input.read_some(max_len=8192) {
      Some(chunk) => self.reader.push(chunk)
      None => {
        if self.reader.has_incomplete_input() {
          raise InvalidOpusStream(reason="truncated ogg stream")
        }
        return None
      }
    }
  }
}

///|
fn push_u16_le(output : Array[Byte], value : Int) -> Unit {
  output.push(value.to_byte())
  output.push((value >> 8).to_byte())
}

///|
fn push_u32_le(output : Array[Byte], value : UInt) -> Unit {
  output.push(value.to_byte())
  output.push((value >> 8).to_byte())
  output.push((value >> 16).to_byte())
  output.push((value >> 24).to_byte())
}

///|
fn push_u64_le(output : Array[Byte], value : UInt64) -> Unit {
  for shift in 0..<8 {
    output.push((value >> (shift * 8)).to_byte())
  }
}

///|
fn opus_packet_segment_count(packet : Bytes) -> Int {
  packet.length() / 255 + 1
}

///|
fn append_opus_packet_lacing(laces : Array[Byte], packet : Bytes) -> Unit {
  let mut remaining = packet.length()
  while remaining >= 255 {
    laces.push(b'\xFF')
    remaining -= 255
  }
  laces.push(remaining.to_byte())
}

///|
/// Pure in-memory Ogg/Opus muxer. Header pages are available immediately from
/// `take_output`; audio pages become available as packet or lacing limits are
/// reached, and `finish` emits the final EOS page.
pub struct OggOpusWriter {
  priv serial : UInt
  priv max_packets_per_page : Int
  priv mut page_sequence : UInt
  priv mut granule : UInt64
  priv audio_packets : Array[Bytes]
  priv mut audio_segments : Int
  priv output : Array[Byte]
  priv mut finished : Bool
}

///|
fn OggOpusWriter::emit_page(
  self : OggOpusWriter,
  header_type : Byte,
  granule : UInt64,
  packets : Array[Bytes],
) -> Unit {
  let laces : Array[Byte] = []
  for packet in packets {
    append_opus_packet_lacing(laces, packet)
  }
  let page : Array[Byte] = [b'O', b'g', b'g', b'S', 0, header_type]
  push_u64_le(page, granule)
  push_u32_le(page, self.serial)
  push_u32_le(page, self.page_sequence)
  push_u32_le(page, 0U)
  page.push(laces.length().to_byte())
  page.append(laces)
  for packet in packets {
    for byte in packet {
      page.push(byte)
    }
  }
  let checksum = ogg_page_crc(page)
  page[22] = checksum.to_byte()
  page[23] = (checksum >> 8).to_byte()
  page[24] = (checksum >> 16).to_byte()
  page[25] = (checksum >> 24).to_byte()
  self.output.append(page)
  self.page_sequence += 1
}

///|
fn OggOpusWriter::flush_audio_page(self : OggOpusWriter, eos~ : Bool) -> Unit {
  if self.audio_packets.is_empty() {
    if eos {
      self.emit_page(b'\x04', self.granule, [])
    }
    return
  }
  self.emit_page(
    if eos {
      b'\x04'
    } else {
      0
    },
    self.granule,
    self.audio_packets,
  )
  self.audio_packets.clear()
  self.audio_segments = 0
}

///|
/// Create an Ogg/Opus muxer and queue its `OpusHead` and `OpusTags` pages.
///
/// # Example
/// ```mbt nocheck
/// async test {
///   let writer = @voice.OggOpusWriter::new(channels=2, pre_skip=312)
///   for frame in recorded_opus_frames() {
///     writer.write_frame(frame)
///   }
///   writer.finish()
///   let file = @fs.create("recording.ogg")
///   defer file.close()
///   file.write(writer.take_output())
/// }
/// ```
///
/// # Panics
/// Panics if `channels` or `pre_skip` cannot be represented in an Opus header,
/// or if `max_packets_per_page` is not positive.
pub fn OggOpusWriter::new(
  channels? : Int = 2,
  pre_skip? : Int = 0,
  serial? : UInt = 0U,
  max_packets_per_page? : Int = 50,
) -> OggOpusWriter {
  if channels <= 0 || channels > 255 {
    abort("OggOpusWriter channels must be between 1 and 255")
  }
  if pre_skip < 0 || pre_skip > 65535 {
    abort("OggOpusWriter pre_skip must be between 0 and 65535")
  }
  if max_packets_per_page <= 0 {
    abort("OggOpusWriter max_packets_per_page must be positive")
  }
  let writer = OggOpusWriter::{
    serial,
    max_packets_per_page,
    page_sequence: 0U,
    granule: 0UL,
    audio_packets: [],
    audio_segments: 0,
    output: [],
    finished: false,
  }
  let head : Array[Byte] = [
    b'O',
    b'p',
    b'u',
    b's',
    b'H',
    b'e',
    b'a',
    b'd',
    1,
    channels.to_byte(),
  ]
  push_u16_le(head, pre_skip)
  push_u32_le(head, 48000U)
  push_u16_le(head, 0)
  head.push(0)
  writer.emit_page(b'\x02', 0UL, [Bytes::from_array(head)])
  let tags = b"OpusTags\x0B\x00\x00\x00discord.mbt\x00\x00\x00\x00"
  writer.emit_page(0, 0UL, [tags])
  writer
}

///|
/// Queue one complete Opus packet and advance the 48 kHz granule position.
pub fn OggOpusWriter::write_frame(
  self : OggOpusWriter,
  opus : Bytes,
  samples? : Int = 960,
) -> Unit raise OggOpusError {
  if self.finished {
    raise InvalidOpusStream(reason="cannot write an Opus frame after finish")
  }
  if samples < 0 {
    raise InvalidOpusStream(reason="Opus frame sample count is negative")
  }
  let segments = opus_packet_segment_count(opus)
  if segments > 255 {
    raise InvalidOpusStream(reason="Opus packet exceeds one Ogg page")
  }
  if !self.audio_packets.is_empty() && self.audio_segments + segments > 255 {
    self.flush_audio_page(eos=false)
  }
  self.audio_packets.push(opus)
  self.audio_segments += segments
  self.granule += samples.to_uint64()
  if self.audio_packets.length() >= self.max_packets_per_page {
    self.flush_audio_page(eos=false)
  }
}

///|
/// Flush remaining packets in a final EOS page. Repeated calls are no-ops.
pub fn OggOpusWriter::finish(self : OggOpusWriter) -> Unit {
  guard !self.finished else { return }
  self.flush_audio_page(eos=true)
  self.finished = true
}

///|
/// Drain all complete Ogg pages generated so far.
pub fn OggOpusWriter::take_output(self : OggOpusWriter) -> Bytes {
  let result = Bytes::from_array(self.output)
  self.output.clear()
  result
}
