///|
/// Where application commands are synchronized after the first READY.
pub(all) enum CommandSync {
  Global
  Guild(@model.GuildId)
  Guilds(Array[@model.GuildId])
  Disabled
} derive(Debug)

///|
/// Configuration errors detected before opening the gateway.
pub(all) suberror BotConfigError {
  EmptyToken
  DuplicateCommand(name~ : String)
  DuplicateCommandPath(command~ : String, path~ : String)
  NestedSubcommandGroup(command~ : String, path~ : String)
  ChoicesWithAutocomplete(command~ : String, path~ : String)
  RequiredOptionAfterOptional(command~ : String, path~ : String)
} derive(Debug)

///|
/// Fatal runtime failures reported by Discord.
pub(all) suberror BotError {
  /// Close codes 4013 and 4014 indicate invalid or disallowed gateway
  /// intents. Check explicit intents and privileged-intent approval.
  FatallyClosed(code~ : Int)
} derive(Debug)

///|
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
  }
}

///|
priv struct TypedEventHandler {
  kind : @model.EventKind
  required_intents : @model.Intents
  dispatch : async (GatewayCtx, @model.Event) -> Unit
}

///|
priv struct ComponentHandler {
  prefix : String
  dispatch : async (@framework.ComponentCtx) -> Unit
}

///|
priv struct ModalHandler {
  prefix : String
  dispatch : async (@framework.ModalCtx) -> Unit
}

///|
priv struct AutocompleteHandler {
  name : String
  dispatch : async (@framework.AutocompleteCtx) -> Unit
}

///|
priv struct ServiceHandler {
  name : String
  dispatch : async (GatewayCtx) -> Unit
}

///|
type Spawner = async (async () -> Unit) -> Unit

///|
/// A declaratively configured Discord bot. Registration mutates this value so
/// callers can use MoonBit's cascade syntax; `run` and
/// `start_interaction_app` freeze the declarations into a Framework.
pub struct Bot {
  priv token_ : String
  priv intents_ : @model.Intents?
  priv sync_ : CommandSync
  priv client_ : @dhttp.Client?
  priv gateway_url_ : String?
  priv shard_id_ : Int
  priv shard_count_ : Int
  priv max_in_flight_ : Int
  priv commands_ : Array[RegisteredCommand]
  priv typed_events_ : Array[TypedEventHandler]
  priv raw_events_ : Array[async (GatewayCtx, @model.Event) -> Unit]
  priv components_ : Array[ComponentHandler]
  priv modals_ : Array[ModalHandler]
  priv autocompletes_ : Array[AutocompleteHandler]
  priv services_ : Array[ServiceHandler]
  priv mut policy_ : ErrorPolicy?
  priv mut warn_ : (String) -> Unit
  // Production uses Shard::start's WebSocket connector. Whitebox tests inject
  // the same in-memory GatewayTransport seam used by gateway_test.mbt.
  priv connector_ : Ref[(async (String) -> &@gateway.GatewayTransport)?]
}

///|
pub fn Bot::new(
  token~ : String,
  intents? : @model.Intents,
  sync? : CommandSync = Global,
  client? : @dhttp.Client,
  gateway_url? : String,
  shard_id? : Int = 0,
  shard_count? : Int = 1,
  max_in_flight? : Int = 64,
) -> Bot {
  {
    token_: token,
    intents_: intents,
    sync_: sync,
    client_: client,
    gateway_url_: gateway_url,
    shard_id_: shard_id,
    shard_count_: shard_count,
    max_in_flight_: max_in_flight,
    commands_: [],
    typed_events_: [],
    raw_events_: [],
    components_: [],
    modals_: [],
    autocompletes_: [],
    services_: [],
    policy_: None,
    warn_: message => println(message),
    connector_: Ref(None),
  }
}

///|
pub fn[A] Bot::command(self : Bot, command : Command[A]) -> Unit {
  self.register(command.erase())
}

///|
pub fn Bot::register(self : Bot, command : RegisteredCommand) -> Unit {
  self.commands_.push(command)
}

