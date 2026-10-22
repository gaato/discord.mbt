///|
/// Fatal runtime failures reported by Discord.
pub(all) suberror BotError {
  /// Close codes 4013 and 4014 indicate invalid or disallowed gateway
  /// intents. Check explicit intents and privileged-intent approval.
  FatallyClosed(code~ : Int32)
  /// `run` was called while this bot was already running.
  AlreadyRunning
  /// The shard layout or limits `GET /gateway/bot` returned cannot be used.
  InvalidGatewayInfo(message~ : String)
  /// The identify session allowance returned by `GET /gateway/bot` cannot
  /// cover the next IDENTIFY. At startup `required` counts the selected
  /// shards without a saved session (a saved session sends RESUME first);
  /// later it is 1 for the shard that was about to identify.
  SessionStartLimitExceeded(
    required~ : Int32,
    remaining~ : Int32,
    reset_after_ms~ : Int64
  )
  /// A guild command such as `GatewayCtx::update_voice_state` belongs on a
  /// shard that this process does not run.
  ShardNotManaged(shard_id~ : Int32)
  /// Discord rejected a Gateway command; retry after the given milliseconds.
  GatewayRateLimited(opcode~ : Int32, retry_after_ms~ : Int64)
  /// A complete member response did not arrive within the operation deadline.
  GatewayRequestTimeout
} derive(Debug)

///|
/// Makes `error.to_string()` return the message `Show` renders.
pub extend BotError with Show::{to_string}

///|
/// Human-readable failure message, including remediation hints for the
/// intent-related close codes.
pub impl Show for BotError with fn output(self, logger) {
  match self {
    FatallyClosed(code~) => {
      logger.write_string("gateway fatally closed with code \{code}")
      if code == 4013 || code == 4014 {
        logger.write_string(
          "; verify configured gateway intents and privileged-intent approval",
        )
      }
    }
    AlreadyRunning => logger.write_string("the bot is already running")
    InvalidGatewayInfo(message~) =>
      logger.write_string("invalid gateway information: \{message}")
    SessionStartLimitExceeded(required~, remaining~, reset_after_ms~) =>
      logger.write_string(
        "gateway session start limit exceeded: need \{required}, have \{remaining}; resets in \{reset_after_ms}ms",
      )
    ShardNotManaged(shard_id~) =>
      logger.write_string("shard \{shard_id} is not run by this process")
    GatewayRateLimited(opcode~, retry_after_ms~) =>
      logger.write_string(
        "gateway opcode \{opcode} rate limited; retry in \{retry_after_ms}ms",
      )
    GatewayRequestTimeout => logger.write_string("gateway request timed out")
  }
}

///|
/// Gateway events that may wait for event handlers before later ones are
/// dropped for handlers.
pub const DEFAULT_EVENT_BACKLOG : Int32 = 10000

///|
priv struct TypedEventHandler {
  kind : @model.EventKind
  required_intents : @model.Intents
  dispatch : async (GatewayCtx, @model.Event) -> Unit
}

///|
priv struct ServiceHandler {
  name : String
  dispatch : async (GatewayCtx) -> Unit
}

///|
/// Gateway executor for a gateway-free application core on native, JavaScript,
/// and Wasm. Voice connections are native-only.
priv struct BotCore {
  app_ : @app.App
  token_ : String
  intents_ : @model.Intents?
  capabilities_ : @model.GatewayCapabilities
  mut presence_ : @model.UpdatePresence?
  client_ : @dhttp.Client?
  gateway_url_ : String?
  shards_ : ShardConfig
  compression_ : @gateway.GatewayCompression?
  saved_sessions_ : Map[Int32, BotSession]
  starting_ : Ref[Bool]
  running_shards_ : Ref[Array[ManagedShard]]
  identify_queue_ : &@queue.IdentifyQueue?
  sync_ : @app.CommandScope?
  sync_unowned_ : @framework.UnownedCommands
  event_backlog_ : Int32
  shutdown_grace_ms_ : Int32
  max_message_bytes_ : Int32
  typed_events_ : Array[TypedEventHandler]
  raw_events_ : Array[async (GatewayCtx, @model.Event) -> Unit]
  event_middleware_ : Array[EventMiddleware]
  mut cache_ : @cache.InMemoryCache?
  decode_errors_ : Array[(String, Json) -> Unit]
  telemetry_ : Array[(@telemetry.TelemetryEvent) -> Unit raise]
  services_ : Array[ServiceHandler]
  collector_ : EventCollector
  // Production uses Shard::start's WebSocket connector. Whitebox tests inject
  // the same in-memory GatewayTransport seam used by gateway_test.mbt.
  connector_ : Ref[(async (String) -> &@gateway.GatewayTransport)?]
  // Whitebox seam for `/gateway/bot`. Production always uses the REST
  // response.
  gateway_bot_info_ : Ref[@model.GatewayBotInfo?]
  // Whitebox seam for virtual time: shards, the identify queue, interaction
  // timing, the shutdown grace period, and the REST client the bot builds
  // from its token all read this clock.
  clock_ : Ref[&@hclock.Clock]
  // Whitebox seam for the shards' heartbeat jitter and backoff; `None` lets
  // each shard seed its own.
  rand_ : Ref[@random.Rand?]
  // Intents resolved (and warned about) once by `BotBuilder::build`.
  frozen_intents_ : @model.Intents?
}

