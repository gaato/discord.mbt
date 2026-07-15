///|
fn test_ogg_crc(bytes : Array[Byte]) -> UInt {
  let mut crc = 0U
  for byte in bytes {
    crc = crc ^ (byte.to_uint() << 24)
    for _ in 0..<8 {
      crc = if (crc & 0x80000000U) != 0 {
        (crc << 1) ^ 0x04C11DB7U
      } else {
        crc << 1
      }
    }
  }
  crc
}

///|
fn push_test_u32_le(bytes : Array[Byte], value : UInt) -> Unit {
  bytes.push(value.to_byte())
  bytes.push((value >> 8).to_byte())
  bytes.push((value >> 16).to_byte())
  bytes.push((value >> 24).to_byte())
}

///|
fn test_ogg_page(
  header_type : Byte,
  page_sequence : UInt,
  laces : Array[Byte],
  body : Bytes,
) -> Bytes {
  let page : Array[Byte] = [b'O', b'g', b'g', b'S', 0, header_type]
  for _ in 0..<8 {
    page.push(0)
  }
  push_test_u32_le(page, 0x11223344U)
  push_test_u32_le(page, page_sequence)
  push_test_u32_le(page, 0U)
  page.push(laces.length().to_byte())
  for lace in laces {
    page.push(lace)
  }
  for byte in body {
    page.push(byte)
  }
  let checksum = test_ogg_crc(page)
  page[22] = checksum.to_byte()
  page[23] = (checksum >> 8).to_byte()
  page[24] = (checksum >> 16).to_byte()
  page[25] = (checksum >> 24).to_byte()
  Bytes::from_array(page)
}

///|
fn test_opus_fixture() -> (Bytes, Array[Bytes]) {
  let head = b"OpusHead\x01\x02\x38\x01\x80\xBB\x00\x00\x00\x00\x00"
  let tags = b"OpusTags\x00\x00\x00\x00"
  let frames : Array[Bytes] = [b"one", b"two", b"three"]
  let body = head + tags + frames[0] + frames[1] + frames[2]
  let page = test_ogg_page(
    b'\x02',
    0U,
    [
      head.length().to_byte(),
      tags.length().to_byte(),
      frames[0].length().to_byte(),
      frames[1].length().to_byte(),
      frames[2].length().to_byte(),
    ],
    body,
  )
  (page, frames)
}

///|
async test "Ogg Opus source validates headers and yields audio packets" {
  let (fixture, frames) = test_opus_fixture()
  let source = @voice.OggOpusSource::from_bytes(fixture)
  assert_eq(source.channels(), 2)
  assert_eq(source.pre_skip(), 312)
  let audio : &@voice.AudioSource = source
  for frame in frames {
    assert_eq(audio.next_frame(), Some(frame))
  }
  assert_eq(audio.next_frame(), None)
}

///|
test "Ogg packet reader accepts one-byte streaming chunks" {
  let (fixture, _) = test_opus_fixture()
  let reader = @voice.OggPacketReader::new()
  let packets : Array[Bytes] = []
  for byte in fixture {
    reader.push(Bytes::from_array([byte]))
    for ;; {
      guard reader.next_packet() is Some(packet) else { break }
      packets.push(packet)
    }
  }
  assert_eq(packets.length(), 5)
  assert_eq(packets[0][:8], b"OpusHead"[:])
  assert_eq(packets[1][:8], b"OpusTags"[:])
  assert_eq(packets[2:], [b"one", b"two", b"three"][:])
}

///|
test "Ogg packet reader rejects CRC corruption" {
  let (fixture, _) = test_opus_fixture()
  let corrupted = fixture.to_array()
  corrupted[corrupted.length() - 1] = corrupted[corrupted.length() - 1] ^
    b'\x01'
  let reader = @voice.OggPacketReader::new()
  reader.push(Bytes::from_array(corrupted))
  try reader.next_packet() catch {
    InvalidOggPage(reason~) => assert_true(reason.contains("CRC"))
    _ => fail("unexpected Ogg error")
  } noraise {
    _ => fail("expected CRC rejection")
  }
}

///|
test "Ogg packet reader reconstructs a packet across continued pages" {
  let packet = Bytes::makei(300, index => (index % 251).to_byte())
  let first = test_ogg_page(b'\x02', 0U, [255], packet[:255].to_owned())
  let second = test_ogg_page(b'\x01', 1U, [45], packet[255:].to_owned())
  let reader = @voice.OggPacketReader::new()
  reader.push(first)
  assert_eq(reader.next_packet(), None)
  reader.push(second)
  assert_eq(reader.next_packet(), Some(packet))
}

///|
async fn collect_ogg_source(source : @voice.OggOpusSource) -> Array[Bytes] {
  let audio : &@voice.AudioSource = source
  let frames : Array[Bytes] = []
  while audio.next_frame() is Some(frame) {
    frames.push(frame)
  }
  frames
}

///|
async fn read_pipe_fixture(
  fixture : Bytes,
  chunk_size : Int,
) -> (Int, Int, Array[Bytes]) {
  @async.with_task_group(group => {
    let (read_end, write_end) = @pipe.pipe()
    defer read_end.close()
    group.spawn_bg(() => {
      defer write_end.close()
      for offset = 0; offset < fixture.length(); {
        let next = offset + chunk_size
        let end = if next < fixture.length() { next } else { fixture.length() }
        write_end.write(fixture[offset:end])
        continue end
      }
    })
    let source = @voice.OggOpusSource::from_reader(read_end)
    (source.channels(), source.pre_skip(), collect_ogg_source(source))
  })
}

