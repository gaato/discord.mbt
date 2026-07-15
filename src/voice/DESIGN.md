# Voice support design (voice gateway v8 + DAVE)

Status: **implemented (M1-M4).**

discord.mbt implements native voice gateway v8, UDP transport encryption,
DAVE end-to-end encryption, Opus send/receive, and `GatewayCtx::join_voice`.
The public API remains experimental while it gains production use.

## Protocol requirements

Discord requires DAVE-encrypted audio calls as of March 1, 2026. The voice
stack uses these protocol rules:

- Voice WebSocket version 8 carries `seq_ack` in heartbeats and replays
  buffered messages after resume.
- The client negotiates DAVE, an MLS-based end-to-end encryption protocol.
- Transport encryption prefers `aead_aes256_gcm_rtpsize` and supports the
  required `aead_xchacha20_poly1305_rtpsize` fallback.
- Discord expects Voice Opcode 5 Speaking before the first RTP packet.

References: Discord's `topics/voice-connections`, https://daveprotocol.com,
and https://github.com/Snazzah/davey.

## Connection flow

1. `GatewayCtx::join_voice` registers `VOICE_STATE_UPDATE` and
   `VOICE_SERVER_UPDATE` collectors before sending main Gateway Opcode 4. It
   ignores a server update with a null endpoint and keeps waiting.
2. The client connects to `wss://<endpoint>?v=8` and sends Voice Opcode 0
   Identify with `max_dave_protocol_version`.
3. Voice Opcode 2 supplies the SSRC, UDP address, and transport modes. Opcode
   8 supplies the heartbeat interval.
4. The client performs UDP IP discovery and sends Select Protocol. Voice
   Opcode 4 supplies the transport key and selected DAVE version.
5. DAVE opcodes 21 through 31 establish and update the MLS group. Opcode 24
   uses `{epoch, protocol_version}`. Opcode 25 supplies the external sender
   package. Opcode 31 reports an invalid commit/welcome and starts recovery
   with a reset session and a new key package.
6. The sender encrypts each Opus frame with DAVE, then wraps it with transport
   AEAD. The receiver reverses both layers and reorders RTP packets before it
   emits `VoiceEvent` values.

Voice WebSocket reconnects use resume where Discord permits it. A close code
that requires a fresh main-Gateway handshake invokes the `rejoin` closure
owned by `VoiceConnection`.

## Implementation layout

The native-only `src/voice/` package owns the public connection and audio API.

| Layer | Implementation |
|---|---|
| `VoiceGateway` | v8 WebSocket state machine, JSON/binary envelopes, heartbeat, resume |
| `VoiceUdp` | UDP socket, IP discovery, RTP packet parsing and construction |
| transport crypto | AES-256-GCM and XChaCha20-Poly1305 through the Rust shim |
| DAVE | `davey`-based MLS session through the same Rust shim |
| audio | 20 ms Opus `AudioSource`, Ogg/Opus demuxing, paced sending |
| receive | transport/DAVE decryption, SSRC mapping, reorder buffer, `VoiceEvent` |

`VoiceConnection::start` attaches the gateway driver, event pump, sender,
receiver, and UDP keepalive tasks to the bot run loop's `TaskGroup`.
`GatewayCtx` keeps one connection per guild. A repeated join returns that
connection; channel moves need an explicit disconnect and join.

## Rust shim and distribution

`voice-shim/` builds one `cdylib` around
[davey](https://github.com/Snazzah/davey). davey is a Rust/OpenMLS
implementation used by discord.js and discord.py. discord.mbt does not bind
the C++ libdave library.

The shim also owns transport AEAD. Keeping DAVE and transport crypto in one
library gives applications one runtime dependency and avoids a separate
OpenSSL/libcrypto loader.

Build the shim from the repository root:

```sh
cd voice-shim
cargo build --release
```

Set `DISCORD_VOICE_SHIM_PATH` to the resulting `.so`, `.dylib`, or `.dll`.
Without the variable, the loader searches the platform library path for the
standard shim filenames. GitHub Releases publish prebuilt artifacts for
supported platforms. A missing shim raises `VoiceError::ShimUnavailable` when
the voice connection establishes its encrypted media session.

## Delivered milestones

- **M1:** voice gateway v8 state machine, envelopes, heartbeat, resume.
- **M2:** UDP, RTP, transport AEAD, Opus sender, Ogg/Opus demuxer.
- **M3:** davey shim exports and DAVE epoch/transition processing.
- **M4:** receive/reorder pipeline, `VoiceConnection`, bot integration,
  facade, example, and user documentation.

The v1 receive API emits raw Opus frames. Applications can add decoding above
`VoiceEvent::OpusReceived` without changing the transport package.
