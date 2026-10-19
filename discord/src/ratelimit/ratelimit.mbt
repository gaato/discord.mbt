///|
/// REST rate limiting through sdk-runtime's requester-driven `RateLimiter`
/// contract. Each completed acquire is paired with a release carrying response
/// headers, or status 0 when no response arrived. `rate_limiter()` configures
/// `WindowLimiter` for Discord; `coordinator` offers the cross-process
/// `RemoteRateLimiter` through the same contract.
///
/// Discord's REST rate limiter:
///
/// - per-bucket accounting from `x-ratelimit-remaining` /
///   `x-ratelimit-reset-after`, with one request in flight per route bucket;
/// - routes that Discord counts in one bucket share that accounting: a
///   response's `x-ratelimit-bucket` hash, together with the route's major
///   parameter (its channel, guild, or webhook), names the state that every
///   route answered with it reads and updates (`server_key`);
/// - a global window of `global_limit` requests per second, skipped for
///   interaction and webhook routes;
/// - a 429 empties its bucket until its `Retry-After`; one with
///   `x-ratelimit-scope: global` or `x-ratelimit-global` blocks every
///   non-exempt bucket instead, and one with `x-ratelimit-scope: shared`
///   (a resource's limit, which Discord does not hold against the bot) only
///   records the bucket's headers;
/// - a 429 that is not Discord's rate limit (`is_discord_rate_limit`) says
///   nothing about which bucket to hold, while every further invalid request
///   counts towards the address's limit: it blocks every non-exempt bucket
///   too;
/// - one second for a 429 without `Retry-After`.
pub fn rate_limiter(
  global_limit~ : Int32 = 50,
  clock~ : &@clock.Clock = @transport.AsyncClock::new(),
) -> @runtime.WindowLimiter {
  @runtime.WindowLimiter::new(
    clock,
    @runtime.rate_limit_headers(
      remaining="x-ratelimit-remaining",
      reset_after_seconds="x-ratelimit-reset-after",
    ),
    gate=() => @transport.SemaphoreGate::new(),
    server_key=discord_server_key,
    scope=discord_scope,
    global={ limit: global_limit, window_ms: 1000, },
    default_retry_after_ms=1000,
  )
}

///|
/// The key Discord counts `bucket` under, from a response's
/// `x-ratelimit-bucket` hash: the hash with the route's major parameter, since
/// Discord keeps one window per hash and major parameter. A route whose
/// major parameter cannot be read keeps its own bucket name instead, so two
/// routes are merged only when both their hash and their major parameter
/// match. `None` when the response names no hash.
fn discord_server_key(bucket : String, headers : @http.Headers) -> String? {
  guard headers.get("x-ratelimit-bucket") is Some(hash) else { return None }
  let hash = hash.trim()
  guard hash.length() > 0 else { return None }
  let major = match major_parameter(bucket) {
    Some(major) => major
    None => bucket
  }
  Some("x-ratelimit-bucket:\{hash}:\{major}")
}

///|
/// The major parameter of a route bucket name (`METHOD:/path` with major
/// IDs kept, as `Route::bucket` writes it): `channels/<id>`, `guilds/<id>`,
/// or `webhooks/<id>[/<token>]` (`interactions/<id>/<token>` likewise) at the
/// start of the path, or `""` for a route without one, such as
/// `/users/@me`. `None` for a name not in that form, such as a custom
/// route's own key.
fn major_parameter(bucket : String) -> String? {
  guard bucket.find(":/") is Some(colon) else { return None }
  let path = bucket[colon + 2:].to_owned()
  let segments = path.split("/").map(segment => segment.to_owned()).collect()
  let literal = (index : Int32) => {
    index < segments.length() &&
    segments[index] != "" &&
    segments[index] != "{}"
  }
  match segments {
    ["channels" | "guilds" as resource, ..] =>
      if literal(1) {
        Some("\{resource}/\{segments[1]}")
      } else {
        None
      }
    ["webhooks" | "interactions" as resource, ..] =>
      if !literal(1) {
        None
      } else if literal(2) {
        Some("\{resource}/\{segments[1]}/\{segments[2]}")
      } else {
        Some("\{resource}/\{segments[1]}")
      }
    _ => Some("")
  }
}

///|
/// What a 429 affects: `x-ratelimit-scope: shared` only its bucket's
/// recorded headers (Discord does not hold a shared limit against the bot),
/// `global` or `x-ratelimit-global` every non-exempt bucket, and one that is
/// not Discord's rate limit every non-exempt bucket too, to protect the
/// address. Any other 429 empties its own bucket.
fn discord_scope(
  _status : Int32,
  headers : @http.Headers,
) -> @runtime.LimitScope {
  let scope = headers
    .get("x-ratelimit-scope")
    .map(value => value.trim().to_lower())
  match scope {
    Some("shared") => Shared
    Some("global") => Global
    _ if headers.contains("x-ratelimit-global") => Global
    _ if !is_discord_rate_limit(headers) => Global
    _ => Bucket
  }
}

///|
/// Whether a 429 is Discord's own rate limit, which tells the client what to
/// wait for: Discord documents its 429s with a JSON body (`retry_after`,
/// `global`) and the `X-RateLimit-Scope` header, and sends `X-RateLimit-Global`
/// for a global limit. A 429 with none of these comes from something in front
/// of Discord, such as Cloudflare. It names no bucket and no reliable wait,
/// and since 401, 403 and 429 count towards the address's invalid-request
/// limit (10,000 per ten minutes), it is better not to send again soon.
pub fn is_discord_rate_limit(headers : @http.Headers) -> Bool {
  headers.contains("x-ratelimit-scope") ||
  headers.contains("x-ratelimit-global") ||
  headers
  .get("content-type")
  .map(value => value.to_lower().contains("json"))
  .unwrap_or(false)
}
