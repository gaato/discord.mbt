# Deno interaction endpoint

This adapter uses the same MoonBit `App`, signature verifier, and HTTP response
mapping as the Cloudflare Worker example. Only the host lifecycle code differs:
`Deno.serve` accepts requests, and a local set retains deferred work until it
settles. The set does not guarantee completion if the host terminates the process.

From the repository root:

```fish
moon build --target js --release --deny-warn src/examples/interactions_js
env DISCORD_PUBLIC_KEY=... DISCORD_TOKEN=... DISCORD_APPLICATION_ID=... deno run --allow-env --allow-net src/examples/deno_echo/entry.js
deno test --allow-net src/examples/deno_echo/entry.test.js
```

Use the native `src/examples/workers_echo/register` runner to register the
shared command set. Set the public URL as Discord's Interactions Endpoint URL
only after deploying to an HTTP host.
