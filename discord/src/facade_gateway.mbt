///|
// Gateway executor and typed event descriptors (native, JavaScript, Wasm).

///|
/// A validated gateway bot, built by `BotBuilder::build`.
pub using @bot {type Bot}

///|
/// Collects a gateway bot's configuration and registrations: typed and raw
/// event handlers, event middleware, services, the cache, and observers.
pub using @bot {type BotBuilder}

///|
/// A gateway configuration that cannot run, found by `BotBuilder::build` before
/// any connection is attempted.
pub using @bot {type BotConfigError}

///|
/// A gateway session to persist with its READY identity, so a restarted bot
/// can resume instead of identifying again.
pub using @bot {type BotSession}

///|
/// Gateway-only services passed to event and service handlers after READY.
pub using @bot {type GatewayCtx}

///|
/// A typed projection from the general gateway event enum.
pub using @bot {type EventType}

///|
/// One expected gateway event, from `GatewayCtx::expect_event`.
pub using @bot {type PendingEvent}

///|
/// Namespace for typed gateway event descriptors.
pub using @bot {type Events}

///|
/// Fatal runtime failures reported by Discord.
pub using @bot {type BotError}

///|
/// Selects which Gateway shards this process owns.
pub using @bot {type ShardConfig}

///|
/// Runs once per decoded gateway event, around the handler fan-out.
pub using @bot {type EventMiddleware}

///|
/// Transport compression for a Gateway connection, chosen with
/// `BotBuilder(compression=...)`.
pub using @gateway {type GatewayCompression}
