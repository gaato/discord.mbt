# Voice support design spike (voice gateway v8 + DAVE)

Status: **design accepted, implementation not started.**
This document is the entry point for implementing voice. It records the
protocol facts (verified against the official documentation on 2026-07-15),
the architecture decision, and the milestone plan. Nothing here is code yet —
shipping a half-working voice stack was rejected in favor of landing the rest
of the roadmap first.

## Why voice is different now

Since **March 1st, 2026**, Discord only supports end-to-end encrypted audio
calls. A voice implementation therefore cannot start with the classic
"UDP + xsalsa20" design that most libraries grew from:

- The voice gateway must be **version 8** (`?v=8`): heartbeats carry
  `seq_ack`, and missed WebSocket messages are re-delivered on resume
  ("buffered resume").
- The client must negotiate the **DAVE protocol** (Discord Audio & Video
  End-to-End Encryption): an MLS (RFC 9420) group per call derives per-sender
  ratcheted media keys; several DAVE opcodes are **binary** WebSocket
  messages, not JSON.
- Transport encryption modes are now `aead_aes256_gcm_rtpsize` (preferred)
  and `aead_xchacha20_poly1305_rtpsize` (required fallback); the historical
  `xsalsa20_poly1305*` modes are being discontinued.

References: `topics/voice-connections` (official docs),
https://daveprotocol.com (protocol whitepaper),
https://github.com/discord/libdave (reference implementation).

## Protocol flow (verified)

1. **Session request** — send gateway (not voice) Opcode 4 Voice State
   Update `{guild_id, channel_id, self_mute, self_deaf}`; wait for **both**
   `VOICE_STATE_UPDATE` (yields `session_id`) and `VOICE_SERVER_UPDATE`
   (yields `token`, `endpoint`). Never cache the endpoint. Note the
   user-limit caveat: a full channel produces no response events without
   `MOVE_MEMBERS`.
2. **Voice WebSocket** — connect `wss://<endpoint>?v=8`. Send voice Opcode 0
   Identify `{server_id, user_id, session_id, token,
   max_dave_protocol_version: 1}`. `max_dave_protocol_version: 0` / absent
   means "no DAVE support" and is not viable after 2026-03-01.
3. **Ready (op 2)** — provides `ssrc`, UDP `ip`/`port`, supported `modes`.
   (Its `heartbeat_interval` field is documented as erroneous — ignore it;
   the real interval arrives in op 8 Hello.)
4. **Heartbeat** — op 3 every `heartbeat_interval` ms with
   `{t: <nonce>, seq_ack: <last numbered message>}` (v8 shape); op 6 ACK
   echoes the nonce. Same zombie detection approach as the main gateway.
5. **UDP + IP discovery** — open UDP to `ip:port`; run IP discovery
   (74-byte packet: type 0x1 request / 0x2 response, ssrc, address, port) if
   NAT traversal requires it.
6. **Select Protocol (op 1)** — `{protocol: "udp", data: {address, port,
   mode}}` with the discovered external address and the chosen transport
   mode.
7. **Session Description (op 4)** — carries `secret_key` (transport key) and
   `dave_protocol_version` selected by the server (lowest shared version in
   the call).
8. **DAVE handshake** — MLS group establishment via binary opcodes
   (key package op 26, proposals op 27, commit/welcome ops 28–30, epoch
   preparation op 24, transition ready op 23 / execute op 22, downgrade
   announcements op 21). Per-sender media keys are derived from the MLS
   epoch secret and ratcheted.
9. **Media** — op 5 Speaking (bitmask since v4) before sending; RTP packets
   (`rtpsize` framing) encrypted twice: E2EE frame encryption with the DAVE
   sender key, then transport encryption with `secret_key`.
10. **Resume** — voice op 7 Resume includes `seq_ack`; v8 servers replay
    buffered messages missed during the disconnect.

## Architecture decision

New native-only package `src/voice/`, mirroring the proven structure of
`src/gateway/`:

| Layer | Contents | Test seam |
|---|---|---|
| `VoiceGateway` | v8 state machine: identify/ready/hello/heartbeat(seq_ack)/resume, JSON + binary opcode envelope | same fake-transport trait pattern as `gateway/transport.mbt` |
| `VoiceUdp` | UDP socket, IP discovery, RTP `rtpsize` packetization | pure packet builders unit-tested against known vectors |
| transport crypto | `aead_aes256_gcm_rtpsize`, `aead_xchacha20_poly1305_rtpsize` | round-trip tests via runtime-loaded OpenSSL (`libcrypto`) |
| `Dave` | MLS session, key ratchets, frame E2EE | C shim over **libdave**, loaded at runtime |
| audio API | `AudioSource` trait producing 20 ms **Opus** frames; passthrough first (accept pre-encoded Opus), libopus FFI as an optional later layer | frame-level unit tests |

Cross-cutting decisions, consistent with the rest of the library:

- **No link-time system dependencies.** OpenSSL's `libcrypto` and the libdave
  shim are `dlopen`ed at runtime, exactly like `moonbitlang/async` loads
  OpenSSL and like `src/gateway/zlib_stream.c` loads zlib. Voice being
  unavailable (missing shim) must fail loudly at `connect`, never at build
  time of downstream projects.
- **libdave over homegrown MLS.** Reimplementing MLS + the DAVE framing from
  the whitepaper is a cryptographic liability. libdave is C++; the plan is a
  small C shim (`extern "C"` wrapper exposing session create/destroy, key
  package generation, proposal/commit/welcome processing, frame
  encrypt/decrypt) built as a shared library in a separate repository or a
  `voice-shim/` subdirectory with its own build. Distribution story (prebuilt
  binaries vs. build instructions) is an open question below.
- **Values over traits** for the public API (project style): a
  `VoiceConnection` handle obtained via
  `ctx.join_voice(guild_id, channel_id, source~)`, with structured
  concurrency owning its tasks.

## Milestones

1. **M1 — voice gateway state machine** (no network, no crypto): typed
   opcode envelope (JSON + binary discrimination), identify/hello/heartbeat/
   ready/session-description/resume flow against a fake transport, seq_ack
   bookkeeping. Reuses gateway test patterns; fully offline-testable.
2. **M2 — UDP + transport encryption**: IP discovery, RTP packetization,
   AEAD transport modes via runtime-loaded libcrypto, opus-passthrough send
   path. Testable with a loopback UDP fixture.
3. **M3 — DAVE**: libdave C shim, MLS handshake opcodes, epoch/transition
   handling, frame E2EE. Interop-testable against libdave's own test vectors.
4. **M4 — receive path + convenience**: decrypt/reorder/jitter concerns,
   optional libopus decode, voice receive events.

M1 and M2 produce a connection that servers will accept only until they
mandate DAVE on every call; they are stepping stones, not shippable
endpoints. The feature flag should stay `experimental` until M3 lands.

## Open questions (need maintainer input)

1. libdave shim distribution: separate repo with prebuilt artifacts, or an
   in-tree `voice-shim/` with documented local build? (Affects onboarding.)
2. Is voice **receive** in scope for v1, or send-only (music-bot use case)?
3. Should `join_voice` live on `GatewayCtx` (needs the gateway for op 4 and
   the two update events — natural home) or as a separate manager?
