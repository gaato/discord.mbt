# Voice

Voice support is native-only and experimental. It implements voice gateway
v8, Discord's DAVE end-to-end encryption, Opus playback, and per-user raw
Opus receive. DAVE MLS and media crypto come from the native-only `gaato/dave`
binding to Discord's official `libdave`; the repository's Rust shim handles
RTP transport AEAD only. The accepted design and its milestones are
documented in [`src/voice/DESIGN.md`](https://github.com/gaato/discord.mbt/blob/main/discord/src/voice/DESIGN.md).

## Install the native dependencies

`gaato/discord` pins transport shim release `voice-shim-v0.1.0` and depends on
`gaato/dave`, which pins official `libdave` `v1.2.0/cpp`. Bootstrap both
verified native runtimes from a native build:

```fish
env DISCORD_VOICE_REQUIRE_SHIM=1 MBT_DAVE_REQUIRE_NATIVE=1 moon build --target native --release
```

The two prebuild hooks download their matching release archives, verify pinned
archive sizes and SHA-256 digests, verify the extracted libraries again, and
cache the complete extractions. Moon invocations without the corresponding
opt-in variable, including JavaScript builds, do not provision host libraries.
Node.js is required for the hooks; transport archive extraction uses `tar` on
Linux and macOS or PowerShell on Windows, while `gaato/dave` also requires
`unzip` on Linux and macOS. The libraries are loaded at runtime rather than
embedded in the Mooncake or installed system-wide.

The pinned upstream release provides `libdave` for Linux x86-64/ARM64, macOS
x86-64/ARM64, and Windows x86-64. A native MoonBit toolchain and the transport
shim must also be available for the same host. The current MoonBit installer
does not provide a macOS x86-64 toolchain, and upstream provides no Windows
ARM64 asset. Cross-compilation is not supported by the host-selected
bootstrap. Upstream's Linux binaries require glibc 2.38 and GLIBCXX 3.4.32.

For offline builds, verified extractions can be selected with
`DISCORD_VOICE_SHIM_ROOT` and `MBT_DAVE_NATIVE_ROOT`;
`DISCORD_VOICE_SHIM_OFFLINE=1` and `MBT_DAVE_NATIVE_OFFLINE=1` forbid
downloads. `DISCORD_VOICE_SHIM_CACHE_DIR` and `MBT_DAVE_NATIVE_CACHE_DIR`
override their cache bases and must be absolute paths. Set
`DISCORD_VOICE_SHIM_PATH` or `MBT_DAVE_NATIVE_LIB` to the absolute path of an
ABI-compatible self-built library when a published binary cannot run on the
host. See
[`gaato/dave`'s native runtime guide](https://github.com/gaato/dave.mbt/blob/main/docs/native-runtime.md)
for the cache layout and all overrides.

Media E2EE is supported, but pairwise identity verification is intentionally
not exposed. The official prebuilt libdave v1.2.0 C ABI rotates its ephemeral
signing identity on every `Init` and provides no reusable identity handle; the
API can be added once upstream exposes one.

To develop the transport component itself or support another host, build it
with Cargo:

```fish
cd voice-shim
cargo build --release
```

Point the runtime at that development build:

```fish
set -gx DISCORD_VOICE_SHIM_PATH "$PWD/target/release/libdiscord_voice_shim.so"
```

macOS uses `libdiscord_voice_shim.dylib`; Windows uses
`discord_voice_shim.dll`. When the explicit path is unset, the loader checks
`DISCORD_VOICE_SHIM_ROOT`, the deterministic `v0.1.0` cache, and finally the
platform library path. `DISCORD_VOICE_SHIM_*` configures only transport AEAD;
the `MBT_DAVE_NATIVE_*` variables configure the separate official libdave
runtime.

## Join and play

Call `join_voice` from a READY handler or a bot service. `GatewayCtx` sends
main Gateway Opcode 4 and waits for the matching state and server updates.
The main Gateway session must include `GUILD_VOICE_STATES`, because Discord
uses that intent to deliver the bot's `VOICE_STATE_UPDATE`:

```mbt check
///|
fn voice_bot(app : @discord.App, token : String) -> @discord.BotBuilder {
  let intents = @model.Intents::guilds() | @model.Intents::guild_voice_states()
  @discord.BotBuilder(app, token~, intents~)
}
```

`join_voice` raises `VoiceError::MissingIntent(intent="GUILD_VOICE_STATES")`
before sending Opcode 4 when the effective intent set omits it.

```mbt check
///|
async fn join_and_play(
  ctx : @discord.GatewayCtx,
  guild_id : @model.GuildId,
  channel_id : @model.ChannelId,
) -> Unit {
  let connection = ctx.join_voice(guild_id, channel_id, timeout_ms=10_000)
  let bytes = @fs.read_file("audio.ogg").binary()
  let source = @discord.OggOpusSource::from_bytes(bytes)
  connection.play((source : &@discord.AudioSource))
}
```

`OggOpusSource` passes encoded Opus packets through without decoding. Create a
48 kHz, stereo stream with one 20 ms packet per Ogg packet:

```fish
ffmpeg -i input.mp3 -c:a libopus -ar 48000 -ac 2 -frame_duration 20 -f ogg out.ogg
```

`play` replaces the current source. `stop` ends playback and sends Discord's
five silence frames. Call `disconnect` when the bot no longer needs the
channel.

A full channel may produce neither of the main Gateway response events when
the bot lacks `MOVE_MEMBERS`. `join_voice` then raises
`VoiceError::JoinTimeout`. A second join for the same guild returns the
registered connection and does not move it to another channel.

## Receive Opus

Receiving is per user. `subscribe` returns a stream of that user's audio in
RTP sequence order; packets from users nobody subscribed to are discarded on
arrival, before decryption. `next_event` carries only membership, speaking,
and lifecycle events, so a common pattern is to subscribe when a user starts
speaking:

```mbt check
///|
async fn receive_opus(
  connection : @discord.VoiceConnection,
  consume_opus : (Int32, UInt32, Bytes) -> Unit,
) -> Unit {
  let user_id = for ;; {
    match connection.next_event() {
      SpeakingChanged(user_id~, flags~, ..) if flags != 0 => break user_id
      _ => ()
    }
  }
  let stream = connection.subscribe(user_id~, end_after_silence_ms=Some(1000))
  while stream.next_packet() is Some(audio) {
    match audio {
      Opus(sequence~, timestamp~, opus~) =>
        consume_opus(sequence, timestamp, opus)
      Lost(count~) => println("lost \{count} frame(s) from \{user_id}")
    }
  }
}

///|
test "voice declarations compile" {
  ignore(voice_bot)
  ignore(join_and_play)
  ignore(receive_opus)
}
```

The library delivers encoded Opus frames. It does not bundle an Opus decoder.
`Lost` reports frames that never arrived (gaps flushed by the reorder buffer)
and frames dropped because the reader fell behind: each stream holds at most
`backlog` unread items (`DEFAULT_RECEIVE_BACKLOG`, five seconds of audio), and
`VoiceTelemetry::ReceiveDropped` reports each drop. The stream also works as an
`AudioSource`, which skips `Lost`, so it can be passed to `play` or written
with `OggOpusWriter`. Unread events are bounded the same way: past
`event_backlog` the oldest event is discarded with
`VoiceTelemetry::EventDropped`.

## Region changes and reconnects

`VoiceConnection` resumes its voice WebSocket when possible and requests new
credentials when Discord requires a fresh session. `GatewayCtx` also watches
for a guild `VOICE_SERVER_UPDATE`. The current public voice API cannot inject
new credentials into an active connection, so the watcher disconnects and
joins the same channel again; callers holding the old handle should fetch the
guild connection by calling `join_voice` again after a region move.

See `examples/voice_player` for an executable that reads configuration
from `DISCORD_TOKEN`, `GUILD_ID`, `CHANNEL_ID`, and `AUDIO_FILE`.

## Verify DAVE against a live channel

`examples/dave_probe` joins an existing channel, waits for
`DaveMediaContextActivated(protocol_version=1)`, sends one second of canonical
Opus silence through the active libdave encryptor, and disconnects. It does
not create or delete Discord resources. Keep a normal DAVE-capable Discord
client in the channel while testing: the gateway sends an initial Add proposal
to the other pending members, so a bot alone cannot establish the group. Set
`DISCORD_TOKEN`, `GUILD_ID`, and `CHANNEL_ID`, then run:

```fish
env DISCORD_VOICE_REQUIRE_SHIM=1 MBT_DAVE_REQUIRE_NATIVE=1 moon run --target native --release examples/dave_probe
```

With no other announced participant, the probe reports an inconclusive result.
It fails if a peer is present but DAVE v1 does not activate within 30 seconds,
or if the control or encryption paths emit a DAVE diagnostic. A successful run proves
the local client completed the server-driven MLS transition and encrypted its
outbound frames. It does not prove that another participant decrypted them;
that final interoperability check requires a second Discord client in the
channel.

For that final outbound interoperability check, explicitly enable the audible
mode with a short, low-volume Ogg/Opus file. The probe still waits for DAVE v1
activation before playback and clips the input at three seconds. For example:

```fish
ffmpeg -y -hide_banner -loglevel error -f lavfi -i 'sine=frequency=880:duration=1.5' -filter:a 'volume=0.7' -c:a libopus -ar 48000 -ac 2 -frame_duration 20 /tmp/discord-dave-tone.ogg
env DAVE_PROBE_AUDIBLE=1 DAVE_PROBE_AUDIO_FILE=/tmp/discord-dave-tone.ogg DISCORD_VOICE_REQUIRE_SHIM=1 MBT_DAVE_REQUIRE_NATIVE=1 moon run --target native --release examples/dave_probe
```

Have the other participant confirm hearing the short tone, and also
require the probe to report no DAVE diagnostics and a clean disconnect. This
is an opt-in manual live test, not a CI test. Hearing the tone confirms the
outbound bot-to-client decrypt/decode/render path; validating the reverse path
requires speaking from the client and observing decrypted frames on a
subscription separately. To perform that reverse check without recording the audio,
set `DAVE_PROBE_RECEIVE=1`, run the same probe, and speak from the other client
when the receive probe starts. It waits up to 20 seconds for ten decrypted Opus
frames and stores only the frame count:

```fish
env DAVE_PROBE_RECEIVE=1 DISCORD_VOICE_REQUIRE_SHIM=1 MBT_DAVE_REQUIRE_NATIVE=1 moon run --target native --release examples/dave_probe
```

UDP can arrive before the voice gateway's initial Speaking event establishes
the SSRC-to-user mapping. The probe subscribes to the first user whose
Speaking event arrives, so earlier frames are discarded unread; it passes the
receive check once ten later frames from that user decrypt successfully. DAVE
decrypt failures remain fatal.

For a content-level manual check, `DAVE_PROBE_ECHO=1` implies receive mode,
waits for a peer Speaking event, discards five warm-up frames, holds the next
100 frames (about two seconds) from that peer in memory, then plays them back
once through the active DAVE encryptor. Speak for about three seconds and stop;
the probe does not write the audio to disk and does not echo while recording,
so it cannot create a continuous feedback loop. It logs only Opus packet-size
statistics, not the sender ID or audio content:

```fish
env DAVE_PROBE_ECHO=1 DISCORD_VOICE_REQUIRE_SHIM=1 MBT_DAVE_REQUIRE_NATIVE=1 moon run --target native --release examples/dave_probe
```

When explicit recording is acceptable, set `DAVE_PROBE_RECORD_PATH` to an Ogg
output path. This also uses the Speaking-gated two-second capture, but does not
enable echo unless `DAVE_PROBE_ECHO=1` is set separately:

```fish
env DAVE_PROBE_RECORD_PATH=/tmp/discord-dave-receive-check.ogg DISCORD_VOICE_REQUIRE_SHIM=1 MBT_DAVE_REQUIRE_NATIVE=1 moon run --target native --release examples/dave_probe
```
