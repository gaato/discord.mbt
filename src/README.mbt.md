# discord.mbt

A low-level Discord bot library for [MoonBit](https://www.moonbit-lang.com/)
(native backend): typed API models, a rate-limited REST client, a WebSocket
gateway shard, and a small command framework on top.

The design follows [twilight](https://github.com/twilight-rs/twilight):
loosely coupled packages that are accurate to the Discord API first, with an
ergonomic layer added on top rather than baked in.

> **Status**: pre-1.0. The API surface may still change. Gateway compression
> and sharding coordination across processes are not implemented yet.

## Install

```bash
moon add gaato/discord
```

The library targets the **native** backend and is built on
[moonbitlang/async](https://github.com/moonbitlang/async).

## Quickstart

A bot that registers a `/echo` slash command and answers it
(see `src/examples/slash_echo` for the full version):

```mbt nocheck
///|
async fn main {
  let token = @env.get_env_var("DISCORD_TOKEN").unwrap_or("")
  let client = @discord.Client::new(token)
  let gateway_url = client.get_gateway()
  @async.with_task_group(group => {
    let shard = @discord.Shard::start(
      group,
      token~,
      intents=@discord.Intents::guilds(),
      gateway_url~,
    )
    let mut framework : @discord.Framework? = None
    for ;; {
      match shard.next() {
        Dispatch(Ready(ready)) => {
          let fw = @discord.Framework::new(client, ready.application.id)
            .command(
              @discord.CommandSpec::slash("echo", "Echo your text back", options=[
                @interaction.string_option(
                  "text",
                  "What to echo",
                  required=true,
                ),
              ]),
              ctx => ctx.respond(content=ctx.options.string("text")),
            )
            .on_error((label, error) => {
              println("\{label} failed: \{to_repr(error)}")
            })
          fw.sync_global() |> ignore
          framework = Some(fw)
        }
        Dispatch(InteractionCreate(interaction)) => {
          guard framework is Some(fw) else { continue }
          fw.process(interaction) |> ignore
        }
        FatallyClosed(code~) => {
          println("closed: \{code}")
          break
        }
        _ => ()
      }
    }
  })
}
```

## Packages

| Package | What it is |
|---|---|
| `gaato/discord` | Facade: aliases for the types a typical bot names directly |
| `gaato/discord/model` | Pure data: ~24 entity domains, gateway payloads, zero IO |
| `gaato/discord/http` | REST `Client`, routes, rate limiting, multipart uploads |
| `gaato/discord/gateway` | `Shard`: connection state machine, heartbeat, resume |
| `gaato/discord/interaction` | Command specs, option builders, typed option decoding |
| `gaato/discord/framework` | Routing interactions to handlers, response contexts |
| `gaato/discord/ratelimit` | Rate limiter trait + in-memory implementation |
| `gaato/discord/queue` | Identify queue trait + in-memory implementation |

Everything below `framework` is usable on its own — a REST-only tool needs
nothing but `http` and `model`.

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
    "type": 1,
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
