# Test coverage ledger

Line coverage of the library packages (`src/` minus `src/examples/`), measured
with `moon coverage analyze` in Coveralls-JSON mode. Companion to
[COVERAGE.md](COVERAGE.md), which tracks REST *endpoint* coverage; this file
tracks *test* coverage and applies the same closed-ledger rule:

> **Every uncovered line is either covered by a test or listed below with a
> reason.** `scripts/coverage_report.sh` enforces this: a file with uncovered
> lines must have a row here whose budget is at least the actual count, and
> the script fails otherwise. Rows for fully covered files are flagged as
> stale so budgets only ever shrink.

Run `scripts/coverage_report.sh` for the per-package table and the check
result. The script pins the measurement pitfalls discovered while building
this ledger: it cleans stale `moonbit_coverage_*` counters and release-profile
`.trace.source` maps before measuring (leftovers silently corrupt the merge),
uses the Coveralls JSON format because `-f summary` omits fully covered files,
sets `MOON_CC=cc` for hosts where moon's bundled tcc cannot link, requires
`gaato/dave`'s pinned libdave bootstrap with `MBT_DAVE_REQUIRE_NATIVE=1`, and
runs a native voice build before measurement. The require-native test fails
closed if libdave cannot be loaded; an inherited `MBT_DAVE_NATIVE_LIB`
override is rejected because it bypasses pinned-asset verification.
Separately, the script builds the in-tree Rust shim with
`cargo build --release --locked`, points `DISCORD_VOICE_SHIM_PATH` at that
artifact, and requires it to load so transport AEAD tests cannot skip.
`--from-json` only rechecks a stored report against the ledger; it does not
repeat either native bootstrap or runtime load check.

Snapshot at the last full measurement (2026-09-20, after the 0.3.0 boundary
hardening and the per-attempt HTTP timeout): **92.5 %** across the library
(8123/8784 coverage points; http 95.8 %, model 95.1 %, interaction 94.9 %,
bot 94.2 %, voice 85.7 %, gateway 75.7 %).

## Policy

Must be covered by tests:

- pure logic: codecs, projections, query/body assembly, parsers, state
  machines behind trait seams (fakes exist for gateway and voice transports);
- every `raise` arm reachable through the public API;
- wire boundaries via `perform_override_` wbtests (exact method/path/body),
  or a loopback `@ahttp.Server` where the real connection path itself is the
  subject (multipart request arms, the connection pool).

Accepted as uncovered (needs a ledger row):

- thin adapters over live sockets/websockets and extern/FFI glue — their
  behavior is exercised by the live probe sweeps recorded in COVERAGE.md
  (run 11: 242 PASS / 0 FAIL, 2026-07-16) and the live voice session checks
  (playback + recording, 2026-07-15);
- timed-wait loops without an injectable sleeper (ratelimit, queue,
  `with_typing`, shard_manager). The gateway shard, voice gateway, voice
  connection, and command limiter loops take `sleeper?`/`rand?` since
  2026-07-18 and their backoff/heartbeat/keepalive cadences are tested
  deterministically — their rows below now cover only defensive arms;
- defensive arms that are unreachable by construction (`abort`, fallbacks
  behind emitters that always produce the expected shape);
- error/cancellation plumbing deep inside async dispatch flows.

Budgets are exact uncovered counts at the last measurement; when a future
change covers lines, the script reports the row as slack/stale — tighten or
drop it.

## Accepted uncovered

Live socket, websocket, and FFI adapters (live-verified; no unit seam):

| File | Budget | Reason |
| --- | --- | --- |
| src/gateway/transport.mbt | 37 | Real websocket adapter behind the GatewayTransport trait; every consumer is tested against FakeTransport. |
| src/voice/transport.mbt | 38 | Real voice websocket adapter behind the VoiceTransport trait. |
| src/voice/udp.mbt | 4 | SocketVoiceUdp impls and `open_voice_udp` over a real UDP socket; parse and retry logic is covered via fakes. |
| src/voice/shim_ffi.mbt | 3 | Extern-C glue whose arms depend on host library state. |
| src/voice/crypto.mbt | 5 | Shim error-status translation paths; round-trips and geometry checks are covered with the shim loaded. |
| src/http/client.mbt | 3 | Connection teardown paths on live pools. |
| src/http/request.mbt | 21 | Cancellation/timeout plumbing on live connections; the JSON, body-less, 204, non-JSON-error, and all three multipart named-file arms are covered by the loopback server tests. |
| src/endpoint_http/endpoint_http.mbt | 15 | HTTP server error/cancellation arms (send failures, teardown); the request paths are covered by the signed-request e2e tests. |
| src/coordinator/protocol.mbt | 3 | Cross-process wire error arms. |
| src/coordinator/remote.mbt | 20 | Reconnecting remote clients against a real coordinator socket; for the cooldown store, the cancellation-during-connect arms and malformed-response arm (its outage, deadline, and gate-wait paths are covered). |
| src/coordinator/server.mbt | 12 | Per-connection cleanup on real disconnects (the existing socket test is retry-flaky; see project notes). |

