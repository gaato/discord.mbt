# Middleware

discord.mbt has middleware at three layers: logical REST calls, routed
interactions, and decoded Gateway events. All three use the same onion model.
Code before `next` can inspect, change, or stop work; code after `next` observes
the completed inner operation.

Register middleware with the `middleware` method on `Client`, `App`, or `Bot`.
Registration returns `Unit`, so cascade syntax keeps related setup together:

```mbt check
///|
fn register_in_order(
  client : @dhttp.Client,
  app : @discord.App,
  bot : @discord.Bot,
  http_a : @dhttp.HttpMiddleware,
  http_b : @dhttp.HttpMiddleware,
  interaction_a : @app.InteractionMiddleware,
  interaction_b : @app.InteractionMiddleware,
  event_a : @bot.EventMiddleware,
  event_b : @bot.EventMiddleware,
) -> Unit {
  client..middleware(http_a).middleware(http_b)
  app..middleware(interaction_a).middleware(interaction_b)
  bot..middleware(event_a).middleware(event_b)
}
```

The first registered middleware is outermost. For `a` followed by `b`, the
order is `a-in`, `b-in`, `b-out`, `a-out`.

## Choose the chain by boundary

| Chain | What `next` wraps | What stays outside |
|---|---|---|
| `Client::middleware` | One logical REST call, including rate-limit acquisition, the wire exchange, and bounded 429 retries | Status-code mapping, typed response decoding, and the caller's code |
| `App::middleware` | Checks, command cooldowns, and command, component, or modal handler dispatch, inside the `ErrorPolicy` boundary | Autocomplete, Gateway events, and services |
| `Bot::middleware` | Typed and raw Gateway handler fan-out for one decoded event | Cache updates, decode-error observation, collectors, and interaction routing |

## HTTP middleware

An HTTP middleware receives `HttpRequest` before transport encoding. `next`
returns the final `HttpResponse` after any internal 429 retries and before a
Discord error status becomes `DiscordHttpError::Api`.

This middleware logs the logical call and adds an extra wire header:

```mbt check
///|
fn http_logging() -> @dhttp.HttpMiddleware {
  (request, next) => {
    let req_method = to_repr(request.route.method_())
    let path = request.route.path()
    println("http -> \{req_method} \{path}")
    request.headers["x-client-feature"] = "example-bot"
    let response = next(request)
    println("http <- \{req_method} \{path} \{response.status}")
    response
  }
}

///|
fn install_http_logging(client : @dhttp.Client) -> Unit {
  client.middleware(http_logging())
}
```

Extra headers are merged after the client's base headers. For requests with a
body, transport encoding still chooses the final `content-type`.

A middleware can return an `HttpResponse` without calling `next`. This is
useful for a test double or a carefully scoped cache:

```mbt check
///|
fn mock_gateway(body : Json) -> @dhttp.HttpMiddleware {
  (request, next) => {
    match request.route {
      @dhttp.Route::GetGateway =>
        { status: 200, headers: { "x-middleware-cache": "hit" }, body }
      _ => next(request)
    }
  }
}
```

The synthetic response still passes through outer middleware and normal
status-code mapping. It does not enter the rate limiter or transport.

HTTP middleware runs once per logical call, not once per attempt. A 429
followed by a successful retry produces one return from `next`, containing the
successful response. Use HTTP telemetry when per-attempt visibility is
required.

## Interaction middleware

`App::middleware` is application-global. It runs for commands, components,
and modals, but not autocomplete. `InteractionCtx` exposes the routed target,
interaction, user, invocation scope, optional guild ID, and `guild_scope()`
for a validated guild id/member bundle (raising `GuildOnly` in DMs).

A ban list can reject an interaction with the same error used by a failed
command check:

```mbt check
///|
fn deny_banned_users(banned : Set[@model.UserId]) -> @app.InteractionMiddleware {
  (ctx, next) => {
    if banned.contains(ctx.user().id) {
      raise @discord.HandlerError::CheckFailed
    }
    next()
  }
}

///|
fn install_ban_list(
  app : @discord.App,
  banned_users : Set[@model.UserId],
) -> Unit {
  app.middleware(deny_banned_users(banned_users))
}
```

