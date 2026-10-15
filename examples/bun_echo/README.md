# Bun interaction endpoint

This adapter runs the shared MoonBit Interaction App through `Bun.serve`.
It retains deferred promises while the process stays alive; shutting down the
process can still interrupt unfinished REST work.

From the repository root:

```fish
moon build --target js --release --deny-warn examples/interactions_js
bun test examples/bun_echo/entry.test.js
env DISCORD_PUBLIC_KEY=... DISCORD_TOKEN=... DISCORD_APPLICATION_ID=... bun examples/bun_echo/entry.js
```

Use the native `examples/workers_echo/register` runner to register the
shared command set. Set the public URL as Discord's Interactions Endpoint URL
only after deploying to an HTTP host.
