# Resource bounds

What a long-running bot or interaction server can accumulate, and what keeps
each structure from growing without limit. Companion to
[TEST_COVERAGE.md](TEST_COVERAGE.md) and follows the same rule: **every
structure that grows with input from Discord, the network, or other processes
is listed here with its bound**. A new one — a queue built with
`kind=Unbounded`, or a map keyed by ids, tokens, or keys that arrive from
outside — needs a row before it ships.

A bound is either a limit the code enforces, or the rate of the input times
how long an entry lives, where both are themselves bounded. Rows of the second
kind say what that product is.

## Enforced limits

| Structure | Bound | On overflow |
|---|---|---|
| One received Gateway message (`gateway/transport.mbt`, `gateway/compression.mbt`) | `max_message_bytes`, default 64 MiB, for the frame, accumulated compressed bytes, and inflated output | The connection ends (1009 for a frame, `InflateError::TooLarge` for zlib) and the shard resumes |
| Shard event queue (`gateway/shard.mbt`) | `queue_capacity`, default 256 | The read loop waits (backpressure) |
| Bot event handler backlog (`bot/bot.mbt`) | `event_backlog`, default 10 000 | Handlers skip the event: `EventDropped` telemetry each, one warning per overload |
| Running interaction handlers (`app/admission.mbt`) | `max_in_flight`, default 64 | Wait within the callback window, then `InteractionDropped` / `DeferredInteractionExpired` |
| Deferred interactions waiting for a handler (`app/admission.mbt`) | `max_pending`, default 1024 | `HandlerError::Busy`; one `DeferredInteractionsRefused` warning per overload |
| Running event handlers (`app/app.mbt`, `App::spawner`) | `max_in_flight` | The backlog fills, see above |
| Gateway commands per connection (`gateway/command_limit.mbt`) | 115 per 60 s, presence 5 per 20 s | The sender waits |
| Cache entries (`cache/cache.mbt`) | `CacheLimits` per resource; everything keyed by a guild or channel leaves with it | Oldest entry evicted |
| Cache unavailable-guild flags (`cache/cache.mbt`) | Guilds the bot is in | — |
| Cooldown windows (`cooldown/cooldown.mbt`) | Live windows: expired keys are swept whenever the map doubles | — |
| REST rate-limit buckets (`gaato/sdk-runtime` `WindowLimiter`, also inside the coordinator) | Buckets in use: idle gates are dropped, expired states swept whenever the map doubles | — |
| Inbound interaction request body (`endpoint_http/endpoint_http.mbt`) | `max_body_bytes`, default 1 MiB | 413 and the connection closes |
| Voice receive stream (`discord_voice/src/subscribe.mbt`) | 250 frames | Newest frames dropped, then a `Lost(count)` marker; `ReceiveDropped` telemetry |
| Voice event queue (`discord_voice/src/connection.mbt`) | 256 events | Oldest dropped; `EventDropped` telemetry |
| Voice reorder buffer (`discord_voice/src/reorder.mbt`) | 8 packets or 60 ms | Flushed as `Lost` |

## Bounded by rate and lifetime

| Structure | Grows with | Bound |
|---|---|---|
| Bot shard event forwarding queue (`bot/bot.mbt`, `shard_events`) | Gateway events not yet routed | Discord's event rate times the routing loop's latency. The loop only updates the cache, routes interactions, and queues handler work; bounding the queue would stall the shards' read loops, leave heartbeat ACKs unread, and trigger false zombie reconnects. The one slow step is the command sync after the first READY. |
| Interaction tasks (`bot/bot.mbt`, `spawn_interaction`) | `INTERACTION_CREATE` events | Each waits at most its callback window (2.5 s) or, deferred, joins the `max_pending` budget |
| Interaction capture races (`app/endpoint.mbt`) | Interactions handled by the HTTP endpoint | One per request, finished within its deadline |
| Interaction HTTP connections (`endpoint_http/endpoint_http.mbt`) | Inbound connections | Each reads its request under a timeout; put the server behind a proxy that limits connections when it is exposed beyond Discord |
| JavaScript interaction responses (`app/interaction_http.js.mbt`) | Requests on the JavaScript adapter | One per request, delivered when its handler answers |
| Event and component waiters (`bot/collector.mbt`, `framework/framework.mbt`) | Calls to `wait_for`, `expect_event`, `wait_for_component` | Removed when matched, timed out, or cancelled; each buffers only the events it matches. Waits without a timeout last as long as the caller keeps them. |
| Coordinator connections and bucket owners (`coordinator/server.mbt`) | Connected processes and the buckets they hold | Released on EOF; TCP keepalive notices a dead peer in about 25 s |
| Voice join gates (`discord_voice/src/client.mbt`) | Guilds joined | Guilds the bot is in |
