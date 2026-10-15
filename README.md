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
| [`discord/`](discord/README.md) | [`gaato/discord`](https://mooncakes.io/docs/gaato/discord) | REST, interactions, gateway bots, and voice |
| [`dave/`](dave/README.mbt.md) | [`gaato/dave`](https://mooncakes.io/docs/gaato/dave) | Bindings to Discord's `libdave` for DAVE end-to-end encryption |
| [`template/`](template/README.md) | (not published) | A bot project to copy |

Other directories: `voice-shim/` is the Rust transport-encryption library that
voice loads at run time, `experiments/` holds host experiments, `scripts/` the
repository's audits and release tooling, and `docs/` design notes.

Run `moon check`, `moon test`, and `moon fmt` from this directory to cover
every module. See [`discord/README.md`](discord/README.md) for usage and
[`discord/CHANGELOG.md`](discord/CHANGELOG.md) for changes.

## License

Apache-2.0
