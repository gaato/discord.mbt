# Commands

Commands are declared as typed `Command[A]` values. One `Args[A]` value defines
both the Discord registration options and the value passed to the handler.

Code blocks marked `mbt check` in this chapter compile and run as part of the
test suite (`moon test --target native`).

## Arguments, defaults, and choices

Combine arguments with `Args::map1` through `Args::map8`:

```mbt check
///|
struct PaintArgs {
  color : String
  coats : Int
} derive(Debug)

///|
let paint_args : @discord.Args[PaintArgs] = @discord.Args::map2(
  @discord.arg_string(name="color", description="Paint color", choices=[
    @discord.string_choice("Red", "red"),
    @discord.string_choice("Blue", "blue"),
  ]),
  @discord.arg_int32(name="coats", description="Number of coats", min=1, max=5).with_default(
    1,
  ),
  (color, coats) => { color, coats, },
)
```

Use `.optional()` for `T?`, `.with_default(value)` for a defaulted value,
`.validate(check)` for application validation, and `.map(f)` for local type
conversion. `arg_int` yields `Int64` because Discord integers exceed 32 bits;
`arg_int32` yields `Int`, registers the `Int` range when `min` or `max` is
omitted, and rejects a received value outside it instead of wrapping. The
combining function may return any type; a tuple works when a
struct is not worth declaring. For more than eight arguments, compose `Args`
values with `zip` and `map`.

## Localization

Commands, subcommands, and options accept name and description localization
maps. Choices accept name localizations. Locale keys use Discord's locale
strings, and the unlocalized name and description remain the fallback:

```mbt check
///|
let localized_greeting : @discord.Command[String] = @discord.slash(
  name="greet",
  description="Send a greeting",
  name_localizations={ "ja": "あいさつ" },
  description_localizations={ "ja": "あいさつを送信します" },
  args=@discord.Args::of(
    @discord.arg_string(
      name="style",
      description="Greeting style",
      name_localizations={ "ja": "スタイル" },
      description_localizations={ "ja": "あいさつの種類" },
      choices=[
        @discord.string_choice("Friendly", "friendly", name_localizations={
          "ja": "フレンドリー",
        }),
      ],
    ),
  ),
  handler=Immediate((_, style) => {
    @discord.CommandReply::message(content="style=\{style}")
  }),
)

///|
test "localized command declaration compiles" {
  ignore(localized_greeting.spec().to_json())
}
```

Command synchronization fetches Discord's localization dictionaries, so an
unchanged localized declaration remains in sync rather than being rewritten
on every startup.

## Autocomplete

Attach autocomplete to the argument that owns it. Do not combine `choices` and
`suggest` on the same argument.

```mbt check
///|
fn name_argument() -> @discord.Arg[String] {
  @discord.arg_string(name="name", description="Who to greet", suggest=(
    _,
    input,
  ) => {
    let query = input.to_lower()
    ["Ada", "Grace", "Linus"]
    .filter(name => query.is_empty() || name.to_lower().has_prefix(query))
    .map(name => @discord.string_choice(name, name))
  })
}
```

The high-level `App` registers the generated autocomplete routes when the
command is added.

## Subcommands

Each subcommand has its own argument type and handler:

```mbt check
///|
let admin : @discord.Command[Unit] = @discord.slash_group(
  name="admin",
  description="Administration commands",
  children=[
    @discord.subcommand(
      name="say",
      description="Send a message",
      args=@discord.Args::of(
        @discord.arg_string(name="text", description="Message text"),
      ),
      handler=Immediate((_, text) => {
        @discord.CommandReply::message(content=text)
      }),
    ),
    @discord.subcommand(
      name="ping",
      description="Check the bot",
      args=@discord.Args::unit(),
      handler=Immediate((_, _) => @discord.CommandReply::message(content="pong")),
    ),
  ],
)
```

Use `subcommand_group` when Discord's extra grouping level is needed.

## Context-menu commands

User commands receive `TargetUser`; message commands receive `Message`:

```mbt check
///|
let wave : @discord.Command[@framework.TargetUser] = @discord.user_command(
  name="Wave",
  handler=Immediate((_, target) => {
    @discord.CommandReply::message(
      content="👋 <@\{target.user.id}>",
      ephemeral=true,
    )
  }),
)

///|
let quote : @discord.Command[@model.Message] = @discord.message_command(
  name="Quote",
  handler=Immediate((_, message) => {
    @discord.CommandReply::message(content="> \{message.content}")
  }),
)

///|
test "command declarations compile" {
  ignore(paint_args)
  ignore(name_argument)
  ignore(admin)
  ignore(wave)
  ignore(quote)
}
```

## Handler modes

App-level contexts expose a validated guild bundle. `guild_scope()` returns
both the guild id and invoking member; in a DM it raises
`HandlerError::GuildOnly`, which the error policy renders like any other
expected handler failure:

```mbt check
///|
let guild_info : @discord.Command[Unit] = @discord.slash(
  name="guild-info",
  description="Show the invoking guild",
  args=@discord.Args::unit(),
  handler=Immediate((ctx, _) => {
    let guild = ctx.guild_scope()
    @discord.CommandReply::message(
      content="guild=\{guild.guild_id}, user=\{guild.user().username}",
    )
  }),
)

///|
test "guild command declaration compiles" {
  ignore(guild_info.spec())
}
```

- `Immediate((ctx, value) => CommandReply)` returns the initial response.
- `Deferred(ephemeral=..., (ctx, value) => Unit)` acknowledges first; use
  `ctx.edit_original`, `ctx.followup`, or `ctx.wait_for_component` afterward.
  Component waits default to the invoking user; pass `from=Anyone` only for a
  flow such as a public poll, or `from=User(user_id)` for a different user.
- `Raw(ctx => Unit)` exposes the lower-level `framework.CommandCtx`; see
  [The framework layer](11-framework.mbt.md) for its full response surface.
  Error policies follow the gate's real state, so a Raw handler that responds
  and then raises receives an error followup through `respond_error`.

`edit_original` and `followup` return the resulting message; append
`|> ignore` when the handler does not need it.

Register every command with `app.command(command)`. To synchronize the
declarations, pass a `CommandScope` to `Bot(sync=...)` or call
`app.sync_commands(client, application_id, scope~)` from a one-shot program.
The call returns a sync report. Both paths default to deleting undeclared
commands in the selected scope, while always preserving the Entry Point
command. Use `unowned=Keep` on `sync_commands` or `sync_unowned=Keep` on `Bot`
for a scope shared with other command owners.

```mbt check
///|
async test "command sync keeps the entry point under either ownership policy" {
  for unowned in [@framework.UnownedCommands::Delete, Keep] {
    let (_, report) = @framework.plan_command_sync(
      [],
      [{ "id": "11", "type": 4, "name": "Launch" }],
      unowned~,
    )
    assert_eq(report.preserved, ["4:Launch"])
    assert_eq(report.deleted, [])
  }
}
```

## Checks and app middleware

A command check is a per-command gate. Cooldown keys include command type,
command name, and the selected User, Guild, or Global bucket. `App()` keeps
windows in a fresh in-memory store; pass `App(cooldown_store=...)` to share them
between Apps or processes. See [Shared cooldowns](08-scaling-processes.mbt.md#shared-cooldowns).
App middleware is application-global and wraps checks, cooldowns, and handler
dispatch for commands, components, and modals. It does not run for
autocomplete. Use checks for command-specific permissions and preconditions.
Checks may call async services such as Discord REST through
`ctx.app().http()`. The command path is middleware, checks in registration
order, cooldown, argument decoding, then the handler. Checks run before the
handler can defer, so they spend Discord's three-second initial-response budget;
keep them fast or cache their results. A cooldown store is called only after
all checks pass, and commands without a cooldown never call it. Remote cooldown
acquisitions also spend that initial-response budget.
Use middleware for policy that spans interaction kinds, or inspect its routed
target to keep the policy scoped. See [Middleware](09-middleware.mbt.md) for
ordering, short-circuiting, and error-policy behavior.