///|
async test "Ogg Opus reader streams the golden fixture in small chunks" {
  let (fixture, frames) = test_opus_fixture()
  let expected_source = @voice.OggOpusSource::from_bytes(fixture)
  let expected = collect_ogg_source(expected_source)
  let (channels, pre_skip, actual) = read_pipe_fixture(fixture, 7)
  assert_eq(channels, 2)
  assert_eq(pre_skip, 312)
  assert_eq(expected, frames)
  assert_eq(actual, expected)
}

///|
async test "Ogg Opus reader accepts headers straddling input chunks" {
  let writer = @voice.OggOpusWriter::new(channels=1, pre_skip=80)
  writer.write_frame(b"audio")
  writer.finish()
  let (channels, pre_skip, frames) = read_pipe_fixture(writer.take_output(), 11)
  assert_eq(channels, 1)
  assert_eq(pre_skip, 80)
  assert_eq(frames, [b"audio"])
}

///|
async test "Ogg Opus reader rejects a stream truncated mid-page" {
  let writer = @voice.OggOpusWriter::new()
  writer.write_frame(b"truncated-frame")
  writer.finish()
  let complete = writer.take_output()
  let truncated = complete[:complete.length() - 1].to_owned()
  @async.with_task_group(group => {
    let (read_end, write_end) = @pipe.pipe()
    defer read_end.close()
    group.spawn_bg(() => {
      defer write_end.close()
      write_end.write(truncated)
    })
    let source = @voice.OggOpusSource::from_reader(read_end)
    let audio : &@voice.AudioSource = source
    try audio.next_frame() catch {
      @voice.OggOpusError::InvalidOpusStream(reason~) =>
        assert_true(reason.contains("truncated"))
      _ => fail("unexpected Ogg/Opus error")
    } noraise {
      _ => fail("expected truncated stream rejection")
    }
  })
}

///|
fn writer_test_frames() -> Array[Bytes] {
  [
    b"a",
    Bytes::makei(255, index => (index % 251).to_byte()),
    Bytes::makei(300, index => ((index + 17) % 251).to_byte()),
    b"last-frame",
  ]
}

///|
async test "Ogg Opus writer round-trips varied packet lengths" {
  let frames = writer_test_frames()
  let writer = @voice.OggOpusWriter::new(
    channels=1,
    pre_skip=312,
    serial=0x11223344U,
  )
  for frame in frames {
    writer.write_frame(frame)
  }
  writer.finish()
  let source = @voice.OggOpusSource::from_bytes(writer.take_output())
  assert_eq(source.channels(), 1)
  assert_eq(source.pre_skip(), 312)
  assert_eq(collect_ogg_source(source), frames)
}

///|
async test "Ogg Opus writer emits contiguous multi-page audio" {
  let frames = writer_test_frames()
  let writer = @voice.OggOpusWriter::new(max_packets_per_page=2)
  for frame in frames {
    writer.write_frame(frame)
  }
  writer.finish()
  let source = @voice.OggOpusSource::from_bytes(writer.take_output())
  assert_eq(collect_ogg_source(source), frames)
}

///|
fn last_ogg_page_header_type(ogg : Bytes) -> Byte {
  let mut cursor = 0
  let mut header_type = b'\x00'
  while cursor < ogg.length() {
    header_type = ogg[cursor + 5]
    let segment_count = ogg[cursor + 26].to_int()
    let mut body_length = 0
    for index in 0..<segment_count {
      body_length += ogg[cursor + 27 + index].to_int()
    }
    cursor += 27 + segment_count + body_length
  }
  header_type
}

///|
test "Ogg Opus writer marks its final page EOS" {
  let writer = @voice.OggOpusWriter::new(max_packets_per_page=2)
  writer.write_frame(b"one")
  writer.write_frame(b"two")
  writer.finish()
  let header_type = last_ogg_page_header_type(writer.take_output())
  assert_true((header_type.to_int() & 0x04) != 0)
}

///|
test "Ogg Opus writer incremental output matches one final drain" {
  let frames = writer_test_frames()
  let incremental_writer = @voice.OggOpusWriter::new(
    serial=7U,
    max_packets_per_page=2,
  )
  let mut incremental = incremental_writer.take_output()
  for frame in frames {
    incremental_writer.write_frame(frame)
    incremental = incremental + incremental_writer.take_output()
  }
  incremental_writer.finish()
  incremental = incremental + incremental_writer.take_output()

  let final_writer = @voice.OggOpusWriter::new(
    serial=7U,
    max_packets_per_page=2,
  )
  for frame in frames {
    final_writer.write_frame(frame)
  }
  final_writer.finish()
  assert_eq(incremental, final_writer.take_output())
}

///|
test "Ogg Opus writer rejects frames after finish" {
  let writer = @voice.OggOpusWriter::new()
  writer.finish()
  try writer.write_frame(b"late") catch {
    InvalidOpusStream(reason~) => assert_true(reason.contains("after finish"))
    _ => fail("unexpected Ogg/Opus error")
  } noraise {
    _ => fail("expected write-after-finish rejection")
  }
}
