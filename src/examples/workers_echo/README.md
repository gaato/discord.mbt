# Cloudflare Workers echo example

This Worker verifies Discord's request signature, dispatches interactions
through an `App`, and keeps deferred handlers alive with `ctx.waitUntil`.
It passes the exact request bytes to a pure MoonBit verifier and caches the
expanded public key between requests.

## Build and deploy

From the repository root:

```fish
moon build --target js --release --deny-warn src/examples/workers_echo
cd src/examples/workers_echo
npx wrangler secret put DISCORD_TOKEN
npx wrangler secret put DISCORD_PUBLIC_KEY
npx wrangler deploy
```

The MoonBit build emits
`_build/js/release/build/examples/workers_echo/workers_echo.js`. `entry.js`
imports that ESM artifact, and Wrangler bundles it into the Worker.

The `/file` command returns `hello.txt` as a streamed multipart callback.
Multipart framing is emitted chunk by chunk and existing `Bytes` file contents
are not concatenated into one body. `FileUpload` still owns its bytes in
memory; this is not filesystem request-body streaming.

## Test locally

The test suite generates a temporary Ed25519 key pair and runs signed requests
inside Cloudflare's local `workerd` runtime. It does not read `.dev.vars` and
does not send requests to Discord or Cloudflare:

```fish
cd src/examples/workers_echo
npm ci
env WRANGLER_SEND_METRICS=false npm test
npm run bundle:check -- --outdir /tmp/discord-mbt-workers-echo
```

The `/vanish` command exercises a deferred Worker-side REST call that deletes
its original response. Its workerd test returns a real null-body 204 response,
covering the Fetch behavior fixed in `moonbitlang/async@0.21.2`.

Set the deployed Worker's URL as the Interactions Endpoint URL in the Discord
developer portal. Discord sends a signed PING request while validating the URL;
the App answers it with a Pong callback.

## Register commands

Workers have no startup phase, so command synchronization runs as a separate
one-shot: `register/` builds the same `App` as the Worker (one definition in
`app.mbt`, no drift possible) and diff-syncs it — nothing is sent when the
registered commands already match. Run it after `wrangler deploy` (or from CI):

```fish
env DISCORD_TOKEN=... moon run --target native src/examples/workers_echo/register
env GUILD_ID=... DISCORD_TOKEN=... moon run --target native src/examples/workers_echo/register # one guild only
```

Deployment and configuring the Discord developer portal are manual steps. The
example does not deploy automatically from this repository.
