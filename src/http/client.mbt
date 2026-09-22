///|
/// Discord REST client: token + HTTP transport + rate limiter.
pub struct Client {
  priv token : String
  priv transport : &@ghttp.Transport
  // The transport this client created and therefore closes.
  priv owned_transport : @transport.AsyncTransport?
  priv limiter : &@ratelimit.RateLimiter
  priv base_url : String
  priv base_path : String
  priv default_allowed_mentions : @model.AllowedMentions
  priv request_timeout_ms_ : Int
  priv max_retries_ : Int
  priv middleware_ : Array[HttpMiddleware]
  priv telemetry_ : Array[(@telemetry.TelemetryEvent) -> Unit raise]
  priv warn_ : Ref[(String) -> Unit]
  priv mut closed_ : Bool
  // An offline client answers every validated request here instead of the
  // rate limiter, network attempts, and retries.
  priv offline_ : (async (HttpRequest) -> HttpResponse)?
  // Whitebox tests intercept prepared requests here; production always uses
  // the pooled transport through `perform`.
  priv perform_override_ : Ref[
    (async (Route, String, Map[String, String], Json?, Array[FileUpload]?) -> HttpResponse)?,
  ]
}

///|
/// Library version, sent in the User-Agent header.
pub const VERSION : String = "0.4.2"

///|
/// Create a client. `token` is the raw bot token (without the `Bot ` prefix).
///
/// `request_timeout_ms` (default 30000) bounds each network attempt, including
/// reading its response body. Rate-limit waits, 429 back-off, and user HTTP
/// middleware are outside it. Timed-out attempts are not retried. For a
/// whole-operation deadline, compose `@async.with_timeout` around the call.
///
/// `transport` is the `gaato/http` `Transport` that performs the wire
/// exchange, below request validation, middleware, rate limiting, 429
/// retries, status mapping, and decoding. By default the client creates a
/// `gaato/http-async` `AsyncTransport` with `request_timeout_ms` and a
/// keep-alive pool of up to `max_connections` parked connections, and closes
/// it in `close`. A supplied transport is shared: the client never closes it,
/// and `max_connections` does not apply to it.
pub fn Client::Client(
  token : String,
  base_url? : String = "https://discord.com",
  api_version? : Int = 10,
  limiter? : &@ratelimit.RateLimiter,
  transport? : &@ghttp.Transport,
  max_connections? : Int = 4,
  request_timeout_ms? : Int = 30000,
  max_retries? : Int = 4,
  default_allowed_mentions? : @model.AllowedMentions,
) -> Client {
  let limiter : &@ratelimit.RateLimiter = match limiter {
    Some(l) => l
    None => @ratelimit.InMemoryRateLimiter()
  }
  let (transport, owned_transport) : (
    &@ghttp.Transport,
    @transport.AsyncTransport?,
  ) = match transport {
    Some(shared) => (shared, None)
    None => {
      let owned = @transport.AsyncTransport::new(
        timeout_ms=request_timeout_ms,
        max_idle_per_origin=max_connections,
      )
      (owned, Some(owned))
    }
  }
  {
    token,
    transport,
    owned_transport,
    limiter,
    base_url,
    base_path: "/api/v\{api_version}",
    default_allowed_mentions: default_allowed_mentions.unwrap_or_else(
      @model.AllowedMentions::safe_default,
    ),
    request_timeout_ms_: request_timeout_ms,
    max_retries_: max_retries,
    middleware_: [],
    telemetry_: [],
    warn_: Ref(message => println(message)),
    closed_: false,
    offline_: None,
    perform_override_: Ref(None),
  }
}

