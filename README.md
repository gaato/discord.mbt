# discord.mbt

[![CI](https://github.com/gaato/discord.mbt/actions/workflows/ci.yml/badge.svg)](https://github.com/gaato/discord.mbt/actions/workflows/ci.yml)
[![Dave](https://github.com/gaato/discord.mbt/actions/workflows/dave.yml/badge.svg)](https://github.com/gaato/discord.mbt/actions/workflows/dave.yml)
[![Voice shim](https://github.com/gaato/discord.mbt/actions/workflows/voice-shim.yml/badge.svg)](https://github.com/gaato/discord.mbt/actions/workflows/voice-shim.yml)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/gaato/discord.mbt)
[![License](https://img.shields.io/github/license/gaato/discord.mbt)](LICENSE)

Discord libraries for [MoonBit](https://www.moonbitlang.com). This repository
is a MoonBit workspace; each directory below is a module.

| Directory | Module | Contents |
| --- | --- | --- |
| [`discord/`](discord/README.md) | [`gaato/discord`](https://mooncakes.io/docs/gaato/discord) | REST, interactions, and gateway bots |
| [`discord_voice/`](discord_voice/README.md) | `gaato/discord_voice` | Voice for `gaato/discord` bots (native) |
| [`dave/`](dave/README.mbt.md) | [`gaato/dave`](https://mooncakes.io/docs/gaato/dave) | Bindings to Discord's `libdave` for DAVE end-to-end encryption |
| [`examples/`](examples) | (not published) | Runnable bots and JavaScript host adapters |
| [`guide/`](guide/README.md) | (not published) | Long-form guides whose code is tested |
| [`template/`](template/README.md) | (not published) | A bot project to copy |

Other directories: `experiments/` holds host experiments, `scripts/` the
repository's audits and release tooling, and `docs/` design notes. Each
published module has its own `CHANGELOG.md`.

Run `moon check`, `moon test`, and `moon fmt` from this directory to cover
every module; native builds here need Node.js, which runs the voice modules'
prebuild hooks. See [`discord/README.md`](discord/README.md) for usage.

## License

Apache-2.0
