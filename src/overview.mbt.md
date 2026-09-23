# discord.mbt

[![CI](https://github.com/gaato/discord.mbt/actions/workflows/ci.yml/badge.svg)](https://github.com/gaato/discord.mbt/actions/workflows/ci.yml)
[![Voice shim](https://github.com/gaato/discord.mbt/actions/workflows/voice-shim.yml/badge.svg)](https://github.com/gaato/discord.mbt/actions/workflows/voice-shim.yml)
[![Release](https://img.shields.io/github/v/release/gaato/discord.mbt)](https://github.com/gaato/discord.mbt/releases)
[![mooncakes](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fmooncakes.io%2Fapi%2Fv0%2Fmodules%2Fgaato%2Fdiscord&query=%24.version&label=mooncakes&prefix=v)](https://mooncakes.io/docs/gaato/discord)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/gaato/discord.mbt)
[![License](https://img.shields.io/github/license/gaato/discord.mbt)](LICENSE)

A Discord application library for [MoonBit](https://www.moonbitlang.com/):
typed interaction declarations, API models, a rate-limited REST client,
native/JS/moonrun Wasm HTTP interactions and WebSocket gateway shards.

The design follows [twilight](https://github.com/twilight-rs/twilight):
loosely coupled packages that model the Discord API, plus an App layer for
typed interaction declarations.

> **Status**: experimental. Minor releases may contain breaking changes; see the
> [changelog](CHANGELOG.md) for migration notes.

Long-form guides live in [`src/guide/`](src/guide/README.md); their code
blocks compile and run as part of the test suite, so the examples cannot
drift from the library. Task-focused recipes are docstring examples on the
relevant symbols — look anything up with `moon ide doc` (see
[Development](#development)).

## Prerequisites

On a clean machine, install `git` and run `moon update` before resolving the
module dependencies. Moon uses `git` to clone the package registry.

Node.js must be on `PATH` for every build, on any target and whether or not
the bot uses voice. `gaato/discord` and its `gaato/dave` dependency declare
prebuild hooks that Moon runs with `node`; without the voice opt-in variables
they exit without downloading anything, but `moon build` still fails when
`node` is missing. `moon check` does not run the hooks.

Every native build compiles the Gateway package's `zlib_stream.c`, which
always includes `<zlib.h>` even when `compress=false`. The zlib development
headers are therefore required for all native builds: install `zlib1g-dev` on
Debian/Ubuntu or `zlib-devel` on Fedora/openSUSE. The zlib shared library is
additionally required at runtime when native Gateway zlib-stream compression is used.

## Install

```sh
moon update
moon add gaato/discord
```

The interaction App, REST client, data packages, and gateway Bot executor
support **native**, **JavaScript**, and **linear-memory Wasm on moonrun**.
Voice is native-only. These executors use
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
  let app = @discord.App()
  app.command(echo)
  let bot = @discord.Bot(app, token~, sync=Global)
  bot.on(@discord.Events::ready(), (_ctx, ready) => {
    println("ready as \{ready.user.username}")
  })
  bot.run()
}
```

## Packages

| Package | What it is | Native | JS | Wasm¹ |
|---|---|---:|---:|---:|
| `gaato/discord` | Facade: golden-path names a typical application uses directly | Yes | Yes² | Yes² |
| `gaato/discord/model` | Pure data: ~24 entity domains, gateway payloads, zero IO | Yes | Yes | Yes |
| `gaato/discord/telemetry` | Structured REST, gateway, and dispatch observability values | Yes | Yes | Yes |
| `gaato/discord/http` | REST `Client`, routes, rate limiting, multipart uploads | Yes | Yes | Yes |
| `gaato/discord/gateway` | `Shard`: connection state machine, heartbeat, resume | Yes | Yes | Yes |
| `gaato/discord/voice` | Experimental native voice gateway v8, DAVE, RTP, and Opus send/receive | Yes | No | No |
| `gaato/discord/interaction` | Command/component builders, typed args and autocomplete data | Yes | Yes | Yes |
| `gaato/discord/framework` | Interaction routing, response gates, low-level response contexts | Yes | Yes | Yes |
| `gaato/discord/app` | Gateway-free typed commands/components/modals, HTTP endpoint, sync and policy | Yes | Yes | Yes |
| `gaato/discord/bot` | Gateway executor and typed gateway event descriptors | Yes | Yes | Yes |
| `gaato/discord/endpoint_http` | Signed-interactions HTTP server (`serve_interactions`) | Yes | No | Yes |
| `gaato/discord/cache` | Opt-in, gateway-driven in-memory cache | Yes | Yes | Yes |
| `gaato/discord/util` | Pure helpers: permissions, mentions, timestamps, CDN URLs | Yes | Yes | Yes |
| `gaato/discord/verify` | Pure MoonBit Ed25519 request verification | Yes | Yes | Yes |
| `gaato/discord/ratelimit` | Rate limiter trait + in-memory implementation | Yes | Yes | Yes |
| `gaato/discord/cooldown` | Command cooldown store trait + in-memory fixed windows | Yes | Yes | Yes |
| `gaato/discord/queue` | Identify queue trait + in-memory implementation | Yes | Yes | Yes |
| `gaato/discord/coordinator` | Experimental TCP coordinator for multi-process Identify, REST limits, and cooldowns | Yes | No | Yes |
| `gaato/discord/testkit` | Deterministic interaction and model fixtures | Yes | Yes | Yes |

¹ Linear-memory Wasm run by `moonrun`. The host imports come from
moonbitlang/async, so generic WASI runtimes, browsers, and wasm-gc are not
targets. See [Wasm runtime and permissions](#wasm-runtime-and-permissions).

² Voice exports exist only on native. The HTTP-server exports exist on native
and Wasm. Gateway zlib-stream compression is native-only; check
`zlib_stream_supported()` before enabling it. As on JS, the root retains DAVE in its dependency
graph, but `gaato/dave.available()` is false on Wasm and its safe constructors
raise `LibraryUnavailable`. This does not enable DAVE or Voice. Packages that
are empty on a backend do not provide that feature, even if Moon accepts them
as dependencies.

### Wasm runtime and permissions

Use `--target wasm` with the pinned MoonBit toolchain and its matching `moonrun`.
This backend uses MoonBit host APIs for sockets, TLS, timers, and environment
variables; it is not a browser, generic WASI, or wasm-gc application target.
Wasm builds do not link the voice/DAVE native libraries, and Gateway
zlib-stream compression is unavailable (leave `compress` off). Node is still
required for the build-time prebuild hooks described above.

The `interactions_http` example also builds for Wasm:

```fish
moon build --target wasm --release src/examples/interactions_http
moonrun --policy discord-policy.json _build/wasm/release/build/examples/interactions_http/interactions_http.wasm
```

An example `discord-policy.json` for that server:

```json
{
  "env": {
    "required_from_host": ["DISCORD_TOKEN", "PUBLIC_KEY"],
    "from_host": ["GUILD_ID"],
    "set": {"PORT": "8080"}
  },
  "net": {
    "connect": ["discord.com:443"],
    "bind": ["0.0.0.0:8080"]
  }
}
```

Supply credentials through the environment, never in the policy file. This
example synchronizes commands at startup; run it only when you intend to update
your application's commands. A REST-only program needs the token and outbound
connection permission but no bind permission. The coordinator needs bind
permission on its server address and connect permission on each client. Add
other destinations only for features that actually need them. In policy mode,
omitted environment, filesystem, network, and process permissions are denied.

Packages remain usable on their own. Import only what the program needs:

The facade follows the typical bot's golden path. Import the focused `http`,
`framework`, `gateway`, `coordinator`, `telemetry`, or `interaction` package for
resource refs, pagination, low-level routing and raw contexts, shard transport,
coordination, observability events, or raw option declarations.

- REST-only tool: `http` (brings `model`).
- Serverless HTTP interactions (Cloudflare Workers, Deno, Bun, and Node.js Functions,
  JS): `app` and `verify`.
- Native HTTP interactions server: `endpoint_http`.
- Gateway bot: `bot`, or the `gaato/discord` facade for everything.

## Examples

Runnable programs live under `src/examples/`:

- `slash_echo`: minimal typed Gateway bot.
- `kitchen_sink`: subcommands, autocomplete, context menus, components, and
  modals.
- `ping_gateway`: low-level Gateway and REST use.
- `low_level`: manual Framework and Shard wiring.
- `workers_echo`: Cloudflare Workers adapter.
- `deno_echo`: Deno adapter for the same MoonBit interaction App.
- `bun_echo`: Bun HTTP server adapter for the same interaction App.
- `vercel_echo`: Vercel Node.js Function adapter for the same interaction App.
- `fastly_echo`: Fastly `FetchEvent` entry point experiment.
- `lambda_url_echo`: Lambda Function URL payload v2 adapter experiment.
- `workers_gateway`: Cloudflare Durable Object running a gateway bot (no voice).
- `interactions_http`: native signed-interactions HTTP server.
- `experiments/spin_interactions`: WASIp2 Spin component for signed PING and
  immediate echo; this experiment sits outside `src/examples/`.
- `plugin_demo`: a stateful feedback feature installed as a separate package.
- `gate_probe`: live probe for error-policy recovery and user-restricted
  component waits (needs a Discord client; guild commands only).
- `voice_player`: join a voice channel and play an Ogg/Opus file.
- `voice_recorder`: record a user's voice to an Ogg/Opus file.

## App core and executors

`App` owns the interaction declaration: commands, components, modals,
autocomplete routes, and the error policy. It has no gateway dependency.
After building an App, choose an executor:

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

`CommandScope` selects global, guild, or multi-guild registration. Pass
`sync=scope` to `Bot` to synchronize once after the first READY; when omitted,
the bot makes no command request. HTTP executors never synchronize commands.
For those deployments, call `app.sync_commands(client, application_id,
scope~)` from a one-shot registration program. It returns an `@app.SyncReport`
whose `scopes` list each scope's created, updated, deleted, unchanged, and
preserved command names, plus whether an overwrite was sent.

Synchronization fetches the remote catalog and only sends a bulk-overwrite
PUT when it differs. By default (`unowned=Delete`), it removes undeclared
commands from the selected scope. The Entry Point command is always preserved,
including its id and fields unknown to this library. Use `unowned=Keep` on
`App::sync_commands` or `Framework::sync_*`, or `sync_unowned=Keep` on `Bot`,
when another process owns commands in the same scope. Bot emits one warning
per scope with deletions through `app.on_warn`. Use exactly one process for
synchronization in a multi-process deployment.

```mbt check
///|
async test "sync preserves entry points and skips an unchanged catalog" {
  let spec = @interaction.CommandSpec::slash("ping", "Ping")
  let (payload, report) = @framework.plan_command_sync(
    [spec],
    [spec.to_json(), { "id": "10", "type": 4, "name": "Launch", "handler": 2 }],
    unowned=Delete,
  )
  assert_true(payload is None)
  assert_false(report.overwritten)
  assert_eq(report.preserved, ["4:Launch"])
}
```

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

The Cloudflare Worker, Deno, Bun, and Vercel Function HTTP adapters verify
the raw request bytes with the reusable pure MoonBit
`@discord.InteractionVerifier` before parsing. The dispatch bridge is
`App::start_signed_http` in the library. The `src/examples/interactions_js`
example is an exported wrapper plus a small `handler.js` that maps a Web
`Request` to `InteractionHttpRequest` and back; the per-host adapters
(Workers, Deno, Bun, Vercel, Fastly, Lambda) only wire their entry point and
lifetime API. The shared handler is tested on
Node.js and Bun, while the Vercel lifecycle adapter is tested with an injected
`waitUntil` collector. These local tests do not establish hosted Vercel
deployment behavior. `workers_echo` is
tested inside Cloudflare's local `workerd` runtime and supports streamed
multipart callbacks for in-memory `FileUpload` values. On native,
`@discord.serve_interactions(group, app, addr~, public_key~, token~)` is a
complete signed-interactions HTTP server. See the
[HTTP interactions guide](src/guide/06-http-interactions.mbt.md) and the
`interactions_http`, `workers_echo`, `deno_echo`, `bun_echo`, and `vercel_echo`
examples. The separate
[Spin experiment](experiments/spin_interactions/README.md) uses WASIp2 and
Spin's variables import for an immediate handler. It does not yet run the
async `App` on a general Wasm host.

The JavaScript host checks cover different boundaries:

| Host | Checked here | Remaining host integration |
| --- | --- | --- |
| Cloudflare Workers | Signed requests and deferred REST in local workerd | Production deployment |
| Deno | `Deno.serve` adapter and signed requests | Hosted lifecycle |
| Bun | Shared MoonBit handler and `Bun.serve` loopback endpoint | Hosted lifecycle |
| Node.js | Shared MoonBit handler and Web APIs | HTTP hosting and process lifecycle |
| Vercel Functions | Node.js `fetch` adapter and `waitUntil` handoff | Vercel packaging and hosted lifecycle |
| Fastly Compute | `FetchEvent` and synchronous lifetime registration with a fake event | Fastly compilation and hosted execution |
| Lambda Function URL | Payload v2 body and response conversion with local events | AWS invocation and deployment |

Other JavaScript function platforms can reuse the handler if they provide Web
`Request`, `Response`, `crypto.subtle`, and `fetch`. Their entry point,
background-work API, deployment bundle, and execution limits still need
platform-specific checks. The Spin experiment instead tests the WASIp2
component boundary.
The [host entry point survey](docs/interaction-host-entrypoints.md) records the
other host conventions and the remaining API decisions, including multipart
responses and background-work lifetime.

The JavaScript REST client supports null-body 204 responses through
`moonbitlang/async@0.22.1`; the `workers_echo` workerd suite covers a deferred
interaction-response deletion end to end. Voice remains native-only; the
gateway also runs on JavaScript and moonrun Wasm.

### Cloudflare Workers gateway

The [`workers_gateway` example](src/examples/workers_gateway/README.md) runs one
gateway shard in a Durable Object with an outbound WebSocket. A bot accepts
saved `BotSession` values through `resume~`; `bot.sessions()` returns snapshots
containing both the Gateway session and its original READY metadata. The
example stores them on a 30-second alarm so a restarted bot can process replayed
events, including interactions arriving before RESUMED. Call `bot.sessions()`
while `bot.run()` is active to capture live sessions:

```mbt nocheck
///|
fn restored_bot(
  app : @discord.App,
  token : String,
  saved : Map[Int, @discord.BotSession],
) -> @discord.Bot {
  @discord.Bot(app, token~, resume=saved)
}

///|
fn current_bot_sessions(bot : @discord.Bot) -> Map[Int, @discord.BotSession] {
  bot.sessions()
}
```

An alarm restarts a failed bot, and a five-minute cron reconciles the object's
stored enabled state after eviction or deployment. `/stop` disables those
restarts and clears the saved session because a graceful close invalidates it;
the public controls require a separate bearer secret. Snapshots are periodic:
they do not guarantee exactly-once event handling or restore application state
or optional cache contents. Cloudflare can evict an object after an outbound
socket has protected it for up to 15 minutes. The JavaScript gateway does not
support zlib-stream compression; received WebSocket messages are limited to
32 MiB, CPU to 30 seconds per event by default, and a connected object incurs
duration charges. See the example README for deployment and local test details.

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

For handler tests without a Discord connection, `Client::offline` answers REST
calls from a function you write, and the native/JS/Wasm
[`gaato/discord/testkit`](testkit/README.mbt.md) provides deterministic
interaction and model fixtures. Import the testkit only in your package's
`for "test"` block.

```fish
moon check --target native --deny-warn
moon check --target js --deny-warn
moon check --target wasm --deny-warn
moon test --target native --release   # debug native builds need a working tcc setup
moon test --target js --release
moon test --target wasm --release
moon fmt
moon -C template fmt --check
moon info --target native             # regenerate pkg.generated.mbti (API review signal)
scripts/gen_extends.py                # regenerate extends.mbt after adding or removing a ToJson type
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
