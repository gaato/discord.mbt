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
priv struct ServiceHandler {
  name : String
  dispatch : async (GatewayCtx) -> Unit
}

///|
/// Native gateway executor for a gateway-free application core.
pub struct Bot {
  priv app_ : @app.App
  priv token_ : String
  priv intents_ : @model.Intents?
  priv client_ : @dhttp.Client?
  priv gateway_url_ : String?
  priv shard_id_ : Int
  priv shard_count_ : Int
  priv typed_events_ : Array[TypedEventHandler]
  priv raw_events_ : Array[async (GatewayCtx, @model.Event) -> Unit]
  priv decode_errors_ : Array[(String, Json) -> Unit]
  priv services_ : Array[ServiceHandler]
  // Production uses Shard::start's WebSocket connector. Whitebox tests inject
  // the same in-memory GatewayTransport seam used by gateway_test.mbt.
  priv connector_ : Ref[(async (String) -> &@gateway.GatewayTransport)?]
}

///|
pub fn Bot::new(
  app : @app.App,
  token~ : String,
  intents? : @model.Intents,
  client? : @dhttp.Client,
  gateway_url? : String,
  shard_id? : Int = 0,
  shard_count? : Int = 1,
) -> Bot {
  {
    app_: app,
    token_: token,
    intents_: intents,
    client_: client,
    gateway_url_: gateway_url,
    shard_id_: shard_id,
    shard_count_: shard_count,
    typed_events_: [],
    raw_events_: [],
    decode_errors_: [],
    services_: [],
    connector_: Ref(None),
  }
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
/// Observe gateway events whose known payload failed typed decoding.
///
/// `marker` is the full synthetic event type
/// `DECODE_ERROR:<event-name>:<decode-error>`, and `payload` is Discord's raw
/// event data. Handlers run synchronously in the dispatch loop and should
/// return promptly. Registering a handler does not add gateway intents or
/// widen the event filter.
pub fn Bot::on_decode_error(
  self : Bot,
  handler : (String, Json) -> Unit,
) -> Unit {
  self.decode_errors_.push(handler)
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
fn Bot::observe_decode_error(self : Bot, event : @model.Event) -> Unit {
  match event {
    Unknown(t~, d~) if t.has_prefix("DECODE_ERROR:") => {
      // Never include `d`: payloads can contain user content and credentials.
      self.app_.warn("gateway event decode failure: \{t}")
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
fn Bot::resolved_intents(self : Bot) -> @model.Intents {
  match self.intents_ {
    Some(explicit) => {
      for subscription in self.typed_events_ {
        let required = subscription.required_intents
        if required.bits() != 0U && (required & explicit).bits() == 0U {
          self.app_.warn(
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
          self.app_.warn(
            "event \{to_repr(subscription.kind)} requires a privileged intent; pass intents explicitly",
          )
        }
        derived = derived | required
      }
      if !self.raw_events_.is_empty() {
        self.app_.warn(
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
          self.app_.report_failure(
            @app.FailureOrigin::Service(name=service.name),
            error,
          )
      }
    })
  }
}

///|
async fn Bot::spawn_event_handlers(
  self : Bot,
  spawner : @app.Spawner,
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
            self.app_.report_failure(@app.FailureOrigin::Event(kind~), error)
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
          self.app_.report_failure(@app.FailureOrigin::Event(kind~), error)
      }
    })
  }
}

///|
async fn Bot::spawn_interaction(
  self : Bot,
  spawner : @app.Spawner,
  framework : @framework.Framework,
  interaction : @model.Interaction,
) -> Unit {
  spawner(() => {
    ignore(
      framework.process(interaction) catch {
        error if @async.is_being_cancelled() ||
          @async.is_cancellation_error(error) => raise error
        error => {
          self.app_.warn("interaction processing failed: \{to_repr(error)}")
          false
        }
      },
    )
  })
}

///|
/// Connect and process gateway events until graceful shutdown or a fatal close.
pub async fn Bot::run(self : Bot) -> Unit {
  self.app_.validate()
  if self.token_.is_empty() {
    raise @app.AppConfigError::EmptyToken
  }
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
    let spawner = self.app_.spawner(group)
    let mut gateway_ctx : GatewayCtx? = None
    let mut framework : @framework.Framework? = None
    for ;; {
      match shard.next() {
        Dispatch(Ready(ready) as event) => {
          if gateway_ctx is None {
            let router = @framework.Framework::new(client, ready.application.id)
            let waiter : @app.ComponentWaiter = (custom_id, timeout_ms) => {
              router.wait_for_component(custom_id~, timeout_ms?)
            }
            let app_ctx = self.app_.attach(
              router,
              client~,
              application_id=ready.application.id,
              waiter~,
            )
            let created : GatewayCtx = {
              app_: app_ctx,
              ready_: ready,
              shard_: shard,
              framework_: router,
              shutdown_requested_: false,
            }
            gateway_ctx = Some(created)
            framework = Some(router)
            self.app_.sync_commands(client, ready.application.id)
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
              self.app_.warn(
                "dropping INTERACTION_CREATE received before READY",
              )
          }
        Dispatch(event) => {
          self.observe_decode_error(event)
          match gateway_ctx {
            Some(ctx) => self.spawn_event_handlers(spawner, ctx, event)
            None =>
              self.app_.warn(
                "dropping \{to_repr(event_kind(event))} received before READY",
              )
          }
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
