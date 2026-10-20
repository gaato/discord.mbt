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
| [`discord_voice/`](discord_voice/README.md) | [`gaato/discord_voice`](https://mooncakes.io/docs/gaato/discord_voice) | Voice for `gaato/discord` bots (native) |
| [`dave/`](dave/README.mbt.md) | [`gaato/dave`](https://mooncakes.io/docs/gaato/dave) | Bindings to Discord's `libdave` for DAVE end-to-end encryption |
| [`examples/`](examples) | (not published) | Runnable bots and JavaScript host adapters |
| [`guide/`](guide/README.md) | (not published) | Long-form guides whose code is tested |
| [`template/`](template/README.md) | (not published) | A bot project to copy |

Other directories: `experiments/` holds host experiments, `scripts/` the
repository's audits and release tooling, and `docs/` design notes. Each
published module has its own `CHANGELOG.md`.

See [`discord/README.md`](discord/README.md) for usage.

## Development

Run these from this directory; they cover every module and build each against
the in-tree versions of the others. Native builds here run every module's
prebuild hook, so they need Node.js on `PATH`.

```sh
moon check --target native --deny-warn
moon check --target js --deny-warn
moon check --target wasm --deny-warn
moon test --target native --release   # debug native builds need a working tcc setup
moon test --target js --release
moon test --target wasm --release
moon fmt
moon info --target native             # regenerate pkg.generated.mbti
scripts/gen_extends.py                # regenerate extends.mbt after adding or removing a ToJson type
```

To build `gaato/discord` alone against its published dependencies, as a
consumer does, run `MOON_WORK=off moon -C discord check --target native`.

Each package's `pkg.generated.mbti` is a concise public-interface snapshot;
review its diff when checking API drift. [`scripts/`](scripts) holds the
audits and release tooling.

The [`ghcr.io/gaato/moonbit`](https://github.com/gaato/moonbit-docker) image
bundles the pinned toolchain with Node.js 24, `gcc`, and `git`. The
`.devcontainer` starts from it, CI runs in it (except the Rust voice shim
job), and `template/Dockerfile` uses it as the builder stage.

Code blocks marked `mbt check` in the guides and docstrings compile and run
as part of the test suite. `discord/README.md` keeps its examples as
`mbt nocheck` for readers; each has a compiled twin in
`discord/src/readme_native_test.mbt`.

## License

Apache-2.0
