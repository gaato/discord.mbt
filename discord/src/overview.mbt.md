# gaato/discord

Build Discord bots and interaction endpoints in MoonBit. Declare a slash
command once: the same declaration registers it with Discord and decodes its
arguments into your type in the handler. A Gateway bot and a signed HTTP
endpoint, such as one on Cloudflare Workers or Deno, can serve the same `App`.
A REST-only tool can import the HTTP client on its own.

Runs on native, JavaScript and Wasm under `moonrun`. Voice is a separate
module, [`gaato/discord_voice`](https://mooncakes.io/docs/gaato/discord_voice).

Unofficial, and not affiliated with Discord. A minor release can change the
API; the
[changelog](https://github.com/gaato/discord.mbt/blob/main/discord/CHANGELOG.md)
lists each change with a migration note.

## Install

```sh
moon add gaato/discord
```

A bot's `main` is an `async fn main`, so its package imports
`moonbitlang/core/async` (part of the standard library, so there is nothing to
`moon add`) and lists it under `allow-experimental-packages`. The
[bot template](https://github.com/gaato/discord.mbt/blob/main/template/README.md)
has the whole setup, including token loading and shutdown.

## Quickstart

Build the interaction `App`, then hand it to the Gateway `Bot`. This bot
registers and answers `/echo` in the scope it is given, such as
`Guild(test_guild_id)` while you develop:

```mbt check
///|
struct QuickstartEchoArgs {
  text : String
  times : Int32
}

///|
async fn run_echo_bot(token : String, scope : @discord.CommandScope) -> Unit {
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
  let bot = @discord.BotBuilder(app.build(), token~, sync=scope)
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

`Args` drives both the registration payload and the decoding of each
invocation, so the two cannot drift apart.

**Command sync replaces what is registered.** With `sync=`, the bot overwrites
the commands in that scope in bulk after its first READY, and by default
deletes commands your app does not declare. During development, sync to a
test guild with `Guild(id)` rather than `Global`. Pass `sync_unowned=Keep`
to leave other commands alone. Without `sync=`, nothing is synchronized. When
a bot runs in several processes, enable sync in exactly one of them.

## Choose the packages

Import only what the program needs:

| Application | Packages under `gaato/discord` |
| --- | --- |
| Gateway bot with commands and events | The root facade: `AppBuilder`, `BotBuilder`, typed `Events`. |
| REST-only tool or background job | `http` (routes, pagination, uploads, rate limiting), which brings `model`. |
| Serverless HTTP interactions (Cloudflare Workers, Deno, Bun, Node.js) | `app` and `verify`. |
| Native or moonrun Wasm HTTP interactions server | `endpoint_http`. |
| Tests without Discord | `testkit` for fixtures. `http.Client::offline` answers REST calls from your function. |

### All packages and their targets

| Package | What it is | Native | JS | Wasm¹ |
|---|---|---:|---:|---:|
| `gaato/discord` | Facade: the names a typical application uses directly | Yes | Yes² | Yes² |
| `gaato/discord/model` | Pure data: API entities and gateway payloads, no I/O | Yes | Yes | Yes |
| `gaato/discord/http` | REST `Client`, routes, rate limiting, multipart uploads | Yes | Yes | Yes |
| `gaato/discord/gateway` | `Shard`: connection state machine, heartbeat, resume | Yes | Yes | Yes |
| `gaato/discord/interaction` | Command and component builders, typed args, autocomplete data | Yes | Yes | Yes |
| `gaato/discord/framework` | Interaction routing, response gates, low-level response contexts | Yes | Yes | Yes |
| `gaato/discord/app` | Gateway-free typed commands, components and modals, HTTP endpoint, sync and policy | Yes | Yes | Yes |
| `gaato/discord/bot` | Gateway executor and typed gateway event descriptors | Yes | Yes | Yes |
| `gaato/discord/endpoint_http` | Signed-interactions HTTP server (`serve_interactions`) | Yes | No | Yes |
| `gaato/discord/cache` | Opt-in, gateway-driven in-memory cache | Yes | Yes | Yes |
| `gaato/discord/util` | Permissions, mentions, timestamps, CDN URLs | Yes | Yes | Yes |
| `gaato/discord/verify` | Pure MoonBit Ed25519 request verification | Yes | Yes | Yes |
| `gaato/discord/ratelimit` | In-memory Discord rate limiter | Yes | Yes | Yes |
| `gaato/discord/cooldown` | Command cooldown store and in-memory fixed windows | Yes | Yes | Yes |
| `gaato/discord/queue` | Identify queue and in-memory implementation | Yes | Yes | Yes |
| `gaato/discord/coordinator` | Experimental TCP coordinator for multi-process Identify, REST limits and cooldowns | Yes | No | Yes |
| `gaato/discord/telemetry` | Structured REST, gateway and dispatch observability values | Yes | Yes | Yes |
| `gaato/discord/testkit` | Deterministic interaction and model fixtures | Yes | Yes | Yes |

¹ Linear-memory Wasm run by `moonrun`. Generic WASI runtimes, browsers and
wasm-gc are not targets.
² The HTTP-server exports exist on native and Wasm only.

## Gateway connections

Gateway connections use `gaato/mttp/ws`. On JavaScript, the host must provide
a WebSocket API (Node.js 22 and later include it); see
[mttp's host support](https://github.com/gaato/mttp/blob/main/mttp/hosts/README.md#websockets).
A message may be up to 64 MiB by default, in either direction
(`max_message_bytes=`). Past the limit, the connection closes with code 1009.

## Guides

The [guides](https://github.com/gaato/discord.mbt/blob/main/guide/README.md)
cover each part in depth, and their code compiles and runs in the test suite:

1. [Getting started](https://github.com/gaato/discord.mbt/blob/main/guide/01-getting-started.mbt.md):
   a minimal slash-command bot and command synchronization
2. [Commands](https://github.com/gaato/discord.mbt/blob/main/guide/02-commands.mbt.md):
   typed arguments, autocomplete, subcommands, context menus, and Discord's
   three-second deadline
3. [Components and modals](https://github.com/gaato/discord.mbt/blob/main/guide/03-components-modals.mbt.md)
4. [Events and intents](https://github.com/gaato/discord.mbt/blob/main/guide/04-events-intents.mbt.md):
   typed subscriptions, intents, sharding, sessions, compression and the cache
5. [REST](https://github.com/gaato/discord.mbt/blob/main/guide/05-rest.mbt.md):
   endpoints, rate limits, uploads and pagination
6. [HTTP interactions](https://github.com/gaato/discord.mbt/blob/main/guide/06-http-interactions.mbt.md):
   gateway-free dispatch, the native server and JavaScript hosts
7. [Structuring bots](https://github.com/gaato/discord.mbt/blob/main/guide/07-structuring-bots.mbt.md)
8. [Scaling across processes](https://github.com/gaato/discord.mbt/blob/main/guide/08-scaling-processes.mbt.md)
9. [Middleware](https://github.com/gaato/discord.mbt/blob/main/guide/09-middleware.mbt.md)
10. [Voice](https://github.com/gaato/discord.mbt/blob/main/guide/10-voice.mbt.md)
11. [The framework layer](https://github.com/gaato/discord.mbt/blob/main/guide/11-framework.mbt.md):
    handler tests without a network
12. [Models and utilities](https://github.com/gaato/discord.mbt/blob/main/guide/12-models-utilities.mbt.md)

Exact types and methods are documented in doc comments, many with examples:
browse them on mooncakes, or run `moon ide doc "@discord"`.

The repository's
[examples](https://github.com/gaato/discord.mbt/blob/main/examples/README.md)
include Gateway bots, HTTP interaction servers, JavaScript host adapters, a
Durable Object bot and voice players. Run one from the repository root with
`moon run --target native examples/slash_echo`.

## Links

- [Changelog](https://github.com/gaato/discord.mbt/blob/main/discord/CHANGELOG.md)
- [Repository](https://github.com/gaato/discord.mbt)
- [Guides](https://github.com/gaato/discord.mbt/blob/main/guide/README.md)
- [Bot template](https://github.com/gaato/discord.mbt/blob/main/template/README.md)

## License

Apache-2.0
