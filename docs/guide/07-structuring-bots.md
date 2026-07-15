# Structuring bots with feature installers

Put each bot feature in its own package and export an installer:

```moonbit
pub fn install_feedback(
  app : @discord.App,
  config~ : FeedbackConfig,
) -> Unit {
  app.middleware(feedback_access_policy(config))
  FeedbackFeature(config).install(app)
}
```

The installer registers middleware, commands, components, and modals that
belong to the feature. App middleware is global, so a feature-specific policy
should inspect its routed target and call `next()` for unrelated interactions.
See [Middleware](09-middleware.md) for a complete installer example. A feature
that consumes Gateway events also accepts `Bot`:

```moonbit
pub fn install_starboard(
  app : @discord.App,
  bot : @discord.Bot,
  config~ : StarboardConfig,
) -> Unit {
  install_starboard_commands(app, config)
  bot.on(@discord.Events::message_reaction_add(), (ctx, event) => {
    handle_star(event, ctx.app().http(), config)
  })
}
```

This convention keeps registration visible at the application entry point:

```moonbit
let app = @discord.App(sync=command_sync)
let bot = @discord.Bot(app, token~)

install_feedback(app, config=feedback_config)
install_starboard(app, bot, config=starboard_config)
```

## Package layout

Use one package per feature when the feature has several handlers or owns
state:

```text
src/
  features/
    feedback/
      moon.pkg
      feedback.mbt
      feedback_test.mbt
  main/
    moon.pkg
    main.mbt
```

Small features can stay in one file. The exported installer remains the
boundary, so you can move its implementation into a package later without
changing `main.mbt`.

## State in a feature struct

A struct can hold configuration and mutable state. Registered handlers capture
the struct value:

```moonbit
pub struct FeedbackFeature {
  priv config_ : FeedbackConfig
  priv mut stored_ : Int
}

pub fn FeedbackFeature::FeedbackFeature(config : FeedbackConfig) -> FeedbackFeature {
  { config_: config, stored_: 0 }
}

pub fn FeedbackFeature::install(
  self : FeedbackFeature,
  app : @discord.App,
) -> Unit {
  let modal = feedback_modal()

  app.command(feedback_command(modal, self.config_.cooldown_seconds))
  app.on_modal(
    modal,
    Deferred(ephemeral=true, (ctx, form) => {
      store_feedback(ctx.app().http(), self.config_, ctx.user(), form)
      self.stored_ += 1
      ctx.edit_original(content="Thanks. Your feedback was saved.") |> ignore
    }),
  )
}
```

Keep the feature value when another part of the bot needs to query its state:

```moonbit
let feedback = FeedbackFeature(config)
feedback.install(app)
```

Use a top-level `install_feedback` function when handlers own all access to the
state. The closures registered by `install` retain the feature value.

## Inject configuration

Read environment variables and configuration files in the application entry
point. Pass typed values to the feature:

```moonbit
pub(all) struct FeedbackConfig {
  destination_channel : @model.ChannelId
  cooldown_seconds : Int
}

let feedback_config = FeedbackConfig {
  destination_channel: feedback_channel_id,
  cooldown_seconds: 30,
}
install_feedback(app, config=feedback_config)
```

The feature package can then run tests without changing process environment or
opening network connections.

## Configure several guilds

Store guild-specific values in the configuration instead of adding one
installer per guild:

```moonbit
pub(all) struct GuildDestination {
  guild_id : @model.GuildId
  channel_id : @model.ChannelId
}

pub(all) struct MultiGuildFeedbackConfig {
  destinations : Array[GuildDestination]
  cooldown_seconds : Int
}

fn MultiGuildFeedbackConfig::destination(
  self : MultiGuildFeedbackConfig,
  guild_id : @model.GuildId,
) -> @model.ChannelId? {
  for entry in self.destinations {
    if entry.guild_id == guild_id {
      return Some(entry.channel_id)
    }
  }
  None
}
```

The handler reads `ctx.guild_id()` and rejects an unconfigured guild with a
user-facing `HandlerError`. One feature instance can then serve the configured
guilds and keep shared state where needed.

## Add checks and cooldowns at registration

Installers own the command policy for their feature:

```moonbit
let command = @discord.slash(
  name="feedback",
  description="Send feedback",
  args=@discord.Args::unit(),
  handler=Immediate((_, _) => {
    @discord.CommandReply::ShowModal(feedback_modal.show())
  }),
)
.check(@discord.guild_only())
.cooldown(seconds=config.cooldown_seconds, bucket=User)

app.command(command)
```

Call `.check` more than once when a command needs several guards. The App runs
them in registration order. Cooldown failures use the same error policy as
handler failures.

## No plugin trait or reload lifecycle

discord.mbt does not define a `Plugin` trait. An installer function composes
with `App` and `Bot` without a second lifecycle model. MoonBit links feature
packages at compile time, so runtime module reload does not fit this design.
If shared tooling later needs discovery metadata or lifecycle hooks, that use
case can define the contract.

See [`src/examples/plugin_demo`](../../src/examples/plugin_demo) for a
compiling feedback feature with injected configuration and retained state.
