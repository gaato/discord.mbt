# gaato/discord_voice

Voice for Discord bots built with
[`gaato/discord`](https://mooncakes.io/docs/gaato/discord): join a voice
channel, play Opus audio, and receive a chosen user's Opus packets. It handles
the voice gateway (v8), the RTP transport and Discord's DAVE end-to-end
encryption. It runs on MoonBit's native backend only.

Unofficial, and not affiliated with Discord. A minor release can change the
API; the
[changelog](https://github.com/gaato/discord.mbt/blob/main/discord_voice/CHANGELOG.md)
lists each change.

## Install

```sh
moon add gaato/discord
moon add gaato/discord_voice
```

Import it next to `gaato/discord` in your package's `moon.pkg`, as `@voice`,
with `gaato/discord/model` for the ids the example takes:

```mbt nocheck
///|
import {
  "gaato/discord",
  "gaato/discord/model",
  "gaato/discord_voice" @voice,
}
```

Voice also needs two native libraries at run time. See
[Native runtime](#native-runtime) below before the first build.

## Play a clip

Create one `VoiceClient` per bot and `attach` it to the builder. Then `join` a
voice channel from a READY handler or a bot service, and `play` an Ogg Opus
file there:

```mbt check
///|
fn play_on_ready(
  bot : @discord.BotBuilder,
  guild_id : @model.GuildId,
  channel_id : @model.ChannelId,
  ogg : Bytes,
) -> Unit {
  let voice = @voice.VoiceClient()
  voice.attach(bot)
  bot.on(@discord.Events::ready(), (ctx, _ready) => {
    let connection = voice.join(ctx, guild_id, channel_id, timeout_ms=10_000)
    let source = @voice.OggOpusSource::from_bytes(ogg)
    connection.play((source : &@voice.AudioSource))
  })
}

///|
test "the usage example compiles" {
  ignore(play_on_ready)
}
```

- **Intents.** The bot's intents must include `GUILD_VOICE_STATES`. Without
  it, `join` raises `VoiceError::MissingIntent` before contacting Discord.
- **Audio format.** `OggOpusSource` passes Opus packets through without
  decoding, so the file must already be 48 kHz stereo Opus with 20 ms frames:

  ```sh
  ffmpeg -i input.mp3 -c:a libopus -ar 48000 -ac 2 -frame_duration 20 -f ogg out.ogg
  ```

## Receive audio

Call `connection.subscribe(user_id=...)` and read that user's Opus packets in
RTP sequence order. Only subscribed users' packets are decrypted. A reader that
falls behind sees `ReceivedAudio::Lost` when its backlog fills. The library
does not decode Opus: decode to PCM in your application if you need it.

The [voice guide](https://github.com/gaato/discord.mbt/blob/main/guide/10-voice.mbt.md)
covers playback, receive, reconnects and region changes. The voice connection
resumes when Discord's session allows it.

## Native runtime

Two shared libraries are downloaded as verified prebuilt archives and loaded
at run time. Nothing is linked into your program or installed system-wide:

- [`gaato/dave`](https://mooncakes.io/docs/gaato/dave), the binding to
  Discord's official `libdave`, for DAVE's MLS and media encryption;
- the voice shim, a small Rust library released from this repository, for RTP
  transport encryption.

Download both once from a native build:

```sh
env DISCORD_VOICE_REQUIRE_SHIM=1 MBT_DAVE_REQUIRE_NATIVE=1 moon build --target native --release
```

This module and `gaato/dave` run prebuild hooks with `node`, so **Node.js must
be on `PATH` for every native `moon build`, `moon test` and `moon run`** of a
program that depends on this module. Without the two variables, the hooks
download nothing. `moon check` does not run them.

Prebuilt `libdave` exists for Linux (x86-64, ARM64), macOS (ARM64) and Windows
(x86-64). Supported hosts, offline builds and cache locations are in
[`gaato/dave`'s native runtime notes](https://github.com/gaato/discord.mbt/blob/main/dave/docs/native-runtime.md)
and the [voice shim README](https://github.com/gaato/discord.mbt/blob/main/discord_voice/shim/README.md).

## Limits

Voice gateway messages are limited to 4 MiB in either direction. An oversized
message ends the connection with Close 1009.

## Links

- [Voice guide](https://github.com/gaato/discord.mbt/blob/main/guide/10-voice.mbt.md)
- [Examples](https://github.com/gaato/discord.mbt/blob/main/examples/README.md)
  (`voice_player`, `voice_recorder`)
- [Changelog](https://github.com/gaato/discord.mbt/blob/main/discord_voice/CHANGELOG.md)
- [Repository](https://github.com/gaato/discord.mbt)

## License

Apache-2.0
