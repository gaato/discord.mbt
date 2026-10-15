///|
test "RTP header matches the Discord voice wire format" {
  let header = @voice.build_rtp_header(
    sequence=0x1234,
    timestamp=0x01020304U,
    ssrc=0xA0B0C0D0U,
  )
  assert_eq(header, b"\x80\x78\x12\x34\x01\x02\x03\x04\xA0\xB0\xC0\xD0")
  let packet = @voice.parse_rtp_packet(header + b"opus")
  assert_eq(packet.sequence, 0x1234)
  assert_eq(packet.timestamp, 0x01020304U)
  assert_eq(packet.ssrc, 0xA0B0C0D0U)
  assert_eq(packet.header_len, 12)
  assert_eq(packet.payload, b"opus")
}

///|
test "RTP sequence arithmetic wraps at u16" {
  let packet = @voice.parse_rtp_packet(
    @voice.build_rtp_header(sequence=0xffff, timestamp=0U, ssrc=1U),
  )
  assert_eq(packet.sequence + 1, 0)
}

///|
test "rtpsize header length covers CSRC and extension preamble" {
  let base = @voice.build_rtp_header(sequence=0, timestamp=0U, ssrc=1U)
  let csrc = b"\x81\x78" + base[2:].to_owned() + b"\x00\x00\x00\x02"
  assert_eq(@voice.rtpsize_header_len(csrc), 16)
  let extension = b"\x91\x78" +
    base[2:].to_owned() +
    b"\x00\x00\x00\x02\xBE\xDE\x00\x01"
  assert_eq(@voice.rtpsize_header_len(extension), 20)
  assert_eq(
    @voice.parse_rtp_packet(extension + b"extension-data").header_len,
    20,
  )
}

///|
fn expect_rtp_error(bytes : Bytes, expected : String) -> Unit raise {
  try @voice.parse_rtp_packet(bytes) catch {
    InvalidRtpPacket(reason~) => assert_eq(reason, expected)
  } noraise {
    _ => fail("expected an RTP parse error: \{expected}")
  }
}

///|
test "RTP parsing rejects each malformed header" {
  let base = @voice.build_rtp_header(sequence=0, timestamp=0U, ssrc=1U)
  expect_rtp_error(base[:11].to_owned(), "RTP packet is shorter than 12 bytes")
  expect_rtp_error(b"\x40" + base[1:].to_owned(), "RTP version is not 2")
  expect_rtp_error(
    b"\x81" + base[1:].to_owned(),
    "RTP CSRC or extension header is truncated",
  )
  expect_rtp_error(
    b"\x90" + base[1:].to_owned(),
    "RTP CSRC or extension header is truncated",
  )
  assert_eq(@voice.rtpsize_header_len(base[:11].to_owned()), 0)
}
