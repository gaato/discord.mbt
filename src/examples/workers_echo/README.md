# Cloudflare Workers echo example

This Worker verifies Discord's request signature, dispatches interactions
through an `App`, and keeps deferred handlers alive with `ctx.waitUntil`.

## Build and deploy

From the repository root:

```sh
moon build --target js src/examples/workers_echo
cd src/examples/workers_echo
wrangler secret put DISCORD_TOKEN
wrangler secret put DISCORD_PUBLIC_KEY
wrangler deploy
```

The MoonBit build emits
`_build/js/debug/build/examples/workers_echo/workers_echo.js`. `entry.js`
imports that ESM artifact, and Wrangler bundles it into the Worker.

Set the deployed Worker's URL as the Interactions Endpoint URL in the Discord
developer portal. Discord sends a signed PING request while validating the URL;
the App answers it with a Pong callback.

Deployment and configuring the Discord developer portal are manual steps. The
example does not deploy automatically from this repository.
