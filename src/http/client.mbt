///|
/// Discord REST client: token + HTTP transport + rate limiter.
pub struct Client {
  priv token : String
  // The transport this client created and therefore closes.
  priv owned_transport : @transport.AsyncTransport?
  priv backend : Backend
  priv base_url : String
  priv base_path : String
  priv default_allowed_mentions : @model.AllowedMentions
  priv request_timeout_ms_ : Int
  priv middleware_ : Array[HttpMiddleware]
  priv telemetry_ : Array[(@telemetry.TelemetryEvent) -> Unit raise]
  priv warn_ : Ref[(String) -> Unit]
  priv mut closed_ : Bool
}

///|
/// What answers a validated logical call, below the middleware.
priv enum Backend {
  // The `gaato/sdk-runtime` client: rate limiting, the wire exchange, and
  // 429 retries, above which status mapping and decoding happen.
  Online(@runtime.Client)
  // A handler that answers in place of all of that.
  Offline(async (HttpRequest) -> HttpResponse)
}

///|
/// Library version, sent in the User-Agent header.
pub const VERSION : String = "0.5.0"

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
/// `max_connections` does not apply to it, and each attempt through it is
/// still bounded by `request_timeout_ms`.
///
/// `limiter` is a `gaato/sdk-runtime` `RateLimiter`; the default is an
/// `InMemoryRateLimiter` with Discord's per-bucket and global accounting.
pub fn Client::Client(
  token : String,
  base_url? : String = "https://discord.com",
  api_version? : Int = 10,
  limiter? : &@runtime.RateLimiter,
  transport? : &@ghttp.Transport,
  max_connections? : Int = 4,
  request_timeout_ms? : Int = 30000,
  max_retries? : Int = 4,
  default_allowed_mentions? : @model.AllowedMentions,
) -> Client {
  let limiter : &@runtime.RateLimiter = match limiter {
    Some(l) => l
    None => @ratelimit.InMemoryRateLimiter()
  }
  let (transport, owned_transport) : (
    &@ghttp.Transport,
    @transport.AsyncTransport?,
  ) = match transport {
    // The default transport bounds each exchange itself; a shared one gets
    // the same deadline from the outside.
    Some(shared) =>
      (
        TimeoutTransport::{ inner: shared, timeout_ms: request_timeout_ms, },
        None,
      )
    None => {
      let owned = @transport.AsyncTransport::new(
        timeout_ms=request_timeout_ms,
        max_idle_per_origin=max_connections,
      )
      (owned, Some(owned))
    }
  }
  let telemetry_ : Array[(@telemetry.TelemetryEvent) -> Unit raise] = []
  let warn_ : Ref[(String) -> Unit] = Ref(message => println(message))
  let runtime = @runtime.Client::new(
    transport,
    @transport.AsyncClock::new(),
    base_url~,
    retry=DiscordRetry::{ max_retries, },
    limiter~,
    observer=attempt => emit_attempt(telemetry_, warn_, attempt),
  )
  {
    token,
    owned_transport,
    backend: Online(runtime),
    base_url,
    base_path: "/api/v\{api_version}",
    default_allowed_mentions: default_allowed_mentions.unwrap_or_else(
      @model.AllowedMentions::safe_default,
    ),
    request_timeout_ms_: request_timeout_ms,
    middleware_: [],
    telemetry_,
    warn_,
    closed_: false,
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
    owned_transport: None,
    backend: Offline(handler),
    base_url: "",
    base_path: "/api/v10",
    default_allowed_mentions: default_allowed_mentions.unwrap_or_else(
      @model.AllowedMentions::safe_default,
    ),
    request_timeout_ms_: 0,
    middleware_: [],
    telemetry_: [],
    warn_: Ref(message => println(message)),
    closed_: false,
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
  emit_event(self.telemetry_, self.warn_, event)
}

///|
fn emit_event(
  hooks : Array[(@telemetry.TelemetryEvent) -> Unit raise],
  warn : Ref[(String) -> Unit],
  event : @telemetry.TelemetryEvent,
) -> Unit {
  for hook in hooks {
    hook(event) catch {
      error => (warn.val)("telemetry hook failed: \{Repr(error)}")
    }
  }
}

///|
/// One network attempt as the runtime reports it: an `HttpRequest` event,
/// followed by `HttpRateLimited` for a 429. The runtime calls this after the
/// limiter's release and before deciding on a retry, so a 429 is observed
/// before its back-off sleep.
fn emit_attempt(
  hooks : Array[(@telemetry.TelemetryEvent) -> Unit raise],
  warn : Ref[(String) -> Unit],
  attempt : @runtime.Attempt,
) -> Unit {
  emit_event(
    hooks,
    warn,
    HttpRequest(
      route_bucket=attempt.bucket,
      method_name=method_name(attempt.request.http_method),
      status=attempt.status,
      duration_ms=attempt.duration_ms,
      retries=attempt.attempt,
    ),
  )
  if attempt.status == 429 {
    let (retry_after_ms, global) = rate_limit_details(
      attempt.headers,
      attempt.body,
    )
    emit_event(
      hooks,
      warn,
      HttpRateLimited(route_bucket=attempt.bucket, global~, retry_after_ms~),
    )
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
/// A supplied transport with the client's per-attempt deadline around each
/// exchange. Expiry surfaces as `HttpError::Timeout`, which the runtime
/// classifies as a transport failure that `DiscordRetry` never resends.
priv struct TimeoutTransport {
  inner : &@ghttp.Transport
  timeout_ms : Int
}

///|
impl @ghttp.Transport for TimeoutTransport with fn send(self, request) {
  within_deadline(self.timeout_ms, () => self.inner.send(request))
}

///|
impl @ghttp.Transport for TimeoutTransport with fn send_stream(self, request) {
  within_deadline(self.timeout_ms, () => self.inner.send_stream(request))
}

///|
/// Run one exchange under a deadline, keeping the transport's error type.
async fn[X] within_deadline(
  timeout_ms : Int,
  exchange : async () -> X raise @ghttp.HttpError,
) -> X raise @ghttp.HttpError {
  @async.with_timeout(
    timeout_ms,
    () => exchange(),
    error=@ghttp.HttpError::Timeout(timeout_ms),
  ) catch {
    @ghttp.HttpError::Connect(message) => raise Connect(message)
    @ghttp.HttpError::Timeout(ms) => raise Timeout(ms)
    @ghttp.HttpError::Protocol(message) => raise Protocol(message)
    // `with_timeout` is typed to raise any error, but here it only passes on
    // the exchange's own errors and its timeout.
    error => raise Protocol("\{error}")
  }
}

///|
pub extend Client with Show::{to_string}

///|
/// Never leak the token through debug output.
pub impl Show for Client with fn output(self, logger) {
  ignore(self.token)
  logger.write_string("discord.Client")
}
