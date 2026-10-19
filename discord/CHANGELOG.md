# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Minor releases
(0.x → 0.y) may contain breaking changes; patch releases do not. Every
breaking change is listed with a migration note.

## [Unreleased]

### Added

- **Gateway `zstd-stream` transport compression.** `BotBuilder(compression=
  ZstdStream)` (and `Shard::start(compression=...)`) asks Discord for
  `compress=zstd-stream` and decodes it with `gaato/zstd`, pure MoonBit like
  the zlib decoder, so it works the same on native, JavaScript, and Wasm.
  `compression=ZlibStream` is the same as `compress=true`, which stays; when
  both are given, `compression` wins. `GatewayCompression` is
  `#non_exhaustive`. `max_message_bytes` bounds a zstd message, compressed or
  decoded, as it does a zlib one.

## [0.10.1] - 2026-10-19

### Changed

- Built on `gaato/http` 0.3.1 and `gaato/sdk-runtime` 0.5.0: multipart bodies,
  the boundary's random source, and `Retry-After` parsing now come from
  `gaato/http` (`gaato/http/multipart`, `gaato/http/random`), where they moved
  from `gaato/sdk-runtime`. The public API is unchanged.

## [0.10.0] - 2026-10-18

### Changed

- **`DiscordHttpError::Transport` and `Timeout` say where the exchange
  failed, and whether the request can have reached Discord.** Both carry a
  `phase~ : @http.Phase` (from `gaato/http`): `Pool` (waiting for a
  connection, or a closed client) and `Dial` (connecting, TLS, or a proxy
  tunnel) mean no byte was sent, and the new `DiscordHttpError::is_unsent()`
  says so; `Write`, `Head`, `Body`, and `Unknown` mean Discord may have acted
  on it. Before, every failure was a `Transport(message~)` holding the
  transport error's debug text, or a `Timeout(timeout_ms~)`, so a caller could
  not tell "never sent" from "maybe sent". `Timeout.timeout_ms` is now the
  limit that ran out rather than the configured `request_timeout_ms` (the
  same for the default transport), and a multipart boundary that cannot be
  chosen is a `Validation` failure, since it happens before any I/O.
  Migration: add `..` (or `phase~`) to patterns on `Transport(message~)` and
  `Timeout(timeout_ms~)`, and pass `phase=` where you construct them
  (`Unknown` when you cannot tell). Code that parsed the transport's debug
  text out of `message` should read `phase` instead; `message` is now the
  failure's description alone (`could not connect: refused`).
- **The REST client resends a call that never reached Discord.** A transient
  transport failure or timeout that proves no byte was sent (a refused or
  failed connection, a proxy that could not reach Discord with 502-504, or a
  timeout waiting for a connection or connecting) is sent again with the
  runtime's default backoff, up to `max_retries` times together with 429
  retries, for every method including `POST`: Discord never saw the first
  attempt, so nothing can be duplicated. Each resend is admitted and released
  by the rate limiter like any attempt and reported to telemetry. A failure
  after connecting, or a timed-out exchange, is still raised at once, and a
  closed client resends nothing, not even a 429. Before, only a 429 was
  resent. Migration: none; pass `max_retries=0` to raise every failure at
  once.

- **Depends on `gaato/http` 0.3.0, `gaato/http-async` 0.3.1, and
  `gaato/sdk-runtime` 0.4.0.** The clock helpers the library kept for itself
  (the wall clock behind every `clock?` default, and the clock-driven
  timeout) now come from `gaato/http-async`'s `AsyncClock` and
  `with_timeout_opt`, and the REST client uses http-async's new response body
  bound (see Fixed). The REST rate limiter now holds a bucket for at most an
  hour whatever reset or `Retry-After` a response sends, and an error keeps
  at most 1 MiB of its body. The default REST transport now goes through the
  proxy named by `HTTPS_PROXY`, `ALL_PROXY` and `NO_PROXY`, as curl does; to
  connect directly, pass `transport=@transport.AsyncTransport::new(trust_env=false)`.
  The Gateway WebSocket still connects directly. A REST transport failure
  now keeps the phase it failed in (see below).
  Migration: a project that also lists any of these modules in its
  `moon.mod` must move it to the same version and follow their changelogs
  where it matches `@http.HttpError` or reads `Request.body`.
- **The App, not the store, decides what an unreachable cooldown store
  means, and reports it.** `CooldownDecision` gains `Unavailable(reason~)`,
  which `RemoteCooldownStore` now returns when the coordinator times out or
  disconnects. `AppBuilder(cooldown_outage~)` picks `Allow` (the default: run
  the command without a cooldown) or `Refuse` (refuse it for the requested
  window), and the first failure of each outage reaches `on_warn` as the new
  `AppWarning::CooldownUnavailable`. Before, the store chose with
  `when_unreachable` and an outage was silent unless `on_error` was set.
  Migration: drop `when_unreachable=` and `on_error=` from
  `RemoteCooldownStore::connect`; pass `cooldown_outage=Refuse` to
  `AppBuilder` where you used `FailClosed`; a custom `CooldownStore` may
  return `Unavailable`, and code matching `CooldownDecision` needs the new
  arm.
- **`Shard::start` and `CommandLimiter` take a `clock~` instead of a
  `sleeper~`.** The clock (`gaato/http/clock`'s `Clock`, the same trait
  `@ratelimit.rate_limiter` takes) supplies both the current time and the
  waits, so a test can drive heartbeats, backoff, and the command window on
  virtual time; before, the limiter read the wall clock even when the sleeper
  was replaced. A clock's sleep cannot fail, so a sleeper that raised to stop
  the reconnect loop has no equivalent: close the shard instead.
  Migration: drop `sleeper=` or pass `clock=` with your own `Clock`.
