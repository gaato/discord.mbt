# discord.mbt

A Discord application library for [MoonBit](https://www.moonbit-lang.com/):
typed interaction declarations, API models, a rate-limited REST client,
JS/serverless HTTP interactions, and a native WebSocket gateway shard.

The design follows [twilight](https://github.com/twilight-rs/twilight):
loosely coupled packages that model the Discord API, plus an App layer for
typed interaction declarations.

> **Status**: pre-1.0. The App and executor APIs may still change.

Long-form guides and task-focused recipes are in
[`docs/`](docs/index.md). Generate the complete API reference with
`moon doc`; package roles and reference commands are listed in
[`docs/reference.md`](docs/reference.md).

## Install

```bash
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
    (text, times) => { text, times: times.to_int() },
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
  let app = @discord.App::new()
  app.command(echo)
  let bot = @discord.Bot::new(app, token~)
  bot.on(@discord.Events::ready(), (_ctx, ready) => {
    println("ready as \{ready.user.username}")
  })
  bot.run()
}

///|
test "quickstart is wired" {
  ignore(run_echo_bot)
}
```

## Packages

| Package | What it is |
|---|---|
| `gaato/discord` | Facade: aliases for the types a typical application names directly |
| `gaato/discord/model` | Pure data: ~24 entity domains, gateway payloads, zero IO |
| `gaato/discord/telemetry` | Structured REST, gateway, and dispatch observability values |
| `gaato/discord/http` | REST `Client`, routes, rate limiting, multipart uploads |
| `gaato/discord/gateway` | `Shard`: connection state machine, heartbeat, resume |
| `gaato/discord/interaction` | Command/component builders, typed args and autocomplete data |
| `gaato/discord/framework` | Interaction routing, response gates, low-level response contexts |
| `gaato/discord/app` | Gateway-free typed commands/components/modals, HTTP endpoint, sync and policy |
| `gaato/discord/bot` | Native gateway executor and typed gateway event descriptors |
| `gaato/discord/ratelimit` | Rate limiter trait + in-memory implementation |
| `gaato/discord/queue` | Identify queue trait + in-memory implementation |
| `gaato/discord/coordinator` | Native TCP coordinator for multi-process Identify and REST limits |

Packages remain usable on their own. A REST-only tool needs `http` and `model`.

## App core and executors

`App` owns the interaction declaration: commands, components, modals,
autocomplete routes, command synchronization, and the error policy. It has no
gateway dependency. After building an App, choose an executor:

- `Bot::new(app, token~)` connects to the gateway and routes
  `InteractionCreate` events through the App.
- `app.serve(group, token~)` creates an `InteractionEndpoint` for an HTTP
  adapter.

Both executors use the same handlers. You can move an application between a
persistent gateway process and an HTTP or serverless deployment without
rewriting its interaction declarations.

`Command[A]` pairs one handler with `Args[A]`. The argument value drives both
Discord's registration payload and interaction decoding. Build records with
`Args::map1` through `Args::map8`; for nine or more fields, compose smaller
values with `zip` and `map`. Use `Args::custom` for a specialized decoder.

Choose a handler mode based on Discord's three-second initial-response
deadline:

- `Immediate` computes and returns a `CommandReply` before the deadline.
- `Deferred` acknowledges first, then receives a `DeferredCtx` with
  `edit_original`, `followup`, and component waiting.
- `Raw` receives the underlying `CommandCtx` for imperative flows.

Interaction contexts expose the executor-neutral `AppCtx` through `app()`.
`AppCtx::http()` returns the REST client, and `AppCtx::application_id()` returns
the application id.

### Gateway executor

`Bot` adds gateway event and service registration. Typed subscriptions use
event descriptors:

```mbt nocheck
bot.on(@discord.Events::message_create(), (ctx, event) => {
  let message = event.message
  println("\{message.author.username}: \{message.content}")
  let client = ctx.app().http()
})
```

Gateway handlers receive `GatewayCtx`. Its `app()` method returns the same
executor-neutral `AppCtx`; READY data, shard access, shutdown, and component
waiting stay on `GatewayCtx`.

Use `ctx.wait_for(Events::message_create(), predicate, timeout_ms=30_000)` for
a one-shot typed gateway-event observation. Multiple collectors can observe
the same event, and normal event handlers still receive it. Waiting does not
add gateway intents dynamically; configure the required intent when it is not
already implied by a registered handler.

If you omit `intents`, `Bot` derives non-privileged intents from typed event
subscriptions. Pass privileged intents for member or presence events and for
message content visibility. Raw event handlers cannot imply an intent set, so
applications using them must pass `intents`.

#### Sharding

`Bot` runs one shard by default (`ShardConfig::Single(id=0, count=1)`). To run
several shards in this process, pass `shards`:

```mbt nocheck
///|
/// Discord's recommended count, all shards in this process.
let auto_bot : @discord.Bot = @discord.Bot::new(app, token~, shards=Auto)

///|
/// An explicit slice of a larger logical shard set.
let sliced_bot : @discord.Bot = @discord.Bot::new(
  app,
  token~,
  shards=Range(ids=[0, 1], count=8),
)
```

All shards share one dispatch path, so handlers, the cache, collectors, and
telemetry observe every shard; telemetry events carry the shard id. Identify
calls are serialized through an `IdentifyQueue` honoring the
`max_concurrency` bucket rules from `GET /gateway/bot`, and startup fails with
`SessionStartLimitExceeded` when the selected shards would exhaust the
remaining session allowance. Multi-process deployments can use the bundled
TCP coordinator with `RemoteIdentifyQueue` and `RemoteRateLimiter`; see
[`docs/guide/08-scaling-processes.md`](docs/guide/08-scaling-processes.md).

#### Gateway compression

Gateway `zlib-stream` compression is opt-in on native builds. Pass
`compress=true` to `Bot::new` (or `Shard::start` at the lower level):

```mbt nocheck
///|
let bot = @discord.Bot::new(app, token~, compress=true)
```

The client adds `compress=zlib-stream` to each Gateway connection and retains
one inflate context for that connection, including across consecutive Gateway
messages. Only server-to-client binary messages are decompressed; identify,
heartbeat, and other client-to-server payloads remain uncompressed text.
The zlib shared library is loaded at runtime (like the async runtime loads
OpenSSL), so neither this library nor applications using it need extra link
flags; building only requires the zlib header. If the shared library is
missing at runtime, enabling compression raises before any connection is
attempted. A successful compressed connection emits
`ShardCompressionEnabled` telemetry.

When a known gateway event fails typed decoding, `Bot` always reports a
`DECODE_ERROR:<event-name>:<decode-error>` summary through the `App` warning
hook without including the payload. The event still reaches raw event handlers.
Register `bot.on_decode_error((marker, payload) => ...)` to inspect the full
marker and raw payload; these callbacks run synchronously and should return
promptly. Decode-error observers do not imply gateway intents.

### Synchronization and failures

`CommandSync` belongs to `App` and defaults to `Global`. The gateway executor
synchronizes after its first READY. `App::serve` synchronizes during startup
when you pass `sync=true`; its default is `false`. Guild and multi-guild targets
are available.

**Synchronization uses Discord's bulk overwrite endpoints. A required PUT
deletes commands registered outside this App from the selected scope.** Use
`Disabled` when another process owns registration.

Install `app.error_policy(...)` to map failures to logs or interaction
responses. Handlers can raise `HandlerError::UserMessage`, `GuildOnly`,
`DmOnly`, `MissingPermission`, `OnCooldown`, or `InvalidArgument` for expected
failures. The gateway executor routes event and service failures through the
same policy.

Commands accept ordered pre-execution checks and fixed-window cooldowns:

```mbt check
///|
fn guarded_command() -> @discord.Command[Unit] {
  @discord.slash(
    name="moderate",
    description="Run a moderation action",
    args=@discord.Args::unit(),
    handler=Immediate((_, _) => {
      @discord.CommandReply::message(content="done", ephemeral=true)
    }),
  )
  .check(@discord.guild_only())
  .check(@discord.required_permissions(@model.Permissions::moderate_members()))
  .cooldown(seconds=10, bucket=User)
}

///|
test "checked command declaration is typed" {
  guarded_command() |> ignore
}
```

Checks run in registration order before argument decoding. A false result
becomes `CheckFailed`; a check can raise a more specific `HandlerError`.
Cooldown buckets are `User`, `Guild`, and `Global`, and denials use the normal
error policy with an ephemeral response by default.

For lower-level work, `client.request(...)` exposes route-level JSON, and
`src/examples/low_level` shows manual gateway and framework wiring.

## Typed interaction APIs

Subcommands carry their own typed `Args`, and autocomplete is attached directly
to the focused argument. User and message context-menu commands can coexist
with slash commands of the same name because routing uses `(type, name)`.
Components route by `custom_id` prefix; a handler can update the message,
reply, defer, or show a typed modal.

```mbt check
///|
struct ReadmeFeedback {
  topic : String
  details : String?
}

///|
fn readme_feedback_modal() -> @discord.Modal[ReadmeFeedback] {
  @discord.modal(
    custom_id="readme-feedback",
    title="Feedback",
    fields=@discord.ModalFields::map2(
      @discord.text_field(custom_id="topic", label="Topic"),
      @discord.text_field(custom_id="details", label="Details").optional(),
      (topic, details) => { topic, details },
    ),
  )
}

///|
fn readme_v3_app() -> @discord.App {
  let feedback = readme_feedback_modal()
  let app = @discord.App::new(sync=Disabled)
  app
  ..command(
    @discord.slash_group(name="demo", description="v3 demo", children=[
      @discord.subcommand(
        name="greet",
        description="Greet somebody",
        args=@discord.Args::of(
          @discord.arg_string(name="name", description="Who to greet", suggest=(
            _,
            input,
          ) => [@discord.string_choice("Use \{input}", input)]),
        ),
        handler=Immediate((_, name) => {
          @discord.CommandReply::message(content="Hello, \{name}!", components=[
            @discord.action_row([
              @discord.button(
                custom_id="readme:feedback:\{name}",
                label="Feedback",
              ),
            ]),
          ])
        }),
      ),
    ]),
  )
  ..command(
    @discord.user_command(
      name="Wave",
      handler=Immediate((_, target) => {
        @discord.CommandReply::message(
          content="👋 <@\{target.user.id}>",
          ephemeral=true,
        )
      }),
    ),
  )
  ..command(
    @discord.message_command(
      name="Quote",
      handler=Immediate((_, message) => {
        @discord.CommandReply::message(content="> \{message.content}")
      }),
    ),
  )
  ..on_component(
    prefix="readme:feedback:",
    Immediate(ctx => {
      @discord.ComponentReply::ShowModal(feedback.show(state=ctx.suffix()))
    }),
  )
  .on_modal(
    feedback,
    Immediate((ctx, form) => {
      @discord.InitialResponse::message(
        content="state=\{ctx.state().unwrap_or("none")}; " +
          "topic=\{form.topic}; details=\{form.details.unwrap_or("none")}",
        ephemeral=true,
      )
    }),
  )
  app
}

///|
test "v3 high-level declarations are wired without network access" {
  readme_v3_app() |> ignore
}
```

The App above can run behind either executor. The complete gateway version in
`src/examples/kitchen_sink` adds `Bot`, a READY subscription, a second
subcommand, and `DeferredUpdate`.

## HTTP interactions (experimental)

`App::serve(group, token~)` starts the HTTP interaction executor and returns an
`InteractionEndpoint`. It uses the App's commands, components, modals,
autocomplete routes, and error policy without opening a gateway.

```mbt check
///|
async fn dispatch_http_interaction(
  app : @discord.App,
  group : @async.TaskGroup[Unit],
  token : String,
  body : Json,
) -> Json? {
  let endpoint = app.serve(group, token~)
  endpoint.handle(body)
}

///|
test "HTTP adapter entry point is typed" {
  ignore(dispatch_http_interaction)
}
```

The caller owns the task group. A handler that defers or exceeds the initial
response deadline stays on that group after `handle` returns. `handle` accepts
decoded JSON and returns callback JSON for `Reply`. Adapters that need
multipart files or explicit outcomes should decode an `@model.Interaction` and
call `handle_interaction`.

The executor split treats serverless deployments such as Cloudflare Workers as
a first-class target. JavaScript adapters can verify the raw request with
`@discord/verify.verify_signature` before parsing or dispatching it. The helper
uses WebCrypto Ed25519 and works on Cloudflare Workers and Node 19+. It is also
re-exported as `@discord.verify_signature` on the JavaScript target. Native
adapters still bring their own Ed25519 implementation, such as libsodium.

The core library does not include an HTTP server. A Workers adapter example is
available at `src/examples/workers_echo`.

### Serverless (Cloudflare Workers) quickstart

See `src/examples/workers_echo` for request verification, the two-promise
`ctx.waitUntil` integration, build instructions, and manual deployment steps.

After verification, pass the decoded body to `endpoint.handle(body)`. A Discord
Ping produces the Pong callback.

A typical status mapping is:

| Outcome | Suggested HTTP response |
|---|---|
| `Reply` | `200` with callback JSON, or multipart when files are present |
| `NoRoute` | `404` |
| `NoResponse` | `202` if intentional, otherwise `500` |
| `TimedOut` | `202` if background continuation is supported, otherwise `500` |

The adapter chooses how to map `NoResponse` and `TimedOut`. Returning `202`
does not create a Discord initial response, so slow handlers should defer first.

## Typed models

Every entity decodes from real API payloads. Unknown enum values and unknown
JSON keys round-trip through `Unknown(...)` variants, so a new Discord feature
does not break your application:

```mbt check
///|
test "decode a user payload" {
  let user : @model.User = @json.from_json(
    @json.parse(
      (
        #|{"id": "80351110224678912", "username": "nelly",
        #| "discriminator": "0", "global_name": "Nelly", "avatar": null}
      ),
    ),
  )
  inspect(user.username, content="nelly")
  debug_inspect(user.id.value(), content="80351110224678912")
}
```

IDs are phantom-typed: a `UserId` (`Id[UserMarker]`) cannot be passed where a
`ChannelId` is expected, values above 2^53 keep full precision, and the
snowflake timestamp is one call away:

```mbt check
///|
test "snowflakes are typed and precise" {
  let id : @model.MessageId = @model.Id::parse("175928847299117063")
  debug_inspect(id.timestamp_ms(), content="1462015105796")
}
```

Discord's wire models use `T?` for optional fields and `Nullable[T]` for
nullable fields. PATCH methods expose plain optional arguments: omit one to
leave it unchanged, pass `[]` to clear an array, or use the corresponding
`clear_<field>=true` flag to clear a nullable scalar.

## Slash commands

Declare a command with builders; the spec serializes to the registration
payload Discord expects:

```mbt check
///|
test "command registration payload" {
  let spec = @interaction.CommandSpec::slash("echo", "Echo your text back", options=[
    @interaction.string_option("text", "What to echo", required=true),
    @interaction.integer_option(
      "times",
      "How many times",
      min_value=1,
      max_value=5,
    ),
  ])
  json_inspect(spec, content={
    "name": "echo",
    "description": "Echo your text back",
    "options": [
      {
        "type": 3,
        "name": "text",
        "description": "What to echo",
        "required": true,
      },
      {
        "type": 4,
        "name": "times",
        "description": "How many times",
        "min_value": 1,
        "max_value": 5,
      },
    ],
  })
}
```

Submitted options decode through typed accessors. Required accessors raise,
`_opt` accessors return `None` when absent, and subcommand paths flatten:

```mbt check
///|
test "typed option decoding" {
  let data : @model.CommandData = @json.from_json(
    @json.parse(
      (
        #|{"id": "600000000000000001", "name": "echo", "type": 1,
        #| "options": [{"name": "text", "type": 3, "value": "hi"}]}
      ),
    ),
  )
  let options = @interaction.CommandOptions::from_data(data)
  inspect(options.string("text"), content="hi")
  debug_inspect(options.int_opt("times"), content="None")
}
```

For more than a couple of options, implement `CommandModel` once and get a
typed struct in the handler:

```mbt nocheck
///|
struct Echo {
  text : String
  times : Int
}

///|
impl @interaction.CommandModel for Echo with fn from_options(options) {
  {
    text: options.string("text"),
    times: options.int_opt("times").unwrap_or(1L).to_int(),
  }
}

///|
async fn handle_echo(ctx : @discord.CommandCtx) -> Unit {
  let echo : Echo = ctx.model()
  ctx.respond(content=echo.text.repeat(echo.times))
}
```

## Components and waiters

Handlers can register for `custom_id` prefixes or wait inline for the next
click. Waiters take precedence, which keeps multi-step flows in one place:

```mbt nocheck
///|
async fn handle_confirm(
  ctx : @discord.CommandCtx,
  fw : @discord.Framework,
) -> Unit {
  ctx.respond(content="Really?", components=[confirm_button()])
  match fw.wait_for_component(custom_id="confirm:yes", timeout_ms=30_000) {
    Some(click) => click.update_message(content="Done!", components=[])
    None => ctx.followup(content="Timed out.", ephemeral=true)
  }
}
```

## File uploads

The client sends attachments as `multipart/form-data`. Pass `files` to any
message-shaped call:

```mbt nocheck
let report = @fs.read_file("report.png").binary()
ctx.respond(content="Here you go", files=[
  @discord.FileUpload::new("report.png", report, content_type="image/png"),
])
```

## REST without the gateway

`http.Client` stands alone: typed wrappers over the routes, per-bucket rate
limiting with a global window, automatic 429 retry, and a raw
`client.request(route, body?)` escape hatch for anything not wrapped yet.

```mbt nocheck
let client = @dhttp.Client::new(token)
let message = client.create_message(channel_id, content="hello")
client.create_message(channel_id, content="with reply", reply_to=message.id) |> ignore
```

Ordinary channel messages suppress `@everyone` and `@here` by default while
still parsing user and role mentions. Override this per client or per request:

```mbt nocheck
let quiet = @model.AllowedMentions::none()
let client = @dhttp.Client::new(token, default_allowed_mentions=quiet)
client.create_message(
  channel_id,
  content="No notifications",
  allowed_mentions=@model.AllowedMentions::none(),
)
|> ignore
```

Interaction responses, followups, and webhook messages omit
`allowed_mentions` unless explicitly supplied, preserving Discord's safer
users-only default for those endpoints.

Endpoints without a typed wrapper can still use the same authentication,
rate limiter, and retry path through a custom route:

```mbt nocheck
///|
let route = @dhttp.Route::custom(
  request_method=@dhttp.RequestMethod::Get,
  path="/guilds/123/stickers",
  bucket="GET:/guilds/123/stickers",
)

///|
let stickers = client.request(route)
```

Omit `bucket` for a method-and-path-derived key. For endpoints with minor
resource IDs, pass a template such as
`PATCH:/guilds/123/auto-moderation/rules/{}` so related requests share rate
limit state.

Invalid custom route metadata raises `CustomRouteError` before any I/O.
Request failures use `DiscordHttpError`: `Api` (Discord error object),
`RateLimited`, `Timeout`, `Deserialize`, `Transport`, and `Validation` (cheap
checks made before any I/O). Configure the whole-request deadline, 429 retry
count, and pool size when constructing a client:

```mbt nocheck
///|
let client = @dhttp.Client::new(
  token,
  request_timeout_ms=15_000,
  max_retries=4,
  max_connections=8,
)
```

### Observability

`Client` and `Bot` expose dependency-free structured telemetry callbacks.
`Bot` aggregates its shard, dispatch, decode-error, and REST client events.
Callbacks are synchronous and should enqueue or record values promptly rather
than perform blocking work.

```mbt nocheck
bot.on_telemetry(event => {
  match event {
    HttpRequest(route_bucket~, status~, duration_ms~, retries~, ..) =>
      metrics.http(route_bucket, status, duration_ms, retries)
    ShardHeartbeatLatency(shard_id~, latency_ms~) =>
      metrics.gateway_latency(shard_id, latency_ms)
    DecodeError(marker~) => logger.error(marker)
    _ => ()
  }
})
```

Telemetry is an additional channel: `App::on_warn` and
`Bot::on_decode_error` retain their existing behavior. A telemetry callback
failure is reported through the warning hook instead of being silently
discarded. Standalone clients can configure that sink with `client.on_warn`.

### Client-bound handles

Lightweight handles bind common Discord ids to a `Client` while keeping model
values as pure data. Their methods delegate to the same typed wrappers, rate
limiter, and validation path as direct client calls.

```mbt nocheck
let channel = client.channel_ref(channel_id)
let sent = channel.send(content="hello")
client.ref_of_message(sent).edit(content="hello again") |> ignore
```

Gateway handlers can derive a message handle directly from a message-create
event:

```mbt nocheck
bot.on(@discord.Events::message_create(), (ctx, event) => {
  if event.message.content == "!ping" {
    ctx.message_ref(event).reply(content="pong") |> ignore
  }
})
```

### Opt-in cache

`gaato/discord/cache` is a portable, gateway-driven in-memory cache. Attach it
to a native `Bot` to apply decoded events before event handlers run. The cache
only sees events allowed by the bot's configured intents.

```mbt nocheck
let cache = @cache.InMemoryCache::new(
  resources=@cache.CacheResources::new(presences=true),
  max_messages_per_channel=100,
)
bot.attach_cache(cache)

match cache.permissions_in(guild_id, channel_id, user_id) {
  Some(permissions) if permissions.contains(@model.Permissions::send_messages()) =>
    println("can send")
  _ => println("missing cache data or permission")
}
```

Guilds, channels, roles, members, users, and voice states are cached by
default. Presences and messages are disabled by default because of their
volume; enable only the resources the application reads. Entity values are
shared read-only model values, while list getters return fresh outer arrays.

### Pagination

List endpoints expose stateful `Paginator[T]` values. `next_page` returns
`None` at the end; `collect` and `each` consume the same cursor state. The
ordinary typed wrappers still perform every request, so rate limiting and 429
retry behavior are unchanged.

```mbt nocheck
let pages = client.paginate_messages(channel_id, page_size=100)
let recent = pages.collect(max=250)

let members = client.paginate_guild_members(guild_id)
members.each(user => println(user.user.unwrap().username))
```

### Pure utilities

The cache-independent `gaato/discord/util` package computes effective
permissions and formats Discord mentions, timestamps, and CDN URLs. It works
on both native and JavaScript targets and depends only on `model`.

```mbt nocheck
///|
let mention = @util.user_mention(user_id)

///|
let avatar = @util.user_avatar_url(user_id, avatar_hash, size=128)

///|
let base = @util.base_permissions(
  is_owner=false,
  everyone_permissions=everyone.permissions,
  role_permissions=member_role_permissions,
)
```

### Feature installers (plugins)

Group a feature behind `pub fn install_<feature>(app : App, config~) -> Unit`.
Pass `Bot` too when the feature subscribes to Gateway events, and keep state in
a captured struct or closure. discord.mbt does not add a plugin trait or reload
lifecycle. The [structuring bots guide](docs/guide/07-structuring-bots.md) and
`src/examples/plugin_demo` show the package layout, configuration injection,
and checks/cooldowns used by this pattern.

## Development

```bash
moon check --target native
moon test --target native --release   # debug native builds need a working tcc setup
moon fmt
moon info                             # regenerate pkg.generated.mbti (API review signal)
```

Code blocks marked `mbt check` in this README compile and run as part of the
test suite.

## License

Apache-2.0