///|
/// Create a client with no network. `handler` answers every logical REST
/// call in place of the rate limiter, the wire exchange, and 429 retries; it
/// has the same shape as the `next` continuation of `HttpMiddleware`, so an
/// offline client is the innermost step of the same chain. Request validation,
/// installed middleware, status-code-to-error mapping, and typed decoding run
/// exactly as they do online, and nothing falls back to Discord.
///
/// There is no token, base URL, timeout, or retry: a 429 from `handler`
/// surfaces as `DiscordHttpError::RateLimited` at once. An error raised by
/// `handler` propagates as itself when it is a `DiscordHttpError` and as
/// `DiscordHttpError::Transport` otherwise. Each call emits the same
/// `HttpRequest` and `HttpRateLimited` telemetry as a single network attempt.
///
/// # Example
/// ```mbt check
/// async test {
///   let calls : Array[@http.Route] = []
///   let client = @http.Client::offline(request => {
///     calls.push(request.route)
///     match request.route {
///       GetGateway => { status: 200, headers: {}, body: { "url": "wss://x" }, }
///       _ => { status: 404, headers: {}, body: { "code": 0, "message": "no" }, }
///     }
///   })
///   inspect(client.get_gateway(), content="wss://x")
///   assert_true(calls is [GetGateway])
/// }
/// ```
pub fn Client::offline(
  handler : async (HttpRequest) -> HttpResponse,
  default_allowed_mentions? : @model.AllowedMentions,
) -> Client {
  {
    token: "",
    transport: NoTransport::{ },
    owned_transport: None,
    limiter: @ratelimit.InMemoryRateLimiter(),
    base_url: "",
    base_path: "/api/v10",
    default_allowed_mentions: default_allowed_mentions.unwrap_or_else(
      @model.AllowedMentions::safe_default,
    ),
    request_timeout_ms_: 0,
    max_retries_: 0,
    middleware_: [],
    telemetry_: [],
    warn_: Ref(message => println(message)),
    closed_: false,
    offline_: Some(handler),
    perform_override_: Ref(None),
  }
}

///|
/// Install middleware around each logical REST call. The first installed
/// middleware is outermost. `next` performs rate limiting, the wire
/// exchange, and bounded 429 retries.
pub fn Client::middleware(self : Client, middleware : HttpMiddleware) -> Unit {
  self.middleware_.push(middleware)
}

///|
/// Observe structured HTTP telemetry. Hooks run synchronously and should
/// return promptly. A hook failure is reported through `on_warn`.
pub fn Client::on_telemetry(
  self : Client,
  hook : (@telemetry.TelemetryEvent) -> Unit raise,
) -> Unit {
  self.telemetry_.push(hook)
}

///|
/// Set the warning sink used for telemetry-hook failures.
pub fn Client::on_warn(self : Client, hook : (String) -> Unit) -> Unit {
  self.warn_.val = hook
}

///|
fn Client::emit_telemetry(
  self : Client,
  event : @telemetry.TelemetryEvent,
) -> Unit {
  for hook in self.telemetry_ {
    hook(event) catch {
      error => (self.warn_.val)("telemetry hook failed: \{Repr(error)}")
    }
  }
}

///|
/// Close the client's own transport (parked keep-alive connections) and
/// reject future requests, including those of an offline client. A supplied
/// transport is left open. A request already inside an offline handler is not
/// cancelled by this method.
pub fn Client::close(self : Client) -> Unit {
  self.closed_ = true
  if self.owned_transport is Some(transport) {
    transport.close()
  }
}

///|
/// The transport of an offline client, which never performs a wire exchange.
priv struct NoTransport {}

///|
impl @ghttp.Transport for NoTransport with fn send(_self, _request) {
  raise @ghttp.HttpError::Connect("offline client has no transport")
}

///|
impl @ghttp.Transport for NoTransport with fn send_stream(_self, _request) {
  raise @ghttp.HttpError::Connect("offline client has no transport")
}

///|
pub extend Client with Show::{to_string}

///|
/// Never leak the token through debug output.
pub impl Show for Client with fn output(self, logger) {
  ignore(self.token)
  logger.write_string("discord.Client")
}
