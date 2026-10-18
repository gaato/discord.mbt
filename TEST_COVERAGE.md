# Test coverage ledger

Line coverage of the library packages (`discord/src/` and `discord_voice/src/`), measured
with `moon coverage analyze` in Coveralls-JSON mode. Companion to
[COVERAGE.md](discord/COVERAGE.md), which tracks REST *endpoint* coverage; this file
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

Snapshot at the last full measurement (2026-10-18, after the robustness
work): **94.9 %** across the library (9617/10133 coverage points; http
97.8 %, bot 97.8 %, model 95.9 %, framework 95.5 %, interaction 95.1 %,
cache 93.7 %, app 93.0 %, endpoint_http 92.6 %, gateway 91.8 %,
coordinator 91.3 %, voice 87.7 %).

## Policy

Files compiled only on JavaScript or Wasm (`*.js.mbt`,
`*_unsupported.mbt`, and the JS files in `discord/src/internal/websocket`) are outside
the native measurement; `moon test --target js` and `--target wasm` cover them.

Must be covered by tests:

- pure logic: codecs, projections, query/body assembly, parsers, state
  machines behind trait seams (fakes exist for gateway and voice transports);
- every `raise` arm reachable through the public API;
- wire boundaries via `Client::offline` handlers (route and body) or a
  scripted `@ghttp.Transport` wbtest (`wire_test_client`: exact wire request,
  retries, limiter pairing, telemetry), or a loopback `@ahttp.Server` where
  the real connection path itself is the subject (multipart request arms).

Accepted as uncovered (needs a ledger row):

- thin adapters over live sockets/websockets and extern/FFI glue — their
  behavior is exercised by the live probe sweeps recorded in COVERAGE.md
  (run 11: 242 PASS / 0 FAIL, 2026-07-16) and the live voice session checks
  (playback + recording, 2026-07-15);
- timed-wait loops without an injectable clock (`with_typing`,
  shard_manager). The gateway shard, command limiter, and identify queue
  take a `clock~`, and the voice gateway, voice connection, and voice client
  a `clock?` (a
  `gaato/http/clock` `Clock`, driven in tests by `gaato/http-async/mock`'s
  `VirtualClock`; `scripts/clock_guard.mbtx` keeps library code off the real
  clock), plus `rand?`; their backoff/heartbeat/keepalive
  cadences, and for voice also playback pacing, receive backoff and
  reordering, ready and silence timeouts, are tested deterministically —
  their rows below now cover only defensive arms;
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
| discord/src/gateway/transport.mbt | 8 | Error arms of the real WebSocket adapter: cancellation re-raises, receive and read failures other than a close, a failing 1009 close, invalid UTF-8 text, and `send`. A loopback test covers receiving, the size limit, the peer's close code, and closing twice. |
| discord_voice/src/transport.mbt | 20 | Error arms of the real voice WebSocket adapter (cancellation re-raises, failures other than a close, a failing 1009 close, invalid UTF-8), `send_text`/`send_binary`, and the close-code mapping arms other than an application code. Loopback tests cover receiving, the size limit, the peer's close code, and closing twice. |
| discord_voice/src/udp.mbt | 4 | SocketVoiceUdp impls and `open_voice_udp` over a real UDP socket; parse and retry logic is covered via fakes. |
| discord_voice/src/shim_ffi.mbt | 3 | Extern-C glue whose arms depend on host library state. |
| discord_voice/src/crypto.mbt | 5 | Shim error-status translation paths; round-trips and geometry checks are covered with the shim loaded. |
| discord/src/http/attempt_deadline.mbt | 1 | The arm for a failure of `with_timeout_opt` itself, which neither the wall clock nor a virtual one raises; expiry, pass-through failures, and both methods are covered on virtual time. |
| discord/src/http/client.mbt | 2 | Default warning sinks (`println`) of the online and offline constructors. |
| discord/src/http/request.mbt | 1 | The `Api` re-raise for middleware that raises it itself; the send loop, its retry rule, request validation, and every error mapping are covered by table and fake-wire contract tests. |
| discord/src/endpoint_http/endpoint_http.mbt | 6 | Arms that need a broken connection or a cancellation mid-failure: a response write that fails because the peer is gone, cancellation of a failed request or write, and a server that stops after startup. Startup failure, 202/504 replies, and a request whose body fails mid-read are tested. |
| discord/src/internal/fuzz/schedule.mbt | 3 | The shrinker's cancellation re-raise arms around the first run, the shrinking runs, and the final re-run: async 0.22 cancellation does not pass through ordinary catches, so they only catch an error raised while being cancelled; a test cancels each stage. |
| discord/src/internal/gatewaysim/fake_transport.mbt | 2 | The test fake's flags recording a close during a send or receive, which a correct shard never triggers; tests assert they stay false. |
| discord/src/coordinator/remote.mbt | 17 | Reconnecting remote clients against a real coordinator socket; for the cooldown store, the cancellation-during-connect arms (its outage, deadline, gate-wait, and malformed-response paths are covered); the cancellation arm of the ping watchdog, which runs only when a request completes while its ping is in flight. |
| discord/src/coordinator/server.mbt | 6 | Config validation arms, and per-connection cleanup on real disconnects (the existing socket test is retry-flaky; see project notes). |

