///|
/// The `DiscordHttpError` for a failure the transport reported, keeping the
/// phase it failed in, so that `DiscordHttpError::is_unsent` agrees with
/// `HttpError::is_unsent`: a failed connection or a proxy's refusal to open
/// a tunnel is `Dial`, a protocol error is `Unknown`, and a network failure
/// reported in `Pool` or `Dial` — which breaks the transport contract, since
/// it does not prove nothing was sent — is `Unknown` too.
fn transport_failure(error : @ghttp.HttpError) -> DiscordHttpError {
  match error {
    Timeout(phase~, ms~) => Timeout(phase~, timeout_ms=ms)
    Connect(message) =>
      Transport(phase=Dial, message="could not connect: \{message}")
    Proxy(status~, message~) =>
      Transport(
        phase=Dial,
        message="proxy refused the tunnel with \{status}: \{message}",
      )
    Network(phase=Pool | Dial, message~) => Transport(phase=Unknown, message~)
    Network(phase~, message~) => Transport(phase~, message~)
    Protocol(message) =>
      Transport(phase=Unknown, message="protocol error: \{message}")
  }
}
