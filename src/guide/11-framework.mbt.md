# The framework layer

`gaato/discord/framework` sits between raw `@model.Interaction` values and the
typed `App` declarations. It does two things: route one interaction to a
registered handler, and enforce Discord's single initial callback through a
`ResponseGate`. `App` is built on it, so most applications never construct a
`Framework` — they meet this layer through `Raw` handler mode, which passes
the contexts documented here. Reach the framework directly when:

- a handler needs the full imperative response surface (`Raw` handlers in
  `App` receive these contexts),
- the executor is custom — your own gateway loop or HTTP adapter — and
  nothing else calls `process` for you,
- handlers should be exercised in tests without any network access.

Code blocks marked `mbt check` in this chapter compile and run as part of the
test suite (`moon test --target native`).

## Routing

A `Framework` binds a REST client and an application id. Registration methods
return `self` for chaining, and each interaction kind has its own routing key:

```mbt check
///|
async fn greet_handler(ctx : @framework.CommandCtx) -> Unit {
  let name = ctx.options.string("name")
  ctx.respond(content="Hello, \{name}!")
}

///|
fn build_router(
  client : @dhttp.Client,
  application_id : @model.ApplicationId,
) -> @framework.Framework {
  @framework.Framework(client, application_id)
  .command(
    @interaction.CommandSpec::slash("greet", "Greet somebody", options=[
      @interaction.string_option("name", "Who to greet", required=true),
    ]),
    greet_handler,
  )
  .component("confirm:", ctx => ctx.update_message(content="Confirmed."))
  .modal("feedback:", ctx => {
    ctx.respond(
      content=ctx.text_value("note").unwrap_or("(empty)"),
      ephemeral=true,
    )
  })
  .on_error((label, error) => println("\{label} failed: \{Repr(error)}"))
}
```

- **Commands** route by command type and top-level name, so a slash command
  and a user command may share a name. Subcommands do not register separately;
  dispatch on `ctx.options.path()` inside the handler.
- **Components** and **modals** route by `custom_id` prefix. Prefixes are
  tried in registration order; the first match wins. Component waiters (below)
  take precedence over registered component handlers.
- **Autocomplete** routes by command name via `autocomplete(name, handler)`.
- **Ping** interactions are answered with `Pong` automatically.

`process` returns `false` when nothing matched, and the interaction is left
unanswered — the executor decides whether that is worth logging. Handler
errors propagate out of `process` unless an `on_error` hook is installed;
the hook receives a `kind:name` label such as `command:greet` and the error.

The registration payload for every declared command is available as
`command_specs()`. `sync_global()` and `sync_guild(guild_id)` send it to the
bulk-overwrite endpoints. As with `App` synchronization, **a bulk overwrite
deletes commands registered outside this `Framework`** from the selected
scope; guild sync applies instantly, global sync can take up to an hour.

A `CommandSpec` serializes to exactly the JSON Discord's registration
endpoints expect:

```mbt check
///|
test "command specs serialize to the registration payload" {
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

## Driving it from an executor

An executor is anything that feeds `InteractionCreate` payloads to `process`.
The gateway version constructs the `Framework` after READY (which carries the
application id) and routes from the shard loop:

```mbt nocheck
let shard = @gateway.Shard::start(group, token~, intents~, gateway_url~)
let mut framework : @framework.Framework? = None
for ;; {
  match shard.next() {
    Dispatch(Ready(ready)) => {
      let fw = @framework.Framework(client, ready.application.id).command(
        echo_spec(),
        handle_echo,
      )
      fw.sync_guild(guild_id) |> ignore
      framework = Some(fw)
    }
    Dispatch(InteractionCreate(interaction)) => {
      guard framework is Some(fw) else { continue }
      fw.process(interaction) |> ignore
    }
    FatallyClosed(code~) => break
    _ => ()
  }
}
```

`src/examples/low_level` is the complete runnable version. HTTP executors
should not call `process` — it acknowledges through REST, while an HTTP
adapter must return the initial callback in the HTTP response body. Use
`process_with` and a capture gate (below), or better, the finished HTTP
executor in [HTTP interactions](06-http-interactions.mbt.md).

## Handler contexts

Each interaction kind gets its own context type. All four expose the bound
`client`, the `application_id`, the raw `interaction`, and the decoded `data`
payload for that kind:

| Context | Routed from | Kind-specific surface |
|---|---|---|
| `CommandCtx` | slash and context-menu commands | `options`, `model()`, `show_modal` |
| `ComponentCtx` | buttons and select menus | `message()`, `update_message`, `defer_update`, `show_modal` |
| `ModalCtx` | modal submits | `text_value(custom_id)`, `origin()` |
| `AutocompleteCtx` | focused autocomplete options | `suggest(choices)` |

`CommandCtx`, `ComponentCtx`, and `ModalCtx` share the response lifecycle:
exactly one initial callback (`respond`, `defer_response`, or a kind-specific
callback such as `update_message` or `show_modal`), then any number of
token-authenticated REST calls — `edit_response`, `followup`,
`original_response`, `delete_response`, and `get_followup` /
`edit_followup` / `delete_followup`. The initial callback goes through the
response gate; everything after it is an ordinary REST call against the
interaction token, which Discord keeps valid for 15 minutes.

`edit_response`, `followup`, and `edit_followup` return the resulting
`@model.Message`; for a followup, that return value is the only way to obtain
the id needed by a later `edit_followup` or `delete_followup`. When the message
is not needed, explicitly discard it with `|> ignore`, the idiom used
throughout this library. `respond`, `defer_*`, and `delete_*` already return
`Unit`, so a handler that never edits its followups remains uncluttered.

They also share invoker accessors. `user()` returns the invoking user, and
`scope()` distinguishes validated guild invocations (with both the guild id
and full member) from DMs. `guild_scope()` is the non-raising shortcut when
only the guild case matters:

```mbt check
///|
async fn audit_scope(ctx : @framework.CommandCtx) -> Unit {
  match ctx.scope() {
    Guild(guild) =>
      ctx.respond(
        content="\{guild.user().username} invoked from guild \{guild.guild_id}",
      )
    Dm(user) => ctx.respond(content="from a DM with \{user.username}")
  }
}
```

A payload that cannot satisfy these guarantees — no invoker, a guild member
without its user or guild id, a component interaction without its host
message — raises `InteractionContextError` (`MissingGuildId` for the missing
guild id case) from `process` before the handler runs. Inside a handler,
`user()`, `scope()`, and `ComponentCtx::message()` therefore never fail.

`ModalCtx::origin()` reports what opened the modal: `FromComponent(message)`
carries the message that hosted the component, `FromCommand` means there is
no host message. `ModalCtx::text_value(custom_id)` finds a submitted text
input anywhere in the modal's component tree.

`AutocompleteCtx` responds with `suggest`, which sends at most 25 choices:

```mbt check
///|
async fn suggest_names(ctx : @framework.AutocompleteCtx) -> Unit {
  let query = ctx.options.string_opt("name").unwrap_or("").to_lower()
  ctx.suggest(
    ["Ada", "Grace", "Linus"]
    .filter(name => query.is_empty() || name.to_lower().has_prefix(query))
    .map(name => @interaction.string_choice(name, name)),
  )
}
```

## Typed option decoding

Submitted options decode through typed accessors on `CommandOptions`
(`ctx.options` in a handler). Required accessors raise, `_opt` accessors
return `None` when absent, and subcommand paths flatten. The same decoding
is available outside a handler through `CommandOptions::from_data`:

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

For more than a couple of options, implement `@interaction.CommandModel` once
and get a typed struct from `ctx.model()` in the handler:

```mbt check
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
async fn handle_echo(ctx : @framework.CommandCtx) -> Unit {
  let echo : Echo = ctx.model()
  ctx.respond(content=Array::make(echo.times, echo.text).join("\n"))
}
```

The declarative `App` layer builds on the same accessors; its `Args` values
decode without a hand-written `CommandModel` — see
[Commands](02-commands.mbt.md).

## The response gate

Discord accepts exactly one initial callback per interaction, and only some
callback types are valid for each interaction type. `ResponseGate` enforces
both at the library boundary instead of leaving them to a REST 400: a second
initial callback raises `ResponseGateError::AlreadyResponded`, and a callback
type Discord would reject raises `ResponseGateError::InvalidCallback` before
any I/O.

| Interaction | Allowed initial callbacks |
|---|---|
| Ping | `Pong` |
| Application command | `ChannelMessageWithSource`, `DeferredChannelMessageWithSource`, `Modal`, `LaunchActivity` |
| Message component | `ChannelMessageWithSource`, `DeferredChannelMessageWithSource`, `DeferredUpdateMessage`, `UpdateMessage`, `Modal`, `LaunchActivity` |
| Autocomplete | `Autocomplete` |
| Modal submit | `ChannelMessageWithSource`, `DeferredChannelMessageWithSource`, `DeferredUpdateMessage`, `UpdateMessage` |

An interaction of unknown type accepts any callback, so a new Discord
interaction kind stays usable through `process_with` before this library
learns its rules.

A gate is constructed one of three ways:

- `ResponseGate::rest(client, interaction)` delivers the callback through
  `POST /interactions/{id}/{token}/callback`. `process` builds this gate.
- `ResponseGate::capture(interaction)` returns the gate plus a
  `ResponseCapture`; the callback value is handed to the receiver instead of
  leaving the process. `App::serve` uses this shape so HTTP adapters can
  return the callback in the HTTP response.
- `ResponseGate::ResponseGate(kind, sink)` wraps any async sink for custom
  transports.

`process_with(interaction, gate~)` routes with a caller-provided gate;
`gate.responded()` tells an executor whether the handler attempted its
initial callback.

## Testing handlers without a network

A capture gate turns handler tests into pure value tests: build an
interaction fixture, route it, and inspect the callback that would have been
sent. Nothing touches the network — the REST client is only dialed by
post-initial calls, which this handler does not make.

```mbt check
///|
fn ping_command_interaction() -> @model.Interaction raise {
  let interaction : @model.Interaction = @json.from_json(
    @json.parse(
      (
        #|{"id": "500000000000000001",
        #| "application_id": "400000000000000001",
        #| "type": 2, "token": "interaction-token", "version": 1,
        #| "data": {"id": "600000000000000001", "name": "ping", "type": 1}}
      ),
    ),
  )
  let user : @model.User = @json.from_json(
    @json.parse(
      (
        #|{"id": "200000000000000001", "username": "nelly",
        #| "discriminator": "0", "global_name": "Nelly", "avatar": null}
      ),
    ),
  )
  { ..interaction, user: Some(user) }
}