Voice session state machine (transport and session flow verified live
2026-07-15 with the pre-libdave backend: ffmpeg streaming playback and a
72-second recording against real Discord voice; current official-libdave
single-member paths are native-tested, while multi-member paths remain
ledgered):

| File | Budget | Reason |
| --- | --- | --- |
| discord_voice/src/connection.mbt | 16 | Impossible alternate negotiation errors, shim-loader failure while the shim is required, opener/discovery cancellation catches, the cancellation catches of `while_open` and of the wait for a new voice server, event-pump and receiver queue teardown, an unemitted `ConnectFailed` case, and unreachable session-state/typed-error fallbacks. Negotiation, discovery, session, DAVE-control, source-replacement, receiver, and lifecycle-recovery failures are tested through the UDP/voice/DAVE seams. |
| discord_voice/src/gateway.mbt | 8 | Protected-shutdown and event-queue teardown catches, stale-transport and non-returning-loop fallbacks, and read-loop cancellation propagation. Disconnected sends, malformed Hello/frames, the Hello sequence, send failures, and protected connector cleanup are tested; backoff, heartbeat, and ACK-latency timing run on a `VirtualClock`. |
| discord_voice/src/dave.mbt | 52 | DAVE/MLS transitions that need a second member and real libdave group state. |
| discord_voice/src/audio.mbt | 5 | `DaveUnavailable`/`DaveInternal` encrypt-drop telemetry arms, and the DAVE-less frame arm that only direct `run_send_loop` callers reach (a connection holds a machine once its session is up). Frame and silence pacing, stop, and `DaveInvalid` drops are tested on a `VirtualClock`. |
| discord_voice/src/subscribe.mbt | 2 | Re-raise arms of the timed and untimed reads for a queue error other than closure, which the stream never raises. Silence end, close during either read, and disconnect are tested. |
| discord_voice/src/client.mbt | 19 | `from_gateway`, `pending_voice_event`, and `join` adapt a `GatewayCtx`, which only a running bot creates, and the service `attach` registers runs only in one; the rejoin closure runs only on a close that needs a fresh main-gateway handshake; the endpoint fallback contradicts the server predicate, and an untimed wait never returns `None`; disconnect and cancellation catches. Joins, reuse, eviction, gates, expectations before opcode 4, timeouts, a client that never runs, server moves and losses, channel moves, and the watches' lifetime are tested through a fake `VoiceGatewayPort` and transport. |
| discord_voice/src/receive.mbt | 5 | Decrypt arms needing real DAVE frames from a second member. |
| discord_voice/src/reorder.mbt | 3 | Arrival-time flush arms. |
| discord_voice/src/ogg_opus.mbt | 4 | Constructor `abort`s (unreachable by construction) and one reader break arm. |

Reconnect/backoff and timed-wait loops (exercised in every live gateway
run; the gateway and voice loops are additionally tested on injected clocks):

