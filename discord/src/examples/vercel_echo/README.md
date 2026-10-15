# Vercel Functions interaction adapter

`api/interactions.js` is a Vercel fetch-style Node.js Function. It passes the
Web `Request` to the same MoonBit dispatch used by the Worker and Deno examples,
and passes deferred work to `@vercel/functions.waitUntil`.
Set `DISCORD_PUBLIC_KEY`, `DISCORD_TOKEN`, and `DISCORD_APPLICATION_ID` in
the Function environment before deployment.

From the repository root, check the adapter locally:

```fish
moon build --target js --release --deny-warn src/examples/interactions_js
node --test src/examples/vercel_echo/adapter.test.mjs
```

The test injects a `waitUntil` collector and fake Discord REST response. It
checks the request and background-work boundary in Node.js. It does not run
Vercel's hosted lifecycle or deployment bundler. A deployment also needs a
build that produces the shared MoonBit ESM artifact before Vercel packages the
Function. The `waitUntil` promise remains subject to the Function's configured
maximum duration.

The sibling `interactions_js/runtime.test.mjs` runs the same signed requests
directly on Node.js and Bun. The Vercel adapter is specific to Vercel because
that host exposes `waitUntil` through `@vercel/functions`; the MoonBit App and
HTTP response mapping stay shared with the other JavaScript hosts.