Because the chain is inside the application's error-policy boundary,
`CheckFailed` reaches the policy exactly as it would from a `CommandCheck`.
The same middleware also applies to components and modals, where command
checks do not run.

For a short-circuit with an initial response, call `respond` and do not call
`next`:

```mbt check
///|
fn maintenance_mode(enabled : Ref[Bool]) -> @app.InteractionMiddleware {
  (ctx, next) => {
    if enabled.val {
      ctx.respond(
        "Maintenance is in progress. Try again shortly.",
        ephemeral=true,
      )
    } else {
      next()
    }
  }
}

///|
fn install_maintenance(
  app : @discord.App,
  maintenance_enabled : Ref[Bool],
) -> Unit {
  app.middleware(maintenance_mode(maintenance_enabled))
}
```

Interaction middleware uses Discord's three-second initial-response window.
If the initial response is not sent within three seconds, Discord invalidates
the interaction token. Do not perform heavy work before `next()`. Respond from
middleware when it owns the result, or call `next()` promptly into a
`Deferred` handler so the handler can acknowledge before doing slow work.
`InteractionCtx` itself has no defer method.

## Rich error-policy responses

The error policy receives the invoking user and, for interaction failures, an
optional raw context. Prefer `respond_error` for replies because it selects an
initial response or followup according to the current response phase:

```mbt check
///|
fn install_rich_error_policy(app : @discord.App) -> Unit {
  app.error_policy((failure, error) => {
    let username = match failure.user() {
      Some(user) => user.username
      None => "unknown user"
    }
    let source = match failure.raw() {
      Some(@app.FailureRaw::RawCommand(_)) => "command"
      Some(@app.FailureRaw::RawComponent(_)) => "component"
      Some(@app.FailureRaw::RawModal(_)) => "modal"
      None => "event or service"
    }
    failure.respond_error(
      embeds=[
        @model.Embed(
          title="Request failed",
          description="source: \{source}\nuser: \{username}\n\{to_repr(error)}",
          color=0xED4245,
        ),
      ],
      components=[
        @discord.action_row([
          @discord.button(
            custom_id="error:dismiss",
            label="Dismiss",
            style=Danger,
          ),
        ]),
      ],
      ephemeral=true,
    )
  })
}

///|
test "rich error policy declaration compiles" {
  ignore(install_rich_error_policy)
}
```

`FailureCtx::user()` and `raw()` return `None` for Gateway event and service
failures. In that case `respond_error` sends a summary to the warning hook
because there is no interaction response target. The raw command, component,
and modal contexts are escape hatches; responding through them directly can
violate the response phase, so ordinary policies should continue to use
`respond_error`. Its optional `content`, `embeds`, `components`, `files`, and
`allowed_mentions` parameters are passed through for both initial responses
and followups.

## Gateway event middleware

`Bot::middleware` is native-only. It receives the `GatewayCtx`, a decoded
`Event`, and `next(event)`. Not calling `next` drops the event from typed and
raw handlers while leaving wire-level processing intact.

This filter ignores messages authored by bots:

```mbt check
///|
fn ignore_bot_messages() -> @bot.EventMiddleware {
  (_, event, next) => {
    match event {
      @model.Event::MessageCreate(created) if created.message.author.bot
        is Some(true) => ()
      _ => next(event)
    }
  }
}
```

Middleware may also pass a rebuilt event to downstream middleware and
handlers:

```mbt check
///|
fn tag_message_content() -> @bot.EventMiddleware {
  (_, event, next) => {
    match event {
      @model.Event::MessageCreate(created) => {
        let message = {
          ..created.message,
          content: "[gateway] \{created.message.content}",
        }
        next(@model.Event::MessageCreate({ ..created, message, }))
      }
      _ => next(event)
    }
  }
}

///|
fn install_event_filters(bot : @discord.Bot) -> Unit {
  bot..middleware(ignore_bot_messages()).middleware(tag_message_content())
}
```

Only handlers see the transformed event. Cache updates, collectors,
decode-error observation, and interaction routing have already received the
decoded wire event. In particular, dropping every event here does not disable
slash-command routing through `App`.

