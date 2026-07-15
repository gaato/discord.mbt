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