///|
async test "handlers can be exercised without any network access" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let fw = @framework.Framework(client, @model.Id::parse("400000000000000001"))
  fw.command(@interaction.CommandSpec::slash("ping", "Health check"), ctx => {
    ctx.respond(content="pong", ephemeral=true)
  })
  |> ignore
  let interaction = ping_command_interaction()
  let (gate, capture) = @framework.ResponseGate::capture(interaction)
  assert_true(fw.process_with(interaction, gate~))
  json_inspect(capture.get().response, content={
    "type": 4,
    "data": { "content": "pong", "flags": 64 },
  })
}
```

`CapturedResponse` also carries any `files` the handler attached, so multipart
callbacks are testable the same way. For handlers that do make post-initial
REST calls, install a `Client::middleware` test double and assert on the
captured route and body — the [middleware guide](09-middleware.mbt.md) shows
the pattern.

## Component waiters

`wait_for_component(custom_id~, timeout_ms?)` suspends the current handler
until the next component interaction whose `custom_id` matches exactly, and
returns `None` on timeout. Waiters win over registered component handlers,
which keeps a multi-step flow inside one handler:

```mbt nocheck
///|
async fn handle_confirm(
  ctx : @framework.CommandCtx,
  fw : @framework.Framework,
) -> Unit {
  ctx.respond(content="Really?", components=[confirm_button()])
  match fw.wait_for_component(custom_id="confirm:yes", timeout_ms=30_000) {
    Some(click) => click.update_message(content="Done!", components=[])
    None => ctx.followup(content="Timed out.", ephemeral=true) |> ignore
  }
}
```

The waiter is removed when it fires or times out, so the registered
`confirm:` prefix handler resumes receiving clicks afterwards. The App layer
exposes the same mechanism on its deferred contexts; see
[Components and modals](03-components-modals.mbt.md).

```mbt check
///|
test "framework guide declarations compile" {
  ignore(build_router)
  ignore(audit_scope)
  ignore(suggest_names)
  ignore(handle_echo)
  ignore(ping_command_interaction)
}
```
