# Resource bounds

What a long-running bot or interaction server can accumulate, and what keeps
each structure from growing without limit. Companion to
[test coverage ledger](test-coverage.md) and follows the same rule: **every
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
| One received Gateway message (`gateway/transport.mbt`, `gateway/compression.mbt`) | `max_message_bytes`, default 64 MiB, for the frame, accumulated compressed bytes, and inflated output | The connection ends (1009 for a frame, `InflateError::TooLarge` for zlib-stream and zstd-stream) and the shard resumes |
| Shard event queue (`gateway/shard.mbt`) | `queue_capacity`, default 256 | The read loop waits (backpressure) |
| Bot event handler backlog (`bot/bot.mbt`) | `event_backlog`, default 10 000 | Handlers skip the event: `EventDropped` telemetry each, one warning per overload |
| Running interaction handlers (`app/admission.mbt`) | `max_in_flight`, default 64 | Wait within the callback window, then `InteractionDropped` / `DeferredInteractionExpired` |
| Deferred interactions waiting for a handler (`app/admission.mbt`) | `max_pending`, default 1024 | `HandlerError::Busy`; one `DeferredInteractionsRefused` warning per overload |
| Running event handlers (`app/app.mbt`, `App::spawner`) | `max_in_flight` | The backlog fills, see above |
| Gateway commands per connection (`gateway/command_limit.mbt`) | 115 per 60 s, presence 5 per 20 s | The sender waits |
| Cache entries (`cache/cache.mbt`) | `CacheLimits` per resource, and everything keyed by a guild or channel leaves with it | Oldest entry evicted |
| Cached messages (`cache/cache.mbt`), when enabled | `messages`, default 100 per channel, times the channels holding them (rows below) | Oldest message evicted |
| Cached DM and group DM channels and their messages (`cache/cache.mbt`, `dm_channels_`) | `dm_channels`, default 128 channels without a guild | Least recently written channel evicted with its messages and their authors' holds |
| Cache deadline indexes (`cache/deadline_heap.mbt`, `Buckets.due_`), per resource with a TTL | 2 × its non-empty buckets + 16 items, checked whenever an item is added or a bucket goes | Rebuilt from the live buckets, one item each |
| Cached users seen without a holder (`cache/user_store.mbt`, `recent_`) | `recent_users`, default 128: bans, departed members, interaction users, authors of messages the cache does not keep | Least recently seen evicted |
| Cooldown windows (`cooldown/cooldown.mbt`) | Live windows: expired keys are swept whenever the map doubles, and at least once a minute | — |
| REST rate-limit buckets (`gaato/mttp/client/ratelimit` `WindowLimiter`, also inside the coordinator) | Buckets in use: idle gates are dropped, expired states swept whenever the map doubles, and at least once a minute | — |
| Learned `X-RateLimit-Bucket` keys (`ratelimit/ratelimit.mbt`, `server_key`; the `WindowLimiter`'s aliases) | One per route bucket that named a hash, pointing at a recorded state: an alias whose state has expired is swept with the states | — |
| Invalid-request count (`http/invalid_requests.mbt`, one per REST client) | 60 counters, one per ten-second step of the last ten minutes | The oldest step's counter is reset and reused |
| REST response body (`http/client.mbt`, including a supplied Backend) | 64 MiB, the same as the Gateway default | The attempt fails with `DiscordHttpError::Transport` and its response body closes |
| Inbound interaction request body (`endpoint_http/endpoint_http.mbt`) | `max_body_bytes`, default 1 MiB | 413 and the connection closes |
| Interaction HTTP connections (`endpoint_http/endpoint_http.mbt`, `serve_interactions`) | `max_connections`, default 256, served at once | Further clients wait to be accepted |
| Time to the next request head on an interaction HTTP connection (`mttp-net/server`) | `header_timeout_ms`, default 5 s, idle keep-alive time included | 408 and the connection closes, freeing its slot |
| Interaction HTTP request heads (`mttp-net/server`) | 16 KiB per request head | 431 and the connection closes |
| REST response heads (default native/Wasm `mttp-net/backend`) | 16 KiB per response head | The attempt fails with a transport limit error |
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
| Voice connection background tasks (`discord_voice/src/connection.mbt`) | Connections | Each connection's receiver, keepalive, playback, and server and channel watches are cancelled when it closes, whatever they wait on; the event pump ends with the teardown it runs, and its wait for a new server after a null endpoint lasts at most `server_timeout_ms` |
| Voice server and channel watches (`discord_voice/src/connection.mbt`, `watch_updates`; the expectations from `discord_voice/src/client.mbt`) | Joins | Two per open connection, each holding one expectation (`VOICE_SERVER_UPDATE`, the bot's own `VOICE_STATE_UPDATE`) that is cancelled when the connection closes; a rejoin waits for the old connection's teardown first |
| Voice receive subscriptions (`discord_voice/src/subscribe.mbt`) | `subscribe` calls | Removed by `close` or when the connection ends |
| Cache guild-scoped state (`cache/cache.mbt`: guilds, unavailable-guild flags, channels, roles, members, voice states, presences, and their message buckets) | Guilds joined and Discord events within them | What Discord holds per guild times the guilds the bot is in: everything leaves with its guild on `GUILD_DELETE`, on eviction or expiry, and when a new session's `READY` no longer lists it; a fresh `GUILD_CREATE` drops the channels and threads it no longer lists |
| Cache thread index and threads (`cache/cache.mbt`, `threads_`) | `THREAD_CREATE`, `THREAD_LIST_SYNC`, and threads in `GUILD_CREATE` | Active threads of the bot's guilds: a thread leaves when deleted, archived, replaced by a thread list sync, or (private) when the bot is removed from it, with its messages, whether or not channels are retained |
| Cached users held by cached entries (`cache/user_store.mbt`, `held_`, `counts_`) | Members, cached messages, and the current user | One record per distinct user those entries hold, released when the last holder goes by any path (removal, eviction, expiry, a dropped guild or channel) |
| Member chunk collection (`bot/member_chunks.mbt`) | `GUILD_MEMBERS_CHUNK` events for one `fetch_guild_members` | The guild's member count, for at most the call's `timeout_ms` |
| Coordinator client leases (`coordinator/remote.mbt`, `RemoteRateLimiter`) | REST requests through the coordinator | Requests in flight: each lease leaves on release |

## Host-dependent limits

JavaScript Fetch parses HTTP response heads in the host runtime, whose header
limits apply. Supplied Backends also own their head-parsing policy. The native
listener's connection cap is global; per-client connection admission remains
the responsibility of the deployment or its reverse proxy.