| File | Budget | Reason |
| --- | --- | --- |
| discord/src/gateway/shard.mbt | 15 | Protected-shutdown and event-queue teardown catches (including the shared fatal close before connecting, reached by a failing inflater factory or a size limit below 1), stale-transport and normal-return fallbacks, and read-loop cancellation re-raise plumbing (async 0.22 cancellation does not pass through ordinary catches). Malformed Hello/frame, compression-mismatch, connector/backoff, the default connector, and disconnected-send arms are tested. |
| discord/src/gateway/platform_native.mbt | 2 | Two OS-specific Identify property arms unavailable on Linux. |
| discord/src/http/handles_channel.mbt | 3 | `with_typing` refresh-failure arm sits behind the real 8-second cadence. |
| discord/src/bot/middleware.mbt | 1 | Middleware chain cancellation arm. |
| discord/src/bot/shard_manager.mbt | 1 | Live gateway discovery's invalid-info arm; fake-connector startup and resume are tested. |
| discord/src/bot/bot.mbt | 17 | Gateway run-loop teardown/cancellation arms; startup, intents, telemetry, and event routing are covered. The event-backlog put fails only on a queue closed by shutdown, and the `ShardEvent::..` arm that `#non_exhaustive` requires outside `@gateway` matches no current event. |

Defensive arms unreachable by construction:

| File | Budget | Reason |
| --- | --- | --- |
| discord/src/util/cdn.mbt | 1 | The `StickerFormatType::..` arm that `#non_exhaustive` requires outside `@model`; every current format is matched by name. |
| discord/src/bot/session.mbt | 1 | Abort if an already decoded READY fails its own JSON round trip; snapshot independence and serialization are tested. |
| discord/src/http/multipart.mbt | 2 | `attachments_json` always returns an array, and encoder errors other than a boundary collision, which `validate_files` rules out before encoding. |
| discord/src/model/interaction.mbt | 4 | Fallbacks behind emitters that always produce objects. |
| discord/src/model/component.mbt | 8 | Non-object fallback plus emit arms for component kinds Discord never sends in the covered contexts. |
| discord/src/model/message.mbt | 3 | Timestamp-parse fallback for values the Timestamp decoder already rejects. |
| discord/src/model/id.mbt | 1 | Phantom-id debug fallback. |
| discord/src/model/command.mbt | 1 | Unknown handler-type emit arm. |

Receive-side model residuals (emit arms of receive-only structs and unknown
variant fallbacks; decode is pinned by fixtures):

| File | Budget | Reason |
| --- | --- | --- |
| discord/src/model/application.mbt | 4 | Unknown-variant emit fallbacks. |
| discord/src/model/auto_moderation.mbt | 9 | Emit arms of receive-only structs. |
| discord/src/model/channel.mbt | 5 | Emit arms of receive-only fields. |
| discord/src/model/command_permissions.mbt | 3 | Emit arms of receive-only structs. |
| discord/src/model/embed.mbt | 13 | Emit arms of receive-only sub-objects (provider/video). |
| discord/src/model/gateway_presence.mbt | 9 | Activity emit arms for fields bots never send. |
| discord/src/model/guild_create.mbt | 2 | Emit arms of the gateway-only guild-create extras. |
| discord/src/model/integration.mbt | 8 | Emit arms of receive-only integration fields. |
| discord/src/model/integration_context.mbt | 2 | Unknown-variant emit fallbacks. |
| discord/src/model/intents.mbt | 2 | Debug rendering arms. |
| discord/src/model/invite.mbt | 8 | Emit arms of receive-only invite metadata. |
| discord/src/model/monetization.mbt | 17 | Emit arms of receive-only entitlement/subscription fields. |
| discord/src/model/role_connection_metadata.mbt | 2 | Unknown-variant emit fallbacks. |
| discord/src/model/scheduled_event.mbt | 6 | Emit arms of receive-only recurrence fields. |
| discord/src/model/webhook_event.mbt | 2 | Lossless raw emit arms for lobby payloads. |

Deep dispatch branches in the interaction stack (error/cancellation arms and
show-flows beyond the covered happy and failing paths):