Voice session state machine (transport and session flow verified live
2026-07-15 with the pre-libdave backend: ffmpeg streaming playback and a
72-second recording against real Discord voice; current official-libdave
single-member paths are native-tested, while multi-member paths remain
ledgered):

| File | Budget | Reason |
| --- | --- | --- |
| src/voice/connection.mbt | 17 | Impossible alternate negotiation errors, shim-loader failure while the shim is required, opener/discovery cancellation catches, event-pump and receiver queue teardown, an unemitted `ConnectFailed` case, and unreachable session-state/typed-error fallbacks. Negotiation, discovery, session, DAVE-control, source-replacement, receiver, and lifecycle-recovery failures are tested through the UDP/voice/DAVE seams. |
| src/voice/gateway.mbt | 13 | Protected-shutdown and event-queue teardown catches, stale-transport and non-returning-loop fallbacks, and read-loop cancellation propagation. Disconnected sends, malformed Hello/frames, the Hello sequence, send failures, and protected connector cleanup are tested; backoff and heartbeat cadence use the injected sleeper. |
| src/voice/dave.mbt | 52 | DAVE/MLS transitions that need a second member and real libdave group state. |
| src/voice/audio.mbt | 6 | Real-time pacing loop (deadline sleeps) and DAVE encrypt-drop telemetry arms. |
| src/voice/subscribe.mbt | 4 | Silence-timeout stream end arms. |
| src/voice/receive.mbt | 7 | Decrypt arms needing real DAVE frames from a second member. |
| src/voice/reorder.mbt | 3 | Arrival-time flush arms. |
| src/voice/rtp.mbt | 3 | Header arms only produced by real senders (CSRC counts). |
| src/voice/ogg_opus.mbt | 4 | Constructor `abort`s (unreachable by construction) and one reader break arm. |

Reconnect/backoff and timed-wait loops (exercised in every live gateway
run; the gateway/voice loops are additionally tested via injected sleepers):

| File | Budget | Reason |
| --- | --- | --- |
| src/gateway/shard.mbt | 16 | Protected-shutdown and event-queue teardown catches, stale-transport and normal-return fallbacks, read-loop cancellation re-raise plumbing (async 0.22 cancellation does not pass through ordinary catches), and two OS-specific Identify properties unavailable on Linux. Malformed Hello/frame, compression-mismatch, connector/backoff, and disconnected-send arms are tested through the fake transport. |
| src/gateway/compression.mbt | 3 | zlib failure statuses require a corrupted native stream state. |
| src/ratelimit/ratelimit.mbt | 2 | Global-window sleep and gate release-on-error paths. |
| src/http/handles_channel.mbt | 3 | `with_typing` refresh-failure arm sits behind the real 8-second cadence. |
| src/bot/middleware.mbt | 1 | Middleware chain cancellation arm. |
| src/bot/shard_manager.mbt | 6 | Multi-shard session-start-limit and staggered-identify paths over live gateways. |
| src/bot/bot.mbt | 19 | Gateway run-loop teardown/cancellation arms; startup, intents, telemetry, and event routing are covered. |
| src/bot/voice.mbt | 19 | Credential timeouts have no injectable timer; the endpoint fallback contradicts the collector predicate; disconnect/cancellation catches; and the new-join/rejoin closures cross `join_voice`'s unseamed live `VoiceConnection::start`. Cache, gate, collector, and failed-watcher-rejoin behaviour is tested. |

Defensive arms unreachable by construction:

| File | Budget | Reason |
| --- | --- | --- |
| src/http/multipart.mbt | 3 | `attachments_json` always returns an array and boundary search never gets an empty needle. |
| src/model/interaction.mbt | 4 | Fallbacks behind emitters that always produce objects. |
| src/model/component.mbt | 8 | Non-object fallback plus emit arms for component kinds Discord never sends in the covered contexts. |
| src/model/message.mbt | 3 | Timestamp-parse fallback for values the Timestamp decoder already rejects. |
| src/model/id.mbt | 1 | Phantom-id debug fallback. |
| src/model/command.mbt | 1 | Unknown handler-type emit arm. |
| src/util/cdn.mbt | 1 | Unreachable extension fallback. |

Receive-side model residuals (emit arms of receive-only structs and unknown
variant fallbacks; decode is pinned by fixtures):

