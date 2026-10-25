///|
/// UDP seam used by voice discovery and media transport.
pub(open) trait VoiceUdp {
  async fn recv(Self, FixedArray[Byte]) -> Int32
  async fn send(Self, Bytes) -> Unit
  async fn close(Self) -> Unit
}

///|
/// Errors raised by voice UDP setup and IP discovery.
#doc(hidden)
pub(all) suberror VoiceUdpError {
  InvalidDiscoveryPacket(reason~ : String)
  IpDiscoveryFailed(attempts~ : Int32, reason~ : String)
} derive(Debug, Eq)

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
#doc(hidden)
pub async fn open_voice_udp(ip : String, port : Int32) -> &VoiceUdp {
  let address = @socket.Addr::resolve(ip, port~)
  let client = @socket.UdpClient(address)
  SocketVoiceUdp::{ client, }
}

///|
/// Build Discord's 74-byte voice IP discovery request.
#doc(hidden)
pub fn build_ip_discovery_request(ssrc : UInt32) -> Bytes {
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
/// Parse Discord's 74-byte voice IP discovery response.
#doc(hidden)
pub fn parse_ip_discovery_response(
  bytes : Bytes,
  expected_ssrc~ : UInt32,
) -> (String, Int32) raise VoiceUdpError {
  if bytes.length() != 74 {
    raise InvalidDiscoveryPacket(reason="response must contain 74 bytes")
  }
  // type, length, SSRC, NUL-padded address, port
  guard bytes
    is [u16be(2), u16be(70), u32be(ssrc), .. address_field, u16be(port)] else {
    raise InvalidDiscoveryPacket(
      reason="expected discovery response type 2 with length 70",
    )
  }
  if ssrc != expected_ssrc {
    raise InvalidDiscoveryPacket(reason="response SSRC does not match request")
  }
  let mut terminator = -1
  for index in 0..<address_field.length() {
    if address_field[index] == 0 {
      terminator = index
      break
    }
  }
  if terminator < 0 {
    raise InvalidDiscoveryPacket(
      reason="response address is not NUL terminated",
    )
  }
  let address = @utf8.decode(address_field[:terminator]) catch {
    _ => raise InvalidDiscoveryPacket(reason="response address is not UTF-8")
  }
  if address.is_empty() {
    raise InvalidDiscoveryPacket(reason="response address is empty")
  }
  (address, port.reinterpret_as_int())
}

///|
/// Run voice IP discovery, retrying only receive timeouts, each timed on
/// `clock`.
#doc(hidden)
pub async fn discover_external_address(
  udp : &VoiceUdp,
  ssrc : UInt32,
  retries~ : Int32 = 3,
  timeout_ms~ : Int32 = 1000,
  clock~ : &@hclock.Clock = @netruntime.AsyncClock::new(),
) -> (String, Int32) {
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
    let received = @netruntime.with_timeout_opt(clock, timeout_ms, () => {
      udp.recv(buffer)
    })
    guard received is Some(received) else {
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
