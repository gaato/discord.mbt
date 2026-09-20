# Structuring bots with feature installers

Put each bot feature in its own package and export an installer:

```mbt check
///|
pub fn install_feedback(app : @discord.App, config~ : FeedbackConfig) -> Unit {
  app.middleware(feedback_access_policy(config))
  FeedbackFeature(config).install(app)
}
```

The installer registers middleware, commands, components, and modals that
belong to the feature. App middleware is global, so a feature-specific policy
should inspect its routed target and call `next()` for unrelated interactions.
See [Middleware](09-middleware.mbt.md) for a complete installer example. A
feature that consumes Gateway events also accepts `Bot`:

```mbt check
///|
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

```mbt check
///|
fn compose(
  token : String,
  command_scope : @discord.CommandScope,
  feedback_config : FeedbackConfig,
  starboard_config : StarboardConfig,
) -> Unit {
  let app = @discord.App()
  let bot = @discord.Bot(app, token~, sync=command_scope)
  install_feedback(app, config=feedback_config)
  install_starboard(app, bot, config=starboard_config)
}
```

`sync=command_scope` uses the combined declarations from all installers.
If another process owns commands in that scope, add `sync_unowned=Keep` to
the Bot constructor to preserve them. The Entry Point command is preserved
under either policy.

```mbt check
///|
async test "feature owners can keep commands from another process" {
  for unowned in [@framework.UnownedCommands::Delete, Keep] {
    let (_, report) = @framework.plan_command_sync(
      [],
      [
        { "id": "10", "name": "other" },
        { "id": "11", "type": 4, "name": "Launch" },
      ],
      unowned~,
    )
    assert_true(report.preserved.contains("4:Launch"))
    assert_eq(report.preserved.contains("other"), unowned == Keep)
  }
}
```

The snippets in this chapter reference a few supporting declarations that a
real feature package would define; representative stubs keep the chapter
compiling:

```mbt check
///|
pub(all) struct StarboardConfig {
  threshold : Int
}

///|
fn feedback_access_policy(
  config : FeedbackConfig,
) -> @app.InteractionMiddleware {
  ignore(config)
  (_, next) => next()
}

///|
fn feedback_modal() -> @discord.Modal[String] {
  @discord.modal(
    custom_id="feedback",
    title="Feedback",
    fields=@discord.ModalFields::map1(
      @discord.text_field(custom_id="text", label="Feedback"),
      text => text,
    ),
  )
}

///|
fn feedback_command(
  modal : @discord.Modal[String],
  cooldown_seconds : Int,
) -> @discord.Command[Unit] {
  ignore(cooldown_seconds)
  @discord.slash(
    name="feedback",
    description="Send feedback",
    args=@discord.Args::unit(),
    handler=Immediate((_, _) => ShowModal(modal.show())),
  )
}

///|
async fn store_feedback(
  client : @dhttp.Client,
  config : FeedbackConfig,
  user : @model.User,
  form : String,
) -> Unit {
  client.create_message(
    config.destination_channel,
    content="feedback from \{user.username}: \{form}",
  )
  |> ignore
}

///|
fn handle_star(
  event : @model.MessageReactionAddEvent,
  client : @dhttp.Client,
  config : StarboardConfig,
) -> Unit {
  ignore(event)
  ignore(client)
  ignore(config)
}

///|
fn install_starboard_commands(
  app : @discord.App,
  config : StarboardConfig,
) -> Unit {
  ignore(app)
  ignore(config)
}
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

```mbt check
///|
pub struct FeedbackFeature {
  priv config_ : FeedbackConfig
  priv mut stored_ : Int
}

///|
pub fn FeedbackFeature::FeedbackFeature(
  config : FeedbackConfig,
) -> FeedbackFeature {
  { config_: config, stored_: 0, }
}

///|
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

```mbt check
///|
pub fn FeedbackFeature::stored(self : FeedbackFeature) -> Int {
  self.stored_
}

