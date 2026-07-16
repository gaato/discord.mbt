# Discord bot starter

This directory is a minimal native Gateway bot with one `/ping` command. Copy
it out of the discord.mbt repository, then change the module name at the top of
`moon.mod` to a name you own.

```sh
cp -R /path/to/discord.mbt/template ./my-discord-bot
cd my-discord-bot
```

## Dependencies

After `gaato/discord` is published, replace `gaato/discord@0.1.0` in
`moon.mod` with the released version and update it with Moon when needed:

```sh
moon update
```

Before publication, use a Moon workspace to resolve `gaato/discord` from a
local checkout. Current Moon represents local path dependencies as workspace
members rather than paths inside `moon.mod`. From a directory containing (or
able to reference) both the checkout and the copied bot, run:

```sh
moon work init /path/to/discord.mbt /path/to/my-discord-bot
moon check /path/to/my-discord-bot/src/main --target native
```

The workspace supplies the local `gaato/discord` module for the dependency in
`moon.mod`; no source import paths need to change. Do not copy a generated
`moon.work` into the bot project unless that workspace layout is intentional.

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

```sh
export GUILD_ID="123456789012345678"
moon run --target native src/main
```

`.env.example` documents the available variables for tools that load dotenv
files. The program reads process environment variables directly and does not
load `.env` itself.
