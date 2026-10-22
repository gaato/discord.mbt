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
| [`dave/`](dave/README.md) | [`gaato/dave`](https://mooncakes.io/docs/gaato/dave) | Bindings to Discord's `libdave` for DAVE end-to-end encryption |
| [`examples/`](examples/README.md) | (not published) | Runnable bots, HTTP interaction servers, and JavaScript host adapters |
| [`guide/`](guide/README.md) | (not published) | Long-form guides whose code is tested |
| [`template/`](template/README.md) | (not published) | A bot project to copy |

Other directories: [`docs/`](docs) holds the REST behaviour notes and the
maintainers' ledgers and design notes, [`scripts/`](scripts/README.md) the
audits and release tooling, and `experiments/` host experiments. Each
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
review its diff when checking API drift. The audits CI runs are described in
[`scripts/README.md`](scripts/README.md).

The [`ghcr.io/gaato/moonbit`](https://github.com/gaato/moonbit-docker) image
bundles the pinned toolchain with Node.js 24, `gcc`, and `git`. The
`.devcontainer` starts from it, CI runs in it (except the Rust voice shim
job), and `template/Dockerfile` uses it as the builder stage.

Code blocks marked `mbt check` in the guides, docstrings, and module READMEs
compile and run as part of the test suite. Each module README is the root
package's `src/overview.mbt.md`, and `README.md` links to it.

Maintainer documents live in `docs/`:

- [`rest-coverage.md`](docs/rest-coverage.md): every Discord REST endpoint
  and its typed wrapper, and what is out of scope.
- [`test-coverage.md`](docs/test-coverage.md): the line-coverage ledger that
  `scripts/coverage_report.sh` checks; run it before tagging a release.
- [`resource-bounds.md`](docs/resource-bounds.md): what bounds each structure
  that grows with outside input.
- [`voice-design.md`](docs/voice-design.md): how `gaato/discord_voice` is
  built.

`gaato/dave` has its own checks, run from `dave/`: the offline downloader
tests (`node --test test/build.test.js`) and the native tests with the pinned
runtime (`env MBT_DAVE_REQUIRE_NATIVE=1 moon test --target native --release`).
Its native bridge smoke test covers a single-member commit, roster and
authenticator decoding, key-ratchet installation, and an encrypted media round
trip; a server-signed Add proposal, Welcome processing, and multi-party DAVE
need a live Discord voice session (`examples/dave_probe`).

## License

Apache-2.0