///|
/// Create a gateway runner for `app`. When `intents` is omitted, the bot
/// infers the union of intents required by its typed event subscriptions at
/// `run` time (privileged intents are only inferred, never invented — they
/// must still be enabled in the developer portal). `client` supplies a
/// preconfigured REST client; by default one is built from `token`.
/// `shards`, `compression` (or the older `compress=true`, meaning
/// `ZlibStream`), and `identify_queue` configure sharding, transport
/// compression, and cross-process identify coordination. Every IDENTIFY, at
/// startup or after a lost session, first reads `session_start_limit` from
/// `GET /gateway/bot`; an exhausted limit ends `run` with
/// `SessionStartLimitExceeded` instead of risking a token reset. `capabilities`
/// is sent in Identify (see `@model.GatewayCapabilities`).
///
/// When `sync` is omitted, the bot performs no command synchronization. When
/// set, synchronization runs once per process after the first READY. It uses
/// Discord's bulk overwrite and deletes commands in that scope that this App
/// does not declare, except for entry points, which are always preserved.
/// `sync_unowned=Keep` also preserves commands registered by other owners.
/// Deletions are reported through the app's warning hook. In multi-process
/// sharding, enable synchronization in exactly one process.
/// `sessions` seeds saved Bot sessions per shard id so those shards RESUME instead
/// of identifying (see `Bot::sessions`). It restores gateway identity, not
/// optional cache contents or application-owned state. `run` rejects a saved
/// session whose gateway id disagrees with its READY session id.
fn BotCore::new(
  app : @app.App,
  token~ : String,
  intents? : @model.Intents,
  capabilities~ : @model.GatewayCapabilities = @model.GatewayCapabilities::none(),
  client? : @dhttp.Client,
  gateway_url? : String,
  shards~ : ShardConfig = Single(id=0, count=1),
  compress~ : Bool = false,
  compression? : @gateway.GatewayCompression,
  identify_queue? : &@queue.IdentifyQueue,
  sync? : @app.CommandScope,
  sync_unowned~ : @framework.UnownedCommands = Delete,
  sessions~ : Map[Int32, BotSession] = Map([]),
  event_backlog~ : Int32 = DEFAULT_EVENT_BACKLOG,
  shutdown_grace_ms~ : Int32 = DEFAULT_SHUTDOWN_GRACE_MS,
  max_message_bytes~ : Int32 = @gateway.DEFAULT_MAX_MESSAGE_BYTES,
) -> BotCore {
  let clock : Ref[&@hclock.Clock] = Ref(@transport.AsyncClock::new())
  {
    app_: app,
    token_: token,
    intents_: intents,
    capabilities_: capabilities,
    presence_: None,
    client_: client,
    gateway_url_: gateway_url,
    shards_: shards,
    compression_: match compression {
      Some(_) => compression
      None => if compress { Some(ZlibStream) } else { None }
    },
    saved_sessions_: {
      let snapshots : Map[Int32, BotSession] = Map([])
      for shard_id, snapshot in sessions {
        snapshots[shard_id] = clone_bot_session(snapshot)
      }
      snapshots
    },
    starting_: Ref(false),
    running_shards_: Ref([]),
    identify_queue_: identify_queue,
    sync_: sync,
    sync_unowned_: sync_unowned,
    event_backlog_: event_backlog,
    shutdown_grace_ms_: shutdown_grace_ms,
    max_message_bytes_: max_message_bytes,
    typed_events_: [],
    raw_events_: [],
    event_middleware_: [],
    cache_: None,
    decode_errors_: [],
    telemetry_: [],
    services_: [],
    collector_: EventCollector(clock~),
    connector_: Ref(None),
    gateway_bot_info_: Ref(None),
    clock_: clock,
    rand_: Ref(None),
    frozen_intents_: None,
  }
}

