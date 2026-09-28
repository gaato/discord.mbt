///|
/// A gateway configuration that cannot run, found by `BotBuilder::build`
/// before any connection is attempted.
pub(all) suberror BotConfigError {
  /// The bot token is empty.
  EmptyToken
  /// `compress=true` on a backend without zlib-stream inflate (see
  /// `@gateway.zlib_stream_supported`).
  CompressionUnavailable
  /// A shard id/count selection cannot be represented by Discord's sharding
  /// rules.
  InvalidShardConfig(message~ : String)
  /// A saved session's gateway id disagrees with its READY session id.
  MismatchedSession(shard_id~ : Int)
} derive(Debug)

///|
/// Collects a gateway bot's configuration and registrations: typed and raw
/// event handlers, event middleware, services, the cache, and observers.
/// `build()` validates it into a `Bot` that can run. Like `AppBuilder`,
/// registering more on the builder afterwards does not change a built `Bot`.
pub struct BotBuilder {
  priv core : BotCore
}

///|
/// Configure a gateway bot for `app`. When `intents` is omitted, `build`
/// infers the union of intents required by the typed event subscriptions
/// (privileged intents are only inferred, never invented — they must still be
/// enabled in the developer portal). `client` supplies a preconfigured REST
/// client; by default one is built from `token`. `shards`, `compress`, and
/// `identify_queue` configure sharding, transport compression, and
/// cross-process identify coordination. Every IDENTIFY, at startup or after a
/// lost session, first reads `session_start_limit` from `GET /gateway/bot`; an
/// exhausted limit ends `run` with `SessionStartLimitExceeded` instead of
/// risking a token reset. `capabilities` is sent in Identify (see
/// `@model.GatewayCapabilities`).
///
/// When `sync` is omitted, the bot performs no command synchronization. When
/// set, synchronization runs once per process after the first READY. It uses
/// Discord's bulk overwrite: every command in that scope that this App does not
/// declare is **deleted**, except entry points, which are always preserved.
/// `sync_unowned=Keep` also preserves commands registered by other owners.
/// Deletions are reported through the app's warning hook. In multi-process
/// sharding, enable synchronization in exactly one process.
///
/// `resume` seeds saved Bot sessions per shard id so those shards RESUME
/// instead of identifying (see `Bot::sessions`). It restores gateway identity,
/// not optional cache contents or application-owned state.
pub fn BotBuilder::BotBuilder(
  app : @app.App,
  token~ : String,
  intents? : @model.Intents,
  capabilities? : @model.GatewayCapabilities = @model.GatewayCapabilities::none(),
  client? : @dhttp.Client,
  gateway_url? : String,
  shards? : ShardConfig = Single(id=0, count=1),
  compress? : Bool = false,
  identify_queue? : &@queue.IdentifyQueue,
  sync? : @app.CommandScope,
  sync_unowned? : @framework.UnownedCommands = Delete,
  resume? : Map[Int, BotSession] = Map([]),
) -> BotBuilder {
  {
    core: BotCore::new(
      app,
      token~,
      intents?,
      capabilities~,
      client?,
      gateway_url?,
      shards~,
      compress~,
      identify_queue?,
      sync?,
      sync_unowned~,
      resume~,
    ),
  }
}

///|
/// Subscribe a typed handler to one gateway event (see `Events` for the
/// descriptors). The event's required intents join the inferred intent set
/// when the builder omits explicit `intents`. Handlers run through the event
/// middleware chain; a raised error is reported via the app's failure policy
/// without stopping the bot.
pub fn[T] BotBuilder::on(
  self : BotBuilder,
  event : EventType[T],
  handler : async (GatewayCtx, T) -> Unit,
) -> Unit {
  self.core.on(event, handler)
}

///|
/// Subscribe to the raw event stream: every decoded gateway dispatch,
/// including `Resumed` and `Unknown`, without payload projection. Unlike
/// `on`, this adds nothing to the inferred intent set.
pub fn BotBuilder::on_event(
  self : BotBuilder,
  handler : async (GatewayCtx, @model.Event) -> Unit,
) -> Unit {
  self.core.on_event(handler)
}

///|
/// Install gateway event middleware. The first installed middleware is
/// outermost. The chain runs serially, in event order, in a dispatch task
/// separate from the shard loop: slow middleware delays later events, never
/// interaction routing. A dropped event emits no EventDispatched
/// telemetry. Middleware cannot widen intents or the gateway event filter.
pub fn BotBuilder::middleware(
  self : BotBuilder,
  middleware : EventMiddleware,
) -> Unit {
  self.core.middleware(middleware)
}

