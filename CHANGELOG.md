# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Minor releases
(0.x → 0.y) may contain breaking changes; patch releases do not. Every
breaking change is listed with a migration note.

## [Unreleased]

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
- `remaining_ms()` on `ImmediateCtx`, `ComponentImmediateCtx`, and
  `ModalImmediateCtx`: the budget left to return the initial response.
- `DeferredCtx`, `ComponentDeferredCtx`, and `ModalDeferredCtx` share one
  message surface: `original()`, `edit_original`, `delete_original()`,
  `followup`, `get_followup`, `edit_followup`, and `delete_followup`.
  Managing a followup no longer requires dropping to `raw()`.
- Every message a library surface sends passes every field Discord accepts
  for that callback. `poll` is accepted by initial replies
  (`CommandReply::message`, `ComponentReply::message`,
  `InitialResponse::message`, and the raw `respond` and `reply`), by
  followups, and by `edit_original`. `keep_attachments` is accepted by
  `edit_original`. Component updates accept `clear_content`, `files`,
  `keep_attachments`, and `poll`.
- `ModalCtx::update_message` and `ModalCtx::defer_update` edit the message
  whose component opened the modal. A modal opened by a command has no such
  message, so both raise `ResponseGateError::InvalidCallback` without sending
  anything.

### Changed

- **Waiting handlers no longer deadlock the executor at `max_in_flight`.**
  Routing and component waiters now run outside the handler budget. Before,
  once `max_in_flight` handlers were all in `wait_for_component`, the button
  press that would wake one of them could not be routed. The Gateway
  dispatch loop also no longer waits for event-handler capacity: event
  middleware and handler fan-out run in their own task with a separate
  budget of the same size, so busy event handlers never delay interactions.
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
  handlers on its builder does not affect it. `App::validate` is gone.
  Migration: construct `AppBuilder(...)` where you constructed `App(...)`,
  and pass `app.build()` to the executor after every declaration is
  registered. A feature installer that also needs `Bot` for events splits
  into one function that takes the builder and one that takes the `Bot`; see
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
- `ComponentDeferredCtx::edit_original(files=...)` on a `DeferredUpdate`
  handler replaced the host message's attachments with no way to keep them;
  pass `keep_attachments` to retain the existing ones.

### Fixed

- A poll combined with Components V2 is rejected before sending on every
  message path. The check existed but no REST call passed the poll to it,
  so `create_message`, `create_followup`, `edit_original_response`, and
  `execute_webhook` sent bodies Discord rejects.

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