///|
/// Current resumable gateway state paired with READY metadata, keyed by shard
/// id. A supplied snapshot is available from the start of `run` until its
/// shard replaces, drops, or invalidates it, including while `run` still
/// resolves the shard layout over REST; an unsaved shard appears after READY.
/// Empty while the bot is not running. Returned values do not alias mutable
/// runtime state.
fn BotCore::sessions(self : BotCore) -> Map[Int32, BotSession] {
  let sessions : Map[Int32, BotSession] = Map([])
  if self.starting_.val {
    for shard_id, saved in self.saved_sessions_ {
      sessions[shard_id] = clone_bot_session(saved)
    }
    return sessions
  }
  for owner in self.running_shards_.val {
    if owner.shard.session() is Some(gateway) &&
      owner.context is Some(ctx) &&
      gateway.id == ctx.ready_.session_id {
      sessions[owner.id] = { gateway, ready: clone_ready(ctx.ready_), }
    }
  }
  sessions
}

///|
/// Observe structured gateway, dispatch, and REST telemetry aggregated by
/// this bot. Hooks run synchronously and should return promptly.
fn BotCore::on_telemetry(
  self : BotCore,
  hook : (@telemetry.TelemetryEvent) -> Unit raise,
) -> Unit {
  self.telemetry_.push(hook)
}

///|
fn BotCore::emit_telemetry(
  self : BotCore,
  event : @telemetry.TelemetryEvent,
) -> Unit {
  for hook in self.telemetry_ {
    hook(event) catch {
      error =>
        self.app_.warn(
          @app.Executor(
            source="gateway",
            message="telemetry hook failed: \{Repr(error)}",
          ),
        )
    }
  }
}

///|
/// Feeds every decoded gateway event into an opt-in cache before dispatching
/// typed and raw event handlers.
fn BotCore::attach_cache(self : BotCore, cache : @cache.InMemoryCache) -> Unit {
  self.cache_ = Some(cache)
}

///|
/// Subscribe a typed handler to one gateway event (see `Events` for the
/// descriptors). The event's required intents join the inferred intent set
/// when `BotBuilder(...)` omits explicit `intents`. Handlers run through the event
/// middleware chain; a raised error is reported via the app's failure policy
/// without stopping the bot.
fn[T] BotCore::on(
  self : BotCore,
  event : EventType[T],
  handler : async (GatewayCtx, T) -> Unit,
) -> Unit {
  self.typed_events_.push({
    kind: event.kind(),
    required_intents: event.required_intents(),
    dispatch: (ctx, raw) => {
      if event.project(raw) is Some(value) {
        handler(ctx, value)
      }
    },
  })
}

///|
/// Subscribe to the raw event stream: every decoded gateway dispatch,
/// including `Resumed` and `Unknown`, without payload projection. Unlike
/// `BotBuilder::on`, this adds nothing to the inferred intent set.
fn BotCore::on_event(
  self : BotCore,
  handler : async (GatewayCtx, @model.Event) -> Unit,
) -> Unit {
  self.raw_events_.push(handler)
}

///|
/// Observe gateway events whose known payload failed typed decoding.
///
/// `marker` is the full synthetic event type
/// `DECODE_ERROR:<event-name>:<decode-error>`, and `payload` is Discord's raw
/// event data. Handlers run synchronously in the dispatch loop and should
/// return promptly. Registering a handler does not add gateway intents or
/// widen the event filter.
fn BotCore::on_decode_error(
  self : BotCore,
  handler : (String, Json) -> Unit,
) -> Unit {
  self.decode_errors_.push(handler)
}

