# Changelog

All notable changes to `gaato/discord_voice` are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Minor
releases (0.x → 0.y) may contain breaking changes; patch releases do not.

## [Unreleased]

### Changed

- **Depends on `gaato/http` 0.3.0 and `gaato/http-async` 0.3.1.** The
  wall clock behind the `clock?` defaults and the clock-driven timeouts now
  come from `gaato/http-async`'s `AsyncClock` and `with_timeout_opt` instead
  of a private copy. Migration: a project that also lists either module in
  its `moon.mod` must move it to the same version.
- **`VoiceConnection::start` and `VoiceGateway::start` take a `clock~`
  instead of a `sleeper~`.** The clock (`gaato/http/clock`'s `Clock`, the
  trait `gaato/discord`'s `Shard::start` takes) supplies both the current time
  and the waits, so a test can drive the heartbeat, reconnect backoff, UDP
  keepalives, and receive backoff, and now also the heartbeat latency,
  playback pacing, receive reordering, the `wait_ready` timeout, and
  subscription silence, on virtual time; before, those read the wall clock
  and the event loop's timers even when the sleeper was replaced.
  `run_send_loop` takes the same `clock?`. A clock's sleep
  cannot fail, so a sleeper that raised to stop the reconnect, keepalive, or
  receive loop has no equivalent: disconnect instead.
  Migration: drop `sleeper=` or pass `clock=` with your own `Clock`.

### Added

- **`VoiceClient` takes a `clock?`.** It times `join`'s wait for `run` and
  every connection the client starts, and voice IP discovery's receive
  timeouts now run on the connection's clock. Before, both read the event
  loop's timers even when the connection had been given a virtual clock.

### Fixed

- **A received frame that arrives as the trailing silence elapses is
  delivered.** `VoiceReceiveStream::next_packet` with `end_after_silence_ms`
  dropped a frame that reached the stream in the same scheduler step as the
  silence timer and ended the stream; it now returns the frame and keeps the
  stream open. Silence with no frame still ends it.

- **A voice connection stays closed once `disconnect` begins.** While
  `disconnect` was still sending the leave to the main gateway, a voice event
  could still be handled: a resume set the state back to `Ready` (so
  `wait_ready` succeeded on a closing connection), and a 4006 or 4014 close
  rejoined the channel after the leave. Events that arrive once teardown has
  begun are now ignored, a session that finishes establishing during it is
  not installed, and the state never leaves `Closed`.

- **A voice server move keeps the connection, and nothing waits for one after
  the connection ends.** A `VOICE_SERVER_UPDATE` for a joined guild now makes
  the same `VoiceConnection` identify on the new server with its session,
  through the new `next_server` argument of `VoiceConnection::start` (it
  returns a `VoiceServer`, the update's token and endpoint). Before,
  `VoiceClient` ran a watcher per join that disconnected the connection,
  making the bot leave the channel, and joined again with a new handle; and
  when the connection ended first, the watcher, its expectation on the main
  gateway, and the closed connection stayed until the guild's next server
  update, possibly forever, with a rejoin adding another. The watch is now a
  task of the connection and ends, unregistering its expectation, when the
  connection closes. Migration: code that re-fetched
  `VoiceClient::connection` after a region move can keep its handle; callers
  of `VoiceConnection::start` that see server updates pass `next_server`.
- **A voice server that went away is dropped, not resumed against.** A
  `VOICE_SERVER_UPDATE` with a null endpoint now closes the voice WebSocket
  and leaves the connection `Reconnecting` until the next update names a
  server, as Discord documents; if none comes within `server_timeout_ms` (the
  join's `timeout_ms` for `VoiceClient`), the connection rejoins. Before, the
  update was ignored and the gateway kept resuming against the old server.
  `VoiceServer::endpoint` is a `String?` for this.
- **A channel move made outside this API reaches DAVE and the rejoin.** The
  connection follows the bot's own `VOICE_STATE_UPDATE` through the new
  `next_channel` argument of `VoiceConnection::start`, and the new
  `VoiceConnection::channel_id` reports it; a new DAVE session and a rejoin
  use that channel. Before, both kept the channel of the original join, so a
  bot dragged to another channel built its DAVE group for the old one and a
  rejoin took it back.
- **No connection task outlives its connection.** The receiver, the UDP
  keepalive, and playback are cancelled when the connection closes; before,
  the keepalive held it until its next 5-second tick and playback until its
  source returned a frame, forever for a live source with nothing to send.
- **`VoiceConnection::disconnect` returns once the teardown is done**, also
  when the connection started it after a fatal close, and `VoiceClient::join`
  waits for that before joining the guild again. Before, it returned at once
  in that case, and the old connection's leave (opcode 4 without a channel)
  could go out after the new join and take the bot out of the channel.
- **Receive state no longer grows as users change SSRCs.** A `Speaking`
  message for a user now replaces the user's earlier SSRC, and an SSRC that
  passes to another user loses its reorder window, so the receive maps hold
  one entry per user in the channel. Before, each SSRC a user ever spoke on
  kept a mapping and a reorder buffer until the user disconnected.
- **A voice gateway message is limited to 4 MiB.** A larger one ends the
  connection with 1009 and the connection resumes; before, any message was
  read whole into memory.
- **Join gates and the roster no longer outlive their use.** The last join for
  a guild, finished or failed, removes its gate, and a new session starts with
  an empty roster; before, every guild ever joined kept a gate, and a user
  whose disconnect was lost with an old session stayed in the roster and was
  handed to each new DAVE session.
- **`OggPacketReader` keeps only the unparsed tail of its input**, so a long
  stream no longer stays in memory whole when pages do not end on a read
  boundary, and one packet is limited to 16 MiB (`InvalidOggPage`).
- **DAVE keeps at most 16 prepared transitions.** Preparing another forgets
  the oldest; before, a transition the gateway never executed stayed for the
  rest of the session.

## [0.2.0] - 2026-10-17

### Changed

- **Builds against `gaato/discord` 0.9.0**, whose breaking changes are listed
  in [its changelog](https://github.com/gaato/discord.mbt/blob/main/discord/CHANGELOG.md).
  Migration: depend on `gaato/discord@0.9.0` alongside this release.
- The wire-protocol layer is hidden from the generated documentation and the
  package interface with `#doc(hidden)`: the `encode_*` / `parse_*` /
  `build_*` helpers, the socket openers, `run_send_loop`, `VoiceGateway`,
  `DaveMachine`, `TransportCipher`, `RtpPacket`, `ReorderBuffer`,
  `OggPacketReader`, and their error types, including `DaveError`. They
  remain callable; the documented surface is `VoiceClient`,
  `VoiceConnection`, audio sources, and the events they deliver.

## [0.1.0] - 2026-10-16

First release, split from the `gaato/discord/voice` package of
`gaato/discord`; its earlier history is in
[gaato/discord's changelog](https://github.com/gaato/discord.mbt/blob/main/discord/CHANGELOG.md).
The entries below are relative to that package in `gaato/discord` 0.7.0.

### Added

- `VoiceClient` replaces `GatewayCtx::join_voice`. It holds a bot's voice
  connections, one per guild, and runs them in its own task group: create one
  per bot, `attach` it to the `BotBuilder` (it runs as the bot service
  `"voice"`), and call `join(ctx, guild_id, channel_id, ...)`, which takes the
  labels `join_voice` took. `connection(guild_id)` returns the held
  connection. Opcode 4 goes to the shard that owns the guild; `join_voice`
  used the calling context's shard, so a join started from a service for a
  guild on another shard went out on the wrong connection and timed out.
- `VoiceGatewayPort` is what a join needs from the main gateway, as values and
  functions; `VoiceGatewayPort::from_gateway(ctx)` builds it from a
  `GatewayCtx`, and `join_via(port, ...)` joins through any port, so a join
  can be tested without a gateway.
- `VoiceError::ClientNotRunning` reports a join while the client's service is
  not running.
- `VoiceReceiveStream::next_packet` yields `ReceivedAudio` values in RTP
  sequence order: `Opus(sequence~, timestamp~, opus~)` for a frame and
  `Lost(count~)` for frames that never arrived or that the stream dropped.
- `VoiceConnection::subscribe` takes `backlog~` (default
  `DEFAULT_RECEIVE_BACKLOG` = 250 frames, five seconds) and
  `VoiceConnection::start` takes `event_backlog~` (default
  `DEFAULT_VOICE_EVENT_BACKLOG` = 256). A receive backlog below 2 (after a
  drop, a delivery needs a slot for the `Lost` marker and one for its frame)
  or an event backlog below 1 raises the new `VoiceError::InvalidBacklog`.
- `VoiceTelemetry::ReceiveDropped(user_id~, backlog~)` and
  `VoiceTelemetry::EventDropped(backlog~)` report each item a full backlog
  discards.

### Changed

- **`VoiceMessage`, `EncryptionMode`, `VoiceEvent`, `VoiceTelemetry`,
  `VoiceGatewayEvent` and `DaveAction` are `#non_exhaustive`**, so a later
  release can add a voice opcode, encryption mode or event without breaking
  matches in your code.
  - Migration: a `match` outside this module that lists every constructor of
    one of these enums needs a last arm `Type::..`, for example
    `@voice.VoiceEvent::.. => ()`. A `_` or binding arm after every
    constructor is reported as unused: replace it with `Type::..`. A `match`
    whose `_` or binding arm still covers some constructors needs no change.
- **Received voice audio is delivered only through `subscribe`, and every
  voice queue is bounded.** Before, each received packet was queued for
  `next_event` with no limit, also when the caller only subscribed or never
  read events at all (`join_voice` received by default), so a connection with
  someone speaking grew without bound. Now `next_event` carries membership,
  speaking, and lifecycle events only, and drops its oldest event past
  `event_backlog`. Packets from users without a live subscription are
  discarded before decryption, so receiving costs nothing until something
  subscribes. A subscription drops new frames past its backlog and reports
  them in the stream as one `Lost`, so the reader always sees where audio is
  missing.
  - Migration: remove `OpusReceived` and `PacketsLost` arms from
    `next_event` loops. Subscribe to the user instead, typically on
    `SpeakingChanged`, and read `next_packet()`: `Opus(sequence~,
    timestamp~, opus~)` replaces `OpusReceived`, and `Lost(count~)` replaces
    `PacketsLost`. Packets from an SSRC Discord never mapped to a user are no
    longer surfaced. `subscribe` and `VoiceConnection::start` now raise
    `VoiceError`.
- `TransportCipher::seal` raises the new `VoiceCryptoError::NonceExhausted`
  after 2^32 packets instead of wrapping its nonce counter and reusing a
  nonce under the same key. A new voice session issues a new key.
- The voice gateway resets its reconnect backoff once a session is active, so
  a single drop after a long healthy run waits the first backoff step instead
  of the cap reached by earlier failures.
- The native prebuild hook recognises a Moon run by `MOON_BACKEND`, which Moon
  sets for prebuild scripts since toolchain 0.10.14, instead of by the JSON
  payload on stdin, which Moon is going to stop sending. Without that change a
  Moon release that drops stdin would have made the hook download the voice
  runtime for every native build. Run directly (`node build.js`), the hook no
  longer waits for end of input.
