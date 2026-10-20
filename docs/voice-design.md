# Voice support design (voice gateway v8 + DAVE)

`gaato/discord_voice` implements native voice gateway v8, UDP transport
encryption, DAVE end-to-end encryption, Opus send/receive, and
`VoiceClient::join` for `gaato/discord` bots.
The public API remains experimental while it gains production use.

## Protocol requirements

Discord requires DAVE-encrypted audio calls. The voice stack uses these
protocol rules:

- Voice WebSocket version 8 carries `seq_ack` in heartbeats and replays
  buffered messages after resume.
- The client negotiates DAVE, an MLS-based end-to-end encryption protocol.
- Transport encryption prefers `aead_aes256_gcm_rtpsize` and supports the
  required `aead_xchacha20_poly1305_rtpsize` fallback.
- Discord expects Voice Opcode 5 Speaking before the first RTP packet.

References: Discord's `topics/voice-connections`, https://daveprotocol.com,
and the official https://github.com/discord/libdave implementation.

## Connection flow

1. `VoiceClient::join` expects `VOICE_STATE_UPDATE` and
   `VOICE_SERVER_UPDATE` (through `GatewayCtx::expect_event`) before sending
   main Gateway Opcode 4 on the guild's shard. It ignores a server update with
   a null endpoint and keeps waiting.
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
   AEAD. The receiver reverses both layers for subscribed senders only and
   reorders their RTP packets before delivering them to per-user streams.

Voice WebSocket reconnects use resume where Discord permits it. A close code
that requires a fresh main-Gateway handshake invokes the `rejoin` closure
owned by `VoiceConnection`. A later `VOICE_SERVER_UPDATE` (a server failover)
comes through the `next_server` closure: the event pump closes the old gateway
and identifies on the new endpoint with the new token and the same session.
A null endpoint means the server went away: the pump closes the gateway and
waits up to `server_timeout_ms` for the next update, then rejoins. The
`next_channel` closure follows the bot's own `VOICE_STATE_UPDATE`, so a
channel move made elsewhere reaches the next DAVE session and the rejoin.

Every background task of a connection ends when it closes. The event pump
runs the teardown; the receiver, keepalive, playback, and server and channel
watches are
cancelled by it, so none waits on a timer, a source, or the main gateway past
the connection's end. `disconnect` returns once the teardown is done, which
`VoiceClient::join` waits for before rejoining a guild.

Media E2EE is supported, but pairwise identity verification is intentionally
not exposed. The official prebuilt libdave v1.2.0 C ABI rotates its ephemeral
signing identity on every `Init` and provides no reusable identity handle.
This can be revisited once upstream exposes an identity-handle API.

## Implementation layout

The native-only root package in `src/` owns the public connection and audio
API. `client.mbt` joins through a `VoiceGatewayPort`, the few main-gateway
values and functions a join needs.

| Layer | Implementation |
|---|---|
| `VoiceGateway` | v8 WebSocket state machine, JSON/binary envelopes, heartbeat, resume |
| `VoiceUdp` | UDP socket, IP discovery, RTP packet parsing and construction |
| transport crypto | AES-256-GCM and XChaCha20-Poly1305 through the Rust shim |
| DAVE | `gaato/dave` safe MoonBit API backed by Discord's official `libdave` |
| audio | 20 ms Opus `AudioSource`, Ogg/Opus demuxing, paced sending |
| receive | SSRC mapping, transport/DAVE decryption, reorder buffer, bounded per-user streams |

`VoiceConnection::start` attaches the gateway driver, event pump, sender,
receiver, and UDP keepalive tasks to the bot run loop's `TaskGroup`.
`GatewayCtx` keeps one connection per guild. A repeated join returns that
connection; channel moves need an explicit disconnect and join.

## Native libraries and distribution

The native boundary is split by responsibility:

- [`gaato/dave`](../dave/README.mbt.md) owns the unsafe FFI
  boundary to Discord's official `libdave` C API. It exposes opaque MLS
  session, key-ratchet, encryptor, and decryptor handles. The voice package
  remains responsible for Gateway opcodes, connected-member bookkeeping,
  transition timing, recovery policy, and assigning actual RTP SSRCs.
- `discord_voice/shim/` is a small Rust `cdylib` for transport AEAD only. It exposes
  AES-256-GCM and XChaCha20-Poly1305 seal/open operations and contains no MLS
  or DAVE session implementation.

This keeps the reusable DAVE protocol/media binding independent from the
Discord voice client while leaving the compact transport shim local to
discord.mbt. Interaction signature verification is implemented separately in
pure MoonBit.

`gaato/dave` pins upstream `libdave` `v1.2.0/cpp`, and `gaato/discord_voice`
pins transport component release `voice-shim-v0.1.0`. Their prebuild hooks
download and verify the matching host archives only when a native build opts
in with `MBT_DAVE_REQUIRE_NATIVE=1` and `DISCORD_VOICE_REQUIRE_SHIM=1`; the
loaders then open the shared libraries from versioned caches, and missing
transport and DAVE runtimes are diagnosed independently. Supported platforms,
cache paths, and loader variables are documented for users in the
[voice guide](../guide/10-voice.mbt.md) and
[native libdave runtime](../dave/docs/native-runtime.md); building the shim
itself is in [`discord_voice/shim/README.md`](../discord_voice/shim/README.md).

## Receive

The receive API delivers raw Opus frames through `VoiceConnection::subscribe`.
Audio is not a `VoiceEvent`: only subscribed users' packets are decrypted, and
every queue a reader can fall behind on is bounded. A subscription drops new
frames past its backlog and reports them in-stream as `ReceivedAudio::Lost`;
unread events drop the oldest. Applications can add decoding above
`ReceivedAudio::Opus` without changing the transport package.
