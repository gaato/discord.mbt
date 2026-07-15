# Commands

Commands are declared as typed `Command[A]` values. One `Args[A]` value defines
both the Discord registration options and the value passed to the handler.

## Arguments, defaults, and choices

Combine arguments with `Args::map1` through `Args::map8`:

```moonbit
///|
struct PaintArgs {
  color : String
  coats : Int
}

///|
let paint_args : @discord.Args[PaintArgs] = @discord.Args::map2(
  @discord.arg_string(
    name="color",
    description="Paint color",
    choices=[
      @discord.string_choice("Red", "red"),
      @discord.string_choice("Blue", "blue"),
    ],
  ),
  @discord.arg_int(
    name="coats",
    description="Number of coats",
    min=1,
    max=5,
  ).with_default(1L),
  (color, coats) => { color, coats: coats.to_int() },
)
```

Use `.optional()` for `T?`, `.with_default(value)` for a defaulted value,
`.validate(check)` for application validation, and `.map(f)` for local type
conversion. For more than eight arguments, compose `Args` values with `zip`
and `map`.

## Autocomplete

Attach autocomplete to the argument that owns it. Do not combine `choices` and
`suggest` on the same argument.

```moonbit
///|
fn name_argument() -> @discord.Arg[String] {
  @discord.arg_string(
    name="name",
    description="Who to greet",
    suggest=(_, input) => {
      let query = input.to_lower()
      ["Ada", "Grace", "Linus"]
      .filter(name => query.is_empty() || name.to_lower().has_prefix(query))
      .map(name => @discord.string_choice(name, name))
    },
  )
}
```

The high-level `App` registers the generated autocomplete routes when the
command is added.

## Subcommands

Each subcommand has its own argument type and handler:

```moonbit
///|
let admin = @discord.slash_group(
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
      handler=Immediate((_, _) => {
        @discord.CommandReply::message(content="pong")
      }),
    ),
  ],
)
```

Use `subcommand_group` when Discord's extra grouping level is needed.

## Context-menu commands

User commands receive `TargetUser`; message commands receive `Message`:

```moonbit
///|
let wave = @discord.user_command(
  name="Wave",
  handler=Immediate((_, target) => {
    @discord.CommandReply::message(
      content="👋 <@\{target.user.id}>",
      ephemeral=true,
    )
  }),
)

///|
let quote = @discord.message_command(
  name="Quote",
  handler=Immediate((_, message) => {
    @discord.CommandReply::message(content="> \{message.content}")
  }),
)
```

## Handler modes

- `Immediate((ctx, value) => CommandReply)` returns the initial response.
- `Deferred(ephemeral=..., (ctx, value) => Unit)` acknowledges first; use
  `ctx.edit_original`, `ctx.followup`, or `ctx.wait_for_component` afterward.
- `Raw(ctx => Unit)` exposes the lower-level `framework.CommandCtx`.

Register every command with `app.command(command)`. Command synchronization is
controlled by `App(sync=...)`: `Global`, `Guild(id)`, `Guilds(ids)`, or
`Disabled`.

## Checks and app middleware

A command check is a per-command gate, and cooldown state is also per-command.
App middleware is application-global and wraps checks, cooldowns, and handler
dispatch for commands, components, and modals. It does not run for
autocomplete.

Use checks for command-specific permissions and preconditions. Use middleware
for policy that spans interaction kinds, or inspect its routed target to keep
the policy scoped. See [Middleware](09-middleware.md) for ordering,
short-circuiting, and error-policy behavior.
