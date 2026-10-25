# mttp migration

This unpublished integration uses the sibling mttp and mttp-net workspaces.
It is not a registry release. The REST client accepts mttp Backends and uses
mttp's immutable headers, clock, retries and response readers. Caller-provided
Backends remain caller-owned; the client does not close them.

## Behavior changes

- The 64 MiB REST response limit applies to supplied Backends as well as the
  default transport. Failed body reads retain a received response's status and
  headers for rate-limit release and attempt telemetry.
- Attempt observers see the decided retry after limiter release. Closing a
  client from its observer prevents another wire send, but a retry wait already
  selected for that attempt may finish first.
- The HTTP interactions route is an mttp Endpoint over the exact signed bytes.
  Its native/Wasm listener uses mttp-net/server: 1 MiB bodies, 16 KiB headers,
  five-second header/body budgets and 256 connections. The handler has no
  transport deadline; the existing 2.5-second interaction deadline still
  returns 504 while allowing deferred app work to continue.
- Oversized declared bodies get 413 before endpoint authentication, including
  requests without signature headers. Header timeouts now send 408 and close.
  Invalid framing and body failures use the bounded transport's error replies.
  `ServerConfigError` is re-exported from mttp-net/server; qualify its
  constructors from that package. `close()` retains immediate cancellation by
  setting the transport drain budget to zero.
- Multipart responses retain their chunks through `stream_body_out`; they are
  not concatenated for Endpoint encoding. Empty chunks are skipped because
  mttp BodyStream reserves `None` for EOF and requires nonempty data chunks.

## Test clock

`VirtualClock.advance` changes time and wakes due timers synchronously. Tests
wait for a specific timer registration, received frame, state or task outcome
with `settle(until=...)` before the next advance. This avoids relying on a
fixed number of scheduler turns to infer that unrelated tasks are idle.

## Validation checkpoint

The final Discord/Voice consumer checkpoint passed 1,482 native, 1,291 Wasm and
1,262 JS tests, including failed 429-body telemetry and failed interaction reply
encoding. The Fetch adapter passed the shared Node
dispatch suite, Fastly/Vercel/Lambda lifecycle tests, and 14 tests in local
Cloudflare workerd, including deferred work after request abort. These are
local tests, not hosted deployments. Documentation, clock and API-surface
audits pass. Native coverage is 95.3%, with every uncovered line ledgered.
The packaged migration graph builds through an isolated registry outside
moon.work. Lambda also rejects oversized and malformed request envelopes before
decoding and bounds buffered replies to 4 MiB. No releases have been published.