- **The cache is bounded under its defaults; archived threads are no longer
  served from it.** Before, a long-running bot's cache grew without limit:
  every distinct user ever seen stayed in `users`, a DM channel's messages
  were never released (Discord sends bots no `CHANNEL_DELETE` for DMs), and
  archived threads kept their channel entry and messages until their guild
  left. Now a user stays only while a cached entry holds it (a member entry,
  a cached message it wrote, or the current user) and leaves with the last
  one, by whatever path; users seen without a holder (bans, departed members,
  interaction users, authors of messages the cache does not keep) go to an
  LRU of the 128 most recent, `CacheLimits(recent_users=)`, which `user()`
  and `users()` also read. Channels without a guild share an LRU of 128,
  `CacheLimits(dm_channels=)`, evicting the least recently written with its
  messages. A thread leaves with its messages when `THREAD_UPDATE` reports it
  archived, when the bot is removed from it if it is private, and when a
  `THREAD_LIST_SYNC` replaces it, also with channels not retained. A new
  session's `READY` drops the guilds of its shard it no longer lists (left
  while disconnected), and a fresh `GUILD_CREATE` drops the channels and
  threads it no longer lists. Expiry reaches across structures: every read
  and event first releases whatever has expired, so a member or message past
  its TTL releases its user, and a DM whose messages are gone its DM slot,
  without its own bucket being read (each TTL'd resource indexes its
  buckets' earliest deadlines, so this costs only the expired entries). The
  `users` limit now applies to held users only, and `USER_UPDATE` only
  updates the current user. Migration: fetch
  archived threads over REST (`channel_ref(id).fetch()` or the archived
  thread listings) instead of reading them from the cache; a bot that relied
  on `user()` finding any user ever seen should fetch misses over REST or
  raise `recent_users`; pass `CacheLimit()` for `dm_channels` or
  `recent_users` to restore the unbounded behaviour.

### Added

- **The REST client takes a `clock`.** `Client(clock?)` and
  `Client::offline(clock?)` (`gaato/http/clock`'s `Clock`, defaulting to the
  wall clock) drive 429 and resend back-off, the default rate limiter's
  windows, the attempt deadline around a supplied transport, telemetry
  durations, and the `ChannelRef::with_typing` keepalive, so a test can run
  them on virtual time. `App::serve(access=Token(..), clock?)` and the bot's
  own client pass their clock on, and the default transport times its phase
  limits and idle connections on it too.
- **`DeliveryFailure::Unsent`**: the callback never reached Discord, so the
  window is still unused. `classify_rest_callback_failure` returns it for a
  `Transport` or `Timeout` for which `is_unsent()` holds, and `ResponseGate`
  returns to `Pending` on it, as on `Rejected`. Migration: a match on
  `DeliveryFailure` with a `..` arm needs an `Unsent` arm (warning 11 under
  `--deny-warn`).

- **`InMemoryQueue` takes a `clock~`** for the Identify spacing, defaulting to
  the wall clock.
- **Interaction timing takes a `clock`.** `Framework(clock?)` times callback
  deadlines, token lifetimes, component waits, and the App's handler
  admission (auto-defer watchdog and capacity waits), and `Framework::clock`
  exposes it to executors. `ResponseGate`, `ResponseGate::rest`,
  `ResponseGate::capture`, and `App::serve` accept the same `clock?`. Every
  default is the wall clock.
- **A received Gateway message has a size limit.** `Shard::start` and
  `BotBuilder` take `max_message_bytes` (default `DEFAULT_MAX_MESSAGE_BYTES`,
  64 MiB), which bounds a message as received, its compressed bytes while they
  accumulate, and its inflated size. A larger message ends the connection
  (code 1009 for an oversized frame, 4000 on JavaScript, whose WebSocket API
  cannot send 1009) and the shard resumes; `InflateError` gains
  `TooLarge(limit~)`, and `connect_websocket` takes the same limit. A limit
  below 1 is refused: `BotBuilder::build` raises
  `BotConfigError::InvalidMaxMessageBytes`, `Shard::start` closes the shard
  fatally with code 0 before connecting, and `connect_websocket` raises the
  new `GatewayConfigError::InvalidMaxMessageBytes`. Before, one message could
  make the process allocate without bound.
- **Command sync can be planned before it is applied.**
  `App::plan_commands` fetches each scope and returns a `CommandPlan` whose
  `report()` lists the commands a sync would create, update, and delete,
  without changing anything; `CommandPlan::apply` performs it.
  `@framework.plan_command_scope`, `Framework::plan_global`, and
  `Framework::plan_guild` return the per-scope `CommandSyncPlan`. The default
  ownership policy is unchanged.
- **Bot shutdown is bounded.** After `GatewayCtx::shutdown`, `run` waits for
  event and interaction handlers that are still running for at most
  `BotBuilder(shutdown_grace_ms~)` (default `DEFAULT_SHUTDOWN_GRACE_MS`,
  10 seconds), then cancels the rest with a warning; `build` rejects a
  negative grace with the new `BotConfigError::InvalidShutdownGrace`. Before,
  it waited for them without limit, so one hung handler kept the process from
  stopping.
  No handler starts once the shutdown is requested: events still waiting in
  the backlog, or passed on by event middleware that was already running
  (which gets the grace too), are discarded with the new `EventDiscarded`
  telemetry event, event handlers waiting for capacity are dropped, and
  interactions waiting for capacity, or arriving later, are dropped with the
  new `AppWarning::InteractionDroppedWhileStopping`. Before, a handler queued at
  the request started as soon as a running one finished, inside the grace
  meant for the running ones.
- **Executors can stop the App's handlers from starting.** A
  `HandlerIntake` passed to `App::spawner(intake?)` and
  `App::attach(intake?)` keeps handlers from starting once it is closed:
  callers waiting for capacity give up at once, and a task spawned but not
  yet started does not run. The Bot closes its intake on shutdown; a custom
  executor can do the same for a graceful stop.

### Fixed

- **A member fetch whose last chunk arrives as it times out completes.**
  `GatewayCtx::fetch_guild_members` raised `GatewayRequestTimeout` when the
  final `GUILD_MEMBERS_CHUNK`, or a matching `RATE_LIMITED`, arrived in the
  same scheduler step as the deadline. It now returns the members, or raises
  `GatewayRateLimited`; a fetch still missing chunks at the deadline times
  out as before.

- **A component click or an awaited event that arrives as its wait times out
  is no longer lost.** `wait_for_component` and `PendingEvent::wait`
  (`GatewayCtx::wait_for`) returned `None` when the delivery and the timeout
  landed in the same scheduler step, although the framework had already
  routed the click to the waiter, so no handler answered it. They now return
  what was delivered.

- **The interaction HTTP server bounds its connections.** `serve_interactions`
  served any number of connections at once and waited for a request head, or
  for the next request on a kept-alive connection, without end, so idle
  clients held memory and file descriptors indefinitely. It now serves at
  most `max_connections` clients at once (256 by default) and closes a
  connection whose next request head does not arrive within
  `header_timeout_ms` (5 s by default). `ServerConfigError` gains
  `InvalidHeaderTimeoutMs` and `InvalidMaxConnections` for non-positive
  values. Migration: add arms for them where you match `ServerConfigError`
  exhaustively.

- **A REST interaction callback that never reached Discord no longer closes
  the callback window.** `classify_rest_callback_failure` treated every
  transport failure as `Uncertain`, so a refused connection left the gate
  `Unconfirmed`: the handler's next reply went out as a followup to a
  callback Discord had never received, and failed, while the auto-defer
  watchdog and the error policy saw no window left to answer in. It is now
  `Unsent`, and the gate stays `Pending`.

- **The App's default cooldown store follows the executor's clock.**
  Without a `cooldown_store`, each built App now makes its in-memory store at
  its first `attach`, timed by that executor's clock (`App::serve(clock~)`,
  the Bot's clock), so a window ends when the rest of the executor's time
  says it does; before, the store always read the wall clock. Apps built
  separately from one `AppBuilder` no longer share the default store's
  windows; pass one `cooldown_store` to share them.
- **A REST response body is limited to 64 MiB.** The transport the client
  creates fails an attempt whose body would exceed it with
  `DiscordHttpError::Transport`; before, any body was read whole into memory.
  A transport passed as `transport=` keeps its own policy. The limit matches
  the Gateway's `DEFAULT_MAX_MESSAGE_BYTES`, far above any response Discord
  documents.
- **Gateway zlib-stream compression no longer truncates large messages.**
  A message whose compressed form exceeded 64 KiB was cut off after its
  first 64 KiB, which failed the JSON parse and left the shared decoder out
  of step with the stream. This regression arrived with the pure MoonBit
  inflater in 0.9.0 and affected only `compress=true`.
- **A coordinator restart no longer lets one process release another's REST
  bucket.** Leases were integers counted from zero by each coordinator
  process, so a release retried against a restarted coordinator could carry
  a lease number that now belonged to another process and free its bucket,
  breaking per-bucket serialization. The coordinator now issues leases as
  opaque strings unique to each coordinator process. This changes the
  coordinator wire protocol: `RemoteRateLimiter` still accepts the integer
  leases of an older coordinator, but the new coordinator refuses every
  `http_acquire` from an older client (before reserving its bucket, so the
  refusal blocks no one else). Migration: upgrade bot processes before the
  coordinator.
- **A guild or channel limit in `CacheLimits` now bounds the state that
  belongs to it.** A guild that left the cache through its entry limit or TTL
  kept its roles, members, voice states, presences, channels, and the messages
  of its channels, and a channel that left the same way kept its messages;
  only GUILD_DELETE and CHANNEL_DELETE released them. Per-guild and
  per-channel maps emptied by deletes or expiry are now dropped too, and the
  cache no longer keeps a channel-to-guild entry for every channel it has
  seen, including threads a THREAD_LIST_SYNC dropped while channels were not
  retained.
- **Coordinator request and response lines are limited to 64 KiB.** A peer
  that streamed bytes without a newline made the other side buffer them
  without bound; the coordinator now answers with an error and closes the
  connection, and the client drops it with `InvalidResponse`.
- **REST rate-limit state no longer grows with every interaction.** Discord's
  webhook and interaction buckets include the token, and the limiter kept an
  entry for every bucket it had seen; `gaato/sdk-runtime` 0.2.3 drops idle
  buckets and sweeps expired ones (this also bounds the coordinator, which
  hosts the same limiter).
- **The coordinator notices peers that die without closing their
  connection.** Coordinator connections now use TCP keepalive, so a client
  host that crashes while holding a REST bucket releases it within about 25
  seconds instead of blocking that bucket for every process until the
  operating system gave up on the connection, and a client stops waiting on a
  coordinator host that vanished.
- **Identify and REST acquisitions stop waiting on a hung coordinator.** A
  coordinator process that stayed connected but stopped answering held every
  waiting shard and REST request forever, since TCP keepalive only notices a
  vanished host. While an acquisition waits, the client now pings the
  coordinator over a separate connection every 10 seconds; a ping unanswered
  for 5 seconds abandons the attempt, which reconnects and retries with the
  usual backoff. Long waits for Identify spacing or a bucket reset continue
  as long as the coordinator answers.
- **Refusing deferred interactions as busy is reported.** When
  `max_pending` deferred interactions already wait for a handler, the first
  refusal of each overload now reaches `on_warn` as the new
  `AppWarning::DeferredInteractionsRefused`; before, only the end user saw
  the busy message.
- **`InMemoryCooldownStore` sweeps expired keys as it grows.** It swept only
  after the window of the call that last swept had passed, so one command
  with a long cooldown kept every expired short window in memory until then.
- **A coordinator response cut off by a closing connection reads as a
  disconnect.** It used to surface as `InvalidResponse`, which is not
  retried, so a coordinator dying mid-response failed the REST request or
  Identify instead of reconnecting.

## [0.9.0] - 2026-10-17

### Changed

- **Gateway zlib-stream compression is pure MoonBit and works on every
  target.** The inflater now uses `moonbit-community/flate` instead of a C
  stub that loaded zlib at runtime, so `compress=true` also works on
  JavaScript and Wasm, and native builds no longer need the zlib development
  headers or the zlib shared library.
- **`@gateway.InflateError` now reports `Malformed(message~)` for a corrupt
  stream.** `InflateError(status~)` carried a zlib status code and
  `Unsupported` marked targets without compression; both are removed.
  Migration: match `Malformed(..)` where you matched `InflateError(..)`, and
  drop `Unsupported` arms.
- **The three `unchecked_raw` escape hatches now raise an
  `alert_unchecked` warning** at each use, since a reply sent through them
  breaks the handler's initial-response discipline. Migration: none needed;
  silence it with `warnings = "-alert_unchecked"` where the bypass is
  deliberate.
- **`Client::get_pinned_messages` and `ChannelRef::pins` are deprecated**,
  following Discord's deprecation of the array-returning pins endpoint.
  Migration: page with `get_channel_pins` or `ChannelRef::pins_page`.
- **Duplicate registrations report both call sites.**
  `AppConfigError::DuplicateCommand`, `DuplicateComponentRoute`, and
  `DuplicateModalRoute` gain `first~` and `second~` source locations, filled
  automatically by `AppBuilder::command`, `register`, `on_component`,
  `on_component_raw`, `on_modal`, and `on_modal_raw` through
  `#callsite(autofill(loc))`. Callers pass nothing new. Migration: a pattern
  naming only the old fields warns until it adds `..` or binds the locations.

### Removed

- `@gateway.zlib_stream_supported()` and
  `BotConfigError::CompressionUnavailable`, since compression is available on
  every target. Migration: delete the checks and their `match` arms.

### Fixed

- A heartbeat ACK that arrives with no heartbeat outstanding (before the
  first beat, or a duplicate ACK) no longer reports a latency. It reported
  the time since the Unix epoch, or since the previous beat, through
  `Shard::latency_ms` and `ShardHeartbeatLatency`.
- After a non-resumable INVALID_SESSION (op 9), a shard waits the documented
  1-5 s once before identifying. It waited 1-5 s with the connection still
  open and then also took a reconnect backoff. The shard now closes the
  connection and emits `Disconnected` before the wait.
- A 429 from an offline handler now reads its delay the way a network 429
  does: the body's `retry_after`, then the `Retry-After-Ms` or `Retry-After`
  header, then one second. It ignored the headers and fell back to one
  second, so `RateLimited` and `HttpRateLimited` reported a different delay
  than the same response would over the network.
- Errors that wrap another error now keep its details instead of only its
  type name: a middleware failure surfaced as `DiscordHttpError::Transport`,
  a coordinator `Transport` error, and the coordinator's "invalid headers"
  response, which now names the offending header.

## [0.8.0] - 2026-10-16

### Added

- Typed Gateway presence, member, soundboard, and channel-info commands, with
  `BotActivity`, `MemberSelect`, `ChannelInfoField`, `PresenceStatus::Invisible`,
  and validated member selection/UTF-8 nonces (`GatewayCommandError`), with
  guild-scoped member rate limits and five-per-20-second presence pacing.
- `BotBuilder::presence` configures initial presence on every local shard;
  `Shard::update_presence` retains the latest sent value for later Identify.
- `GatewayCtx` broadcasts presence and routes guild commands to their shards.
  `fetch_guild_members` assembles nonce-correlated chunks into `FetchedMembers`,
  with `BotError::GatewayRateLimited` and `GatewayRequestTimeout` failures.
- Select-menu `required`, READY application `flags_new`, client status `vr`,
  member-update `banner`/`collectibles`, and embed image/video media metadata.
  Modal validation rejects `min_values=0` on a select unless `required=false`,
  as Discord does.
- Guild channel creation and position updates accept channel `flags`; position
  updates also accept `clear_flags=true` for the documented nullable field.
- `MessageActivityType::StreamRequest`, `GuildFeature::PruneRequiresAdmin`, and
  named constants for all nine documented `ActivityFlags` bits.
- `GatewayCtx::expect_event(event_type, predicate)` registers an expected
  gateway event at once and returns a `PendingEvent` to `wait` on (or
  `cancel`), so it can be installed before sending the command that makes
  Discord dispatch the event. `wait_for` is `expect_event(..).wait(..)`.
  `PendingEvent` is re-exported from the facade.
- `@model.UpdateVoiceState` and `@gateway.Shard::update_voice_state` send
  opcode 4; `GatewayCtx::update_voice_state` sends it on the shard that owns
  the guild. `BotError::ShardNotManaged(shard_id~)` reports a guild whose
  shard runs in another process.
- `GatewayCtx::intents` returns the intents the bot identified with.
- `@model.text_length` returns the length Discord applies its text limits
  to: Unicode code points.

### Changed

- **New fields on `pub(all)` structs break existing struct literals.** Migration:
  use the existing constructor or add `required`, `flags_new`, `vr`,
  `banner`/`collectibles`, or the five new embed media fields (default `None`).
- **`@ratelimit.InMemoryRateLimiter` is replaced by
  `@ratelimit.rate_limiter()`**, which returns sdk-runtime's `WindowLimiter`
  configured for Discord and accepts an injected `clock`. Migration:
  `InMemoryRateLimiter(global_limit=n)` → `rate_limiter(global_limit=n)`;
  change type annotations to `@runtime.WindowLimiter`, which needs
  `"gaato/sdk-runtime@0.2.2"` in your `moon.mod` and `"gaato/sdk-runtime"
  @runtime` in `moon.pkg`.
  Bucket state now requires valid remaining and reset-after headers together,
  decrements remaining on admission, and leaves state unchanged on status 0.
  Waits no longer add a millisecond to the reset deadline. Retry-After also
  accepts HTTP dates; malformed values use the one-second fallback.
- **Request bodies now use `gaato/sdk-runtime/json`'s presence values and
  object builder.** Migration: add `"gaato/sdk-runtime@0.2.2"` to the
  `import` of your `moon.mod` (a `moon.pkg` import alone does not resolve),
  import `"gaato/sdk-runtime/json" @sdkjson` in `moon.pkg`, and replace
  `@model.Undefinable[T]` with `@sdkjson.Presence[T]` (`Missing` →
  `Absent`), `@model.ObjBuilder()` with `@sdkjson.ObjBuilder::new()`, and
  `.und(...)` with `.presence(...)`.
  `Presence` values are emitted through the builder rather than standalone
  `ToJson`/`FromJson` implementations.
- **Removed `@model.Undefinable` and its `ToJson`/`FromJson` implementations
  and `to_option`, and `@model.ObjBuilder`.** Use the sdk-runtime replacements
  above; `Presence::to_option` preserves the lossy option conversion.
- **Enums whose values Discord may extend, and the library enums that report
  events and results, are `#non_exhaustive`.** This covers the `@model` value
  sets that carry `Unknown(..)` (for example `ChannelType`,
  `InteractionType`, `MessageType`, `Component`, `Event` and `EventKind`) and
  `ShardEvent`, `DeliveryFailure`, `AppWarning`, `InteractionOutcome`,
  `FailureOrigin`, `InteractionTarget` and `TelemetryEvent`. A value that
  arrives as `Unknown(..)` today, or a new library event, can then become a
  constructor without breaking matches in your code. `Unknown(..)` still
  carries values Discord sends that this version does not know.
  - Migration: a `match` outside this module that lists every constructor of
    one of these enums needs a last arm `Type::..`, for example
    `@model.InteractionType::.. => ...`; it can share an arm with
    `Unknown(_)`. A `_` or binding arm after every constructor is reported as
    unused, because it does not stand for future constructors: replace it
    with `Type::..`. A `match` whose `_` or binding arm still covers some
    constructors needs no change.
- **Voice moved to its own module, `gaato/discord_voice`.** The
  `gaato/discord/voice` package, `GatewayCtx::join_voice`, and the native
  facade re-exports (`VoiceConnection`, `VoiceEvent`, `VoiceError`,
  `VoiceConnectionState`, `VoiceTelemetry`, `AudioSource`, `OggOpusSource`,
  `OggOpusWriter`, `OggOpusError`, `VoiceReceiveStream`, `ReceivedAudio`,
  `SILENCE_FRAME`) are gone from this module. `gaato/discord` no longer
  depends on `gaato/dave` and has no prebuild hook, so its native builds no
  longer need Node.js; the `DISCORD_VOICE_*` variables now belong to
  `gaato/discord_voice`.
  - Migration: add `gaato/discord_voice` to `moon.mod` and
    `"gaato/discord_voice" @voice` to `moon.pkg`. Create one
    `@voice.VoiceClient()` per bot and `attach` it to the `BotBuilder`, then
    replace `ctx.join_voice(guild_id, channel_id, ...)` with
    `voice.join(ctx, guild_id, channel_id, ...)` (same labels) and
    `@discord.Voice*` and the other names above with `@voice.*`.
- The examples and the guide are no longer packages of this module; they are
  unpublished modules in the repository's `examples/` and `guide/`.
- `BotError` gains `ShardNotManaged(shard_id~)`.
  - Migration: add an arm (or a wildcard) to exhaustive `BotError` matches.
- The Gateway resets its reconnect backoff after a connection reaches READY
  or RESUMED, so a single drop after a long healthy run waits the first
  backoff step instead of the cap reached by earlier failures.
- A modal text input's prefilled `value` must fit the input's own
  `max_length` (4000 when unset), counted in UTF-16 units. Discord accepts a
  prefill up to 4000 code points, but the official clients (checked on
  Android and the web) count the field in UTF-16 units and would not submit
  the modal until the user deleted text, so a prefill over `max_length` was a
  modal nobody could submit as shown. `ModalShowError::ValueTooLong` gains
  `max~`.
  - Migration: add `max~` (or `..`) to `ValueTooLong(custom_id~, length~)`
    patterns.
- Requires `moonbitlang/async` 0.22.5 (was 0.22.4); the bot template depends
  on the same version. It fixes an HTTP chunked body that ends early inside a
  chunk and no longer queues a scheduler tick for a coroutine that has already
  finished, so the JS example hosts' `whenIdle()` no longer yields an extra
  macrotask to let that tick run.
- `serve_interactions` bounds request bodies: a body over `max_body_bytes`
  (default 1 MiB) gets 413 and one not received within `body_timeout_ms`
  (default 5000) gets 408, both closing the connection. A request rejected
  before verification (405, 404, or missing signature headers) has its body
  discarded up to the same limits instead of drained without bound.
  Non-positive values raise `ServerConfigError`.

### Fixed

- Guild descriptions now accept up to 300 characters and auto-moderation
  rules accept one through five actions, matching Discord's OpenAPI limits.
- A shard closes its WebSocket with code 4000 when it is about to resume (op
  7 Reconnect, op 9, a missed heartbeat ACK, or a read failure). It sent 1000
  for every close, and Discord invalidates the session on a 1000 or 1001
  close, so those resumes could not succeed. Shutdown (`close`, or cancelling
  the shard's task group) still sends 1000. The voice gateway follows the same
  rule.
- `X-Audit-Log-Reason` is percent-encoded UTF-8, as Discord documents. A
  reason with non-ASCII text, spaces, or line breaks was sent raw, and Discord
  stored non-ASCII text as mojibake. The reason must be 1-512 characters,
  counted before encoding; an empty or longer one raises `Validation` before
  the request is sent, where Discord would silently truncate it. A value set
  directly through `headers` is still sent as given.
- Text limits are counted in code points, as Discord counts them, instead of
  UTF-16 units. An emoji outside the Basic Multilingual Plane counted as two,
  so the client rejected text Discord accepts: a 51-emoji role name or a
  1001-emoji message. This covers `Validation` for REST parameters and
  message content, `@model` embed, component, modal, and command limits (the
  embed and command totals included), custom ids and route ids, and
  `@util.split_content`, which now fills each chunk with up to 2000 code
  points. Verified against the live API for message content, embed fields
  and totals, button custom ids and labels, command descriptions, role names,
  and audit log reasons. A modal text input's prefilled `value` is the
  exception (see Changed).

## [0.7.0] - 2026-10-08

### Added

- `CommandCtx::reply`, `ComponentCtx::reply`, and `ModalCtx::reply` send a
  message through whichever path the response state allows: the initial
  response while pending, an edit of a deferred message's loading
  placeholder, or a followup.
- `remaining_ms()` on every interaction context and on `ResponseGate`: the
  milliseconds left before the initial-response window closes.
- `ResponseGate::placeholder_open()` and `close_placeholder()`, and the
  `DEFAULT_INTERACTION_DEADLINE_MS` constant (2500).
- `@model.command_limit_violations` and `CommandSpec::limit_violations()`
  check a command declaration against the limits Discord documents: name and
  description lengths, including localizations; the ASCII part of the
  CHAT_INPUT naming rule; at most 25 options per level, with unique names; at
  most 25 choices, with their name and value lengths; `min_length` and
  `max_length` ranges; and the 8000-unit total per command.
  `AppBuilder::build` raises the new `AppConfigError::CommandOutsideLimits`
  for the first violation, so a declaration Discord would reject with 400 fails
  before any executor starts.
- `token_remaining_ms()` on every raw interaction context and on
  `ResponseGate`, with the `INTERACTION_TOKEN_LIFETIME_MS` constant (15
  minutes): the time left for followups and edits, counted from receipt.
- `remaining_ms()` on `ImmediateCtx`, `ComponentImmediateCtx`, and
  `ModalImmediateCtx`: the budget left to return the initial response.
- `DeferredCtx`, `ComponentDeferredCtx`, and `ModalDeferredCtx` share one
  message surface: `original()`, `edit_original`, `delete_original()`,
  `followup`, `get_followup`, `edit_followup`, and `delete_followup`.
  Managing a followup no longer requires dropping to `raw()`.
- Every message a library surface sends passes every field Discord accepts
  for that callback. `poll` is accepted by initial replies
  (`CommandReply::message`, `ComponentReply::message`,
  `ModalReply::message`, and the raw `respond` and `reply`), by followups,
  and by `edit_original`; Discord accepts a poll in an edit only while
  editing a deferred response, so `edit_followup` does not take one. `keep_attachments` is accepted by
  `edit_original`. Component updates accept `clear_content`, `files`,
  `keep_attachments`, and `poll`.
- Modal submissions can update the message whose component opened the modal:
  `ModalReply::update_message` from an `Immediate` handler, or the new
  `ModalSubmitHandler::DeferredUpdate`. A modal opened by a command has no
  such message; the submission then fails with the new
  `HandlerError::UnsupportedResponse` before anything is sent, and the error
  policy answers with a message instead.
- `ModalCtx::update_message` and `ModalCtx::defer_update` edit the message
  whose component opened the modal. A modal opened by a command has no such
  message, so both raise `ResponseGateError::InvalidCallback` without sending
  anything.

- The `gaato/discord` facade now exports every type its golden path hands
  out: `ComponentCtx`, `GuildInvocation`, `InvocationScope`, `ModalOrigin`,
  `ResponseState`, and `TargetUser` from the framework; `DiscordHttpError`
  and the refs a gateway context returns (`MessageRef`, `ChannelRef`,
  `GuildRef`, `MemberRef`, `UserRef`, `ApplicationRef`); `InMemoryCache` with
  its `CacheResources`, `CacheLimits`, and `CacheLimit`; `InteractionCtx`,
  `InteractionTarget`, and `SyncReport`; `EventMiddleware`; and the new types
  of this release. `scripts/api_surface_audit.mbtx` checks in CI that the
  facade stays closed and that no public function takes swappable positional
  arguments.

### Changed

- **Waiting handlers no longer deadlock the executor at `max_in_flight`.**
  Routing and component waiters now run outside the handler budget. Before,
  once `max_in_flight` handlers were all in `wait_for_component`, the button
  press that would wake one of them could not be routed. The Gateway
  dispatch loop also no longer waits for event-handler capacity: event
  middleware and handler fan-out run in their own task with a separate
  budget of the same size, so busy event handlers never delay interactions.
  Both waits are bounded. At most `max_pending` deferred interactions
  (`AppBuilder`, default 1024) wait for handler capacity; one more is
  refused before it is acknowledged with the new `HandlerError::Busy`, which
  the default policy answers with a try-again message, and one still waiting
  when its interaction token expires (15 minutes after the executor received
  it) is dropped with `AppWarning::DeferredInteractionExpired`. A handler
  never starts once its window has closed, even when a permit is free or
  arrives at the last moment: a deferring route after its token expired, any
  other route after its response deadline passed (`AppWarning::InteractionDropped`).
  At most `event_backlog` decoded
  events (`BotBuilder`, default `DEFAULT_EVENT_BACKLOG` = 10000) wait for
  event handlers; later events skip the handlers, each with the new
  `TelemetryEvent::EventDropped`, with one warning per overload (until the
  backlog drains), while the
  cache and interaction routing are unaffected. `build` rejects
  `max_pending` and `event_backlog` below 1 (`AppConfigError::InvalidMaxPending`,
  `BotConfigError::InvalidEventBacklog`).
- **Initial-response deadlines are measured from receipt.**
  `InteractionEndpoint::handle_interaction`'s `deadline_ms` now includes
  time spent waiting for handler capacity. Gateway interactions get the same
  2500 ms deadline through `Framework::process(deadline_ms?)`. An immediate
  or raw handler that cannot get capacity before the deadline is dropped
  with a warning instead of answering late.
- **Deferring routes acknowledge in time even when middleware, checks, or
  decoding are slow.** For `Deferred`, `DeferredUpdate`, and
  `DeferredMessage` handlers, a watchdog defers on the handler's behalf when
  1000 ms of the budget remain. Fast failures still get an ephemeral initial
  response. Failures after the automatic defer, and
  `InteractionCtx::respond` from middleware, replace the loading
  placeholder; its visibility is the one the handler declared.
- **`FailureCtx::respond_error` edits a deferred message's loading
  placeholder instead of sending a followup.** Discord documents the
  followup-as-edit behavior as deprecated. After the handler has edited the
  original response, errors are still sent as followups.
- `ResponseGate` sorts delivery failures three ways (`DeliveryFailure`:
  `Rejected`, `Expired`, `Uncertain`). A callback rejected with Unknown
  Interaction (10062) now closes the window (`Expired`) instead of reopening
  it. A pending gate whose deadline has passed reads as `Expired`. A `send`
  made while another callback is being delivered waits for that delivery to
  finish and then sees its result.
- Breaking: `ResponseGate(rejected~ : (Error) -> Bool)` is now
  `classify~ : (Error) -> DeliveryFailure`. Migration: return `Rejected`
  where the classifier returned `true` and `Uncertain` where it returned
  `false`. The REST classifier is public as
  `@framework.classify_rest_callback_failure`.
- Breaking: `ResponseGate::responded()` is replaced by `is_pending()`.
  Migration: `gate.responded()` becomes `!gate.is_pending()`.
- **User-correctable input and malformed interactions are separate errors.**
  `HandlerError::InvalidArgument(String)` is replaced by
  `InvalidInput(name~ : String?, message~ : String)` and
  `Malformed(reason~ : String)`.
  - A failed `Arg::validate` or `ModalField::validate` is `InvalidInput`,
    and its message is shown to the user.
  - A missing or mistyped option, missing resolved data, an unknown
    subcommand path, a missing required modal field, and component state
    that does not decode are `Malformed`. The default policy logs the reason
    and tells the user only that the interaction is out of date.
  - Before, the `Repr` of the underlying error was shown to the user.
  Migration: match `InvalidInput(..)` for errors the user can correct and
  `Malformed(..)` for the rest, and raise `InvalidInput(name=None, message=...)`
  where you raised `InvalidArgument(message)` for user input.
- The default error policy answers errors that are not `HandlerError`s with
  an ephemeral "Something went wrong." and warns with the details. Before, it
  only warned, and a deferred interaction kept its loading message forever.
- Breaking: `CustomIdCodec::custom(decode~)` and `imap(to~)` accept a decoder
  that may raise any error. A `HandlerError` keeps its meaning; any other
  error becomes `Malformed`. Existing decoders compile unchanged.
- **Breaking: declarations are collected by `AppBuilder`, and `App` is the
  validated, immutable result.** `AppBuilder::build()` runs every check that
  `App::validate` ran and raises `AppConfigError`. `Bot`, `App::serve`,
  `App::attach`, `App::start_signed_http`, `serve_interactions`, and
  `App::sync_commands` take an `App`, so an executor can no longer start from
  unvalidated declarations. A built `App` cannot change: registering more
  handlers on its builder does not affect it, and neither does changing a
  registered command's spec or the arrays and maps passed to its
  constructor. `Command::check` and `Command::cooldown` return a new command
  and leave the receiver unchanged, so one command can be the base of
  several variants; a call whose result is discarded no longer has an
  effect. `App::validate` is gone.
  Migration: construct `AppBuilder(...)` where you constructed `App(...)`,
  and pass `app.build()` to the executor after every declaration is
  registered. Chain `.check(...)` and `.cooldown(...)` into the value you
  register (or bind their result) instead of calling them for their effect. A feature installer that also needs the gateway for events
  splits into one function that takes the `AppBuilder` and one that takes
  the `BotBuilder` (see the `BotBuilder` entry below); see
  [Structuring bots](src/guide/07-structuring-bots.mbt.md).
- Breaking: `raw()` on `ImmediateCtx`, `ComponentImmediateCtx`, and
  `ModalImmediateCtx` is renamed `unchecked_raw()`. Its response methods
  bypass the rule that an immediate handler answers by returning its reply;
  the name now says so. Behavior is unchanged. Migration: rename the call, or
  use the context's read-only accessors. Deferred contexts keep `raw()`.
- Breaking: `ComponentReply::UpdateMessage` carries a `MessageUpdate` value
  instead of four labeled fields, matching `Message(InitialResponse)`.
  `ComponentReply::update_message(...)` builds it and is unchanged for
  existing arguments. Migration: replace a direct
  `UpdateMessage(content~, embeds~, components~, allowed_mentions~)` with
  `ComponentReply::update_message(content?, embeds?, components?,
  allowed_mentions?)`, and match `UpdateMessage(_)` without destructuring.
- Breaking: warnings are structured. `AppBuilder::on_warn` takes
  `(AppWarning) -> Unit` and `App::warn` takes an `AppWarning`. Each variant
  names one situation (`InteractionDropped`, `MalformedInteraction`,
  `AutocompleteTruncated`, ...) and carries its data; gateway warnings arrive
  as `Executor(source="gateway", message~)`. `Show` renders the same text the
  hook used to receive, and the default hook still prints it. Migration:
  `app.on_warn(message => log(message))` becomes
  `app.on_warn(warning => log(warning.to_string()))`, or match the variants
  you act on.
- Breaking: modal state is typed, like component route state. `modal`
  takes `state~ : CustomIdCodec[S]` and returns `Modal[S, A]`;
  `Modal::show(state, values?)` takes the state value; handlers receive
  `(ctx, state, form)`; `ModalImmediateCtx::state()` and
  `ModalDeferredCtx::state()` are removed. Migration: pass
  `state=CustomIdCodec::unit()` and call `show(())` for a modal without state;
  replace `show(state=codec.encode(value))` plus `codec.decode(ctx.state()...)`
  with `state=codec`, `show(value)`, and the handler's `state` argument; add
  the state parameter to handlers (`(ctx, form)` becomes `(ctx, _, form)`).
  State that does not decode is `HandlerError::Malformed`.
- Breaking: modal handlers answer with `ModalReply`. `Immediate` returns
  `ModalReply` instead of `InitialResponse`, `Deferred` is renamed
  `DeferredMessage` (matching `ComponentHandler`), and
  `InitialResponse::message` is no longer public: every immediate reply is
  built with its reply type's `message`. Migration: replace
  `InitialResponse::message(...)` with the reply type of the handler that
  returns it — `CommandReply::message(...)` in a command handler,
  `ComponentReply::message(...)` in a component handler, and
  `ModalReply::message(...)` in a modal handler (a `Message(InitialResponse::
  message(...))` wrapper becomes the bare `XReply::message(...)`) — and
  `Deferred(ephemeral~, ...)` in a modal handler becomes
  `DeferredMessage(ephemeral~, ...)`.
- Breaking: `Modal::show` raises `ModalShowError` instead of an untyped
  error. `ModalPrefillError` is renamed `ModalShowError` and gains
  `InvalidCustomId(CustomIdError)` for state that does not encode or does not
  fit in 100 UTF-16 units. Migration: rename the type in `catch` arms and
  match `InvalidCustomId(TooLong(..))` where you matched
  `CustomIdError::TooLong`.
- Breaking: waits name the component by route and state instead of a raw
  custom id. `wait_for_component(route, state, from?, timeout_ms?)` on
  `DeferredCtx` and `ComponentDeferredCtx`, and
  `GatewayCtx::wait_for_component(route, state, user?, timeout_ms?)`, wait
  for exactly `route.custom_id(state)`, so the button and the wait are built
  from the same values. `ModalDeferredCtx` gains the same wait: a modal
  submission can now post a button and wait for it. Migration: replace
  `wait_for_component(custom_id="confirm:\{id}")` with a route such as
  `component_route(id="confirm", state=CustomIdCodec::id())` used for both
  the button (`route.custom_id(id)`) and the wait
  (`wait_for_component(route, id)`). `Framework::wait_for_component` keeps
  its string id for low-level use.
- Breaking: the gateway bot is split into `BotBuilder` and `Bot`, like
  `AppBuilder` and `App`. `BotBuilder(app, token~, ...)` takes the former
  `Bot(...)` arguments and owns every registration (`on`, `on_event`,
  `middleware`, `service`, `attach_cache`, `on_telemetry`,
  `on_decode_error`). `build()` validates the configuration — an empty token,
  `compress=true` without zlib-stream support, a shard selection Discord
  cannot represent, a saved session whose ids disagree — and raises the new
  `BotConfigError` before any connection, where `run` used to raise
  `AppConfigError::EmptyToken` or `BotError::InvalidShardConfig`. It also
  resolves intents once. The resulting `Bot` keeps `run` and `sessions`;
  registering on the builder afterwards does not change it. `run` raises the
  new `BotError::AlreadyRunning` while the same bot is running and may run
  again after it returns. `BotError::InvalidShardConfig` is replaced by
  `InvalidGatewayInfo` for layouts Discord supplies at run time. Migration:
  `let bot = Bot(app, token~)` becomes `let bot = BotBuilder(app, token~)`,
  `bot.run()` becomes `bot.build().run()`, keep the built `Bot` where you
  read `sessions()`, and a feature's `attach_x(bot : Bot)` takes a
  `BotBuilder`.
- Breaking: `App::serve` and `serve_interactions` take a required
  `access~ : RestAccess` instead of optional `client` and `token`, which
  allowed passing neither (an error at startup) or both (the token was
  silently ignored). Migration: `token~` becomes `access=Token(token)` and
  `client~` becomes `access=Client(client)`.
- Breaking: `@testkit.component(custom_id, typ?, values?)` is split into
  fixtures that produce what Discord sends: `button(custom_id)` (no
  `values`) and `select(custom_id, values~, kind?)` with a typed
  `SelectKind`. `component_raw(custom_id, typ~, values?)` builds any other
  shape, including malformed ones. Migration: `component(id)` becomes
  `button(id)`, `component(id, typ=5, values~)` becomes
  `select(id, kind=UserSelect, values~)`.
- The examples and the project template stop on an invalid `GUILD_ID`
  instead of falling back to a global command sync, which would have deleted
  every undeclared global command.
- Breaking: REST calls whose positional arguments had the same type take
  those arguments by label, so swapping them no longer compiles:
  `name~`, `image~` on `create_guild_emoji`, `create_application_emoji`, and
  the `GuildRef`/`ApplicationRef` `create_emoji`; `name~`, `sound~` on
  `create_guild_soundboard_sound` and `GuildRef::create_soundboard_sound`;
  `name~`, `description~`, `tags~` on `create_guild_sticker` and
  `GuildRef::create_sticker`; `name~` on `create_guild_from_template`.
  Migration: add the labels, e.g. `create_emoji("wave", data_uri)` becomes
  `create_emoji(name="wave", image=data_uri)`.
- Breaking: `string_choice`, `int_choice`, and `number_choice` take
  `name~` and `value~` by label. `name` is the label users see and `value`
  is what the handler receives; for `string_choice` both are strings and
  could be swapped without a compile error. Migration:
  `string_choice("Ada", "ada")` becomes
  `string_choice(name="Ada", value="ada")`, and likewise for the other two.
- `ComponentDeferredCtx::edit_original(files=...)` on a `DeferredUpdate`
  handler replaced the host message's attachments with no way to keep them;
  pass `keep_attachments` to retain the existing ones.
- **Breaking:** Component embeds (Discord docs, 2026-10-05): `Embed` gains
  `components : Array[Component]?`, the single Container of a link preview
  that the linked page builds from Discord components, and `EmbedType` gains
  `Components` for the `"components"` embed type, which decoded as
  `Unknown("components")` before. Both are receive-only; `Embed(...)` is
  unchanged. Migration: exhaustive matches on `EmbedType` need a new arm, and
  `Embed` record literals need `components: None`.

### Fixed

- `App::serve` and `serve_interactions` close the client they built from a
  token when the startup `GET /applications/@me` fails, instead of keeping
  it open until the caller's task group ends.
- A poll combined with Components V2 is rejected before sending on every
  message path. The check existed but no REST call passed the poll to it,
  so `create_message`, `create_followup`, `edit_original_response`, and
  `execute_webhook` sent bodies Discord rejects.
- The REST client sends one `User-Agent` header. With `moonbitlang/async`
  0.21.0 or later, the connection added its default `moonbit-http-client/1.1`
  next to `DiscordBot (...)`; `gaato/http-async` 0.1.2 sets the request's
  `User-Agent` when it opens the connection instead. Requires
  `gaato/http-async` 0.1.2 (was 0.1.1).

## [0.6.0] - 2026-09-25

### Added

- The bot template ships a `Dockerfile` that builds with the
  `ghcr.io/gaato/moonbit` toolchain image and runs the native executable on
  `gcr.io/distroless/base-debian13`; CI builds and starts that image. A
  `.devcontainer` starts from the same image, and CI runs in it except the
  Rust voice shim job.
- Invite target users without a CSV (Discord docs, 2026-09-18):
  `Client::add_invite_target_user`, `remove_invite_target_user`,
  `bulk_add_invite_target_users`, and `bulk_delete_invite_target_users`
  (up to 1000 users), with the matching `InviteRef` methods and `Route`
  variants, and `target_user_ids` on `Client::create_channel_invite` and
  `ChannelRef::create_invite`. `target_user_ids` and `target_users_file` are
  mutually exclusive; sending both is a `Validation` error.

### Changed

- Requires `moonbitlang/async` 0.22.4 (was 0.22.1); the bot template depends
  on the same version.
- **The REST send loop runs on `gaato/sdk-runtime` 0.2.1.** Rate limiting,
  the wire exchange, 429 retries, and per-attempt telemetry now go through the
  runtime's `Client`, which `gaato/github`, `gaato/openai`, and
  `gaato/anthropic` share. Behavior is unchanged: only a 429 is resent, after
  the delay in its body (then its `Retry-After` header, then one second); a
  timed-out attempt is never resent; middleware wraps the whole retry loop;
  `HttpRateLimited` is emitted before the back-off. Multipart bodies are
  encoded by `gaato/sdk-runtime/multipart`, so part headers are now spelled
  `Content-Disposition` and `Content-Type` and the boundary starts with
  `mbt-sdk-`.
- **Breaking:** `Client(limiter=...)` takes a `gaato/sdk-runtime`
  `RateLimiter`, and `gaato/discord/ratelimit` no longer defines the trait.
  Its `release` receives `headers~ : @http.Headers` (from `gaato/http`)
  instead of a `Map[String, String]`. `InMemoryRateLimiter` and
  `coordinator.RemoteRateLimiter` implement the new trait. Migration: import
  the trait from `gaato/sdk-runtime` and read headers with
  `headers.get(name)`, which is case-insensitive.
- **Breaking:** `Paginator[T]` is now an alias for the `gaato/sdk-runtime`
  `Paginator[T, DiscordHttpError]`. `next_page`, `collect`, and `each` raise
  `DiscordHttpError`, and the callback of `each` may be async. Type
  annotations that name `@http.Paginator[T]` keep compiling.
- **Breaking:** `encode_multipart_body` returns `Array[Bytes]` chunks, and
  `InteractionHttpBody::Chunks` carries `Array[Bytes]`; `MultipartChunk` is
  removed. Each file's bytes are still a chunk of their own and are not
  copied. Migration: write each chunk's bytes in order, as the `Blob` arm
  did.
- **Breaking:** `ActionMetadata.custom_message` is `Nullable[String]?`, because
  Discord documents it as nullable (2026-09-18). A rule whose action carried
  `"custom_message": null` failed to decode before. Migration: match
  `Some(Value(message))` where you matched `Some(message)`, and build
  `Some(Value(message))`; `Some(Null)` clears the message.

## [0.5.0] - 2026-09-24

### Added

- The Deno and Cloudflare Workers interaction adapters now share one MoonBit
  JavaScript `App` artifact; a Spin 4.1 WASIp2 experiment verifies signed PING
  and immediate echo through a Component Model handler.
- The shared interaction handler now runs in Node.js and Bun tests; a Vercel
  Node.js Function adapter passes deferred work to `waitUntil`, and a Bun
  adapter serves signed interactions over HTTP.
- Fastly `FetchEvent` and Lambda Function URL entry point experiments exercise
  synchronous lifetime registration and base64 payload conversion.
- Gateway `Shard` and `Bot` now run on JavaScript and moonrun Wasm. The
  JavaScript WebSocket client lives in `gaato/discord/internal/websocket`.
- Gateway `Session` derives `ToJson` and `FromJson`. `Shard::start(resume~)` and
  `Shard::session()` expose wire RESUME state; `Bot(resume~)` and
  `Bot::sessions()` use `BotSession` snapshots that also retain original READY
  metadata for replayed events before RESUMED. Shards with a saved session are
  not counted against `session_start_limit.remaining`, `Bot::sessions()`
  reports the supplied snapshots until the shards start, and a snapshot whose
  READY was recorded under another shard layout is dropped with a warning.
- `Bot` reads `session_start_limit` from `GET /gateway/bot` before every
  IDENTIFY, including the single-shard default and the fallback after a
  rejected RESUME, and ends `run` with `SessionStartLimitExceeded` when the
  limit is exhausted. A limit that cannot be read is reported through the
  warning hook and the shard identifies anyway.
- `zlib_stream_supported()` reports Gateway compression availability.
- The `workers_gateway` example runs a gateway bot in a Cloudflare Durable
  Object with periodic session snapshots and alarm/cron recovery. A deployed
  run on 2026-09-23 answered `/ping` over the Gateway, resumed its session
  after an eviction and after a redeploy, and re-identified through the
  session start limit check when Discord rejected a RESUME; see the example
  README.
- `InteractionHttpRequest`, `InteractionHttpBody`, `InteractionHttpResponse`,
  and `InteractionEndpoint::handle_signed_http`: one host-independent entry
  point that verifies the raw request bytes, decodes one interaction, and
  returns a status, content type, and bytes or multipart chunks. The native
  `endpoint_http` server is built on it.
- `App::start_signed_http` (JavaScript only) returning
  `InteractionHttpDispatch`, a `{ response, background }` object for host
  adapters: the initial callback and the completion of deferred work as two
  promises created synchronously, with a per-public-key verifier cache and a
  dispatch-owned REST client.

### Changed

- An inflater factory failure now closes fatally before connecting
  (`FatallyClosed(code=0)`) instead of entering resume/backoff.
- After three consecutive connector failures with a saved session, a shard
  drops that session and retries the default `gateway_url`.
- `Bot::run` raises `InvalidShardConfig` for `compress=true` on JavaScript or
  Wasm, where zlib-stream is unavailable.
- **Breaking:** `InflateError` gains `Unsupported`; exhaustive matches need a
  new arm.
- The native `endpoint_http` server answers `NoResponse` with 202 (was 500)
  and `TimedOut` with 504 (was 202), matching `handle_signed_http`.

## [0.4.3] - 2026-09-23

### Added

- Experimental linear-memory Wasm support on `moonrun` for REST, typed
  interactions, signature verification, the HTTP interactions server, TCP
  coordinator, and common data/test packages. The root facade exposes its
  common APIs and HTTP server on Wasm; Gateway/Bot and Voice remain native-only.
- Wasm loopback coverage for HTTP, connection pooling, signed interactions,
  and coordinator behavior, plus a Wasm build of the HTTP interactions example.

## [0.4.2] - 2026-09-22

### Fixed

- **The documentation appears once on mooncakes.** 0.4.1 removed the `readme`
  field, but the published package still contains `README.md` (the GitHub
  README), which mooncakes uses as the module README when the field is absent,
  and it rendered the root package's `src/README.mbt.md` again below it. The
  root package guide is now `src/overview.mbt.md`, still compiled with the
  test suite, and it is the module README (`readme = "README.md"`, a link to
  it). No code changed.

## [0.4.1] - 2026-09-22

### Fixed

- **The documentation no longer appears twice on mooncakes.** `moon.mod`
  named `README.mbt.md`, a link to the root package's `src/README.mbt.md`, as
  the module README, so mooncakes rendered the same document as the module
  page and again as the root package's documentation. The module now has no
  separate README: the root package guide is the one document, on mooncakes
  and on GitHub. No code changed.

## [0.4.0] - 2026-09-22

### Added

- **`Client(transport=...)` accepts a `gaato/http` `Transport`.** The wire
  exchange below request validation, middleware, rate limiting, 429 retries,
  status mapping, and typed decoding is now a `gaato/http` `Transport`. By
  default the client creates a `gaato/http-async` `AsyncTransport` with
  `request_timeout_ms` and a keep-alive pool of up to `max_connections`
  parked connections, and closes it in `close`; a supplied transport is
  shared and left open. Any `Transport`, including the `gaato/http/mock`
  `FakeTransport`, can stand in for the network below the same middleware
  chain that `Client::offline` answers above it.
- **`Client::offline` runs handlers without a network.** It takes a function
  of the same shape as the `next` continuation of `HttpMiddleware` and answers
  every logical REST call from it: no token, base URL, rate limiter, timeout, or
  retry, while request validation, installed middleware, status-code-to-error
  mapping, and typed decoding run exactly as online. A 429 surfaces as
  `RateLimited` at once. `FileUpload` exposes read-only filename, content, and
  content-type accessors for assertions on uploads.
- **Fixtures for handler tests (`gaato/discord/testkit`), on JS and native.**
  Deterministic model and interaction fixtures that depend only on `@model`.
  Together with `Client::offline`, `ResponseGate::capture`, and
  `Framework::process_with`, a test exercises real App validation, routing,
  decoding, checks, middleware, and error policy; see the testkit guide.
- **Outgoing embeds, components, and modals are checked against Discord's
  documented limits.** Discord answers a value outside one — a text input
  `max_length` over 4000, a button label over 80, embeds totalling more than
  6000 — with 400 Invalid Form Body, whatever the user did. Typed message send
  helpers (REST, webhooks, interaction responses and followups, edits) and
  `show_modal` now raise `DiscordHttpError::Validation` naming the offending
  path before any request is made. `App::validate` applies the modal limits to
  registered typed modals at startup (`AppConfigError::ModalOutsideLimits`),
  and `Modal::show` raises the new `ModalPrefillError::ValueTooLong` for a
  prefill value over 4000 units. The checks are public as
  `@model.embed_limit_violations`, `message_component_limit_violations`, and
  `modal_limit_violations`, each returning `LimitViolation`s. Only limits the
  official documentation states are encoded, so only requests that Discord
  already rejected are affected; exhaustive matches on
  `AppConfigError` and `ModalPrefillError` need the new cases.
- **CDN URL builders cover Discord's CDN endpoint table.** `@util` gains
  `guild_member_avatar_url`, `guild_member_banner_url`, `user_banner_url`,
  `avatar_decoration_url`, `guild_discovery_splash_url`, `guild_tag_badge_url`,
  `role_icon_url`, `scheduled_event_cover_url`, `application_icon_url`,
  `application_cover_url`, `team_icon_url`, and `sticker_pack_banner_url`,
  plus `display_avatar_url`, which resolves guild member avatar, user avatar,
  then default avatar the way clients do. `scripts/docs_cdn_audit.mbtx` audits
  names, paths and formats against a pinned table in CI; run it against updated
  documentation to discover new routes.

### Changed

- **Connection pooling moved to `gaato/http-async`.** The private per-client
  pool is gone; `max_connections` now bounds the connections the default
  transport keeps parked per origin instead of the connections in flight, so
  concurrent requests beyond it dial instead of waiting. A parked connection
  the server had dropped is retried once on a fresh connection for idempotent
  requests and surfaces as `Transport` for the rest. `gaato/http` and
  `gaato/http-async` are new dependencies.
- **CDN URL corrections and migration.** Animated WebP includes
  `animated=true`; GIF stickers use `media.discordapp.net`. Remove the `size`
  argument from `sticker_url` calls: Discord ignores it. Static-only endpoints
  default to PNG even for an `a_` hash and reject GIF with the new
  `CdnUrlError::UnsupportedFormat`; add this case to exhaustive error matches.
  Raw `Client::request` and raw interaction callback bodies remain escape
  hatches, not a promise of full outgoing model validation.
- **Typed route ids may contain `:`.** `component_route` and `modal` ids were
  rejected by `App::validate` when they contained the state separator, which
  forced a bot adopting typed routes to keep ids already attached to posted
  messages (`bot:rolemenu`) on `on_component_raw`. The rule guarded against one
  typed route receiving another's state, so `App::validate` now rejects
  exactly that — two typed ids nested at a `:` boundary, such as `ticket`
  beside `ticket:close` — with `InvalidRouteId`. Every configuration that
  validated before still validates.

- **Dot-callable trait methods are declared explicitly.** moonc 0.10.14
  deprecates the implicit promotion of trait methods to regular methods. The
  ones meant to be called with dot syntax are now `pub extend` declarations:
  `to_json()` on every `ToJson` type, `to_string()` on `Id`, `BotError`, and
  `Client`, and the `RateLimiter` / `IdentifyQueue` / `CooldownStore` /
  `AudioSource` methods on their concrete types. Nothing changes under the
  current compiler. Other promoted methods (`equal`, `not_equal`, `to_repr`,
  `T::from_json`, `lor`, `land`, `compare`, `hash`) stop resolving once the
  compiler removes the promotion; use the operators, `@debug`, and
  `@json.from_json` instead.

### Fixed

- **The Node.js build prerequisite is documented.** Moon runs the prebuild
  hooks of `gaato/discord` and `gaato/dave` with `node` on every `moon build`,
  so a bot that never uses voice still fails to build in an environment
  without Node.js. Only the voice guide said so; the README, the
  getting-started guide, and the template now list it with the other
  prerequisites.

## [0.3.1] - 2026-09-21

### Added

- **`arg_int32`: an integer option that decodes to `Int`.** `arg_int` yields
  `Int64`, and narrowing it with `to_int()` wraps silently when a command
  registers no bounds. `arg_int32` registers the `Int` range for a missing
  `min` or `max` and fails decoding with `ArgsDecodeError::Validation` for a
  received value outside the range, so counts and page numbers need no
  caller-side conversion.

### Fixed

- **Gateway jitter was identical in every shard and process.** `Shard::start`,
  `VoiceGateway`, and `VoiceConnection` defaulted `rand` to
  `@random.Rand::chacha8()`, whose default seed is a fixed constant, so the
  first-heartbeat jitter, reconnect backoff, and invalid-session wait replayed
  the same sequence everywhere. The default is now `@random.Rand::new()`,
  seeded from platform entropy. Pass `rand=` to keep a deterministic sequence.

## [0.3.0] - 2026-09-20

Boundary hardening: escape hatches, routing, and lifecycle side effects now
have explicit, checked contracts.

### Changed

- **Command synchronization is no longer configured on `App`.** `App` is
  declaration-only; `CommandSync` is renamed to `CommandScope` and loses
  `Disabled`. Migration: `App(sync=X)` + `Bot(app, token~)` becomes `App()` +
  `Bot(app, token~, sync=X)`; `App(sync=Disabled)` becomes `App()`. Omitting
  `sync` performs no command request. When set, it runs once per process after
  the first READY — enable it in exactly one process when sharding across
  processes.
- **`App::serve` and `serve_interactions` no longer take `sync`.** Registration
  is a deploy-time step. Migration: call
  `app.sync_commands(client, application_id, scope=...)` from a one-shot
  program (see `src/examples/workers_echo/register`) or before serving in a
  long-lived process; never per request.
- **Synchronization preserves commands it does not own.** Discord's Entry Point
  command (type 4, created automatically when Activities are enabled) is always
  re-sent in the bulk overwrite, with its id and unmodelled fields intact —
  omitting it makes Discord reject the whole request (error 50240). A PUT is
  sent only when something would be created, updated, or deleted.
  `App::sync_commands` returns `SyncReport`; `Framework::sync_global` /
  `sync_guild` now diff first and return `ScopeSyncReport`. Migration: inspect
  the report or discard it with `|> ignore`. `Bot` warns once per scope whose
  sync deleted commands.
- **Error policies follow the response gate's real state.** A `Raw` handler (or
  `ctx.raw()`) that responds and then fails, a failed initial send or defer,
  and middleware raising after `next()` now produce a followup instead of
  degrading to a warning. A callback Discord definitively rejects (4xx other
  than 429 / already-acknowledged) reopens the gate, so the policy's message is
  delivered as the initial response. Migration: replace `failure.phase()` with
  `failure.response_state()` and match on `@framework.ResponseState`.
- **HTTP interaction deadlines expire the gate.** A handler that responds after
  the endpoint gave up gets `ResponseGateError::Expired`; `respond_error` only
  warns in that state. A callback that already won the capture race is never
  dropped.
- **Components are routed by typed `ComponentRoute[A]`.** One route value
  produces the custom id (`route.custom_id(state)`) and registers the handler
  (`app.on_component(route, handler)`); `ComponentHandler[A]` handlers receive
  the decoded state as a second argument. A state that fails to decode reaches
  the error policy as `InvalidArgument`. Migration: define the route once and
  use it on both sides; `CustomIdCodec::string()` yields the old suffix.
- **Typed component and modal routes match the exact id or `id:state`.** A
  modal `feedback` no longer captures `feedbackish`. Migration: use
  `on_component_raw(prefix~)` / `on_modal_raw(prefix~)` for intentional
  literal-prefix routing. Longest effective prefix still wins.
- **`App::validate` checks routes**: empty routes, duplicate effective prefixes
  (previously the second handler was silently dead), and typed ids containing
  `:` or longer than 100 UTF-16 units are `AppConfigError`s.
- **`Modal::show` enforces the 100-unit custom id limit** and may raise
  `CustomIdError` in addition to `ModalPrefillError`.
- **Component waits are restricted to the invoking user by default.**
  `DeferredCtx::wait_for_component` and `ComponentDeferredCtx::wait_for_component`
  take `from? : WaitFrom = Invoker`. Another user's click no longer satisfies
  the wait; it falls through to registered routes. Migration: pass
  `from=Anyone` for polls and other shared waits. Executor-supplied
  `ComponentWaiter` closures take `(custom_id, user, timeout_ms)`.
- **Command checks are async**: `CommandCheck = async (CheckCtx) -> Bool`, so a
  check can consult REST or a database. Any error a check raises reaches the
  error policy unchanged. Checks run after middleware and before cooldown,
  argument decoding, and the handler, and spend the three-second
  initial-response budget. Migration: add `async` to explicitly typed check
  callbacks.
- **Cooldowns use an injectable store.** Windows live in a `CooldownStore`
  (default: a per-`App` `InMemoryCooldownStore`) keyed by command type, name,
  and bucket. Migration: none for in-process use; pass
  `App(cooldown_store=...)` to share windows across processes or to get real
  cooldowns on per-request runtimes such as Cloudflare Workers, where an
  in-memory store is rebuilt for every request.
- **The `gaato/discord` facade is cut to golden-path families** (169 → 113
  names). Migration: import the focused package for anything removed — see
  "Removed" below and the header of `src/facade.mbt`.
- **`request_timeout_ms` bounds one network attempt, not the whole request.**
  Rate-limit waits, 429 back-off, and HTTP middleware no longer count against
  it, so a request that only has to wait for its bucket (for example a third
  command sync within a minute: Discord allows two bulk overwrites per ~60 s)
  succeeds instead of failing with `Timeout`. A timed-out attempt is not
  retried, because it may have reached Discord. Migration: compose
  `@async.with_timeout` around calls that need an overall deadline.
- `@http.VERSION` now matches the module version.
- The `voice` and `coordinator` packages are marked experimental: their APIs
  may change in minor releases until declared stable.

### Fixed

- Command synchronization no longer re-sends every global command on each run
  for apps that support user installs. An omitted `integration_types` is filled
  in by Discord from the app's installation contexts (`[0, 1]` rather than
  `[0]`), which the diff used to read as a change. An undeclared
  `integration_types` now matches whatever Discord echoes; a declared one is
  still compared.

