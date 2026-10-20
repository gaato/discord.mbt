# REST resends and rate limits

How `gaato/discord`'s REST `Client` resends requests and holds rate limits,
and the source each rule follows. Discord's developer documentation decides
where it says something; where it is silent, the library follows the common
practice of discord.js and discord.py, and stays conservative where a resend
could act twice. Discord has no official SDK to compare against.

## Sources

- Discord Developer Docs:
  [Rate Limits](https://discord.com/developers/docs/topics/rate-limits),
  [Opcodes and Status Codes](https://discord.com/developers/docs/topics/opcodes-and-status-codes),
  [Create Message](https://discord.com/developers/docs/resources/message#create-message),
  [API Reference](https://discord.com/developers/docs/reference).
- Community libraries, at fixed commits:
  [`discordjs/discord.js@03777df`](https://github.com/discordjs/discord.js/tree/03777df7f7cc372de88fd05cd3999ab59e5c36c0)
  (`packages/rest`) and
  [`Rapptz/discord.py@65232c3`](https://github.com/Rapptz/discord.py/tree/65232c38702be5844cf2ce865a4777eb1928b5d0)
  (`discord/http.py`).

What Discord documents:

- "rate limits should not be hard coded into your app. Instead, your app
  should parse response headers".
- "per-route limits will be shared across a set of similar endpoints,
  indicated in the `X-RateLimit-Bucket` header. It's recommended to use this
  header as a unique identifier for a rate limit".
- On a 429, "rely on the `Retry-After` header or `retry_after` field to
  determine when to retry the request".
- "All bots can make up to 50 requests per second to our API."
- Invalid requests: "this limit is **10,000 per 10 minutes**. An invalid
  request is one that results in **401**, **403**, or **429** statuses", and
  "429 errors returned with `X-RateLimit-Scope: shared` are not counted
  against you". Large apps "should consider logging and tracking the rate of
  invalid requests".
- A 502 means "wait a bit and retry".
- A message create with a `nonce` and `enforce_nonce: true` returns the
  message already created for that nonce instead of creating another.

## Resends

| Response or failure | Resent? | Basis |
|---|---|---|
| Discord's 429 | Every method, after the body's `retry_after` (plus 1 ms), however long | Discord |
| A 429 that is not Discord's (below) | Never; raised at once | Discord: each resend counts towards the invalid-request limit |
| 502 | Every method, `POST` and `PATCH` included, with backoff | Discord: "wait a bit and retry" |
| Other 5xx | Idempotent calls only, with backoff | discord.js and discord.py resend them; Discord does not object |
| Transport failure or timeout after the request may have been sent | Idempotent calls only, with backoff | Same |
| A failure known to have sent nothing | Every method | Nothing reached Discord |
| 401, 403, other 4xx | Never | Discord's answer, and 401/403 count as invalid requests |

Idempotent calls are `GET`, `HEAD`, `PUT`, `DELETE`, `OPTIONS`, and a message
create with a `nonce` and `enforce_nonce: true`. A `POST` or `PATCH` that may
have reached Discord is otherwise raised at once rather than risk a second
effect. Resends stop after `max_retries` (default 4); the backoff is
`gaato/sdk-runtime`'s conservative one (500 ms doubling up to 30 s, within
±20 %), and each attempt is bounded by `request_timeout_ms` (default 30 s).

**Whose 429 is it?** A 429 is Discord's when it has an `X-RateLimit-Scope`
or `X-RateLimit-Global` header or a JSON content type, as Discord documents.
Any other 429 comes from something in front of Discord, such as Cloudflare,
and names no wait. `@ratelimit.is_discord_rate_limit` makes this decision for
both the resend rule and the rate limiter, so the two always agree.
discord.py treats such a response the same way ("Banned by Cloudflare more
than likely").

## Rate limits

- Buckets follow `X-RateLimit-Bucket` together with the route's major
  parameter (channel, guild, or webhook), so routes Discord groups share one
  state. Until Discord names a route's bucket, the route has its own.
- The global limit is 50 requests per second; interaction and webhook routes
  are outside it. A 429 with
  `X-RateLimit-Global` or `X-RateLimit-Scope: global` holds every
  non-interaction route.
- A 429 with `X-RateLimit-Scope: shared` does not hold its bucket: Discord
  does not count a shared limit against the bot.
- A 429 that is not Discord's holds every non-interaction route for its
  `Retry-After`, or one second.

## Invalid requests

`Client::invalid_requests()` counts the 401, 403, and 429 responses of the
past ten minutes, resends included and shared-scope 429s excluded, so a bot
can watch the count and slow down before Discord bans the address. It covers
one client.

## Implementation

- `discord/src/http/retry.mbt`: `discord_retry_rule` is a `gaato/http/retry`
  `RetryRule`, and `resend_decision` adds the Discord-specific inputs (the
  429 wait and whether the call is idempotent).
- The resend decision cannot see a multipart body, which is assembled just
  before sending. `wire_request` therefore marks a `CreateMessage` whose body
  has a `nonce` and `enforce_nonce: true` with the internal header
  `x-discord-mbt-replay-safe`; the client removes it before the transport, so
  it never reaches Discord, and removes it from callers' requests first.
- `Timeouts` from `gaato/sdk-runtime` wrap only a transport the caller
  supplies. The default `AsyncTransport` times each phase itself, so it can
  tell a timeout before sending (`Pool`, `Dial`) from one after.
