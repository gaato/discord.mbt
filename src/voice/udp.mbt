///|
/// UDP seam used by voice discovery and media transport.
pub(open) trait VoiceUdp {
  async fn recv(Self, FixedArray[Byte]) -> Int
  async fn send(Self, Bytes) -> Unit
  async fn close(Self) -> Unit
}

///|
/// Errors raised by voice UDP setup and IP discovery.
pub(all) suberror VoiceUdpError {
  InvalidDiscoveryPacket(reason~ : String)
  IpDiscoveryFailed(attempts~ : Int, reason~ : String)
} derive(Debug, Eq)

///|
priv suberror VoiceDiscoveryTimeout {
  VoiceDiscoveryTimeout
} derive(Debug)

///|
priv struct SocketVoiceUdp {
  client : @socket.UdpClient
}

///|
impl VoiceUdp for SocketVoiceUdp with fn recv(self, buffer) {
  self.client.recv(buffer)
}

///|
impl VoiceUdp for SocketVoiceUdp with fn send(self, bytes) {
  self.client.send(bytes)
}

///|
impl VoiceUdp for SocketVoiceUdp with fn close(self) {
  self.client.close()
}

///|
/// Open a connected UDP socket for a Discord voice server.
pub async fn open_voice_udp(ip : String, port : Int) -> &VoiceUdp {
  let address = @socket.Addr::resolve(ip, port~)
  let client = @socket.UdpClient(address)
  SocketVoiceUdp::{ client, }
}

///|
/// Build Discord's 74-byte voice IP discovery request.
pub fn build_ip_discovery_request(ssrc : UInt) -> Bytes {
  let bytes : Array[Byte] = [0, 1, 0, 70]
  bytes.push((ssrc >> 24).to_byte())
  bytes.push((ssrc >> 16).to_byte())
  bytes.push((ssrc >> 8).to_byte())
  bytes.push(ssrc.to_byte())
  for _ in 8..<74 {
    bytes.push(0)
  }
  Bytes::from_array(bytes)
}

///|
fn read_u32_be(bytes : Bytes, offset : Int) -> UInt {
  (bytes[offset].to_uint() << 24) |
  (bytes[offset + 1].to_uint() << 16) |
  (bytes[offset + 2].to_uint() << 8) |
  bytes[offset + 3].to_uint()
}

///|
/// Parse Discord's 74-byte voice IP discovery response.
pub fn parse_ip_discovery_response(
  bytes : Bytes,
  expected_ssrc~ : UInt,
) -> (String, Int) raise VoiceUdpError {
  if bytes.length() != 74 {
    raise InvalidDiscoveryPacket(reason="response must contain 74 bytes")
  }
  let packet_type = (bytes[0].to_int() << 8) | bytes[1].to_int()
  let payload_length = (bytes[2].to_int() << 8) | bytes[3].to_int()
  if packet_type != 2 || payload_length != 70 {
    raise InvalidDiscoveryPacket(
      reason="expected discovery response type 2 with length 70",
    )
  }
  if read_u32_be(bytes, 4) != expected_ssrc {
    raise InvalidDiscoveryPacket(reason="response SSRC does not match request")
  }
  let mut terminator = -1
  for index in 8..<72 {
    if bytes[index] == 0 {
      terminator = index
      break
    }
  }
  if terminator < 0 {
    raise InvalidDiscoveryPacket(
      reason="response address is not NUL terminated",
    )
  }
  let address = @utf8.decode(bytes[8:terminator]) catch {
    _ => raise InvalidDiscoveryPacket(reason="response address is not UTF-8")
  }
  if address.is_empty() {
    raise InvalidDiscoveryPacket(reason="response address is empty")
  }
  let port = (bytes[72].to_int() << 8) | bytes[73].to_int()
  (address, port)
}

///|
/// Run voice IP discovery, retrying only receive timeouts.
pub async fn discover_external_address(
  udp : &VoiceUdp,
  ssrc : UInt,
  retries? : Int = 3,
  timeout_ms? : Int = 1000,
) -> (String, Int) {
  if retries <= 0 || timeout_ms <= 0 {
    raise VoiceUdpError::IpDiscoveryFailed(
      attempts=0,
      reason="retries and timeout_ms must be positive",
    )
  }
  let request = build_ip_discovery_request(ssrc)
  for attempt in 0..<retries {
    udp.send(request)
    let buffer : FixedArray[Byte] = FixedArray::make(74, 0)
    let received = @async.with_timeout(
      timeout_ms,
      () => udp.recv(buffer),
      error=VoiceDiscoveryTimeout,
    ) catch {
      VoiceDiscoveryTimeout => -1
      error => raise error
    }
    if received < 0 {
      if attempt + 1 == retries {
        raise VoiceUdpError::IpDiscoveryFailed(
          attempts=retries,
          reason="timed out waiting for discovery response",
        )
      }
      continue
    }
    let response = Bytes::from_array(buffer[:received])
    return parse_ip_discovery_response(response, expected_ssrc=ssrc)
  }
  raise VoiceUdpError::IpDiscoveryFailed(
    attempts=retries,
    reason="discovery exhausted",
  )
}
