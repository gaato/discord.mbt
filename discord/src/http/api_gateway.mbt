///|
/// Get the gateway WebSocket URL (unauthenticated).
pub async fn Client::get_gateway(
  self : Client,
) -> String raise DiscordHttpError {
  match self.request(GetGateway) {
    { "url": String(url), .. } => url
    other =>
      raise Deserialize(
        message="expected gateway url, got \{other.stringify()}",
      )
  }
}

///|
/// Get the gateway URL plus recommended shard count and identify limits.
pub async fn Client::get_gateway_bot(
  self : Client,
) -> @model.GatewayBotInfo raise DiscordHttpError {
  decode(self.request(GetGatewayBot))
}