///|
fn keep_feature_value(app : @discord.App, config : FeedbackConfig) -> Unit {
  let feedback = FeedbackFeature(config)
  feedback.install(app)
  println("stored so far: \{feedback.stored()}")
}
```

Use a top-level `install_feedback` function when handlers own all access to the
state. The closures registered by `install` retain the feature value.

## Inject configuration

Read environment variables and configuration files in the application entry
point. Pass typed values to the feature:

```mbt check
///|
pub(all) struct FeedbackConfig {
  destination_channel : @model.ChannelId
  cooldown_seconds : Int
}

///|
fn wire_feedback(
  app : @discord.App,
  feedback_channel_id : @model.ChannelId,
) -> Unit {
  let feedback_config = FeedbackConfig::{
    destination_channel: feedback_channel_id,
    cooldown_seconds: 30,
  }
  install_feedback(app, config=feedback_config)
}
```

The feature package can then run tests without changing process environment or
opening network connections.

## Configure several guilds

Store guild-specific values in the configuration instead of adding one
installer per guild:

```mbt check
///|
pub(all) struct GuildDestination {
  guild_id : @model.GuildId
  channel_id : @model.ChannelId
}

///|
pub(all) struct MultiGuildFeedbackConfig {
  destinations : Array[GuildDestination]
  cooldown_seconds : Int
}

///|
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

///|
test "multi-guild configuration resolves destinations" {
  let config = MultiGuildFeedbackConfig::{
    destinations: [{ guild_id: Id(10UL), channel_id: Id(20UL), }],
    cooldown_seconds: 30,
  }
  assert_true(config.destination(Id(10UL)) is Some(_))
  assert_true(config.destination(Id(99UL)) is None)
}
```

The handler uses `let guild = ctx.guild_scope()` and looks up
`guild.guild_id`; a DM raises `GuildOnly`, while an unconfigured guild can be
rejected with a user-facing `HandlerError`. One feature instance can then
serve the configured guilds and keep shared state where needed.

## Add checks and cooldowns at registration

Installers own the command policy for their feature:

```mbt check
///|
fn register_guarded_feedback(
  app : @discord.App,
  config : FeedbackConfig,
) -> Unit {
  let modal = feedback_modal()
  let command = @discord.slash(
      name="feedback",
      description="Send feedback",
      args=@discord.Args::unit(),
      handler=Immediate((_, _) => ShowModal(modal.show())),
    )
    .check(@discord.guild_only())
    .cooldown(seconds=config.cooldown_seconds, bucket=User)
  app.command(command)
}

///|
test "feature installer declarations compile" {
  ignore(compose)
  ignore(keep_feature_value)
  ignore(wire_feedback)
  ignore(register_guarded_feedback)
}
```

Call `.check` more than once when a command needs several guards. The App runs
them in registration order. The complete command path is middleware, checks,
cooldown, argument decoding, then the handler. A check may use `ctx.app()` for
async I/O, but checks run before the handler can defer and therefore spend
Discord's three-second initial-response budget; keep them fast or cache their
results. Cooldown failures use the same error policy as handler failures.

Cooldown storage belongs to the App, with a fresh `InMemoryCooldownStore` by
default. Command type, name, and bucket are included in each storage key, so
features sharing a store do not collide. Supply `App(cooldown_store=...)` when
windows must be shared across Apps or processes; the portable `CooldownStore`
trait and native `RemoteCooldownStore` are described under
[Shared cooldowns](08-scaling-processes.mbt.md#shared-cooldowns).

## No plugin trait or reload lifecycle

discord.mbt does not define a `Plugin` trait. An installer function composes
with `App` and `Bot` without a second lifecycle model. MoonBit links feature
packages at compile time, so runtime module reload does not fit this design.
If shared tooling later needs discovery metadata or lifecycle hooks, that use
case can define the contract.

See [`src/examples/plugin_demo`](../examples/plugin_demo) for a compiling
feedback feature with injected configuration and retained state.
