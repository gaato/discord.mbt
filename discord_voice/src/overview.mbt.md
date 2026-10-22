# gaato/discord_voice

[![CI](https://github.com/gaato/discord.mbt/actions/workflows/ci.yml/badge.svg)](https://github.com/gaato/discord.mbt/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/gaato/discord.mbt)](https://github.com/gaato/discord.mbt/blob/main/discord_voice/LICENSE)

Discord voice for bots built with
[`gaato/discord`](https://mooncakes.io/docs/gaato/discord): voice gateway v8,
Discord's DAVE end-to-end encryption, Opus playback, and per-user Opus
receive. It runs on MoonBit's native backend only.

> **Status**: experimental. Minor releases may contain breaking changes; the
> [changelog](https://github.com/gaato/discord.mbt/blob/main/discord_voice/CHANGELOG.md)
> lists each one.

## Install

```sh
moon add gaato/discord
moon add gaato/discord_voice
```

Import it next to `gaato/discord` in your package's `moon.pkg`, as `@voice`:

```mbt nocheck
///|
import {
  "gaato/discord",
  "gaato/discord_voice" @voice,
}
```

## Usage

Create one `VoiceClient` per bot and `attach` it to the builder. Then `join`
a voice channel from a READY handler or a bot service, and `play` an Ogg Opus
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

The bot's intents must include `GUILD_VOICE_STATES`; `join` raises
`VoiceError::MissingIntent` before contacting Discord when they do not.
`OggOpusSource` passes Opus packets through without decoding, so the file
must already be 48 kHz stereo Opus with 20 ms frames:

```sh
ffmpeg -i input.mp3 -c:a libopus -ar 48000 -ac 2 -frame_duration 20 -f ogg out.ogg
```

To receive, `subscribe` to a user on a `VoiceConnection` and read their Opus
packets in RTP sequence order. The library does not decode Opus. The
[voice guide](https://github.com/gaato/discord.mbt/blob/main/guide/10-voice.mbt.md)
covers playback, receive, reconnects, and region changes.

## Native runtime

DAVE MLS and media encryption come from
[`gaato/dave`](https://mooncakes.io/docs/gaato/dave), the binding to
Discord's official `libdave`. RTP transport encryption comes from a small
Rust library, the voice shim, released from this repository. Both are
downloaded as verified prebuilt archives and loaded at run time; nothing is
linked into your program or installed system-wide.

Download both once from a native build:

```sh
env DISCORD_VOICE_REQUIRE_SHIM=1 MBT_DAVE_REQUIRE_NATIVE=1 moon build --target native --release
```

This module and `gaato/dave` declare prebuild hooks that Moon runs with
`node` for native builds, so Node.js must be on `PATH` for every native
`moon build`, `moon test`, and `moon run` of a program that depends on this
module. Without the two variables the hooks exit without downloading
anything. Moon does not run them for `moon check`.

The supported hosts, offline builds, and cache locations are described in
the voice guide and in
[`gaato/dave`'s native runtime notes](https://github.com/gaato/discord.mbt/blob/main/dave/docs/native-runtime.md).

## Links

- [Changelog](https://github.com/gaato/discord.mbt/blob/main/discord_voice/CHANGELOG.md)
- [Repository](https://github.com/gaato/discord.mbt)
- [Voice guide](https://github.com/gaato/discord.mbt/blob/main/guide/10-voice.mbt.md)
- [Voice shim](https://github.com/gaato/discord.mbt/blob/main/discord_voice/shim/README.md)
- [Examples](https://github.com/gaato/discord.mbt/blob/main/examples/README.md)
  (`voice_player`, `voice_recorder`)

## License

Apache-2.0