| File | Budget | Reason |
| --- | --- | --- |
| src/model/application.mbt | 4 | Unknown-variant emit fallbacks. |
| src/model/auto_moderation.mbt | 9 | Emit arms of receive-only structs. |
| src/model/channel.mbt | 5 | Emit arms of receive-only fields. |
| src/model/command_permissions.mbt | 3 | Emit arms of receive-only structs. |
| src/model/embed.mbt | 13 | Emit arms of receive-only sub-objects (provider/video). |
| src/model/gateway_presence.mbt | 16 | Activity emit arms for fields bots never send. |
| src/model/guild_create.mbt | 2 | Emit arms of the gateway-only guild-create extras. |
| src/model/integration.mbt | 8 | Emit arms of receive-only integration fields. |
| src/model/integration_context.mbt | 2 | Unknown-variant emit fallbacks. |
| src/model/intents.mbt | 2 | Debug rendering arms. |
| src/model/invite.mbt | 8 | Emit arms of receive-only invite metadata. |
| src/model/monetization.mbt | 17 | Emit arms of receive-only entitlement/subscription fields. |
| src/model/role_connection_metadata.mbt | 2 | Unknown-variant emit fallbacks. |
| src/model/scheduled_event.mbt | 6 | Emit arms of receive-only recurrence fields. |
| src/model/webhook_event.mbt | 2 | Lossless raw emit arms for lobby payloads. |

Deep dispatch branches in the interaction stack (error/cancellation arms and
show-flows beyond the covered happy and failing paths):

| File | Budget | Reason |
| --- | --- | --- |
| src/app/app.mbt | 13 | Cancellation re-raise arms and per-kind failure plumbing beyond the covered component/modal policy flows. |
| src/app/check.mbt | 2 | Permission-check arms needing resolved member permissions in a guild payload. |
| src/app/command.mbt | 9 | Group/subcommand registration arms beyond the covered paths. |
| src/app/component.mbt | 13 | Deferred-ctx accessor duplicates and waiter arms behind a live gateway. |
| src/app/ctx.mbt | 4 | Waiter plumbing behind a live gateway. |
| src/app/endpoint.mbt | 7 | `serve` startup with an owned token/client (creates a real Client and fetches the application id). |
| src/app/middleware.mbt | 4 | Component-scope middleware arms not reachable in the covered flows. |
| src/app/modal.mbt | 20 | Show/prefill dispatch arms beyond the covered decode, validation, and error flows. |
| src/app/policy.mbt | 11 | Followup-with-files arms and member-user extraction beyond the covered flows. |
| src/framework/ctx.mbt | 14 | Autocomplete/modal response variants beyond the covered response-management flows. |
| src/framework/sync.mbt | 2 | Option-comparison early exits not hit by the covered spec shapes (moved from `src/app/sync.mbt`). |
| src/framework/framework.mbt | 9 | Dispatch fallbacks for unroutable interactions. |
| src/framework/gate.mbt | 1 | Double-response guard arms. |
| src/interaction/args.mbt | 8 | Suggest-handler closures that only run inside a live autocomplete dispatch. |
| src/interaction/options.mbt | 8 | Focused-option accessors for kinds not used by any covered command shape. |
| src/cache/cache.mbt | 17 | Permission-overwrite computation arms needing full guild channel fixtures. |
| src/http/api_application.mbt | 3 | Emit arms of optional request fields not exercised by the pinned shapes. |
| src/http/api_channel.mbt | 15 | Remaining optional-parameter emit arms. |
| src/http/api_guild.mbt | 4 | Remaining optional-parameter emit arms. |
| src/http/api_interaction.mbt | 3 | Callback-with-files arms needing a live token. |
| src/http/api_message.mbt | 5 | Remaining optional-parameter emit arms. |
| src/http/api_oauth2.mbt | 4 | Bearer-token flows (401-checked live only). |
| src/http/api_poll.mbt | 1 | One optional-parameter emit arm. |
| src/http/api_sticker.mbt | 3 | Global catalog delegations (get_sticker, sticker packs) without a guild anchor; ENV-LIMITED live. |
| src/http/api_voice.mbt | 4 | Remaining optional-parameter emit arms. |
| src/http/api_webhook.mbt | 2 | Remaining optional-parameter emit arms. |
| src/http/handles_guild.mbt | 1 | One delegation arm. |
| src/http/handles_member_user.mbt | 6 | Bearer-token delegations (401-checked live only). |
| src/http/handles_message.mbt | 4 | Delegations whose params only differ on live-only flags. |
| src/http/paginator.mbt | 3 | Defensive cursor arms not reachable through the wrapped endpoints. |
| src/http/route.mbt | 1 | One custom-route arm. |