///|
/// Register a long-running background task started alongside the shards when
/// the bot runs (e.g. a periodic status updater). `name` labels the service
/// in failure reports. A raised error is reported via the app's failure
/// policy and stops only that service, not the bot.
fn BotCore::service(
  self : BotCore,
  name~ : String,
  handler : async (GatewayCtx) -> Unit,
) -> Unit {
  self.services_.push({ name, dispatch: handler, })
}

///|
fn BotCore::observe_decode_error(self : BotCore, event : @model.Event) -> Unit {
  match event {
    Unknown(t~, d~) if t.has_prefix("DECODE_ERROR:") => {
      // Never include `d`: payloads can contain user content and credentials.
      self.app_.warn(
        @app.Executor(
          source="gateway",
          message="gateway event decode failure: \{t}",
        ),
      )
      self.emit_telemetry(DecodeError(marker=t))
      for handler in self.decode_errors_ {
        handler(t, d)
      }
    }
    _ => ()
  }
}

///|
fn privileged_intents() -> @model.Intents {
  @model.Intents::guild_members() |
  @model.Intents::guild_presences() |
  @model.Intents::message_content()
}

///|
/// Resolve gateway intents from typed subscriptions. `required_intents` is an
/// event-delivery union, so an explicit configuration satisfies a descriptor
/// when it intersects that union. Automatic mode follows the requested union
/// literally, then removes privileged bits; enabling those always requires an
/// explicit opt-in by the application.
fn BotCore::resolved_intents(self : BotCore) -> @model.Intents {
  match self.intents_ {
    Some(explicit) => {
      for subscription in self.typed_events_ {
        let required = subscription.required_intents
        if required.bits() != 0U && (required & explicit).bits() == 0U {
          self.app_.warn(
            @app.Executor(
              source="gateway",
              message="event \{Repr(subscription.kind)} may not be delivered; add one of its required intents explicitly",
            ),
          )
        }
      }
      explicit
    }
    None => {
      let mut derived = @model.Intents::none()
      let privileged = privileged_intents()
      for subscription in self.typed_events_ {
        let required = subscription.required_intents
        if (required & privileged).bits() != 0U {
          self.app_.warn(
            @app.Executor(
              source="gateway",
              message="event \{Repr(subscription.kind)} requires a privileged intent; pass intents explicitly",
            ),
          )
        }
        derived = derived | required
      }
      if !self.raw_events_.is_empty() {
        self.app_.warn(
          @app.Executor(
            source="gateway",
            message="raw event handlers do not imply gateway intents; pass intents explicitly for the events they consume",
          ),
        )
      }
      let privileged_bits = derived.bits() & privileged.bits()
      @model.Intents::from_bits(derived.bits() ^ privileged_bits)
    }
  }
}

