# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Minor releases
(0.x → 0.y) may contain breaking changes; patch releases do not. Every
breaking change is listed with a migration note.

## [Unreleased]

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
