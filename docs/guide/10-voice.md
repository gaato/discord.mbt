# Voice

Voice support is native-only and experimental. It implements voice gateway
v8, Discord's DAVE end-to-end encryption, Opus playback, and raw Opus receive
events.

## Install the native shim

Download a prebuilt voice shim from the project's
[GitHub Releases](https://github.com/gaato/discord.mbt/releases), or build it:

```sh
cd voice-shim
cargo build --release
```

Point the runtime at the built library:

```sh
set -x DISCORD_VOICE_SHIM_PATH "$PWD/voice-shim/target/release/libdiscord_voice_shim.so"
```

macOS uses `libdiscord_voice_shim.dylib`; Windows uses
`discord_voice_shim.dll`. The loader also checks the platform library path
when `DISCORD_VOICE_SHIM_PATH` is unset.

## Join and play

Call `join_voice` from a READY handler or a bot service. `GatewayCtx` sends
main Gateway Opcode 4 and waits for the matching state and server updates.

```moonbit
let connection = ctx.join_voice(guild_id, channel_id, timeout_ms=10_000)
let bytes = @fs.read_file("audio.ogg").binary()
let source = @discord.OggOpusSource::from_bytes(bytes)
connection.play((source : &@discord.AudioSource))
```

`OggOpusSource` passes encoded Opus packets through without decoding. Create a
48 kHz, stereo stream with one 20 ms packet per Ogg packet:

```sh
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

`next_event` returns membership, speaking, packet-loss, and media events. The
receive path maps SSRC values to users when Discord has announced the mapping.

```moonbit
for ;; {
  match connection.next_event() {
    OpusReceived(user_id~, ssrc~, sequence~, timestamp~, opus~) => {
      consume_opus(user_id, ssrc, sequence, timestamp, opus)
    }
    PacketsLost(user_id~, ssrc~, count~) =>
      println("lost \{count} packet(s) from \{to_repr(user_id)} / \{ssrc}")
    _ => ()
  }
}
```

The library emits encoded Opus frames. It does not bundle an Opus decoder.
Packet loss events report gaps flushed by the reorder buffer.

## Region changes and reconnects

`VoiceConnection` resumes its voice WebSocket when possible and requests new
credentials when Discord requires a fresh session. `GatewayCtx` also watches
for a guild `VOICE_SERVER_UPDATE`. The current public voice API cannot inject
new credentials into an active connection, so the watcher disconnects and
joins the same channel again; callers holding the old handle should fetch the
guild connection by calling `join_voice` again after a region move.

See `src/examples/voice_player` for an executable that reads configuration
from `DISCORD_TOKEN`, `GUILD_ID`, `CHANNEL_ID`, and `AUDIO_FILE`.
