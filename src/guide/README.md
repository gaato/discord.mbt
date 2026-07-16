# Guides

Long-form guides for building applications with discord.mbt. Every MoonBit
code block marked `mbt check` in these chapters compiles and runs as part of
the test suite (`moon test --target native src/guide`), so the examples cannot
drift from the library.

1. [Getting started](01-getting-started.mbt.md): install the module and run a
   minimal slash-command bot.
2. [Commands](02-commands.mbt.md): arguments, autocomplete, subcommands, and
   context menus.
3. [Components and modals](03-components-modals.mbt.md): buttons, selects,
   modal forms, and component waiters.
4. [Events and intents](04-events-intents.mbt.md): typed Gateway subscriptions
   and intent selection.
5. [REST](05-rest.mbt.md): typed endpoints, pagination, rate limits, and
   custom routes.
6. [HTTP interactions](06-http-interactions.mbt.md): gateway-free dispatch and
   serverless adapters.
7. [Structuring bots](07-structuring-bots.mbt.md): feature installers,
   configuration, and state ownership.
8. [Scaling across processes](08-scaling-processes.mbt.md): run the bundled
   coordinator and share Identify and REST rate limits between workers.
9. [Middleware](09-middleware.mbt.md): wrap REST calls, routed interactions,
   and Gateway handler fan-out.
10. [Voice](10-voice.mbt.md): join channels, play and receive Opus, and
    install the native DAVE shim.
11. [The framework layer](11-framework.mbt.md): direct interaction routing,
    response gates, and testing handlers without a network.
12. [Models and utilities](12-models-utilities.mbt.md): the pure data layer,
    typed snowflakes, and permission, mention, timestamp, and CDN helpers.

The guides explain normal application structure and assume the reader starts
from an empty module. Exact type and method documentation lives in doc
comments; look symbols up with `moon ide doc "@discord"` (or any package or
symbol name).