///|
pub fn[T] Bot::on(
  self : Bot,
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
pub fn Bot::on_event(
  self : Bot,
  handler : async (GatewayCtx, @model.Event) -> Unit,
) -> Unit {
  self.raw_events_.push(handler)
}

///|
pub fn Bot::component(
  self : Bot,
  prefix : String,
  handler : async (@framework.ComponentCtx) -> Unit,
) -> Unit {
  self.components_.push({ prefix, dispatch: handler })
}

///|
pub fn Bot::modal(
  self : Bot,
  prefix : String,
  handler : async (@framework.ModalCtx) -> Unit,
) -> Unit {
  self.modals_.push({ prefix, dispatch: handler })
}

///|
/// Register a raw autocomplete handler. A raw handler takes precedence over
/// Arg-level `suggest` handlers registered for the same command name.
pub fn Bot::autocomplete(
  self : Bot,
  name : String,
  handler : async (@framework.AutocompleteCtx) -> Unit,
) -> Unit {
  self.autocompletes_.push({ name, dispatch: handler })
}

///|
pub fn Bot::service(
  self : Bot,
  name~ : String,
  handler : async (GatewayCtx) -> Unit,
) -> Unit {
  self.services_.push({ name, dispatch: handler })
}

///|
pub fn Bot::error_policy(self : Bot, policy : ErrorPolicy) -> Unit {
  self.policy_ = Some(policy)
}

///|
pub fn Bot::on_warn(self : Bot, hook : (String) -> Unit) -> Unit {
  self.warn_ = hook
}

///|
fn Bot::current_policy(self : Bot) -> ErrorPolicy {
  self.policy_.unwrap_or_else(() => default_error_policy(self.warn_))
}

///|
fn validate_command_options(
  command : String,
  parent_path : Array[String],
  options : Array[@model.CommandOption],
) -> Unit raise BotConfigError {
  let mut saw_optional = false
  for option in options {
    let path = parent_path.copy()
    path.push(option.name)
    if option.autocomplete is Some(true) && option.choices is Some(_) {
      raise ChoicesWithAutocomplete(command~, path=path.join("/"))
    }
    if !(option.typ is (SubCommand | SubCommandGroup)) {
      if option.required is Some(true) {
        if saw_optional {
          raise RequiredOptionAfterOptional(command~, path=path.join("/"))
        }
      } else {
        saw_optional = true
      }
    }
    if option.options is Some(children) {
      validate_command_options(command, path, children)
    }
  }
}

///|
fn Bot::validate(self : Bot) -> Unit raise BotConfigError {
  if self.token_.is_empty() {
    raise EmptyToken
  }
  let commands : Set[String] = Set([])
  for command in self.commands_ {
    let command_key = command_key(command.definition.typ, command.name_)
    if commands.contains(command_key) {
      raise DuplicateCommand(name=command.name_)
    }
    commands.add(command_key)
    for path in command.nested_group_paths_ {
      raise NestedSubcommandGroup(command=command.name_, path=path.join("/"))
    }
    let paths : Set[String] = Set([])
    for path in command.node_paths_ {
      let key = path_key(path)
      if paths.contains(key) {
        raise DuplicateCommandPath(command=command.name_, path=path.join("/"))
      }
      paths.add(key)
    }
    validate_command_options(command.name_, [], command.definition.options)
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
fn Bot::resolved_intents(self : Bot) -> @model.Intents {
  match self.intents_ {
    Some(explicit) => {
      for subscription in self.typed_events_ {
        let required = subscription.required_intents
        if required.bits() != 0U && (required & explicit).bits() == 0U {
          (self.warn_)(
            "event \{to_repr(subscription.kind)} may not be delivered; add one of its required intents explicitly",
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
          (self.warn_)(
            "event \{to_repr(subscription.kind)} requires a privileged intent; pass intents explicitly",
          )
        }
        derived = derived | required
      }
      if !self.raw_events_.is_empty() {
        (self.warn_)(
          "raw event handlers do not imply gateway intents; pass intents explicitly for the events they consume",
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
    Unknown(..) => KUnknown
  }
}

///|
fn Bot::event_filter(self : Bot) -> (@model.EventKind) -> Bool {
  if !self.raw_events_.is_empty() {
    return _ => true
  }
  kind => {
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
async fn spawn_limited(
  group : @async.TaskGroup[Unit],
  limiter : @async.Semaphore,
  body : async () -> Unit,
) -> Unit {
  // Acquire in the pull loop: at capacity, gateway delivery applies bounded
  // backpressure instead of allocating an unbounded list of pending tasks.
  limiter.acquire()
  group.spawn_bg(allow_failure=true, () => {
    defer limiter.release()
    body()
  })
}

///|
fn bounded_spawner(
  group : @async.TaskGroup[Unit],
  limiter : @async.Semaphore,
) -> Spawner {
  body => spawn_limited(group, limiter, body)
}

///|
fn failure_context(
  origin : FailureOrigin,
  phase : ResponsePhase?,
  raw : @framework.CommandCtx?,
  warn : (String) -> Unit,
) -> FailureCtx {
  { origin_: origin, phase_: phase, raw_: raw, warn_: warn }
}

///|
async fn Bot::run_registered_command(
  self : Bot,
  bot : BotCtx,
  waiter : ComponentWaiter?,
  command : RegisteredCommand,
  raw : @framework.CommandCtx,
) -> Unit {
  (command.dispatch)(bot, waiter, self.warn_, raw) catch {
    error if @async.is_being_cancelled() || @async.is_cancellation_error(error) =>
      raise error
    BotDispatchError::Failure(command=name, phase~, source~) =>
      invoke_error_policy(
        self.current_policy(),
        failure_context(Command(name~), Some(phase), Some(raw), self.warn_),
        source,
      )
    error =>
      invoke_error_policy(
        self.current_policy(),
        failure_context(
          Command(name=command.name_),
          Some(BeforeInitial),
          Some(raw),
          self.warn_,
        ),
        error,
      )
  }
}

///|
async fn Bot::run_registered_autocomplete(
  self : Bot,
  command : RegisteredCommand,
  raw : @framework.AutocompleteCtx,
) -> Unit {
  dispatch_suggest(command.suggest_routes_, raw) catch {
    error if @async.is_being_cancelled() || @async.is_cancellation_error(error) =>
      raise error
    error => {
      invoke_error_policy(
        self.current_policy(),
        failure_context(
          Autocomplete(name=command.name_),
          None,
          None,
          self.warn_,
        ),
        error,
      )
      // ErrorPolicy is transport-neutral and cannot construct an autocomplete
      // callback, so complete the interaction with a safe empty result.
      raw.suggest([])
    }
  }
}

///|
fn Bot::populate_framework(
  self : Bot,
  framework : @framework.Framework,
  bot : BotCtx,
  waiter : ComponentWaiter?,
) -> Unit {
  for command in self.commands_ {
    framework.command(command.definition, raw => {
      self.run_registered_command(bot, waiter, command, raw)
    })
    |> ignore
    if !command.suggest_routes_.is_empty() {
      framework.autocomplete(command.name_, raw => {
        self.run_registered_autocomplete(command, raw)
      })
      |> ignore
    }
  }
  for entry in self.components_ {
    framework.component(entry.prefix, entry.dispatch) |> ignore
  }
  for entry in self.modals_ {
    framework.modal(entry.prefix, entry.dispatch) |> ignore
  }
  // Registered last so explicitly configured raw handlers win by name.
  for entry in self.autocompletes_ {
    framework.autocomplete(entry.name, entry.dispatch) |> ignore
  }
  framework.on_error((label, error) => {
    if @async.is_being_cancelled() || @async.is_cancellation_error(error) {
      raise error
    }
    (self.warn_)("framework handler failed (\{label}): \{to_repr(error)}")
  })
  |> ignore
}

///|
async fn Bot::sync_commands(
  self : Bot,
  client : @dhttp.Client,
  application_id : @model.ApplicationId,
) -> Unit {
  let specs = self.commands_.map(command => command.definition)
  match self.sync_ {
    Global => sync_global_commands(client, application_id, specs)
    Guild(guild_id) =>
      sync_guild_commands(client, application_id, guild_id, specs)
    Guilds(guild_ids) =>
      for guild_id in guild_ids {
        sync_guild_commands(client, application_id, guild_id, specs)
      }
    Disabled => ()
  }
}

///|
fn Bot::spawn_services(
  self : Bot,
  group : @async.TaskGroup[Unit],
  gateway : GatewayCtx,
) -> Unit {
  for service in self.services_ {
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      (service.dispatch)(gateway) catch {
        error if @async.is_being_cancelled() ||
          @async.is_cancellation_error(error) => raise error
        error =>
          invoke_error_policy(
            self.current_policy(),
            failure_context(Service(name=service.name), None, None, self.warn_),
            error,
          )
      }
    })
  }
}

///|
async fn Bot::spawn_event_handlers(
  self : Bot,
  spawner : Spawner,
  gateway : GatewayCtx,
  event : @model.Event,
) -> Unit {
  let kind = event_kind(event)
  for subscription in self.typed_events_ {
    if subscription.kind == kind {
      spawner(() => {
        (subscription.dispatch)(gateway, event) catch {
          error if @async.is_being_cancelled() ||
            @async.is_cancellation_error(error) => raise error
          error =>
            invoke_error_policy(
              self.current_policy(),
              failure_context(Event(kind~), None, None, self.warn_),
              error,
            )
        }
      })
    }
  }
  for handler in self.raw_events_ {
    spawner(() => {
      handler(gateway, event) catch {
        error if @async.is_being_cancelled() ||
          @async.is_cancellation_error(error) => raise error
        error =>
          invoke_error_policy(
            self.current_policy(),
            failure_context(Event(kind~), None, None, self.warn_),
            error,
          )
      }
    })
  }
}

///|
async fn Bot::spawn_interaction(
  self : Bot,
  spawner : Spawner,
  framework : @framework.Framework,
  interaction : @model.Interaction,
) -> Unit {
  spawner(() => {
    ignore(
      framework.process(interaction) catch {
        error if @async.is_being_cancelled() ||
          @async.is_cancellation_error(error) => raise error
        error => {
          (self.warn_)("interaction processing failed: \{to_repr(error)}")
          false
        }
      },
    )
  })
}

///|
/// Connect and process gateway events until graceful shutdown or a fatal close.
pub async fn Bot::run(self : Bot) -> Unit {
  self.validate()
  let intents = self.resolved_intents()
  let owns_client = self.client_ is None
  let client = self.client_.unwrap_or_else(() => @dhttp.Client::new(self.token_))
  defer (if owns_client { client.close() })
  let gateway_url = match self.gateway_url_ {
    Some(url) => url
    None => client.get_gateway()
  }
  @async.with_task_group(group => {
    let filter = self.event_filter()
    let shard = match self.connector_.val {
      Some(connector) =>
        @gateway.Shard::start(
          group,
          token=self.token_,
          intents~,
          gateway_url~,
          shard_id=self.shard_id_,
          shard_count=self.shard_count_,
          event_filter=filter,
          connector~,
        )
      None =>
        @gateway.Shard::start(
          group,
          token=self.token_,
          intents~,
          gateway_url~,
          shard_id=self.shard_id_,
          shard_count=self.shard_count_,
          event_filter=filter,
        )
    }
    let limiter = @async.Semaphore::new(self.max_in_flight_)
    let spawner = bounded_spawner(group, limiter)
    let mut gateway_ctx : GatewayCtx? = None
    let mut framework : @framework.Framework? = None
    for ;; {
      match shard.next() {
        Dispatch(Ready(ready) as event) => {
          if gateway_ctx is None {
            let bot : BotCtx = {
              client_: client,
              application_id_: ready.application.id,
            }
            let router = @framework.Framework::new(client, ready.application.id)
            let waiter : ComponentWaiter = (custom_id, timeout_ms) => {
              router.wait_for_component(custom_id~, timeout_ms?)
            }
            self.populate_framework(router, bot, Some(waiter))
            let created : GatewayCtx = {
              bot_: bot,
              ready_: ready,
              shard_: shard,
              framework_: router,
              shutdown_requested_: false,
            }
            gateway_ctx = Some(created)
            framework = Some(router)
            self.sync_commands(client, ready.application.id)
            self.spawn_services(group, created)
          }
          guard gateway_ctx is Some(ctx)
          ctx.ready_ = ready
          self.spawn_event_handlers(spawner, ctx, event)
        }
        Dispatch(InteractionCreate(interaction) as event) =>
          match (gateway_ctx, framework) {
            (Some(ctx), Some(router)) => {
              // Processing is another bounded child task. Awaiting it here
              // would deadlock handlers waiting for a later component event.
              self.spawn_interaction(spawner, router, interaction)
              self.spawn_event_handlers(spawner, ctx, event)
            }
            _ =>
              (self.warn_)("dropping INTERACTION_CREATE received before READY")
          }
        Dispatch(event) =>
          match gateway_ctx {
            Some(ctx) => self.spawn_event_handlers(spawner, ctx, event)
            None =>
              (self.warn_)(
                "dropping \{to_repr(event_kind(event))} received before READY",
              )
          }
        Connected(..) => ()
        Disconnected(..) =>
          if gateway_ctx is Some(ctx) && ctx.shutdown_requested_ {
            break
          }
        FatallyClosed(code~) => {
          if gateway_ctx is Some(ctx) && ctx.shutdown_requested_ {
            break
          }
          raise BotError::FatallyClosed(code~)
        }
      }
    }
  })
}
