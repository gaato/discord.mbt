# gaato/discord

[![CI](https://github.com/gaato/discord.mbt/actions/workflows/ci.yml/badge.svg)](https://github.com/gaato/discord.mbt/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/gaato/discord.mbt)](https://github.com/gaato/discord.mbt/blob/main/LICENSE)

A Discord application library for [MoonBit](https://www.moonbitlang.com/):
typed interaction declarations, API models, a rate-limited REST client,
signed HTTP interactions, and Gateway bots on the native, JavaScript, and
moonrun Wasm backends. Like [twilight](https://github.com/twilight-rs/twilight),
it is a set of loosely coupled packages with an App layer on top.

> **Status**: experimental. Minor releases may contain breaking changes; the
> [changelog](https://github.com/gaato/discord.mbt/blob/main/discord/CHANGELOG.md)
> lists each one with a migration note.

## Install

Install `git` (Moon uses it to clone the package registry), then:

```sh
moon update
moon add gaato/discord
moon add moonbitlang/async
```

## Quickstart

Build the interaction `App`, then hand it to the Gateway `Bot`. This bot
registers and answers `/echo`:

```mbt check
///|
struct QuickstartEchoArgs {
  text : String
  times : Int32
}

///|
async fn run_echo_bot(token : String) -> Unit {
  let args : @discord.Args[QuickstartEchoArgs] = @discord.Args::map2(
    @discord.arg_string(name="text", description="What to echo"),
    @discord.arg_int32(
      name="times",
      description="How many times (1-5)",
      min=1,
      max=5,
    ).with_default(1),
    (text, times) => { text, times, },
  )
  let echo = @discord.slash(
    name="echo",
    description="Echo your text back",
    args~,
    handler=Immediate((_ctx, value) => {
      @discord.CommandReply::message(
        content=Array::make(value.times, value.text).join("\n"),
      )
    }),
  )
  let app = @discord.AppBuilder()
  app.command(echo)
  let bot = @discord.BotBuilder(app.build(), token~, sync=Global)
  bot.on(@discord.Events::ready(), (_ctx, ready) => {
    println("ready as \{ready.user.username}")
  })
  bot.build().run()
}

///|
test "the quickstart bot compiles" {
  ignore(run_echo_bot)
}
```

`Args` drives both the command's registration payload and the decoding of
each invocation. The same `App` can also be served over signed HTTP
interactions instead of the Gateway. Continue with
[Getting started](https://github.com/gaato/discord.mbt/blob/main/guide/01-getting-started.mbt.md),
or copy the [bot template](https://github.com/gaato/discord.mbt/blob/main/template/README.md).

## Packages

| Package | What it is | Native | JS | Wasm¹ |
|---|---|---:|---:|---:|
| `gaato/discord` | Facade: golden-path names a typical application uses directly | Yes | Yes² | Yes² |
| `gaato/discord/model` | Pure data: API entities and gateway payloads, zero IO | Yes | Yes | Yes |
| `gaato/discord/telemetry` | Structured REST, gateway, and dispatch observability values | Yes | Yes | Yes |
| `gaato/discord/http` | REST `Client`, routes, rate limiting, multipart uploads | Yes | Yes | Yes |
| `gaato/discord/gateway` | `Shard`: connection state machine, heartbeat, resume | Yes | Yes | Yes |
| `gaato/discord/interaction` | Command/component builders, typed args and autocomplete data | Yes | Yes | Yes |
| `gaato/discord/framework` | Interaction routing, response gates, low-level response contexts | Yes | Yes | Yes |
| `gaato/discord/app` | Gateway-free typed commands/components/modals, HTTP endpoint, sync and policy | Yes | Yes | Yes |
| `gaato/discord/bot` | Gateway executor and typed gateway event descriptors | Yes | Yes | Yes |
| `gaato/discord/endpoint_http` | Signed-interactions HTTP server (`serve_interactions`) | Yes | No | Yes |
| `gaato/discord/cache` | Opt-in, gateway-driven in-memory cache | Yes | Yes | Yes |
| `gaato/discord/util` | Pure helpers: permissions, mentions, timestamps, CDN URLs | Yes | Yes | Yes |
| `gaato/discord/verify` | Pure MoonBit Ed25519 request verification | Yes | Yes | Yes |
| `gaato/discord/ratelimit` | In-memory Discord rate limiter for the `gaato/sdk-runtime` `RateLimiter` trait | Yes | Yes | Yes |
| `gaato/discord/cooldown` | Command cooldown store trait + in-memory fixed windows | Yes | Yes | Yes |
| `gaato/discord/queue` | Identify queue trait + in-memory implementation | Yes | Yes | Yes |
| `gaato/discord/coordinator` | Experimental TCP coordinator for multi-process Identify, REST limits, and cooldowns | Yes | No | Yes |
| `gaato/discord/testkit` | Deterministic interaction and model fixtures | Yes | Yes | Yes |

¹ Linear-memory Wasm run by `moonrun`, whose host APIs come from
moonbitlang/async; generic WASI runtimes, browsers, and wasm-gc are not
targets. The [`interactions_http` example](https://github.com/gaato/discord.mbt/blob/main/examples/interactions_http/README.md)
shows a `moonrun --policy` setup.

² The HTTP-server exports exist on native and Wasm. A package that is empty
on a backend does not provide that feature there, even if Moon accepts it as
a dependency.

Voice is a separate, native-only module:
[`gaato/discord_voice`](https://mooncakes.io/docs/gaato/discord_voice).

Import only what the program needs:

- Gateway bot: the `gaato/discord` facade.
- REST-only tool: `http` (brings `model`).
- Serverless HTTP interactions (Cloudflare Workers, Deno, Bun, Node.js): `app`
  and `verify`.
- Native or moonrun Wasm HTTP interactions server: `endpoint_http`.

The facade leaves lower-level names in their own packages: `http` for
resource refs and pagination, `framework` for the router and the raw contexts
of `Raw` handlers, `gateway` for shard transport, `coordinator` for
multi-process coordination, `telemetry` for observability events, and
`interaction` for raw option builders.

## Guides

The [guides](https://github.com/gaato/discord.mbt/blob/main/guide/README.md)
cover each part in depth; their code compiles and runs in the test suite.

1. [Getting started](https://github.com/gaato/discord.mbt/blob/main/guide/01-getting-started.mbt.md):
   a minimal slash-command bot and command synchronization.
2. [Commands](https://github.com/gaato/discord.mbt/blob/main/guide/02-commands.mbt.md):
   typed arguments, autocomplete, subcommands, context menus, and handler
   modes against Discord's three-second deadline.
3. [Components and modals](https://github.com/gaato/discord.mbt/blob/main/guide/03-components-modals.mbt.md):
   buttons, selects, typed modals, and component waits.
4. [Events and intents](https://github.com/gaato/discord.mbt/blob/main/guide/04-events-intents.mbt.md):
   typed Gateway subscriptions, intent derivation, sharding, saved sessions,
   compression, and the cache.
5. [REST](https://github.com/gaato/discord.mbt/blob/main/guide/05-rest.mbt.md):
   typed endpoints, resource refs, rate limits and resends, uploads, and
   pagination.
6. [HTTP interactions](https://github.com/gaato/discord.mbt/blob/main/guide/06-http-interactions.mbt.md):
   gateway-free dispatch, the native server, and JavaScript hosts.
7. [Structuring bots](https://github.com/gaato/discord.mbt/blob/main/guide/07-structuring-bots.mbt.md):
   feature installers, state, configuration, checks, and cooldowns.
8. [Scaling across processes](https://github.com/gaato/discord.mbt/blob/main/guide/08-scaling-processes.mbt.md):
   share Identify and REST limits through the bundled coordinator.
9. [Middleware](https://github.com/gaato/discord.mbt/blob/main/guide/09-middleware.mbt.md):
   wrap REST calls, routed interactions, and Gateway fan-out; error-policy
   responses and telemetry.
10. [Voice](https://github.com/gaato/discord.mbt/blob/main/guide/10-voice.mbt.md):
    `gaato/discord_voice` with DAVE encryption.
11. [The framework layer](https://github.com/gaato/discord.mbt/blob/main/guide/11-framework.mbt.md):
    direct routing, response gates, and handler tests without a network.
12. [Models and utilities](https://github.com/gaato/discord.mbt/blob/main/guide/12-models-utilities.mbt.md):
    typed snowflakes, forward-compatible enums, and permission, mention,
    timestamp, and CDN helpers.

Exact type and method documentation lives in doc comments, many with
examples: browse them here on mooncakes, or run `moon ide doc "@discord"`
(any package or symbol name works).

## Examples

The repository's
[`examples/`](https://github.com/gaato/discord.mbt/blob/main/examples/README.md)
has runnable Gateway bots, HTTP interaction servers and JavaScript host
adapters, a Durable Object bot, and voice players; run one from the
repository root with `moon run --target native examples/slash_echo`.

## Testing

`Client::offline` answers REST calls from a function you write, and
[`gaato/discord/testkit`](https://github.com/gaato/discord.mbt/blob/main/discord/src/testkit/README.mbt.md)
provides deterministic interaction and model fixtures; import it only in your
package's `for "test"` block. See
[the framework layer](https://github.com/gaato/discord.mbt/blob/main/guide/11-framework.mbt.md)
for handler tests without a network.

## Links

- [Changelog](https://github.com/gaato/discord.mbt/blob/main/discord/CHANGELOG.md)
- [Repository](https://github.com/gaato/discord.mbt)
- [Guides](https://github.com/gaato/discord.mbt/blob/main/guide/README.md)
- [Examples](https://github.com/gaato/discord.mbt/blob/main/examples/README.md)
- [Bot template](https://github.com/gaato/discord.mbt/blob/main/template/README.md)

## License

Apache-2.0
