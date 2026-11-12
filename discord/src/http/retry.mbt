///|
/// Reserved header stripped from caller-supplied headers before the backend
/// sees them. Retry safety uses the typed `replay_safe` attribute instead, so
/// a caller cannot forge safety with a wire header.
const REPLAY_SAFE_HEADER : String = "x-discord-mbt-replay-safe"

///|
/// Discord's resend rule as a `gaato/mttp_core/client/retry` rule, up to
/// `max_retries` resends:
///
/// - a 429 for any method, after the delay Discord asked for (supplied by
///   `resend_decision`, uncapped: the caller's deadline bounds it);
/// - a 502 for any method: Discord documents it as "wait a bit and retry";
/// - any other 5xx only for an idempotent request, since Discord does not
///   promise that a failed `POST` or `PATCH` did nothing;
/// - a transport failure that proves nothing was sent, for any method, and
///   one after sending only for an idempotent request.
///
/// Other statuses, 401 and 403 among them, are Discord's answer. Retries
/// that the response does not time back off as the runtime's conservative
/// preset does: 500 ms doubling to 30 s, within ±20 %.
fn discord_retry_rule(max_retries : Int32) -> @retry.RetryRule {
  {
    max_retries,
    // First match wins: 502 before the idempotent-only 5xx range.
    statuses: [
      { statuses: [Code(429), Code(502)], methods: Any, },
      { statuses: [Range(500, 599)], methods: Idempotent, },
    ],
    sent_failures: Idempotent,
    unsent_failures: true,
    override_header: None,
    retry_after: {
      source: MsThenHeader,
      cap: NoCap,
      zero_means_backoff: false,
    },
    backoff: @runtime.RetryPolicy::conservative().rule.backoff,
  }
}

///|
/// Whether to send a call again after a failed attempt, and after how long.
/// Nothing is resent once the client is `closed`. Otherwise
/// `discord_retry_rule(max_retries)` decides, with two Discord-specific
/// inputs:
///
/// - a 429's delay is the body's `retry_after` (fractional seconds), then
///   `Retry-After-Ms` or `Retry-After`, then one second, plus one
///   millisecond; but a 429 that is not Discord's rate limit
///   (`@ratelimit.is_discord_rate_limit`: no JSON content type and no
///   `X-RateLimit-Scope` or `X-RateLimit-Global`, as from Cloudflare in front
///   of Discord) gives no wait to honour, and resending it only adds to the
///   address's invalid requests, so it fails at once;
/// - a call is idempotent when its method is (`GET`, `HEAD`, `PUT`,
///   `DELETE`, `OPTIONS`) or when its typed `replay_safe` attribute is true.
fn resend_decision(
  attempt : @runtime.AttemptResult[Result[Bytes, @runtime.ResponseFailure]],
  context : @runtime.RetryContext,
  max_retries~ : Int32,
  closed~ : Bool,
) -> @retry.Decision {
  if closed {
    return Stop(NotRetryable)
  }
  let outcome = attempt.http_outcome()
  let server_delay_ms = match attempt {
    Buffered(reply) if reply.status == 429 => {
      let head : @ghttp.ResponseHead = {
        status: reply.status,
        headers: reply.headers,
      }
      let body = match reply.body {
        Ok(body) => body
        Err(
          @runtime.UnexpectedStatus(_, body~)
          | @runtime.Deserialization(_, body~, ..)
        ) => body
        Err(@runtime.ResponseFailure::..) => b""
      }
      let headers = head.headers
      if !@ratelimit.is_discord_rate_limit(headers) {
        return Stop(NotRetryable)
      }
      let (retry_after_ms, _) = rate_limit_from_json(
        headers,
        json_body(body).unwrap_or(Json::null()),
      )
      Some(retry_after_ms.max(0L).min(2147483646L).to_int() + 1)
    }
    _ => None
  }
  let request = context.request
  discord_retry_rule(max_retries).decide(
    outcome,
    request,
    attempt=context.attempt,
    random=context.random,
    now_unix_ms=context.now_unix_ms,
    remaining_ms?=context.remaining_ms,
    server_delay_ms?,
    idempotent=context.idempotent,
    replayable=context.replayable,
  )
}

///|
/// A response body as JSON, or `None` when it is not JSON.
fn json_body(body : Bytes) -> Json? {
  if body.is_empty() {
    return None
  }
  Some(@json.parse(@utf8.decode_lossy(body))) catch {
    _ => None
  }
}
