///|
/// The owned backend's proxy, from `HTTP_PROXY`, `HTTPS_PROXY` and `NO_PROXY`.
fn proxy_from_env() -> @h1client.ProxyConfig {
  @h1client.ProxyConfig::from_env(@env.get_env_var)
}