///|
fn event_kind(event : @model.Event) -> @model.EventKind {
  match event {
    ApplicationCommandPermissionsUpdate(_) =>
      KApplicationCommandPermissionsUpdate
    AutoModerationActionExecution(_) => KAutoModerationActionExecution
    AutoModerationRuleCreate(_) => KAutoModerationRuleCreate
    AutoModerationRuleDelete(_) => KAutoModerationRuleDelete
    AutoModerationRuleUpdate(_) => KAutoModerationRuleUpdate
    ChannelCreate(_) => KChannelCreate
    ChannelDelete(_) => KChannelDelete
    ChannelInfo(_) => KChannelInfo
    ChannelPinsUpdate(_) => KChannelPinsUpdate
    ChannelUpdate(_) => KChannelUpdate
    EntitlementCreate(_) => KEntitlementCreate
    EntitlementDelete(_) => KEntitlementDelete
    EntitlementUpdate(_) => KEntitlementUpdate
    GuildAuditLogEntryCreate(_) => KGuildAuditLogEntryCreate
    GuildBanAdd(_) => KGuildBanAdd
    GuildBanRemove(_) => KGuildBanRemove
    GuildCreate(_) => KGuildCreate
    GuildDelete(_) => KGuildDelete
    GuildEmojisUpdate(_) => KGuildEmojisUpdate
    GuildIntegrationsUpdate(_) => KGuildIntegrationsUpdate
    GuildMemberAdd(_) => KGuildMemberAdd
    GuildMemberRemove(_) => KGuildMemberRemove
    GuildMembersChunk(_) => KGuildMembersChunk
    GuildMemberUpdate(_) => KGuildMemberUpdate
    GuildRoleCreate(_) => KGuildRoleCreate
    GuildRoleDelete(_) => KGuildRoleDelete
    GuildRoleUpdate(_) => KGuildRoleUpdate
    GuildScheduledEventCreate(_) => KGuildScheduledEventCreate
    GuildScheduledEventDelete(_) => KGuildScheduledEventDelete
    GuildScheduledEventUpdate(_) => KGuildScheduledEventUpdate
    GuildScheduledEventUserAdd(_) => KGuildScheduledEventUserAdd
    GuildScheduledEventUserRemove(_) => KGuildScheduledEventUserRemove
    GuildSoundboardSoundCreate(_) => KGuildSoundboardSoundCreate
    GuildSoundboardSoundDelete(_) => KGuildSoundboardSoundDelete
    GuildSoundboardSoundsUpdate(_) => KGuildSoundboardSoundsUpdate
    GuildSoundboardSoundUpdate(_) => KGuildSoundboardSoundUpdate
    SoundboardSounds(_) => KSoundboardSounds
    GuildStickersUpdate(_) => KGuildStickersUpdate
    GuildUpdate(_) => KGuildUpdate
    IntegrationCreate(_) => KIntegrationCreate
    IntegrationDelete(_) => KIntegrationDelete
    IntegrationUpdate(_) => KIntegrationUpdate
    InteractionCreate(_) => KInteractionCreate
    InviteCreate(_) => KInviteCreate
    InviteDelete(_) => KInviteDelete
    MessageCreate(_) => KMessageCreate
    MessageDelete(_) => KMessageDelete
    MessageDeleteBulk(_) => KMessageDeleteBulk
    MessagePollVoteAdd(_) => KMessagePollVoteAdd
    MessagePollVoteRemove(_) => KMessagePollVoteRemove
    MessageReactionAdd(_) => KMessageReactionAdd
    MessageReactionRemove(_) => KMessageReactionRemove
    MessageReactionRemoveAll(_) => KMessageReactionRemoveAll
    MessageReactionRemoveEmoji(_) => KMessageReactionRemoveEmoji
    MessageUpdate(_) => KMessageUpdate
    PresenceUpdate(_) => KPresenceUpdate
    RateLimited(_) => KRateLimited
    Ready(_) => KReady
    Resumed => KResumed
    StageInstanceCreate(_) => KStageInstanceCreate
    StageInstanceDelete(_) => KStageInstanceDelete
    StageInstanceUpdate(_) => KStageInstanceUpdate
    SubscriptionCreate(_) => KSubscriptionCreate
    SubscriptionDelete(_) => KSubscriptionDelete
    SubscriptionUpdate(_) => KSubscriptionUpdate
    ThreadCreate(_) => KThreadCreate
    ThreadDelete(_) => KThreadDelete
    ThreadListSync(_) => KThreadListSync
    ThreadMembersUpdate(_) => KThreadMembersUpdate
    ThreadMemberUpdate(_) => KThreadMemberUpdate
    ThreadUpdate(_) => KThreadUpdate
    TypingStart(_) => KTypingStart
    UserUpdate(_) => KUserUpdate
    VoiceChannelEffectSend(_) => KVoiceChannelEffectSend
    VoiceChannelStartTimeUpdate(_) => KVoiceChannelStartTimeUpdate
    VoiceChannelStatusUpdate(_) => KVoiceChannelStatusUpdate
    VoiceServerUpdate(_) => KVoiceServerUpdate
    VoiceStateUpdate(_) => KVoiceStateUpdate
    WebhooksUpdate(_) => KWebhooksUpdate
    Unknown(..) | @model.Event::.. => KUnknown
  }
}

///|
fn BotCore::event_filter(self : BotCore) -> (@model.EventKind) -> Bool {
  if self.cache_ is Some(_) || !self.raw_events_.is_empty() {
    return _ => true
  }
  kind => {
    if self.collector_.waits_for(kind) {
      return true
    }
    if kind == KReady || kind == KInteractionCreate {
      return true
    }
    for subscription in self.typed_events_ {
      if subscription.kind == kind {
        return true
      }
    }
    false
  }
}

///|
fn BotCore::spawn_services(
  self : BotCore,
  group : @async.TaskGroup[Unit],
  gateway : GatewayCtx,
) -> Unit {
  for service in self.services_ {
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      (service.dispatch)(gateway) catch {
        error if @async.is_being_cancelled() => raise error
        error => self.app_.report_failure(Service(name=service.name), error)
      }
    })
  }
}