### Removed

- `CommandSync` (renamed `CommandScope`), `CommandSync::Disabled`, the `sync`
  parameter of `App::App`, `App::serve`, and `serve_interactions`.
- `@app.commands_in_sync`. Migration: `@framework.plan_command_sync` returns
  the payload it would send and a report.
- `ResponsePhase`, `FailureCtx::phase()`, and `AppDispatchError`. Handler errors
  reach the error policy unwrapped.
- The string-prefix `App::on_component(prefix~, ...)`,
  `ComponentImmediateCtx::suffix()`, and `ComponentDeferredCtx::suffix()`.
- From the facade: the REST `*Ref` handles and `Paginator` (`gaato/discord/http`);
  `Framework` and the raw interaction contexts used by `Raw` handlers
  (`gaato/discord/framework`); `Shard` / `ShardEvent` (`gaato/discord/gateway`);
  the coordinator types (`gaato/discord/coordinator`); `TelemetryEvent`
  (`gaato/discord/telemetry`); the raw `*_option` and `sub_command*` builders,
  `CommandSpec`, `CommandOptions`, `CommandModel`, `ArgsDecodeError`
  (`gaato/discord/interaction`); `Spawner`, `ComponentWaiter`,
  `RegisteredCommand`, `FailureRaw` (`gaato/discord/app`).

