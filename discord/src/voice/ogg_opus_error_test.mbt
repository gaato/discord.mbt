///|
fn expect_page_error(pages : Array[Bytes], expected : String) -> Unit raise {
  let reader = @voice.OggPacketReader::new()
  for page in pages {
    reader.push(page)
  }
  try {
    for ;; {
      guard reader.next_packet() is Some(_) else { break }
    }
  } catch {
    InvalidOggPage(reason~) => assert_eq(reason, expected)
    _ => fail("unexpected Ogg error for: \{expected}")
  } noraise {
    _ => fail("expected an Ogg page error: \{expected}")
  }
}

///|
fn expect_stream_error(stream : Bytes, expected : String) -> Unit raise {
  try @voice.OggOpusSource::from_bytes(stream) |> ignore catch {
    InvalidOpusStream(reason~) => assert_eq(reason, expected)
    _ => fail("unexpected Opus stream error for: \{expected}")
  } noraise {
    _ => fail("expected an Opus stream error: \{expected}")
  }
}

///|
fn reserialize_page(page : Bytes, patch : (Array[Byte]) -> Unit) -> Bytes {
  let bytes = page.to_array()
  patch(bytes)
  for index in 22..<26 {
    bytes[index] = 0
  }
  let checksum = test_ogg_crc(bytes)
  bytes[22] = checksum.to_byte()
  bytes[23] = (checksum >> 8).to_byte()
  bytes[24] = (checksum >> 16).to_byte()
  bytes[25] = (checksum >> 24).to_byte()
  Bytes::from_array(bytes)
}

///|
test "Ogg packet reader rejects each malformed page shape" {
  let valid = test_ogg_page(b'\x02', 0U, [3], b"abc")
  let broken_capture = valid.to_array()
  broken_capture[0] = b'X'
  expect_page_error(
    [Bytes::from_array(broken_capture)],
    "missing OggS capture pattern",
  )
  expect_page_error(
    [reserialize_page(valid, bytes => bytes[4] = 1)],
    "unsupported Ogg bitstream version",
  )
  expect_page_error(
    [
      valid,
      reserialize_page(test_ogg_page(b'\x00', 1U, [1], b"z"), bytes => {
        bytes[14] = 0x99
      }),
    ],
    "multiple logical Ogg streams are unsupported",
  )
  expect_page_error(
    [valid, test_ogg_page(b'\x00', 5U, [1], b"z")],
    "non-contiguous Ogg page sequence",
  )
  expect_page_error(
    [test_ogg_page(b'\x01', 0U, [3], b"abc")],
    "continued page has no preceding packet",
  )
  let unfinished = test_ogg_page(
    b'\x02',
    0U,
    [255],
    Bytes::makei(255, index => (index % 251).to_byte()),
  )
  expect_page_error(
    [unfinished, test_ogg_page(b'\x00', 1U, [1], b"z")],
    "continued packet is missing its page flag",
  )
}

///|
test "Ogg Opus source rejects each malformed header stream" {
  expect_stream_error(b"", "missing OpusHead packet")
  expect_stream_error(
    test_ogg_page(b'\x02', 0U, [8], b"NotAHead"),
    "invalid OpusHead packet",
  )
  expect_stream_error(
    test_ogg_page(
      b'\x02',
      0U,
      [19],
      b"OpusHead\x02\x02\x38\x01\x80\xBB\x00\x00\x00\x00\x00",
    ),
    "unsupported OpusHead version",
  )
  expect_stream_error(
    test_ogg_page(
      b'\x02',
      0U,
      [19],
      b"OpusHead\x01\x00\x38\x01\x80\xBB\x00\x00\x00\x00\x00",
    ),
    "OpusHead channel count is zero",
  )
  let head = b"OpusHead\x01\x02\x38\x01\x80\xBB\x00\x00\x00\x00\x00"
  expect_stream_error(
    test_ogg_page(b'\x02', 0U, [head.length().to_byte()], head),
    "missing OpusTags packet",
  )
  expect_stream_error(
    test_ogg_page(b'\x02', 0U, [head.length().to_byte(), 7], head + b"NotTags"),
    "invalid OpusTags packet",
  )
}

///|
test "Ogg Opus writer rejects unwritable frames and splits full pages" {
  let writer = @voice.OggOpusWriter::new()
  try writer.write_frame(b"x", samples=-1) catch {
    InvalidOpusStream(reason~) =>
      assert_eq(reason, "Opus frame sample count is negative")
    _ => fail("unexpected writer error")
  } noraise {
    _ => fail("expected a negative sample count error")
  }
  try writer.write_frame(Bytes::new(66000)) catch {
    InvalidOpusStream(reason~) =>
      assert_eq(reason, "Opus packet exceeds one Ogg page")
    _ => fail("unexpected writer error")
  } noraise {
    _ => fail("expected an oversized packet error")
  }
  // Two ~half-page packets force the mid-stream page flush.
  writer.write_frame(Bytes::new(33000))
  writer.write_frame(Bytes::new(33000))
  writer.finish()
  assert_true(writer.take_output().length() > 66000)
}