///|
async fn BotCore::spawn_event_handlers(
  self : BotCore,
  spawner : @app.Spawner,
  gateway : GatewayCtx,
  event : @model.Event,
) -> Unit {
  let kind = event_kind(event)
  // Middleware that was running when the shutdown was requested can still
  // pass the event on; its handlers would not start.
  if !gateway.intake_.is_open() {
    self.emit_telemetry(EventDiscarded(kind="\{Repr(kind)}"))
    return
  }
  let mut handler_count = self.raw_events_.length()
  for subscription in self.typed_events_ {
    if subscription.kind == kind {
      handler_count += 1
    }
  }
  self.emit_telemetry(EventDispatched(kind="\{Repr(kind)}", handler_count~))
  for subscription in self.typed_events_ {
    if subscription.kind == kind {
      spawner(() => {
        (subscription.dispatch)(gateway, event) catch {
          error if @async.is_being_cancelled() => raise error
          error => self.app_.report_failure(Event(kind~), error)
        }
      })
    }
  }
  for handler in self.raw_events_ {
    spawner(() => {
      handler(gateway, event) catch {
        error if @async.is_being_cancelled() => raise error
        error => self.app_.report_failure(Event(kind~), error)
      }
    })
  }
}

///|
fn BotCore::spawn_interaction(
  self : BotCore,
  group : @async.TaskGroup[Unit],
  handlers : HandlerTracker,
  framework : @framework.Framework,
  interaction : @model.Interaction,
) -> Unit {
  // Admission is unbounded and never blocks the dispatch loop: the response
  // deadline starts here, and the app applies its work budget per handler.
  handlers.enter()
  group.spawn_bg(allow_failure=true, () => {
    defer handlers.leave()
    ignore(
      framework.process(interaction) catch {
        error if @async.is_being_cancelled() => raise error
        error => {
          self.app_.warn(@app.InteractionProcessingFailed(error~))
          false
        }
      },
    )
  })
}

