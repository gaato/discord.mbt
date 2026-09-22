# discord.mbt

[![CI](https://github.com/gaato/discord.mbt/actions/workflows/ci.yml/badge.svg)](https://github.com/gaato/discord.mbt/actions/workflows/ci.yml)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/gaato/discord.mbt)

A Discord application library for [MoonBit](https://www.moonbitlang.com/):
typed interaction declarations, API models, a rate-limited REST client,
JS/serverless HTTP interactions, and a native WebSocket gateway shard with
voice (DAVE end-to-end encryption).

The design follows [twilight](https://github.com/twilight-rs/twilight):
loosely coupled packages that model the Discord API, plus an App layer for
typed interaction declarations. The interaction App, REST client, and data
packages support **native** and **JavaScript**; the gateway Bot executor is
native-only. Both are built on
[moonbitlang/async](https://github.com/moonbitlang/async), and the REST client
speaks to the network through a [`gaato/http`](https://mooncakes.io/docs/gaato/http)
`Transport`, so it can be tested without Discord.

> **Status**: experimental. Minor releases may contain breaking changes and
> patch releases do not; see the [changelog](CHANGELOG.md) for migration notes.

## Install

```sh
moon update
moon add gaato/discord
```

Node.js must be on `PATH` for every build (prebuild hooks), and native builds
need the zlib development headers. The
[root package guide](src/README.mbt.md#prerequisites) has the details.

## Documentation

- [Root package guide](src/README.mbt.md): prerequisites, quickstart, the
  package map, executors, HTTP interactions, typed models, REST without the
  gateway, and development workflow.
- [Long-form guides](src/guide/README.md): twelve chapters from getting
  started to voice and the low-level framework. Their code blocks compile and
  run as part of the test suite, so the examples cannot drift from the library.
- [Testkit](src/testkit/README.mbt.md): handler tests without a Discord
  connection.
- Task-focused recipes are docstring examples on the relevant symbols; look
  anything up with `moon ide doc`.
- [Template](template/): a minimal bot to copy.

## License

Apache-2.0.