| File | Budget | Reason |
| --- | --- | --- |
| discord/src/app/app.mbt | 7 | Cancellation re-raise arms of the per-kind failure handlers and of the framework error hook, and the no-op busy handlers of autocomplete routes, which never defer and so are never refused. |
| discord/src/app/check.mbt | 2 | Permission-check arms needing resolved member permissions in a guild payload. |
| discord/src/app/command.mbt | 9 | Group/subcommand registration arms beyond the covered paths. |
| discord/src/app/admission.mbt | 11 | Acknowledgement-plan arms for kinds that never carry that plan, the autocomplete gate stubs, the cancellation re-raise, the pending-count cleanup that only runs when a waiting deferred route is cancelled, and the watchdog's failed-defer warning (the defer itself is covered). |
| discord/src/app/component.mbt | 10 | Deferred-ctx accessor duplicates and waiter arms behind a live gateway. |
| discord/src/app/ctx.mbt | 4 | Waiter plumbing behind a live gateway. |
| discord/src/app/endpoint.mbt | 6 | Closing an owned client when the startup application lookup fails (needs a real token and network), the endpoint's cancellation re-raise and processing-failure warning, and outcome arms the covered flows do not reach. |
| discord/src/app/middleware.mbt | 4 | Component-scope middleware arms not reachable in the covered flows. |
| discord/src/app/modal.mbt | 16 | Show/prefill dispatch arms beyond the covered decode, validation, and error flows. |
| discord/src/app/policy.mbt | 2 | Member-without-user extraction and the policy cancellation re-raise. |
| discord/src/framework/ctx.mbt | 5 | Autocomplete response variants and nested-component lookup arms beyond the covered flows. `AutocompleteCtx::token_remaining_ms` (autocomplete answers within the callback window; the accessor is covered on the other contexts). |
| discord/src/framework/responder.mbt | 3 | `reply`'s cancellation re-raise, the re-raise of an edit failure on a confirmed deferral, and the followup fallback after an unconfirmed deferral's edit fails (verified live with `gate_probe`, 2026-09-28). |
| discord/src/framework/sync.mbt | 1 | Option-comparison early exit not hit by the covered spec shapes (moved from `src/app/sync.mbt`). |
| discord/src/framework/framework.mbt | 9 | Dispatch fallbacks for unroutable interactions. |
| discord/src/framework/gate.mbt | 2 | The callback rule for an unknown interaction type and the cancellation re-raise during delivery. |
| discord/src/interaction/args.mbt | 8 | Suggest-handler closures that only run inside a live autocomplete dispatch. |
| discord/src/interaction/options.mbt | 8 | Focused-option accessors for kinds not used by any covered command shape. |
| discord/src/cache/cache.mbt | 14 | Defensive arms (10): payloads without a guild id for presences and voice states, an unavailable `GUILD_CREATE`, role events with roles off, a READY marking a guild available, unhandled events, and `permissions_in` guards; and the eviction callbacks of reads (4), which run only when time passes between a read's sweep of expired owners and its lookup. |
| discord/src/http/api_application.mbt | 2 | Emit arms of optional request fields not exercised by the pinned shapes. |
| discord/src/http/api_guild.mbt | 4 | Remaining optional-parameter emit arms. |
| discord/src/http/api_interaction.mbt | 3 | Callback-with-files arms needing a live token. |
| discord/src/http/api_message.mbt | 3 | Remaining optional-parameter emit arms. |
| discord/src/http/api_oauth2.mbt | 4 | Bearer-token flows (401-checked live only). |
| discord/src/http/api_poll.mbt | 1 | One optional-parameter emit arm. |
| discord/src/http/api_sticker.mbt | 3 | Global catalog delegations (get_sticker, sticker packs) without a guild anchor; ENV-LIMITED live. |
| discord/src/http/api_voice.mbt | 4 | Remaining optional-parameter emit arms. |
| discord/src/http/api_webhook.mbt | 2 | Remaining optional-parameter emit arms. |
| discord/src/http/handles_guild.mbt | 1 | One delegation arm. |
| discord/src/http/handles_member_user.mbt | 6 | Bearer-token delegations (401-checked live only). |
| discord/src/http/handles_message.mbt | 4 | Delegations whose params only differ on live-only flags. |
| discord/src/http/paginator.mbt | 3 | Defensive cursor arms not reachable through the wrapped endpoints. |
| discord/src/http/route.mbt | 1 | One custom-route arm. |