### Added

- `@framework.ResponseState` (`Pending`, `Sent(type)`, `Unconfirmed(type)`,
  `Expired`), `ResponseGate::state()` / `expire()`, a `rejected` classifier on
  `ResponseGate`, and `response_state()` on the command, component, and modal
  contexts and on `FailureCtx`.
- `ComponentRoute::decode(custom_id)` reads the state back from an id the route
  produced (for ids that arrive undecoded, such as a waiter's `ComponentCtx`,
  and for tests).
- `ComponentRoute`, `component_route`, `CustomIdCodec` (`unit`, `string`,
  `int`, `id`, `custom`, `zip`, `imap`, `encode`, `decode`), `CustomIdError`,
  `App::on_component_raw`, `Framework::component_id` / `modal_id`.
- `WaitFrom` and an optional `user` filter on `Framework::wait_for_component`
  and `GatewayCtx::wait_for_component`.
- `CheckCtx::app()` for REST-backed preconditions.
- Package `gaato/discord/cooldown`: `CooldownStore`, `CooldownDecision`,
  `InMemoryCooldownStore`. `@coordinator.RemoteCooldownStore` shares windows
  across processes over its own connection with a short deadline; it fails open
  by default (`when_unreachable=FailClosed` to deny instead), unlike
  `RemoteRateLimiter`, which stays fail-closed because 429 bans are a
  correctness concern.
- `UnownedCommands` (`Delete`, `Keep`) on `App::sync_commands`,
  `Framework::sync_*`, and `Bot(sync_unowned=...)`: `Keep` re-sends every
  undeclared remote command so other owners survive. `SyncReport`,
  `ScopeSyncReport`, the pure planner `@framework.plan_command_sync`,
  `@framework.sync_command_scope`, and `Client::get_global_commands_raw` /
  `get_guild_commands_raw`.
- Guide prose that states behaviour is now pinned by an adjacent compiled test.

## [0.2.0] - 2026-09-20

## [0.1.0] - 2026-08-30