///|
/// Register a long-running background task started alongside the shards when
/// the bot runs (e.g. a periodic status updater). `name` labels the service
/// in failure reports. A raised error is reported via the app's failure
/// policy and stops only that service, not the bot.
pub fn BotBuilder::service(
  self : BotBuilder,
  name~ : String,
  handler : async (GatewayCtx) -> Unit,
) -> Unit {
  self.core.service(name~, handler)
}

///|
/// Feed every decoded gateway event into an opt-in cache before dispatching
/// typed and raw event handlers.
pub fn BotBuilder::attach_cache(
  self : BotBuilder,
  cache : @cache.InMemoryCache,
) -> Unit {
  self.core.attach_cache(cache)
}

///|
/// Observe structured gateway, dispatch, and REST telemetry aggregated by
/// this bot. Hooks run synchronously and should return promptly.
pub fn BotBuilder::on_telemetry(
  self : BotBuilder,
  hook : (@telemetry.TelemetryEvent) -> Unit raise,
) -> Unit {
  self.core.on_telemetry(hook)
}

///|
/// Observe gateway events whose known payload failed typed decoding.
///
/// `marker` is the full synthetic event type
/// `DECODE_ERROR:<event-name>:<decode-error>`, and `payload` is Discord's raw
/// event data. Handlers run synchronously in the dispatch loop and should
/// return promptly. Registering a handler does not add gateway intents or
/// widen the event filter.
pub fn BotBuilder::on_decode_error(
  self : BotBuilder,
  handler : (String, Json) -> Unit,
) -> Unit {
  self.core.on_decode_error(handler)
}

///|
/// Validate the configuration and freeze the registrations into a `Bot`.
/// Raises `BotConfigError` for an empty token, `compress=true` without
/// zlib-stream support, a shard selection Discord cannot represent, or a saved
/// session whose ids disagree. Intents are resolved here, so warnings about
/// subscriptions the intents cannot deliver appear once, at build time.
pub fn BotBuilder::build(self : BotBuilder) -> Bot raise BotConfigError {
  let core = self.core
  if core.token_.is_empty() {
    raise EmptyToken
  }
  if core.compress_ && !@gateway.zlib_stream_supported() {
    raise CompressionUnavailable
  }
  let static_layout = match core.shards_ {
    Auto => None
    Single(id~, count~) => Some(([id], count))
    Fixed(count~) => Some((Array::makei(count.max(0), id => id), count))
    Range(ids~, count~) => Some((ids, count))
  }
  if static_layout is Some((ids, count)) &&
    shard_layout_problem(ids, count) is Some(message) {
    raise InvalidShardConfig(message~)
  }
  for shard_id, saved in core.resume_ {
    if saved.gateway.id != saved.ready.session_id {
      raise MismatchedSession(shard_id~)
    }
  }
  let resume : Map[Int, BotSession] = Map([])
  for shard_id, saved in core.resume_ {
    resume[shard_id] = clone_bot_session(saved)
  }
  {
    core: {
      ..core,
      resume_: resume,
      typed_events_: core.typed_events_.copy(),
      raw_events_: core.raw_events_.copy(),
      event_middleware_: core.event_middleware_.copy(),
      decode_errors_: core.decode_errors_.copy(),
      telemetry_: core.telemetry_.copy(),
      services_: core.services_.copy(),
      starting_: Ref(false),
      running_shards_: Ref([]),
      collector_: EventCollector(),
      frozen_intents_: Some(core.resolved_intents()),
    },
    running_: Ref(false),
  }
}

///|
/// A validated gateway bot, built by `BotBuilder::build`. Its configuration
/// and registrations are fixed; `run` connects it.
pub struct Bot {
  priv core : BotCore
  priv running_ : Ref[Bool]
}

///|
/// Connect and process gateway events until graceful shutdown or a fatal
/// close. Raises `BotError::AlreadyRunning` when this bot is already running;
/// it may run again after `run` returns. Other failures are connection-time:
/// REST errors from `GET /gateway/bot` or the command sync, `BotError` for a
/// fatal gateway close, an exhausted session start limit, or unusable gateway
/// information.
pub async fn Bot::run(self : Bot) -> Unit {
  if self.running_.val {
    raise AlreadyRunning
  }
  self.running_.val = true
  defer {
    self.running_.val = false
  }
  self.core.run()
}

///|
/// Current resumable gateway state paired with READY metadata, keyed by shard
/// id. A supplied snapshot is available from the start of `run` until its
/// shard replaces, drops, or invalidates it, including while `run` still
/// resolves the shard layout over REST; an unsaved shard appears after READY.
/// Empty while the bot is not running. Returned values do not alias mutable
/// runtime state.
pub fn Bot::sessions(self : Bot) -> Map[Int, BotSession] {
  self.core.sessions()
}
