///|
/// On JavaScript the owned backend is the host's `fetch`, which applies the
/// host's own proxy settings and ignores this one. Reading the environment
/// here would also fail on hosts that guard it, such as Deno without
/// `--allow-env`.
fn proxy_from_env() -> @h1client.ProxyConfig {
  @h1client.ProxyConfig::none()
}
