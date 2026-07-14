# API reference

The API reference is generated from MoonBit doc comments. The guides and
cookbook explain workflows; use the generated reference for complete records,
enums, errors, and method signatures.

## Generate and browse

From the repository root:

```sh
moon doc
moon doc --serve --bind 127.0.0.1 --port 3000
```

`moon doc` writes generated data under `_build/doc`. `moon doc --serve` starts
the local reference browser. For terminal lookup, query a package or symbol:

```sh
moon ide doc "@discord"
moon ide doc "@http.Client::create_message"
moon ide doc "@model.Message"
moon ide doc "@util.channel_permissions"
```

Run `moon info` when reviewing a change to regenerate each
`pkg.generated.mbti`. These files are concise public-interface snapshots and
are useful when checking API drift.

## Package map

| Package | Role |
|---|---|
| `gaato/discord` | Application facade. Re-exports the common interaction API, plus native Gateway or JavaScript verification symbols by target. |
| `gaato/discord/model` | Discord entities, payloads, IDs, bitfields, and wire codecs. No I/O. |
| `gaato/discord/telemetry` | Dependency-free structured REST, Gateway, and dispatch observability events. |
| `gaato/discord/interaction` | Command options, typed `Arg`/`Args`, autocomplete data, and component builders. |
| `gaato/discord/app` | Typed commands, components, modals, command synchronization, and HTTP interaction endpoint. |
| `gaato/discord/framework` | Lower-level interaction contexts, routing, response gates, and waiters. |
| `gaato/discord/http` | REST client, typed endpoints, routes, multipart uploads, and paginators. |
| `gaato/discord/bot` | Native `Bot`, `GatewayCtx`, and typed `Events` descriptors. |
| `gaato/discord/gateway` | Native low-level Shard transport and connection state. |
| `gaato/discord/ratelimit` | Rate-limiter interface and in-memory implementation. |
| `gaato/discord/queue` | Identify queue interface and in-memory implementation. |
| `gaato/discord/coordinator` | Native JSON-lines coordinator and remote queue/limiter implementations. |
| `gaato/discord/util` | Pure permission calculations, mention/timestamp formatting, and CDN URLs. |
| `gaato/discord/verify` | JavaScript WebCrypto Ed25519 verification. |

Start with the facade for normal applications. Import `model`, `http`, or
`util` directly when the focused package is clearer or the facade intentionally
does not re-export a symbol.
