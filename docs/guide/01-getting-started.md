# Getting started

This guide creates a native Gateway bot with one `/echo` command.

## Install

From a MoonBit module root:

```sh
moon add gaato/discord
moon add moonbitlang/async
```

The resulting `moon.mod` contains module dependencies equivalent to:

```moonbit
import {
  "gaato/discord",
  "moonbitlang/async",
}
```

Create an executable package, for example `src/main/moon.pkg`:

```moonbit
import {
  "gaato/discord",
  "moonbitlang/async",
  "moonbitlang/async/signal",
  "moonbitlang/core/env",
}

supported_targets = "native"

options(
  "is-main": true,
)
```

## Define the command and bot

Put this in `src/main/main.mbt`:

```moonbit
///|
fn echo_command() -> @discord.Command[String] {
  @discord.slash(
    name="echo",
    description="Echo text back",
    args=@discord.Args::of(
      @discord.arg_string(name="text", description="What to echo"),
    ),
    handler=Immediate((_, text) => {
      @discord.CommandReply::message(content=text)
    }),
  )
}

///|
async fn main {
  @signal.set_global_cancellation_signals([SIGINT, SIGTERM])
  try {
    let token = @env.get_env_var("DISCORD_TOKEN").unwrap_or("")
    let app = @discord.App(sync=Global)
    app.command(echo_command())

    let bot = @discord.Bot(app, token~)
    bot.on(@discord.Events::ready(), (_, ready) => {
      println("ready as \{ready.user.username}")
    })
    bot.run()
  } catch {
    error if @async.is_being_cancelled() || @async.is_cancellation_error(error) =>
      ()
    error => raise error
  }
  println("[bot] shutting down")
}
```

`App` owns the commands and interaction handlers. `Bot` adds the native
Gateway connection and dispatch loop. The default global synchronization uses
Discord's bulk overwrite endpoint; use `CommandSync::Guild(guild_id)` while
developing if the command should appear immediately in one guild.

## Run

Create a bot application in the Discord developer portal, install it with the
`applications.commands` and `bot` scopes, then run:

```sh
DISCORD_TOKEN=... moon run --target native src/main
```

The token passed to `Bot(...)` and `Client(...)` is the raw bot token without a
`Bot ` prefix.

## Stop the bot

Pressing Ctrl-C or sending SIGTERM cancels the async runtime because the entry
point calls `set_global_cancellation_signals`. Structured concurrency then
unwinds the bot's task groups and completes their teardown before the process
exits. Signal handling is an entry-point concern; `Bot` does not install
process-global signal handlers implicitly.

Continue with [Commands](02-commands.md), or use
[HTTP interactions](06-http-interactions.md) when the application should not
open a Gateway connection.
