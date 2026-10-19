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
  priv middleware_ : Array[HttpMiddleware]
  priv telemetry_ : Array[(@telemetry.TelemetryEvent) -> Unit raise]
  priv warn_ : Ref[(String) -> Unit]
  priv clock_ : &@hclock.Clock
  // Shared with the runtime's retry rule, which resends nothing once set.
  priv closed_ : Ref[Bool]
  // Fed by the runtime's observer; an offline client never records.
  priv invalid_ : InvalidRequests
}

///|
/// What answers a validated logical call, below the middleware.
priv enum Backend {
  // The `gaato/sdk-runtime` client: rate limiting, the wire exchange, and
  // retries, above which status mapping and decoding happen.
  Online(@runtime.Client)
  // A handler that answers in place of all of that.
  Offline(async (HttpRequest) -> HttpResponse)
}

///|
/// Library version, sent in the User-Agent header.
pub const VERSION : String = "0.12.1"

///|
/// The largest response body the default transport buffers, the same 64 MiB
/// as the Gateway's `DEFAULT_MAX_MESSAGE_BYTES`. A longer body fails the
/// attempt instead of growing without bound.
const MAX_RESPONSE_BODY_BYTES : Int32 = 67_108_864

///|
/// Create a client. `token` is the raw bot token (without the `Bot ` prefix).
///
/// `request_timeout_ms` (default 30000) bounds each network attempt, including
/// reading its response body. Rate-limit waits, retry back-off, and user HTTP
/// middleware are outside it. For a whole-operation deadline, compose
/// `@async.with_timeout` around the call.
///
/// `max_retries` (default 4) bounds how often one call is sent again. Every
/// resend goes through the rate limiter again, and a call is resent only
/// where Discord's documentation allows it or it cannot cause a second
/// effect:
///
/// - a 429, for any method, once the delay Discord asks for (the body's
///   `retry_after`, then `Retry-After`) has passed, however long; except a
///   429 that is not Discord's rate limit (no JSON content type and no
///   Discord rate-limit header, as from Cloudflare in front of Discord), which
///   names no wait and raises at once;
/// - a 502, for any method, with backoff: Discord asks to "wait a bit and
///   retry";
/// - a transport failure or timeout that proves no byte was sent
///   (`DiscordHttpError::is_unsent`), for any method, with backoff;
/// - another 5xx, and a failure or timeout after sending, with backoff, only
///   for an idempotent call: `GET`, `HEAD`, `PUT`, `DELETE`, `OPTIONS`, or a
///   message create with a `nonce` and `enforce_nonce: true`, which Discord
///   does not create twice. A `POST` or `PATCH` that may have reached
///   Discord is raised at once.
///
/// The backoff is 500 ms, doubling up to 30 s, within ±20 %. Anything else,
/// 401 and 403 included, is Discord's answer and is never resent.
///
/// `transport` is the `gaato/http` `Transport` that performs the wire
/// exchange, below request validation, middleware, rate limiting, retries,
/// status mapping, and decoding. By default the client creates a
/// `gaato/http-async` `AsyncTransport` with `request_timeout_ms`, a
/// keep-alive pool of up to `max_connections` parked connections, and a
/// 64 MiB bound on each buffered response body, and closes it in `close`. A
/// supplied transport is shared: the client never closes it,
/// `max_connections` and the body bound do not apply to it, and each attempt
/// through it is still bounded by `request_timeout_ms`, by the
/// `gaato/sdk-runtime` client's `Timeouts` on `clock`. A supplied transport
/// cannot say how far an attempt got, so one that runs out of time fails
/// with `Timeout(phase=Unknown)`, as does every attempt when
/// `request_timeout_ms` is not positive.
///
/// `limiter` is a `gaato/sdk-runtime` `RateLimiter`; the default is an
/// `@ratelimit.rate_limiter()` with Discord's per-bucket and global accounting.
///
/// `clock` (default: the wall clock) drives the client's time: 429 and
/// resend back-off, the default rate limiter's windows, the attempt timeout
/// around a supplied transport, telemetry durations, the window of
/// `invalid_requests`, the typing keepalive of `ChannelRef::with_typing`,
/// and the default transport's phase limits and idle connections.
pub fn Client::Client(
  token : String,
  base_url~ : String = "https://discord.com",
  api_version~ : Int32 = 10,
  limiter? : &@runtime.RateLimiter,
  transport? : &@ghttp.Transport,
  max_connections~ : Int32 = 4,
  request_timeout_ms~ : Int32 = 30000,
  max_retries~ : Int32 = 4,
  default_allowed_mentions? : @model.AllowedMentions,
  clock~ : &@hclock.Clock = @transport.AsyncClock::new(),
) -> Client {
  let limiter : &@runtime.RateLimiter = match limiter {
    Some(l) => l
    None => @ratelimit.rate_limiter(clock~)
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
        max_body_bytes=MAX_RESPONSE_BODY_BYTES,
        clock~,
      )
      (owned, Some(owned))
    }
  }
  let telemetry_ : Array[(@telemetry.TelemetryEvent) -> Unit raise] = []
  let warn_ : Ref[(String) -> Unit] = Ref(message => println(message))
  let closed_ = Ref(false)
  let invalid_ = InvalidRequests::new()
  // The default transport bounds each exchange itself, phase by phase, which
  // tells an unsent timeout from a sent one; a shared one gets the same
  // limit from the runtime. Giving the default one both would race two
  // timers on one deadline.
  let timeouts = if owned_transport is None {
    Some(
      @runtime.Timeouts::new(
        @transport.ClockTimer::new(clock~),
        attempt_ms=request_timeout_ms,
      ),
    )
  } else {
    None
  }
  let runtime = @runtime.Client::new(
    ClosedGate::{ inner: transport, closed: closed_, },
    clock,
    base_url~,
    retry=DiscordRetry::{ max_retries, closed: closed_, },
    limiter~,
    observer=attempt => {
      if is_invalid_request(attempt.status, attempt.headers) {
        invalid_.record(clock.now_unix_ms())
      }
      emit_attempt(telemetry_, warn_, attempt)
    },
    timeouts?,
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
    middleware_: [],
    telemetry_,
    warn_,
    clock_: clock,
    closed_,
    invalid_,
  }
}

