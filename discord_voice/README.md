# gaato/discord_voice

[![CI](https://github.com/gaato/discord.mbt/actions/workflows/ci.yml/badge.svg)](https://github.com/gaato/discord.mbt/actions/workflows/ci.yml)
[![Voice shim](https://github.com/gaato/discord.mbt/actions/workflows/voice-shim.yml/badge.svg)](https://github.com/gaato/discord.mbt/actions/workflows/voice-shim.yml)
[![License](https://img.shields.io/github/license/gaato/discord.mbt)](https://github.com/gaato/discord.mbt/blob/main/discord_voice/LICENSE)

Experimental Discord voice for bots built with
[`gaato/discord`](https://github.com/gaato/discord.mbt/blob/main/discord/README.md), on MoonBit's native
backend: voice gateway v8, Discord's DAVE end-to-end encryption, Opus
playback, and per-user Opus receive. The module lives in the `discord_voice/`
directory of [gaato/discord.mbt](https://github.com/gaato/discord.mbt).

```sh
moon add gaato/discord_voice
```

Import it next to `gaato/discord`, as `@voice`:

```moonbit
import {
  "gaato/discord",
  "gaato/discord_voice" @voice,
}
```

Create one `VoiceClient` per bot, attach it to the builder, and join from a
READY handler or a bot service:

```moonbit
let voice = @voice.VoiceClient()
voice.attach(bot)
// later, with a GatewayCtx:
let connection = voice.join(ctx, guild_id, channel_id)
```

The [voice guide](https://github.com/gaato/discord.mbt/blob/main/guide/10-voice.mbt.md) covers playback,
receive, reconnects, and the examples.

## Native runtime

DAVE MLS and media encryption come from
[`gaato/dave`](https://github.com/gaato/discord.mbt/blob/main/dave/README.mbt.md), the binding to Discord's
official `libdave` (pinned at `v1.2.0/cpp`). RTP transport AEAD comes from a
small Rust library released as `voice-shim-v0.1.0`; its sources are in
`shim/`. Both are loaded at run time, not linked or installed system-wide.

A native build bootstraps and verifies both prebuilt runtimes when asked to:

```sh
env DISCORD_VOICE_REQUIRE_SHIM=1 MBT_DAVE_REQUIRE_NATIVE=1 moon build --target native --release
```

This module and `gaato/dave` declare prebuild hooks that Moon runs with
`node` for native builds, so Node.js must be on `PATH` for every native
`moon build`, `moon test`, and `moon run` of a program that depends on this
module. Without the opt-in variables the hooks exit without downloading
anything. Moon does not run them for `moon check`.

## License

Apache-2.0
