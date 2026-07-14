# discord.mbt

A Discord bot library for [MoonBit](https://www.moonbit-lang.com/) (native
backend): typed API models, a rate-limited REST client, a WebSocket gateway
shard, and a high-level typed bot layer.

The design follows [twilight](https://github.com/twilight-rs/twilight):
loosely coupled packages that are accurate to the Discord API first, with an
ergonomic layer added on top rather than baked in.

> **Status**: pre-1.0. The high-level bot layer is available, but the API
> surface may still change. Gateway compression and sharding coordination
> across processes are not implemented yet.

## Install

```bash
moon add gaato/discord
```

The library targets the **native** backend and is built on
[moonbitlang/async](https://github.com/moonbitlang/async).

## Quickstart

A bot that registers a `/echo` slash command and answers it
(see `src/examples/slash_echo` for the full version):

```mbt check
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
| `gaato/discord` | Facade: aliases for the types a typical bot names directly |
| `gaato/discord/model` | Pure data: ~24 entity domains, gateway payloads, zero IO |
| `gaato/discord/http` | REST `Client`, routes, rate limiting, multipart uploads |
| `gaato/discord/gateway` | `Shard`: connection state machine, heartbeat, resume |
| `gaato/discord/interaction` | Command/component builders, typed args and autocomplete data |
| `gaato/discord/framework` | Interaction routing, response gates, low-level response contexts |
| `gaato/discord/app` | Gateway-free typed commands/components/modals, HTTP endpoint, sync and policy |
| `gaato/discord/bot` | Native gateway executor and typed gateway event descriptors |
| `gaato/discord/ratelimit` | Rate limiter trait + in-memory implementation |
| `gaato/discord/queue` | Identify queue trait + in-memory implementation |

Everything below `framework` is usable on its own — a REST-only tool needs
nothing but `http` and `model`.

## High-level bot layer

`Command[A]` pairs one handler with `Args[A]`. The argument value is the single
source of truth for both Discord's option registration payload and interaction
decoding. Build records with `Args::map1` through `Args::map8`; for nine or
more fields, compose smaller values with `zip` and `map`. `Args::custom`
remains available when a command needs a specialized decoder.

Choose a handler mode according to Discord's three-second initial-response
deadline:

- `Immediate` computes and returns a `CommandReply` before the deadline.
- `Deferred` acknowledges first, then receives a `DeferredCtx` exposing only
  `edit_original`, `followup`, and component waiting.
- `Raw` receives the underlying `CommandCtx` for imperative or unusual flows.

Typed gateway subscriptions use descriptors:

```mbt nocheck
bot.on(@discord.Events::message_create(), (ctx, message) => {
  println("\{message.author.username}: \{message.content}")
  let client = ctx.app().http()
})
```

Gateway event and service handlers receive `GatewayCtx`. Its `app()` method
returns the transport-neutral `AppCtx`; READY, shard, shutdown, and component
waiting remain gateway-only, with no reverse reference from `AppCtx`.

When `intents` is omitted, `Bot` derives non-privileged intents from these
descriptors. Privileged intents are never enabled automatically; pass them
explicitly when subscribing to member or presence events, or when message
content visibility is required.

`CommandSync` defaults to `Global`. On the first READY, the bot fetches current
commands and skips the bulk PUT when declarations already match. Guild and
multi-guild targets are also available. **Synchronization uses Discord's bulk
overwrite endpoints: commands registered outside this code are deleted from
the selected scope when a PUT is needed.** Use `Disabled` when another process
owns registration.

Install an `error_policy` to map failures to logs or interaction responses.
Handlers can raise `HandlerError::UserMessage`, `GuildOnly`,
`MissingPermission`, or `InvalidArgument` for expected failures; unexpected
errors reach the same policy with their command, autocomplete, component,
modal, event, or service origin.

Escape hatches are layered rather than hidden:

1. `AppCtx::http()` returns the typed REST `Client`; gateway handlers obtain it
   through `GatewayCtx::app()`.
2. `client.request(...)` exposes route-level raw JSON for unsupported payloads.
3. Fully manual gateway/framework wiring remains documented in
   `src/examples/low_level`.

## v3 high-level APIs

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
fn readme_v3_bot(token : String) -> @discord.Bot {
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
  @discord.Bot::new(app, token~)
}

///|
test "v3 high-level declarations are wired without network access" {
  readme_v3_bot("test-token") |> ignore
}
```

The complete runnable version is `src/examples/kitchen_sink`; it also shows a
second subcommand, `DeferredUpdate`, guild-scoped synchronization, and the
gateway lifecycle.

## HTTP interactions (experimental)

`InteractionEndpoint` dispatches the same declarations without opening a gateway.
The caller owns the task group; handlers that defer or exceed the initial
response deadline continue on that group after `handle` returns.

```mbt check
///|
async fn dispatch_http_interaction(
  app : @discord.App,
  group : @async.TaskGroup[Unit],
  token : String,
  body : Json,
) -> Json? {
  let endpoint = app.serve(group, token~, sync=false)
  endpoint.handle(body, deadline_ms=2500)
}

///|
test "HTTP adapter entry point is typed" {
  ignore(dispatch_http_interaction)
}
```

`handle` is the thin JSON form: it returns callback JSON only for `Reply`.
Adapters that need multipart files or explicit status decisions should decode
the body as `@model.Interaction` and call `handle_interaction`.

The HTTP server/Workers adapter is responsible for accepting Discord's Ping
handshake request, reading the raw request body, and validating
`X-Signature-Ed25519` plus `X-Signature-Timestamp` **before** dispatch. Ed25519
verification is mandatory. Workers can use WebCrypto
`crypto.subtle.verify`; a native adapter will need a suitable implementation
such as libsodium when one is integrated. A verified Ping passed to the app
produces the Pong callback.

A typical status mapping is:

| Outcome | Suggested HTTP response |
|---|---|
| `Reply` | `200` with callback JSON, or multipart when files are present |
| `NoRoute` | `404` |
| `NoResponse` | `202` if intentional, otherwise `500` |
| `TimedOut` | `202` if background continuation is supported, otherwise `500` |

The last two are operational choices: returning `202` does not create a
Discord initial response, so handlers should normally defer before doing slow
work.

## Typed models

Every entity decodes from real API payloads. Unknown enum values and unknown
JSON keys never fail — they round-trip through `Unknown(...)` variants so a
new Discord feature cannot break your bot:

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

Discord's three field states are modeled explicitly: `T?` for optional,
`Nullable[T]` for nullable, and `Undefinable[T]` for PATCH arguments that
distinguish "leave unchanged" / "clear" / "set".

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

Submitted options decode through typed accessors — required accessors raise,
`_opt` accessors return `None` when absent, and subcommand paths flatten
automatically:

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

Handlers can register for `custom_id` prefixes, or wait inline for the next
click — waiters take precedence, which keeps multi-step flows in one place:

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

Attachments go through `multipart/form-data` transparently — pass `files` to
any message-shaped call:

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

Errors are one suberror: `Api` (Discord error object), `RateLimited`,
`Deserialize`, `Transport`, and `Validation` (cheap checks made before any
IO). Cancellation is never wrapped, so structured concurrency stays intact.

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
