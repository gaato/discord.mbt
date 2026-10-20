# Discord bot starter

This directory is a minimal native Gateway bot with one `/ping` command. Copy
it out of the discord.mbt repository, then change the module name at the top of
`moon.mod` to a name you own.

```sh
cp -R /path/to/discord.mbt/template ./my-discord-bot
cd my-discord-bot
```

## Dependencies

`moon.mod` pins the released `gaato/discord`; update it with Moon when needed:

```sh
moon update
```

Install `git` before running `moon update`; Moon uses it to clone the package
registry. A bot that adds voice (`gaato/discord_voice`) also needs Node.js on
`PATH` for native builds, including container builder stages, because voice
and its `gaato/dave` dependency declare prebuild hooks that Moon runs with
`node`. Node.js is not needed to run the built executable.

To build against an unreleased `gaato/discord`, resolve it from a local
checkout with a Moon workspace; Moon represents local dependencies as
workspace members rather than paths inside `moon.mod`. From a directory that
can reference both the checkout and the copied bot, run:

```sh
moon work init /path/to/discord.mbt/discord /path/to/my-discord-bot
moon check /path/to/my-discord-bot/src/main --target native
```

The workspace supplies the local `gaato/discord` module for the dependency in
`moon.mod`; no source import paths need to change. Do not copy a generated
`moon.work` into the bot project unless that workspace layout is intentional.

## Run in a container

The `Dockerfile` builds the bot with the
[`ghcr.io/gaato/moonbit`](https://github.com/gaato/moonbit-docker) toolchain
image and copies the executable onto `gcr.io/distroless/base-debian13`:

```sh
docker build -t my-discord-bot .
docker run --rm -e DISCORD_TOKEN="your-token" my-discord-bot
```

Pass `--build-arg MOONBIT_IMAGE=...` to build with
another toolchain tag.

## Configure and run

Create a Discord application and bot, install it with the `bot` and
`applications.commands` scopes, then export its raw token (without a `Bot `
prefix):

```sh
export DISCORD_TOKEN="your-token"
moon run --target native src/main
```

Set `GUILD_ID` while developing to synchronize `/ping` to one guild, where it
will appear immediately. If it is omitted, the command is synchronized
globally and can take time to appear.

The starter opts into synchronization on the bot's first READY. Discord's bulk
overwrite deletes commands in the selected scope that this App does not
declare.

```sh
export GUILD_ID="123456789012345678"
moon run --target native src/main
```

`.env.example` documents the available variables for tools that load dotenv
files. The program reads process environment variables directly and does not
load `.env` itself.
