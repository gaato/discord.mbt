# discord.mbt

[![CI](https://github.com/gaato/discord.mbt/actions/workflows/ci.yml/badge.svg)](https://github.com/gaato/discord.mbt/actions/workflows/ci.yml)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/gaato/discord.mbt)

A Discord application library for [MoonBit](https://www.moonbitlang.com/):
typed interaction declarations, API models, a rate-limited REST client,
JS/serverless HTTP interactions, and a native WebSocket gateway shard.

The design follows [twilight](https://github.com/twilight-rs/twilight):
loosely coupled packages that model the Discord API, plus an App layer for
typed interaction declarations.

> **Status**: experimental, pre-1.0. APIs may change between releases.

Long-form guides live in [`src/guide/`](src/guide/README.md); their code
blocks compile and run as part of the test suite, so the examples cannot
drift from the library. Task-focused recipes are docstring examples on the
relevant symbols — look anything up with `moon ide doc` (see
[Development](#development)).

## Prerequisites

On a clean machine, install `git` and run `moon update` before resolving the
module dependencies. Moon uses `git` to clone the package registry.

Every native build compiles the Gateway package's `zlib_stream.c`, which
always includes `<zlib.h>` even when `compress=false`. The zlib development
headers are therefore required for all native builds: install `zlib1g-dev` on
Debian/Ubuntu or `zlib-devel` on Fedora/openSUSE. The zlib shared library is
additionally required at runtime when Gateway zlib-stream compression is used.

## Install

```sh
moon update
moon add gaato/discord
```

The interaction App, REST client, and data packages support **native** and
**JavaScript**. The gateway Bot executor is native-only. Both are built on
[moonbitlang/async](https://github.com/moonbitlang/async).

## Quickstart

Build the interaction `App`, then pass it to the gateway `Bot` executor. This
example registers and answers a `/echo` command. See
`src/examples/slash_echo` for the runnable version.

```mbt nocheck
///|
struct QuickstartEchoArgs {
  text : String
  times : Int
}

///|
async fn run_echo_bot(token : String) -> Unit {
  let args : @discord.Args[QuickstartEchoArgs] = @discord.Args::map2(
    @discord.arg_string(name="text", description="What to echo"),
    @discord.arg_int(
      name="times",
      description="How many times (1-5)",
      min=1,
      max=5,
    ).with_default(1L),
    (text, times) => { text, times: times.to_int(), },
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
  let app = @discord.App()
  app.command(echo)
  let bot = @discord.Bot(app, token~)
  bot.on(@discord.Events::ready(), (_ctx, ready) => {
    println("ready as \{ready.user.username}")
  })
  bot.run()
}
```

## Packages

| Package | What it is | Native | JS |
|---|---|---:|---:|
| `gaato/discord` | Facade: aliases for the types a typical application names directly | Yes | Yes* |
| `gaato/discord/model` | Pure data: ~24 entity domains, gateway payloads, zero IO | Yes | Yes |
| `gaato/discord/telemetry` | Structured REST, gateway, and dispatch observability values | Yes | Yes |
| `gaato/discord/http` | REST `Client`, routes, rate limiting, multipart uploads | Yes | Yes |
| `gaato/discord/gateway` | `Shard`: connection state machine, heartbeat, resume | Yes | No |
| `gaato/discord/voice` | Experimental native voice gateway v8, DAVE, RTP, and Opus send/receive | Yes | No |
| `gaato/discord/interaction` | Command/component builders, typed args and autocomplete data | Yes | Yes |
| `gaato/discord/framework` | Interaction routing, response gates, low-level response contexts | Yes | Yes |
| `gaato/discord/app` | Gateway-free typed commands/components/modals, HTTP endpoint, sync and policy | Yes | Yes |
| `gaato/discord/bot` | Native gateway executor and typed gateway event descriptors | Yes | No |
| `gaato/discord/endpoint_http` | Native signed-interactions HTTP server (`serve_interactions`) | Yes | No |
| `gaato/discord/cache` | Opt-in, gateway-driven in-memory cache | Yes | Yes |
| `gaato/discord/util` | Pure helpers: permissions, mentions, timestamps, CDN URLs | Yes | Yes |
| `gaato/discord/verify` | Pure MoonBit Ed25519 request verification | Yes | Yes |
| `gaato/discord/ratelimit` | Rate limiter trait + in-memory implementation | Yes | Yes |
| `gaato/discord/queue` | Identify queue trait + in-memory implementation | Yes | Yes |
| `gaato/discord/coordinator` | Native TCP coordinator for multi-process Identify and REST limits | Yes | No |

\* The facade's gateway and HTTP-server exports exist only on native.
WebAssembly is not currently enabled or validated as an application target in
this repository.

Packages remain usable on their own. A REST-only tool needs `http` and `model`.
The dependency graph, generated from the `moon.pkg` declarations by
`tools/package_graph` and transitively reduced:

<!-- Absolute URL: mooncakes.io serves only README.md, so relative image paths break there. -->
![Package dependency graph](https://raw.githubusercontent.com/gaato/discord.mbt/main/docs/packages.svg)

Amber nodes are native-only; every other package also runs on JS.

## Examples

Runnable programs live under `src/examples/`:

- `slash_echo`: minimal typed Gateway bot.
- `kitchen_sink`: subcommands, autocomplete, context menus, components, and
  modals.
- `ping_gateway`: low-level Gateway and REST use.
- `low_level`: manual Framework and Shard wiring.
- `workers_echo`: Cloudflare Workers adapter.
- `interactions_http`: native signed-interactions HTTP server.
- `plugin_demo`: a stateful feedback feature installed as a separate package.
- `voice_player`: join a voice channel and play an Ogg/Opus file.
- `voice_recorder`: record a user's voice to an Ogg/Opus file.

## App core and executors

`App` owns the interaction declaration: commands, components, modals,
autocomplete routes, command synchronization, and the error policy. It has no
gateway dependency. After building an App, choose an executor:

- `Bot(app, token~)` connects to the gateway and routes
  `InteractionCreate` events through the App.
- `app.serve(group, token~)` creates an `InteractionEndpoint` for an HTTP
  adapter.

Both executors use the same handlers, so an application can move between a
persistent gateway process and an HTTP or serverless deployment without
rewriting its interaction declarations.

`Command[A]` pairs one handler with `Args[A]`; the argument value drives both
Discord's registration payload and interaction decoding (build records with
`Args::map1` through `Args::map8`). Choose a handler mode against Discord's
three-second initial-response deadline: `Immediate` computes and returns a
`CommandReply` before it, `Deferred` acknowledges first and continues on a
`DeferredCtx`, and `Raw` receives the underlying `CommandCtx` for imperative
flows. Subcommands carry their own typed `Args`, autocomplete attaches
directly to the focused argument, and context-menu commands, components, and
typed modals route through the same App — see the
[commands](src/guide/02-commands.mbt.md) and
[components and modals](src/guide/03-components-modals.mbt.md) guides.

`Client`, `App`, and `Bot` each accept onion-style middleware — around one
logical REST call, around routed interaction dispatch, and around gateway
event fan-out — plus structured telemetry callbacks. See the
[middleware guide](src/guide/09-middleware.mbt.md).

### Gateway executor

`Bot` adds typed gateway event subscriptions and services:

```mbt nocheck
bot.on(@discord.Events::message_create(), (ctx, event) => {
  let message = event.message
  println("\{message.author.username}: \{message.content}")
})
```

If `intents` is omitted, `Bot` derives non-privileged intents from typed
subscriptions; pass privileged intents (members, presences, message content)
explicitly, and pass the full set when raw event handlers are used.
`ctx.wait_for(...)` makes one-shot typed event observations inside a handler.
The [events and intents guide](src/guide/04-events-intents.mbt.md) covers
descriptors, intent derivation, decode-error observers, opt-in `zlib-stream`
compression, and the gateway-driven in-memory cache.

Several shards can run in one process behind the same dispatch path, so
handlers, the cache, collectors, and telemetry observe every shard:

```mbt nocheck
///|
let bot = @discord.Bot(app, token~, shards=Auto)
```

Identify calls honor the `max_concurrency` bucket rules from
`GET /gateway/bot`, and multi-process deployments can share Identify and REST
limits through the bundled TCP coordinator. See the
[scaling guide](src/guide/08-scaling-processes.mbt.md).

### Voice (experimental)

Native builds can join voice gateway v8 calls, play 20 ms Opus frames, and
receive per-user Opus streams. Discord requires DAVE encryption, so voice
applications use the native-only
[`gaato/dave`](https://github.com/gaato/dave.mbt) binding to Discord's
official `libdave` for MLS and media encryption. The separate Rust library in
`voice-shim/` handles RTP transport AEAD only. `gaato/dave` currently pins
upstream `v1.2.0/cpp`; `gaato/discord` pins transport component release
`voice-shim-v0.1.0`. A native voice build can bootstrap and verify both
prebuilt runtimes without installing Cargo. See the
[voice guide](src/guide/10-voice.mbt.md) for installation and runtime limits,
the `dave_probe`, `voice_player`, and `voice_recorder` examples, and the accepted design in
[`src/voice/DESIGN.md`](src/voice/DESIGN.md).

### Synchronization and failures

`CommandSync` belongs to `App` and defaults to `Global`. The gateway executor
synchronizes after its first READY; `App::serve` synchronizes during startup
only when you pass `sync=true`. Guild and multi-guild targets are available.

**Synchronization uses Discord's bulk overwrite endpoints. A required PUT
deletes commands registered outside this App from the selected scope.** Use
`Disabled` when another process owns registration.

Install `app.error_policy(...)` to map failures to logs or interaction
responses; handlers raise `HandlerError` variants such as `UserMessage` or
`MissingPermission` for expected failures, and commands accept ordered
pre-execution checks and fixed-window cooldowns. See the
[structuring bots guide](src/guide/07-structuring-bots.mbt.md).

## HTTP interactions (experimental)

`App::serve(group, token~)` starts the HTTP interaction executor and returns
an `InteractionEndpoint` that uses the App's declarations and error policy
without opening a gateway. `handle` accepts decoded interaction JSON and
returns callback JSON for `Reply`; the caller owns the task group, so
handlers that defer keep running on it after `handle` returns:

```mbt nocheck
///|
async fn handle_http_interaction(
  app : @discord.App,
  group : @async.TaskGroup[Unit],
  token : String,
  body : Json,
) -> Json? {
  app.serve(group, token~).handle(body)
}
```

Serverless targets such as Cloudflare Workers are first class: adapters verify
the raw request bytes with the reusable pure MoonBit
`@discord.InteractionVerifier` before parsing. The `workers_echo` example is
tested inside Cloudflare's local `workerd` runtime and supports streamed
multipart callbacks for in-memory `FileUpload` values. On native,
`@discord.serve_interactions(group, app, addr~, public_key~, token~)` is a
complete signed-interactions HTTP server. See the
[HTTP interactions guide](src/guide/06-http-interactions.mbt.md) and the
`interactions_http` and `workers_echo` examples.

The JavaScript REST client supports null-body 204 responses through
`moonbitlang/async@0.22.1`; the `workers_echo` workerd suite covers a deferred
interaction-response deletion end to end. Gateway and Voice transports remain
native-only.

## Typed models

Every entity decodes from real API payloads, and unknown enum values and
unknown JSON keys round-trip through `Unknown(...)` variants, so a new
Discord feature does not break your application. IDs are phantom-typed
snowflakes — a `UserId` cannot be passed where a `ChannelId` is expected —
that keep full precision above 2^53:

```mbt nocheck
let id : @model.MessageId = @model.Id::parse("175928847299117063")
println(id.timestamp_ms()) // 1462015105796
```

Wire models use `T?` for optional fields and `Nullable[T]` for nullable
fields; PATCH methods expose plain optional arguments with
`clear_<field>=true` flags for clearing. See the
[models and utilities guide](src/guide/12-models-utilities.mbt.md).

## REST without the gateway

`http.Client` stands alone: typed wrappers over the routes, per-bucket rate
limiting with a global window, automatic 429 retry, multipart file uploads,
and a raw `client.request(route)` escape hatch for anything not wrapped yet.
Ordinary channel messages suppress `@everyone` and `@here` by default while
still parsing user and role mentions.

```mbt nocheck
let client = @dhttp.Client(token)
let message = client.create_message(channel_id, content="hello")
client.create_message(channel_id, content="with reply", reply_to=message.id)
|> ignore
```

Every endpoint with a resource anchor is also available through client-bound
refs, which chain from parent to child resource before applying a verb:

```mbt nocheck
client.guild_ref(guild_id).emoji_ref(emoji_id).edit(name="renamed") |> ignore
```

Validation failures raise before any I/O, request failures use
`DiscordHttpError`, and list endpoints expose stateful `Paginator[T]` values.
The [REST guide](src/guide/05-rest.mbt.md) covers the full ref surface,
allowed mentions, file uploads, pagination, and custom routes.

Also in the box, each with its guide chapter:

- an opt-in, gateway-driven in-memory cache —
  [events and intents](src/guide/04-events-intents.mbt.md);
- pure helpers for permissions, mentions, timestamps, and CDN URLs —
  [models and utilities](src/guide/12-models-utilities.mbt.md);
- structured REST, gateway, and dispatch telemetry —
  [middleware](src/guide/09-middleware.mbt.md);
- a feature-installer convention for structuring larger bots —
  [structuring bots](src/guide/07-structuring-bots.mbt.md);
- the interaction router, response gates, and no-network handler testing
  under `App` — [the framework layer](src/guide/11-framework.mbt.md).

## Development

```fish
moon check --target native --deny-warn
moon check --target js --deny-warn
moon test --target native --release   # debug native builds need a working tcc setup
moon test --target js --release
moon fmt
moon -C template fmt --check
moon -C tools/package_graph fmt --check
moon info --target native             # regenerate pkg.generated.mbti (API review signal)
```

Look up any package, type, or symbol — including its docstring examples —
from the terminal:

```fish
moon ide doc "@discord"
moon ide doc "@http.Client::create_message"
moon ide doc "@model.Message"
moon ide doc "@util.channel_permissions"
```

Each package's `pkg.generated.mbti` is a concise public-interface snapshot;
review its diff when checking API drift.

Every MoonBit code block in this README has a compiled twin in
`src/readme_native_test.mbt`, and code blocks marked `mbt check` in the
[guides](src/guide/README.md) and in docstrings compile and run as part of
the test suite.

## License

Apache-2.0
