///|
/// The `DiscordHttpError` for a failure the transport reported, keeping the
/// phase it failed in, so that `DiscordHttpError::is_unsent` agrees with
/// `TransportError::is_unsent`: a failed connection or a proxy's refusal to open
/// a tunnel is `Dial`, a protocol error is `Unknown`, and a network failure
/// reported in `Pool` or `Dial` — which breaks the transport contract, since
/// it does not prove nothing was sent — is `Unknown` too.
fn transport_failure(error : @ghttp.TransportError) -> DiscordHttpError {
  let @ghttp.TransportError(kind~, phase~, detail=message) = error
  match (kind, phase) {
    (Timeout(ms~), _) => Timeout(phase~, timeout_ms=ms)
    (Connect, _) =>
      Transport(phase=Dial, message="could not connect: \{message}")
    (Proxy(status~), _) =>
      Transport(
        phase=Dial,
        message="proxy refused the tunnel with \{status}: \{message}",
      )
    (Network, Pool | Dial) => Transport(phase=Unknown, message~)
    (Network, _) => Transport(phase~, message~)
    (Protocol, _) =>
      Transport(phase=Unknown, message="protocol error: \{message}")
    _ => Transport(phase=Unknown, message~)
  }
}
