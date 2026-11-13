///|
/// core/async after MoonBit 0.10.20 renames `UdpClient::recv` into a buffer
/// to `recv_into`, so this impl is the only part of the UDP seam that differs
/// between the toolchains; compat/core_async_next holds the other version.
impl VoiceUdp for SocketVoiceUdp with fn recv(self, buffer) {
  self.client.recv(buffer)
}