///|
/// Connect and process gateway events until graceful shutdown or a fatal close.
async fn BotCore::run(self : BotCore) -> Unit {
  let intents = self.frozen_intents_.unwrap_or_else(() => {
    self.resolved_intents()
  })
  let owns_client = self.client_ is None
  let client = self.client_.unwrap_or_else(() => {
    Client(self.token_, clock=self.clock_.val)
  })
  defer (if owns_client { client.close() })
  // Forward REST telemetry only while this run lasts: a caller-owned client
  // outlives the bot and must neither keep it alive nor call it afterwards.
  let detach = client.attach_telemetry(event => self.emit_telemetry(event))
  defer detach()
  // Supplied snapshots stay visible through `sessions()` until the shards
  // exist, so a periodic persister never observes an empty map mid-startup.
  self.starting_.val = true
  defer {
    self.starting_.val = false
  }
  let resolved = self.resolve_shards(client)
  @async.with_task_group((group : @async.TaskGroup[Unit]) => {
    let filter = self.event_filter()
    let shard_events : @aqueue.Queue[ManagedShardEvent] = Queue(kind=Unbounded)
    let identify_queue : &@queue.IdentifyQueue = match self.identify_queue_ {
      Some(queue) => queue
      None =>
        @queue.InMemoryQueue(
          max_concurrency=resolved.max_concurrency,
          clock=self.clock_.val,
        )
    }
    let identify_queue : &@queue.IdentifyQueue = (
      { bot: self, client, inner: identify_queue, refusals: shard_events, } :
      IdentifyGuard)
    let managed_shards : Array[ManagedShard] = []
    let shard_handles : Array[@gateway.Shard] = []
    // Register cleanup before any shard starts, so it is in place however the
    // group ends; the arrays fill in below.
    group.add_defer(() => self.running_shards_.val = [])
    group.add_defer(() => {
      @async.protect_from_cancel(() => close_shards(shard_handles))
    })
    for shard_id in resolved.ids {
      let shard = self.start_managed_shard(
        group,
        token=self.token_,
        intents~,
        gateway_url=resolved.gateway_url,
        shard_id~,
        shard_count=resolved.count,
        identify_queue~,
        event_filter=filter,
        session?=resolved.saved_sessions
          .get(shard_id)
          .map(snapshot => snapshot.gateway),
      )
      managed_shards.push({ id: shard_id, shard, context: None, })
      shard_handles.push(shard)
    }
    self.running_shards_.val = managed_shards
    let shard_routes : Map[Int32, @gateway.Shard] = Map([])
    for owner in managed_shards {
      shard_routes[owner.id] = owner.shard
    }
    self.starting_.val = false
    for owner in managed_shards {
      group.spawn_bg(no_wait=true, () => {
        for ;; {
          shard_events.put(Shard(owner~, event=owner.shard.next()))
        }
      })
    }
    // Closed by `GatewayCtx::shutdown`: from then on no event middleware,
    // event handler, or interaction handler starts, and what waits to start
    // is dropped; the tracker counts what has started, for the grace period.
    let intake = @app.HandlerIntake()
    let handlers = HandlerTracker::new()
    let spawner = handlers.spawner(self.app_.spawner(group, intake~))
    // Event middleware and handler fan-out run in their own task so the
    // dispatch loop never waits for event handler capacity; interactions,
    // including those that wake component waiters, are always read promptly.
    // Bounded: when handlers fall behind for long, later events are dropped
    // for handlers (not for the cache or interactions, which ran already)
    // instead of queueing without limit.
    let event_jobs : @aqueue.Queue[(GatewayCtx, @model.Event)] = Queue(
      kind=Blocking(self.event_backlog_),
    )
    let backlog = Backlog::new()
    let discard = (event : @model.Event) => {
      self.emit_telemetry(EventDiscarded(kind="\{Repr(event_kind(event))}"))
    }
    group.spawn_bg(no_wait=true, () => {
      for ;; {
        let (ctx, event) = event_jobs.get()
        backlog.taken()
        // Judged as the job is taken, with nothing to wait for before the
        // middleware starts.
        if intake.is_open() {
          handlers.track(() => self.dispatch_event(spawner, ctx, event))
        } else {
          discard(event)
        }
      }
    })
    let dispatch_event = (ctx : GatewayCtx, event : @model.Event) => {
      if !intake.is_open() {
        discard(event)
        return
      }
      let queued_now = event_jobs.try_put((ctx, event)) catch { _ => false }
      if queued_now {
        backlog.queued()
      } else {
        let kind = "\{Repr(event_kind(event))}"
        self.emit_telemetry(EventDropped(kind~, backlog=self.event_backlog_))
        if backlog.dropped() {
          self.app_.warn(
            @app.Executor(
              source="gateway",
              message="event handlers are \{self.event_backlog_} events behind; dropping \{kind} and later events until they catch up",
            ),
          )
        }
      }
    }
    let mut app_ctx : @app.AppCtx? = None
    let mut framework : @framework.Framework? = None
    let initialize_context = (owner : ManagedShard, ready : @model.Ready) => {
      if framework is None {
        let router = @framework.Framework(
          client,
          ready.application.id,
          clock=self.clock_.val,
        )
        let waiter : @app.ComponentWaiter = (custom_id, user, timeout_ms) => {
          router.wait_for_component(custom_id~, user?, timeout_ms?)
        }
        let latency_ms = () => {
          let mut total = 0L
          let mut count = 0L
          for shard in shard_handles {
            if shard.latency_ms() is Some(latency) {
              total += latency
              count += 1L
            }
          }
          if count == 0L {
            None
          } else {
            Some(total / count)
          }
        }
        let attached = self.app_.attach(
          router,
          client~,
          application_id=ready.application.id,
          waiter~,
          latency_ms~,
          intake~,
        )
        app_ctx = Some(attached)
        framework = Some(router)
      }
      guard app_ctx is Some(attached) && framework is Some(router) else {
        abort("gateway runtime initialized without an application context")
      }
      match owner.context {
        Some(existing) => {
          existing.ready_ = ready
          existing
        }
        None => {
          let created = GatewayCtx::{
            app_: attached,
            ready_: ready,
            intents_: intents,
            shard_: owner.shard,
            shards_: shard_handles,
            shard_routes_: shard_routes,
            shard_count_: resolved.count,
            cache_: self.cache_,
            framework_: router,
            collector_: self.collector_,
            intake_: intake,
          }
          owner.context = Some(created)
          created
        }
      }
    }
    // Prepare restored contexts before reading any replayed Gateway dispatch.
    for owner in managed_shards {
      if resolved.saved_sessions.get(owner.id) is Some(saved) {
        initialize_context(owner, clone_ready(saved.ready)) |> ignore
      }
    }
    let mut services_started = false
    let mut sync_done = false
    let start_services = (ctx : GatewayCtx) => {
      if !services_started {
        services_started = true
        self.spawn_services(group, ctx)
      }
    }
    for ;; {
      let (owner, event) = match shard_events.get() {
        Shard(owner~, event~) => (owner, event)
        IdentifyRefused(error) => {
          close_shards(shard_handles)
          raise error
        }
      }
      match event {
        Dispatch(Ready(ready) as event) => {
          if self.cache_ is Some(cache) {
            cache.update(event)
          }
          let ctx = initialize_context(owner, ready)
          if !sync_done {
            sync_done = true
            match self.sync_ {
              Some(scope) => {
                let report = self.app_.sync_commands(
                  client,
                  ready.application.id,
                  scope~,
                  unowned=self.sync_unowned_,
                )
                for scope in report.scopes {
                  if !scope.deleted.is_empty() {
                    let target = match scope.guild_id {
                      None => "global scope"
                      Some(guild_id) => "guild \{guild_id}"
                    }
                    self.app_.warn(
                      @app.Executor(
                        source="gateway",
                        message="command sync deleted \{scope.deleted.join(", ")} in \{target}; use sync_unowned=Keep to preserve undeclared commands",
                      ),
                    )
                  }
                }
              }
              None => ()
            }
          }
          start_services(ctx)
          self.collector_.dispatch(event)
          dispatch_event(ctx, event)
        }
        Dispatch(InteractionCreate(interaction) as event) => {
          if self.cache_ is Some(cache) {
            cache.update(event)
          }
          match (owner.context, framework) {
            (Some(ctx), Some(router)) => {
              start_services(ctx)
              self.collector_.dispatch(event)
              // Processing is another bounded child task. Awaiting it here
              // would deadlock handlers waiting for a later component event.
              self.spawn_interaction(group, handlers, router, interaction)
              dispatch_event(ctx, event)
            }
            _ =>
              self.app_.warn(
                @app.Executor(
                  source="gateway",
                  message="dropping INTERACTION_CREATE received before shard \{owner.id} READY",
                ),
              )
          }
        }
        Dispatch(event) => {
          let event = match (event, self.cache_) {
            (MessageUpdate(update), Some(cache)) =>
              @model.Event::MessageUpdate({
                ..update,
                before: cache.message(
                  update.message.channel_id,
                  update.message.id,
                ),
              })
            _ => event
          }
          if self.cache_ is Some(cache) {
            cache.update(event)
          }
          self.observe_decode_error(event)
          match owner.context {
            Some(ctx) => {
              start_services(ctx)
              self.collector_.dispatch(event)
              dispatch_event(ctx, event)
            }
            None =>
              self.app_.warn(
                @app.Executor(
                  source="gateway",
                  message="dropping \{Repr(event_kind(event))} received before shard \{owner.id} READY",
                ),
              )
          }
        }
        Connected(resumed~) =>
          if resumed && owner.context is Some(ctx) {
            start_services(ctx)
          }
        Disconnected(..) => if !intake.is_open() { break }
        FatallyClosed(code~) => {
          if !intake.is_open() {
            break
          }
          close_shards(shard_handles)
          raise BotError::FatallyClosed(code~)
        }
        @gateway.ShardEvent::.. => ()
      }
    }
    // Only a requested shutdown ends the loop, at the first shard to go; the
    // handler that asked may still be closing the others. Discard the events
    // still waiting for handlers, finish closing the shards, then give
    // running handlers the grace period and cancel what is left with the
    // rest of the group.
    while event_jobs.try_get() is Some((_, event)) {
      backlog.taken()
      discard(event)
    }
    close_shards(shard_handles)
    let grace_ms = self.shutdown_grace_ms_
    if @transport.with_timeout_opt(self.clock_.val, grace_ms, () => {
        handlers.wait_idle()
      })
      is None {
      self.app_.warn(
        @app.Executor(
          source="gateway",
          message="\{handlers.active} handlers were still running \{grace_ms} ms after shutdown; cancelling them",
        ),
      )
      group.return_immediately(())
    }
  })
}
