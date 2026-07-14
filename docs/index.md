# discord.mbt documentation

discord.mbt provides typed Discord API models, interaction declarations, a
rate-limited REST client, a native Gateway executor, and an HTTP interaction
executor for native and JavaScript adapters.

## Where to start

- [Getting started](guide/01-getting-started.md): install the module and run a
  minimal slash-command bot.
- [Commands](guide/02-commands.md): arguments, autocomplete, subcommands, and
  context menus.
- [Components and modals](guide/03-components-modals.md): buttons, selects,
  modal forms, and component waiters.
- [Events and intents](guide/04-events-intents.md): typed Gateway subscriptions
  and intent selection.
- [REST](guide/05-rest.md): typed endpoints, pagination, rate limits, and custom
  routes.
- [HTTP interactions](guide/06-http-interactions.md): gateway-free dispatch and
  serverless adapters.
- [Cookbook](cookbook/dm-user.md): focused examples for common tasks.
- [API reference](reference.md): package map and `moon doc` commands.

The guides explain normal application structure. The cookbook assumes that a
client, IDs, and application configuration are already available. Exact type
and method documentation is generated from the source with `moon doc`.

## Target matrix

| Surface | Native | JavaScript | Notes |
|---|---:|---:|---|
| `gaato/discord` facade | Yes | Yes | Gateway exports exist only on native; signature verification exists only on JavaScript. |
| `model`, `interaction`, `app`, `framework` | Yes | Yes | Typed data and interaction routing. |
| `http`, `ratelimit`, `queue` | Yes | Yes | Async REST and supporting services. |
| `util` | Yes | Yes | Pure permission and formatting helpers. |
| `gateway`, `bot` | Yes | No | Native WebSocket Gateway transport and executor. |
| `verify` | No | Yes | WebCrypto Ed25519 verification. |

WebAssembly is not a supported application target for the current async
executors.

## Runnable examples

- `src/examples/slash_echo`: minimal typed Gateway bot.
- `src/examples/kitchen_sink`: subcommands, autocomplete, context menus,
  components, and modals.
- `src/examples/ping_gateway`: low-level Gateway and REST use.
- `src/examples/low_level`: manual Framework and Shard wiring.
- `src/examples/workers_echo`: Cloudflare Workers adapter.
