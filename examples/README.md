# Examples

Runnable programs for `gaato/discord` and `gaato/discord_voice`. This
directory is one workspace module (not published); run each example from the
repository root. Gateway bots read `DISCORD_TOKEN` (the raw bot token) and,
when set, sync their commands to the `GUILD_ID` guild instead of globally.

```sh
export DISCORD_TOKEN="your-token"
export GUILD_ID="123456789012345678"
moon run --target native examples/slash_echo
```

## Gateway bots

- `slash_echo`: a minimal typed `/echo` command.
- `kitchen_sink`: subcommands, autocomplete, context menus, components, and
  typed modals.
- `plugin_demo`: a stateful feedback feature installed from its own package;
  set `FEEDBACK_CHANNEL_ID` to the channel that receives feedback.
- `ping_gateway`: a gateway `Shard` and REST `Client` without `App` or `Bot`,
  replying to `ping` messages (needs the message content intent).
- `low_level`: `Shard`, `Framework`, and command sync wired by hand.

`RUN_SECONDS` stops these bots after that many seconds.

## HTTP interactions

- `interactions_http`: the native and moonrun Wasm signed-interactions server
  ([README](interactions_http/README.md)).
- `interactions_js`: the shared JavaScript handler that the host adapters
  below wrap.
- `workers_echo`, `deno_echo`, `bun_echo`, `vercel_echo`: adapters for
  Cloudflare Workers, Deno, Bun, and Vercel Functions; each README has its
  build and test commands.
- `fastly_echo`, `lambda_url_echo`: experimental adapters for Fastly Compute
  and AWS Lambda Function URLs.
- `workers_gateway`: a Gateway bot in a Cloudflare Durable Object
  ([README](workers_gateway/README.md)).

## Voice

Voice examples need the native runtimes; opt in to their download on the
first build:

```sh
export GUILD_ID="123456789012345678" CHANNEL_ID="123456789012345678"
env DISCORD_VOICE_REQUIRE_SHIM=1 MBT_DAVE_REQUIRE_NATIVE=1 AUDIO_FILE=music.ogg \
  moon run --target native --release examples/voice_player
```

- `voice_player`: play `AUDIO_FILE` in `CHANNEL_ID`, then leave. Ogg/Opus
  files play directly; other formats stream through `ffmpeg`.
- `voice_recorder`: record `TARGET_USER_ID` to `OUTPUT_PATH` (default
  `recording.ogg`) until a second of silence.
- `dave_probe`: a manual DAVE check against a live channel
  ([README](dave_probe/README.md)).

## Live probes

These run against the real Discord API and are for checking the library
itself, not for copying.

- `live_probe`: calls every typed REST endpoint in a disposable guild,
  creating and deleting resources there, and prints a pass/fail report.
- `gate_probe`: error-policy recovery and user-restricted component waits,
  driven from a Discord client.
- `update_probe`: decoding of `MESSAGE_UPDATE` payloads and related fixes.
