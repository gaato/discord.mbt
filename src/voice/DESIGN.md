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
and the official https://github.com/discord/libdave implementation.

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
   package and may arrive before Opcode 4, so `VoiceConnection` buffers it
   until the DAVE machine exists. A fresh rejoin clears that buffer. The
   machine is retained in protocol v0 passthrough mode so a later Opcode 24
   epoch-one upgrade can reuse the external sender and publish a key package.
   Opcode 31 reports an invalid commit or Welcome. Recovery from
   either invalid message reinitializes the current protocol while retaining
   libdave's roster, and sends a fresh single-use key package. Commit and
   Welcome results then apply roster deltas; an empty delta preserves the
   existing membership.
6. The sender encrypts each Opus frame with DAVE, then wraps it with transport
   AEAD. The receiver reverses both layers and reorders RTP packets before it
   emits `VoiceEvent` values.

Voice WebSocket reconnects use resume where Discord permits it. A close code
that requires a fresh main-Gateway handshake invokes the `rejoin` closure
owned by `VoiceConnection`.

Media E2EE is supported, but pairwise identity verification is intentionally
not exposed. The official prebuilt libdave v1.2.0 C ABI rotates its ephemeral
signing identity on every `Init` and provides no reusable identity handle.
This can be revisited once upstream exposes an identity-handle API.

## Implementation layout

The native-only `src/voice/` package owns the public connection and audio API.

| Layer | Implementation |
|---|---|
| `VoiceGateway` | v8 WebSocket state machine, JSON/binary envelopes, heartbeat, resume |
| `VoiceUdp` | UDP socket, IP discovery, RTP packet parsing and construction |
| transport crypto | AES-256-GCM and XChaCha20-Poly1305 through the Rust shim |
| DAVE | `gaato/dave` safe MoonBit API backed by Discord's official `libdave` |
| audio | 20 ms Opus `AudioSource`, Ogg/Opus demuxing, paced sending |
| receive | transport/DAVE decryption, SSRC mapping, reorder buffer, `VoiceEvent` |

`VoiceConnection::start` attaches the gateway driver, event pump, sender,
receiver, and UDP keepalive tasks to the bot run loop's `TaskGroup`.
`GatewayCtx` keeps one connection per guild. A repeated join returns that
connection; channel moves need an explicit disconnect and join.

## Native libraries and distribution

The native boundary is split by responsibility:

- [`gaato/dave`](https://github.com/gaato/dave.mbt) owns the unsafe FFI
  boundary to Discord's official `libdave` C API. It exposes opaque MLS
  session, key-ratchet, encryptor, and decryptor handles. The voice package
  remains responsible for Gateway opcodes, connected-member bookkeeping,
  transition timing, recovery policy, and assigning actual RTP SSRCs.
- `voice-shim/` is a small Rust `cdylib` for transport AEAD only. It exposes
  AES-256-GCM and XChaCha20-Poly1305 seal/open operations and contains no MLS
  or DAVE session implementation.

This keeps the reusable DAVE protocol/media binding independent from the
Discord voice client while leaving the compact transport shim local to
discord.mbt. Interaction signature verification is implemented separately in
pure MoonBit.

`gaato/dave` pins upstream `libdave` `v1.2.0/cpp`, and `gaato/discord` pins
transport component release `voice-shim-v0.1.0`. A native Moon build with
`MBT_DAVE_REQUIRE_NATIVE=1` and `DISCORD_VOICE_REQUIRE_SHIM=1` makes their
prebuild hooks download and verify the matching host archives and extracted
libraries; builds without the opt-ins do not bootstrap host runtimes. The
loaders then open the shared libraries from versioned caches. Both releases
cover Linux x86-64/ARM64, macOS x86-64/ARM64, and Windows x86-64. The current
MoonBit installer has no macOS x86-64 toolchain, and neither release provides
Windows ARM64. The official Linux libdave binaries require glibc 2.38 and
GLIBCXX 3.4.32. Older Linux systems need an ABI-compatible self-built libdave
selected with `MBT_DAVE_NATIVE_LIB` or a newer runtime environment.

The normal consumer bootstrap is:

```fish
env DISCORD_VOICE_REQUIRE_SHIM=1 MBT_DAVE_REQUIRE_NATIVE=1 moon build --target native --release
```

For transport component development, build the shim from the repository root:

```fish
cd voice-shim
cargo build --release
```

Set `DISCORD_VOICE_SHIM_PATH` to the resulting `.so`, `.dylib`, or `.dll`.
Without the variable, the loader searches `DISCORD_VOICE_SHIM_ROOT`, the
versioned cache, and the platform library path. The remaining
`DISCORD_VOICE_SHIM_*` variables control offline and cache behavior;
`MBT_DAVE_NATIVE_ROOT`, `MBT_DAVE_NATIVE_CACHE_DIR`, and
`MBT_DAVE_NATIVE_LIB` configure the separate libdave loader. Missing transport
and DAVE runtimes are diagnosed independently.

## Delivered milestones

- **M1:** voice gateway v8 state machine, envelopes, heartbeat, resume.
- **M2:** UDP, RTP, transport AEAD, Opus sender, Ogg/Opus demuxer.
- **M3:** official libdave binding and DAVE epoch/transition processing.
- **M4:** receive/reorder pipeline, `VoiceConnection`, bot integration,
  facade, example, and user documentation.

The v1 receive API emits raw Opus frames. Applications can add decoding above
`VoiceEvent::OpusReceived` without changing the transport package.
