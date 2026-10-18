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
| Cache entries (`cache/cache.mbt`) | `CacheLimits` per resource, and everything keyed by a guild or channel leaves with it. The defaults limit only messages (100 per channel); see the known gaps for what that leaves unbounded | Oldest entry evicted |
| Cache unavailable-guild flags (`cache/cache.mbt`) | Guilds the bot is in | — |
| Cooldown windows (`cooldown/cooldown.mbt`) | Live windows: expired keys are swept whenever the map doubles, and at least once a minute | — |
| REST rate-limit buckets (`gaato/sdk-runtime` `WindowLimiter`, also inside the coordinator) | Buckets in use: idle gates are dropped, expired states swept whenever the map doubles, and at least once a minute | — |
| REST response body (`http/client.mbt`, the transport the client creates) | 64 MiB, the same as the Gateway default | The attempt fails with `DiscordHttpError::Transport` and the connection closes; a supplied `transport=` keeps its own policy |
| Inbound interaction request body (`endpoint_http/endpoint_http.mbt`) | `max_body_bytes`, default 1 MiB | 413 and the connection closes |
| Interaction HTTP connections (`endpoint_http/endpoint_http.mbt`, `serve_interactions`) | `max_connections`, default 256, served at once | Further clients wait to be accepted |
| Time to the next request head on an interaction HTTP connection (`endpoint_http/endpoint_http.mbt`, `serve_connection`) | `header_timeout_ms`, default 5 s, idle keep-alive time included | The connection closes, freeing its slot |
| Voice receive stream (`discord_voice/src/subscribe.mbt`) | 250 frames | Newest frames dropped, then a `Lost(count)` marker; `ReceiveDropped` telemetry |
| Voice event queue (`discord_voice/src/connection.mbt`) | 256 events | Oldest dropped; `EventDropped` telemetry |
| Voice reorder buffer (`discord_voice/src/reorder.mbt`) | 8 packets or 60 ms | Flushed as `Lost` |
| Voice SSRC mappings and reorder windows (`discord_voice/src/receive.mbt`) | One per user in the channel: a user's new SSRC replaces the old one, and both leave on `ClientDisconnect` or a session reset | — |
| DAVE prepared transitions (`discord_voice/src/dave.mbt`) | 16 | The oldest is forgotten; executing it later does nothing |
| One received voice gateway message (`discord_voice/src/transport.mbt`) | 4 MiB | The connection ends with 1009 and resumes |
| Coordinator request and response lines (`coordinator/line.mbt`) | 64 KiB | The coordinator answers with an error and closes the connection; the client drops it with `InvalidResponse` |
| Ogg input (`discord_voice/src/ogg_opus.mbt`, `OggPacketReader`) | Only the unparsed tail is kept; one packet at most 16 MiB | `InvalidOggPage` |

## Bounded by rate and lifetime

| Structure | Grows with | Bound |
|---|---|---|
| Bot shard event forwarding queue (`bot/bot.mbt`, `shard_events`) | Gateway events not yet routed | Discord's event rate times the routing loop's latency. The loop only updates the cache, routes interactions, and queues handler work; bounding the queue would stall the shards' read loops, leave heartbeat ACKs unread, and trigger false zombie reconnects. The one slow step is the command sync after the first READY. |
| Interaction tasks (`bot/bot.mbt`, `spawn_interaction`) | `INTERACTION_CREATE` events | Each waits at most its callback window (2.5 s) or, deferred, joins the `max_pending` budget |
| Interaction capture races (`app/endpoint.mbt`) | Interactions handled by the HTTP endpoint | One per request, finished within its deadline |
| JavaScript interaction responses (`app/interaction_http.js.mbt`) | Requests on the JavaScript adapter | One per request, delivered when its handler answers |
| Event and component waiters (`bot/collector.mbt`, `framework/framework.mbt`) | Calls to `wait_for`, `expect_event`, `wait_for_component` | Removed when matched, timed out, or cancelled; each buffers only the events it matches. Waits without a timeout last as long as the caller keeps them. |
| Coordinator connections and bucket owners (`coordinator/server.mbt`) | Connected processes and the buckets they hold | Released on EOF; TCP keepalive notices a dead peer in about 25 s |
| Voice join gates (`discord_voice/src/client.mbt`) | Joins in progress | The last join for a guild, finished or failed, removes its gate |
| Voice connections (`discord_voice/src/client.mbt`, `connections`) | Guilds joined | Removed when the connection leaves or closes, and when `run` ends |
| Voice connection roster and DAVE rosters and decryptors (`discord_voice/src/connection.mbt`, `discord_voice/src/dave.mbt`) | `ClientsConnect`, MLS commits and welcomes | Users in the current session: `ClientDisconnect` and MLS removals take them out, and a new session starts empty (the roster is cleared, the DAVE machine replaced) |
| Voice connection background tasks (`discord_voice/src/connection.mbt`) | Connections | Each connection's receiver, keepalive, playback, and server watch are cancelled when it closes, whatever they wait on; the event pump ends with the teardown it runs |
| Voice server watches (`discord_voice/src/connection.mbt`, `run_server_watch`; the expectation from `discord_voice/src/client.mbt`) | Joins | One per open connection, holding one `VOICE_SERVER_UPDATE` expectation that is cancelled when the connection closes; a rejoin waits for the old connection's teardown first |
| Voice receive subscriptions (`discord_voice/src/subscribe.mbt`) | `subscribe` calls | Removed by `close` or when the connection ends |
| Member chunk collection (`bot/member_chunks.mbt`) | `GUILD_MEMBERS_CHUNK` events for one `fetch_guild_members` | The guild's member count, for at most the call's `timeout_ms` |
| Coordinator client leases (`coordinator/remote.mbt`, `RemoteRateLimiter`) | REST requests through the coordinator | Requests in flight: each lease leaves on release |

## Known gaps

Growth the library does not bound yet, with what limits it in practice.

| Structure | Grows with | What limits it |
|---|---|---|
| REST response heads (`moonbitlang/async` HTTP client under the `gaato/http-async` transport) | Status line and header size | Parsed with no byte limit; only `request_timeout_ms` times bandwidth, from Discord over TLS |
| Interaction HTTP request heads (`moonbitlang/async` HTTP server under `endpoint_http`) | Request line and header size | No byte limit: only `header_timeout_ms` times the client's bandwidth, per connection, for `max_connections` connections. A client holding every slot delays Discord's requests until its heads time out; put the server behind a proxy that limits header size and connections per client when it is exposed beyond Discord |
| Cached users (`cache/cache.mbt`, `users_`) | Every distinct user seen in members, messages, bans, and presences | Unlimited by default and not keyed by guild, so leaving a guild keeps them; set `CacheLimits(users=...)` for a long-running bot |
| Cached DM message buckets and archived threads (`cache/cache.mbt`) | DM channels with messages, when message caching is on (`CacheResources(messages=true)`); threads that are archived instead of deleted | DM buckets are never dropped (bots get no `CHANNEL_DELETE` for DMs); archived threads stay until their guild leaves or a thread list sync. Set a `channels` limit, and keep message caching off where DMs are many |
