///|
/// The `DiscordHttpError` for a failure the transport reported, keeping the
/// phase it failed in, so that `DiscordHttpError::is_unsent` agrees with
/// the Backend contract: a failed connection or a proxy's refusal to open
/// a tunnel is `Dial`, a protocol error is `Unknown`, and other failures
/// retain the backend's phase. `Pool` and `Dial` prove nothing was sent.
fn transport_failure(error : @ghttp.TransportError) -> DiscordHttpError {
  let @ghttp.TransportError(kind~, phase~, detail~) = error
  match kind {
    Timeout(ms~) => Timeout(phase~, timeout_ms=ms)
    Closed => Transport(phase=Pool, message=CLOSED_MESSAGE)
    Connect => Transport(phase=Dial, message="could not connect: \{detail}")
    Proxy(status~) =>
      Transport(
        phase=Dial,
        message="proxy refused the tunnel with \{status}: \{detail}",
      )
    Protocol => Transport(phase=Unknown, message="protocol error: \{detail}")
    _ => Transport(phase~, message=detail)
  }
}
