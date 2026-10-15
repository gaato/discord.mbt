///|
/// A parsed RTP packet with the `rtpsize` cleartext header separated.
pub(all) struct RtpPacket {
  sequence : UInt16
  timestamp : UInt32
  ssrc : UInt32
  header_len : Int32
  header : Bytes
  payload : Bytes
} derive(Debug, Eq)

///|
/// Errors raised while validating an RTP packet.
pub(all) suberror RtpError {
  InvalidRtpPacket(reason~ : String)
} derive(Debug, Eq)

///|
/// Build Discord's RTP header for a 20 ms Opus frame.
pub fn build_rtp_header(
  sequence~ : UInt16,
  timestamp~ : UInt32,
  ssrc~ : UInt32,
) -> Bytes {
  Bytes::from_array([
    0x80,
    0x78,
    (sequence >> 8).to_byte(),
    sequence.to_byte(),
    (timestamp >> 24).to_byte(),
    (timestamp >> 16).to_byte(),
    (timestamp >> 8).to_byte(),
    timestamp.to_byte(),
    (ssrc >> 24).to_byte(),
    (ssrc >> 16).to_byte(),
    (ssrc >> 8).to_byte(),
    ssrc.to_byte(),
  ])
}

///|
/// Return the cleartext RTP header length used as AEAD associated data.
pub fn rtpsize_header_len(bytes : Bytes) -> Int32 {
  // version, padding, extension, CSRC count | marker + payload type,
  // sequence, timestamp, SSRC
  match bytes {
    [
      u2be(_),
      u1be(_),
      u1be(extension),
      u4be(csrc_count),
      u8be(_),
      u16be(_),
      u32be(_),
      u32be(_),
      ..,
    ] =>
      12 +
      csrc_count.reinterpret_as_int() * 4 +
      extension.reinterpret_as_int() * 4
    _ => 0
  }
}

///|
/// Parse an RTP v2 packet and retain extension data in `payload`.
pub fn parse_rtp_packet(bytes : Bytes) -> RtpPacket raise RtpError {
  if bytes.length() < 12 {
    raise InvalidRtpPacket(reason="RTP packet is shorter than 12 bytes")
  }
  guard bytes
    is [u2be(2), u14be(_), u16be(sequence), u32be(timestamp), u32be(ssrc), ..] else {
    raise InvalidRtpPacket(reason="RTP version is not 2")
  }
  let header_len = rtpsize_header_len(bytes)
  if header_len > bytes.length() {
    raise InvalidRtpPacket(reason="RTP CSRC or extension header is truncated")
  }
  {
    sequence: sequence.to_uint16(),
    timestamp,
    ssrc,
    header_len,
    header: bytes[:header_len].to_owned(),
    payload: bytes[header_len:].to_owned(),
  }
}
