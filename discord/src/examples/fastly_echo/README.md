# Fastly Compute entry point experiment

`respondToFetchEvent` adapts Fastly's `FetchEvent` to the shared MoonBit
Interaction handler. It registers the lifetime promise with `event.waitUntil`
**synchronously**, before calling `event.respondWith`. The promise then follows
deferred MoonBit work after the initial response is ready.

From the repository root:

```fish
moon build --target js --release --deny-warn src/examples/interactions_js
node --test src/examples/fastly_echo/adapter.test.mjs
```

The test uses a fake `FetchEvent`. It checks the delivery convention and the
background promise, but does not compile or run inside Fastly Compute. A
deployable entry point still needs Fastly configuration and credential loading.