The event chain runs serially in each shard's dispatch loop, and `next`
returns once handlers have been spawned rather than when they finish. Return
promptly, just as a telemetry hook must. A dropped event emits no
`EventDispatched` telemetry. Middleware cannot widen configured intents or
the Gateway event filter. If event middleware raises, the bot reports it to
the warning sink and continues the dispatch loop.

## Before and after `next`

Use the onion boundary deliberately: raise or short-circuit before `next`, and
observe or clean up after it returns. This matters most for interaction
middleware. An error raised after `next()` returns is reported to the error
policy with phase `BeforeInitial`. If the inner handler already sent an
initial response, the policy cannot replace it and the failure may degrade to
a warning.

HTTP middleware can inspect the final wire status, headers, and body after
`next(request)`. Event middleware can inspect only the completion of handler
fan-out; handlers themselves keep running independently.

## Checks and middleware

A command check is a per-command gate, and cooldown state is also per-command.
Both belong to the command declaration. Checks are the right place for rules
such as guild-only or permission requirements. App middleware is global and
wraps commands, components, and modals around their checks, cooldowns, and
handlers.

See [Commands](02-commands.mbt.md) for command checks and cooldowns. Use app
middleware for policy that truly spans interaction kinds, or inspect
`ctx.target()` when a global chain should affect only selected routes.

## Install middleware with a feature

A feature installer can register middleware and declarations together:

```mbt check
///|
fn moderation_command() -> @discord.Command[Unit] {
  @discord.slash(
    name="ban",
    description="Ban a user",
    args=@discord.Args::unit(),
    handler=Raw(_ => ()),
  )
}

///|
fn unban_command() -> @discord.Command[Unit] {
  @discord.slash(
    name="unban",
    description="Unban a user",
    args=@discord.Args::unit(),
    handler=Raw(_ => ()),
  )
}

///|
pub fn install_moderation(
  app : @discord.App,
  banned~ : Set[@model.UserId],
) -> Unit {
  app.middleware(deny_banned_users(banned))
  app.command(moderation_command())
  app.command(unban_command())
}

///|
test "middleware declarations compile" {
  ignore(register_in_order)
  ignore(install_http_logging)
  ignore(mock_gateway)
  ignore(install_ban_list)
  ignore(install_maintenance)
  ignore(install_event_filters)
}
```

This keeps all registration visible at the composition root. Remember that
app middleware remains global even when a feature installs it; match on
`ctx.target()` if the policy belongs only to that feature's commands,
components, or modals.

The installer is an ordinary function, not a plugin object. See
[Structuring bots with feature installers](07-structuring-bots.mbt.md) for the
package pattern and why discord.mbt does not define a `Plugin` trait.

## Telemetry

Middleware wraps work; telemetry observes it. `Client` and `Bot` expose
dependency-free structured telemetry callbacks through `on_telemetry`. `Bot`
aggregates its shard, dispatch, decode-error, and REST client events, and
shard-scoped events carry the shard id:

```mbt check
///|
fn install_telemetry(bot : @discord.Bot) -> Unit {
  bot.on_telemetry(event => {
    match event {
      HttpRequest(route_bucket~, status~, duration_ms~, retries~, ..) =>
        println("http \{route_bucket} \{status} \{duration_ms}ms x\{retries}")
      ShardHeartbeatLatency(shard_id~, latency_ms~) =>
        println("shard \{shard_id} heartbeat \{latency_ms}ms")
      DecodeError(marker~) => println(marker)
      _ => ()
    }
  })
}

///|
test "telemetry declarations compile" {
  ignore(install_telemetry)
}
```

Callbacks run synchronously in the request or dispatch path — enqueue or
record values promptly rather than perform blocking work, the same contract
event middleware has. Unlike HTTP middleware, which returns once per logical
call, HTTP telemetry reports per-attempt values such as `HttpRateLimited`.

Telemetry is an additional channel: `App::on_warn` and `Bot::on_decode_error`
retain their behavior, and a telemetry callback failure is reported through
the warning hook instead of being silently discarded. Standalone clients
install the same observer with `client.on_telemetry` and configure the
warning sink with `client.on_warn`.
