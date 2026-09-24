# Discord bot starter

This directory is a minimal native Gateway bot with one `/ping` command. Copy
it out of the discord.mbt repository, then change the module name at the top of
`moon.mod` to a name you own.

```fish
cp -R /path/to/discord.mbt/template ./my-discord-bot
cd my-discord-bot
```

## Dependencies

`moon.mod` pins the released `gaato/discord`; update it with Moon when needed:

```fish
moon update
```

Install `git` before running `moon update`; Moon uses it to clone the package
registry. Node.js must be on `PATH` for every build, including container
builder stages: `gaato/discord` and its `gaato/dave` dependency declare
prebuild hooks that Moon runs with `node`. They do nothing unless voice is
opted into, but `moon build` fails when `node` is missing. Node.js is not
needed to run the built executable.

Native builds also require the zlib development headers because the
Gateway package always compiles a C source that includes `<zlib.h>`, even when
compression is disabled. Install `zlib1g-dev` on Debian/Ubuntu or `zlib-devel`
on Fedora/openSUSE. The zlib shared library is required at runtime when using
Gateway zlib-stream compression.

Before publication, use a Moon workspace to resolve `gaato/discord` from a
local checkout. Current Moon represents local path dependencies as workspace
members rather than paths inside `moon.mod`. From a directory containing (or
able to reference) both the checkout and the copied bot, run:

```fish
moon work init /path/to/discord.mbt /path/to/my-discord-bot
moon check /path/to/my-discord-bot/src/main --target native
```

The workspace supplies the local `gaato/discord` module for the dependency in
`moon.mod`; no source import paths need to change. Do not copy a generated
`moon.work` into the bot project unless that workspace layout is intentional.

## Run in a container

The `Dockerfile` builds the bot with the
[`ghcr.io/gaato/moonbit`](https://github.com/gaato/moonbit-docker) toolchain
image and copies the executable onto `gcr.io/distroless/base-debian13`:

```fish
docker build -t my-discord-bot .
docker run --rm -e DISCORD_TOKEN="your-token" my-discord-bot
```

The runtime image carries no zlib. If you enable Gateway zlib-stream
compression, switch the final stage to a base that provides `zlib1g`, such as
`debian:trixie-slim`. Pass `--build-arg MOONBIT_IMAGE=...` to build with
another toolchain tag.

## Configure and run

Create a Discord application and bot, install it with the `bot` and
`applications.commands` scopes, then export its raw token (without a `Bot `
prefix):

```fish
set -x DISCORD_TOKEN "your-token"
moon run --target native src/main
```

Set `GUILD_ID` while developing to synchronize `/ping` to one guild, where it
will appear immediately. If it is omitted, the command is synchronized
globally and can take time to appear.

The starter opts into synchronization on the bot's first READY. Discord's bulk
overwrite deletes commands in the selected scope that this App does not
declare.

```fish
set -x GUILD_ID "123456789012345678"
moon run --target native src/main
```

`.env.example` documents the available variables for tools that load dotenv
files. The program reads process environment variables directly and does not
load `.env` itself.
