# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). The project is
pre-1.0: minor releases may contain breaking changes, and every breaking
change is listed with a migration note.

## [Unreleased]

### Fixed

- **Gateway jitter was identical in every shard and process.** `Shard::start`,
  `VoiceGateway`, and `VoiceConnection` defaulted `rand` to
  `@random.Rand::chacha8()`, whose default seed is a fixed constant, so the
  first-heartbeat jitter, reconnect backoff, and invalid-session wait replayed
  the same sequence everywhere. The default is now `@random.Rand::new()`,
  seeded from platform entropy. Pass `rand=` to keep a deterministic sequence.

## [0.3.0] - 2026-09-20

Boundary hardening before 1.0: escape hatches, routing, and lifecycle side
effects now have explicit, checked contracts.

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
