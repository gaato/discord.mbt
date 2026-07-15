///|
/// A parsed RTP packet with the `rtpsize` cleartext header separated.
pub(all) struct RtpPacket {
  sequence : UInt16
  timestamp : UInt
  ssrc : UInt
  header_len : Int
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
  timestamp~ : UInt,
  ssrc~ : UInt,
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
pub fn rtpsize_header_len(bytes : Bytes) -> Int {
  if bytes.length() < 12 {
    return 0
  }
  let csrc_count = (bytes[0].to_int() & 0x0f) * 4
  let extension_header = if (bytes[0].to_int() & 0x10) != 0 { 4 } else { 0 }
  12 + csrc_count + extension_header
}

///|
/// Parse an RTP v2 packet and retain extension data in `payload`.
pub fn parse_rtp_packet(bytes : Bytes) -> RtpPacket raise RtpError {
  if bytes.length() < 12 {
    raise InvalidRtpPacket(reason="RTP packet is shorter than 12 bytes")
  }
  if bytes[0].to_int() >> 6 != 2 {
    raise InvalidRtpPacket(reason="RTP version is not 2")
  }
  let header_len = rtpsize_header_len(bytes)
  if header_len == 0 || header_len > bytes.length() {
    raise InvalidRtpPacket(reason="RTP CSRC or extension header is truncated")
  }
  let sequence = (bytes[2].to_uint16() << 8) | bytes[3].to_uint16()
  let timestamp = read_u32_be(bytes, 4)
  let ssrc = read_u32_be(bytes, 8)
  {
    sequence,
    timestamp,
    ssrc,
    header_len,
    header: bytes[:header_len].to_owned(),
    payload: bytes[header_len:].to_owned(),
  }
}
