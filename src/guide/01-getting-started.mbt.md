# Getting started

This guide creates a native Gateway bot with one `/echo` command.

## Prerequisites

On a clean machine, install `git` and run `moon update` first; Moon clones its
package registry with `git` when resolving dependencies.

Node.js must be on `PATH` for every build, even for a bot that never uses
voice. `gaato/discord` and its `gaato/dave` dependency declare prebuild hooks
that Moon runs with `node`; they do nothing unless voice is opted into (see
[Voice](10-voice.mbt.md)), but `moon build` fails when `node` is missing.
`moon check` does not run the hooks.

All native builds compile the Gateway package's `zlib_stream.c`, which always
includes `<zlib.h>`, regardless of whether Gateway compression is enabled.
Install the zlib development headers (`zlib1g-dev` on Debian/Ubuntu or
`zlib-devel` on Fedora/openSUSE). The zlib shared library is also needed at
runtime if the bot enables zlib-stream compression.

## Install

From a MoonBit module root:

```sh
moon update
moon add gaato/discord
moon add moonbitlang/async
```

The resulting `moon.mod` contains module dependencies equivalent to:

```mbt nocheck
///|
import {
  "gaato/discord",
  "moonbitlang/async",
}
```

Create an executable package, for example `src/main/moon.pkg`:

```mbt nocheck
import {
  "gaato/discord",
  "moonbitlang/async",
  "moonbitlang/async/signal",
  "moonbitlang/core/env",
}

supported_targets = "native"

pkgtype(kind: "executable")
```

## Define the command and bot

Put this in `src/main/main.mbt`. In the executable package the entry point is
`async fn main`; this guide compiles as a test suite, so the block below names
it `getting_started_main` instead — the body is what goes in `main`:

```mbt check
///|
fn echo_command() -> @discord.Command[String] {
  @discord.slash(
    name="echo",
    description="Echo text back",
    args=@discord.Args::of(
      @discord.arg_string(name="text", description="What to echo"),
    ),
    handler=Immediate((_, text) => @discord.CommandReply::message(content=text)),
  )
}

///|
async fn getting_started_main() -> Unit {
  @signal.set_global_cancellation_signals([SIGINT, SIGTERM])
  @async.handle_cancellation(() => {
    let token = @env.get_env_var("DISCORD_TOKEN").unwrap_or("")
    let app = @discord.App()
    app.command(echo_command())
    let bot = @discord.Bot(app, token~, sync=Global)
    bot.on(@discord.Events::ready(), (_, ready) => {
      println("ready as \{ready.user.username}")
    })
    bot.run()
  })
  |> ignore
  println("[bot] shutting down")
}

///|
test "getting started quickstart compiles" {
  ignore(getting_started_main)
}
```

`App` owns the commands and interaction handlers. `Bot` adds the
Gateway connection and dispatch loop. Passing `sync=Global` opts into command
synchronization once after the first READY; omitting it performs no command
request. Use `CommandScope::Guild(guild_id)` while developing if the command
should appear immediately in one guild.

Synchronization uses Discord's bulk overwrite endpoint and deletes commands
in that scope that this App does not declare, except that the Entry Point
command is always preserved. Pass `sync_unowned=Keep` to preserve other owners'
commands too.

```mbt check
///|
async test "default sync deletes undeclared commands but preserves the entry point" {
  let (payload, report) = @framework.plan_command_sync(
    [],
    [
      { "id": "10", "name": "old" },
      { "id": "11", "type": 4, "name": "Launch", "handler": 2 },
    ],
    unowned=Delete,
  )
  assert_eq(report.deleted, ["old"])
  assert_eq(report.preserved, ["4:Launch"])
  assert_eq(
    payload,
    Some(
      Json::array([{ "id": "11", "type": 4, "name": "Launch", "handler": 2 }]),
    ),
  )
}
```

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
exits. Cancellation is a signal rather than an error, so the entry point uses
`handle_cancellation` instead of `catch` when it needs to continue to the final
shutdown message. Signal handling is an entry-point concern; `Bot` does not
install process-global signal handlers implicitly.

Continue with [Commands](02-commands.mbt.md), or use
[HTTP interactions](06-http-interactions.mbt.md) when the application should
not open a Gateway connection.