///|
/// Create a client with no network. `handler` answers every logical REST
/// call in place of the rate limiter, the wire exchange, and retries; it
/// has the same shape as the `next` continuation of `HttpMiddleware`, so an
/// offline client is the innermost step of the same chain. Request validation,
/// installed middleware, status-code-to-error mapping, and typed decoding run
/// exactly as they do online, and nothing falls back to Discord.
///
/// There is no token, base URL, timeout, or retry: a 429 from `handler`
/// surfaces as `DiscordHttpError::RateLimited` at once. An error raised by
/// `handler` propagates as itself when it is a `DiscordHttpError` and as
/// `DiscordHttpError::Transport(phase=Unknown, ..)` otherwise. Each call
/// emits the same `HttpRequest` and `HttpRateLimited` telemetry as a single
/// network attempt, its duration read from `clock` (default: the wall
/// clock), which also drives `ChannelRef::with_typing`.
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
  clock~ : &@hclock.Clock = @transport.AsyncClock::new(),
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
    middleware_: [],
    telemetry_: [],
    warn_: Ref(message => println(message)),
    clock_: clock,
    closed_: Ref(false),
    invalid_: InvalidRequests::new(),
  }
}

///|
/// How many of this client's requests in the past ten minutes Discord counts
/// as invalid: those answered with 401, 403 or 429, except a 429 with
/// `X-RateLimit-Scope: shared`. Every attempt counts, resends included.
///
/// Discord allows 10,000 invalid requests per ten minutes from one address;
/// past that, Discord restricts the address for a while (its documentation
/// calls this a Cloudflare ban), for every client on it. The count moves in ten-second steps, so a request leaves it between
/// 590 and 600 seconds after it was answered, and covers only this client:
/// add up the clients that share an address. An offline client sends nothing
/// and always reports 0.
pub fn Client::invalid_requests(self : Client) -> Int32 {
  self.invalid_.count(self.clock_.now_unix_ms())
}

///|
/// Install middleware around each logical REST call. The first installed
/// middleware is outermost. `next` performs rate limiting, the wire
/// exchange, and bounded retries.
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
/// Observe telemetry until the returned function is called, which removes the
/// hook. Executors use it to forward a caller-owned client's events only while
/// they run. Hidden from the public interface.
#doc(hidden)
pub fn Client::attach_telemetry(
  self : Client,
  hook : (@telemetry.TelemetryEvent) -> Unit raise,
) -> () -> Unit {
  self.telemetry_.push(hook)
  () => {
    for index, attached in self.telemetry_ {
      if physical_equal(attached, hook) {
        self.telemetry_.remove(index) |> ignore
        break
      }
    }
  }
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
  self.closed_.val = true
  if self.owned_transport is Some(transport) {
    transport.close()
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
