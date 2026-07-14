///|
/// Discord REST client: token + connection pool + rate limiter.
pub struct Client {
  priv token : String
  priv pool : @pool.Pool
  priv limiter : &@ratelimit.RateLimiter
  priv base_path : String
  priv default_allowed_mentions : @model.AllowedMentions
}

///|
/// Library version, sent in the User-Agent header.
pub const VERSION : String = "0.1.0"

///|
/// Create a client. `token` is the raw bot token (without the `Bot ` prefix).
pub fn Client::new(
  token : String,
  base_url? : String = "https://discord.com",
  api_version? : Int = 10,
  limiter? : &@ratelimit.RateLimiter,
  max_connections? : Int = 4,
  default_allowed_mentions? : @model.AllowedMentions,
) -> Client {
  let limiter : &@ratelimit.RateLimiter = match limiter {
    Some(l) => l
    None => @ratelimit.InMemoryRateLimiter::new()
  }
  {
    token,
    pool: @pool.Pool::new(base_url, max_connections~),
    limiter,
    base_path: "/api/v\{api_version}",
    default_allowed_mentions: default_allowed_mentions.unwrap_or_else(
      @model.AllowedMentions::safe_default,
    ),
  }
}

///|
/// Close all pooled connections.
pub fn Client::close(self : Client) -> Unit {
  self.pool.close()
}

///|
/// Never leak the token through debug output.
pub impl Show for Client with fn output(self, logger) {
  ignore(self.token)
  logger.write_string("discord.Client")
}
