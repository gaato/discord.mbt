# Changelog

All notable changes to `gaato/discord_voice` are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Minor
releases (0.x → 0.y) may contain breaking changes; patch releases do not.

## [Unreleased]

### Changed

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

### Fixed

- **Receive state no longer grows as users change SSRCs.** A `Speaking`
  message for a user now replaces the user's earlier SSRC, and an SSRC that
  passes to another user loses its reorder window, so the receive maps hold
  one entry per user in the channel. Before, each SSRC a user ever spoke on
  kept a mapping and a reorder buffer until the user disconnected.
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
