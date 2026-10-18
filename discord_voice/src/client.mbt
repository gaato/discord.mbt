///|
/// A main-gateway event the voice join waits for. `wait` returns it, or
/// `None` after `timeout_ms`; `cancel` abandons it without waiting.
pub(all) struct PendingVoiceEvent[T] {
  wait : async (Int32?) -> T?
  cancel : () -> Unit
}

///|
/// What joining voice needs from the main gateway, as values and functions.
/// `from_gateway` builds one from a bot's `GatewayCtx`; a test can build its
/// own to drive `VoiceClient::join_via` without a gateway connection.
pub(all) struct VoiceGatewayPort {
  user_id : @model.UserId
  intents : @model.Intents
  /// Register an expected VOICE_STATE_UPDATE now, before opcode 4 is sent.
  expect_voice_state : ((@model.VoiceState) -> Bool) -> PendingVoiceEvent[
    @model.VoiceState,
  ]
  /// Register an expected VOICE_SERVER_UPDATE now, before opcode 4 is sent.
  expect_voice_server : ((@model.VoiceServerUpdateEvent) -> Bool) -> PendingVoiceEvent[
    @model.VoiceServerUpdateEvent,
  ]
  /// Send opcode 4 for the guild.
  update_voice_state : async (@model.UpdateVoiceState) -> Unit
}

///|
/// The gateway capabilities of `ctx`'s bot. Opcode 4 goes to the shard that
/// owns each guild, whichever shard `ctx` belongs to.
pub fn VoiceGatewayPort::from_gateway(
  ctx : @bot.GatewayCtx,
) -> VoiceGatewayPort {
  {
    user_id: ctx.ready().user.id,
    intents: ctx.intents(),
    expect_voice_state: predicate => {
      pending_voice_event(
        ctx.expect_event(@bot.Events::voice_state_update(), predicate),
      )
    },
    expect_voice_server: predicate => {
      pending_voice_event(
        ctx.expect_event(@bot.Events::voice_server_update(), predicate),
      )
    },
    update_voice_state: state => ctx.update_voice_state(state),
  }
}

///|
fn[T] pending_voice_event(event : @bot.PendingEvent[T]) -> PendingVoiceEvent[T] {
  { wait: timeout_ms => event.wait(timeout_ms?), cancel: () => event.cancel(), }
}

///|
/// A bot's voice connections: at most one per guild. Create one per bot,
/// `attach` it to the bot's builder, and `join` from event or service
/// handlers. The connections run in the client's own task group, which lives
/// as long as `run` (the service that `attach` registers).
pub struct VoiceClient {
  priv connections : Map[@model.GuildId, VoiceConnection]
  priv join_gates : Map[@model.GuildId, JoinGate]
  priv mut group : @async.TaskGroup[Unit]?
  priv started : @cond_var.Cond
  // What the connections open, and the clock they and the joins use; a
  // test replaces them.
  priv connector_ : Ref[async (String) -> &VoiceTransport]
  priv clock_ : Ref[&@hclock.Clock]
}

///|
/// Serializes joins for one guild. `users` counts the joins holding or
/// waiting on `gate`, so the entry can go when the last one finishes.
priv struct JoinGate {
  gate : @async.Semaphore
  mut users : Int32
}

///|
/// Create a client. `clock` times the joins' waits and every connection the
/// client starts (see `VoiceConnection::start`).
pub fn VoiceClient::VoiceClient(
  clock~ : &@hclock.Clock = @transport.AsyncClock::new(),
) -> VoiceClient {
  {
    connections: Map([]),
    join_gates: Map([]),
    group: None,
    started: @cond_var.Cond(),
    connector_: Ref(connect_voice_websocket),
    clock_: Ref(clock),
  }
}

///|
/// Run the client's task group until cancelled. Connections and their
/// background tasks run in it, so cancelling `run` closes every connection.
/// `attach` runs it as a bot service; call it directly only when the client
/// is not attached to a builder.
pub async fn VoiceClient::run(self : VoiceClient) -> Unit {
  @async.with_task_group(group => {
    self.group = Some(group)
    defer {
      self.group = None
      self.connections.clear()
    }
    self.started.broadcast()
    @cond_var.Cond().wait()
  })
}

///|
/// Run the client as the service `"voice"` of the bot that `builder` builds.
pub fn VoiceClient::attach(
  self : VoiceClient,
  builder : @bot.BotBuilder,
) -> Unit {
  builder.service(name="voice", _ => self.run())
}

///|
/// The connection the client holds for `guild_id`, if any.
pub fn VoiceClient::connection(
  self : VoiceClient,
  guild_id : @model.GuildId,
) -> VoiceConnection? {
  self.connections.get(guild_id)
}

///|
/// Join a guild voice channel through `ctx`'s bot and wait until its voice
/// transport is ready. See `join_via` for the behavior.
pub async fn VoiceClient::join(
  self : VoiceClient,
  ctx : @bot.GatewayCtx,
  guild_id : @model.GuildId,
  channel_id : @model.ChannelId,
  self_mute~ : Bool = false,
  self_deaf~ : Bool = false,
  timeout_ms~ : Int32 = 10000,
  telemetry~ : (VoiceTelemetry) -> Unit = _ => (),
) -> VoiceConnection {
  self.join_via(
    VoiceGatewayPort::from_gateway(ctx),
    guild_id,
    channel_id,
    self_mute~,
    self_deaf~,
    timeout_ms~,
    telemetry~,
  )
}

///|
/// Join a guild voice channel and wait until its voice transport is ready.
///
/// A second call for the same guild returns the registered connection; moving
/// an existing connection to another channel is outside this API. Discord may
/// send no response events when the channel is full and the bot lacks
/// `MOVE_MEMBERS`; that case raises `VoiceError::JoinTimeout`.
///
/// The bot must connect the main Gateway with the `GUILD_VOICE_STATES` intent.
/// This method raises `VoiceError::MissingIntent` before sending Opcode 4 when
/// that intent is absent, and `VoiceError::ClientNotRunning` when `run` has
/// not started within `timeout_ms`.
///
/// Pass `telemetry` to observe non-fatal voice gateway and media diagnostics.
pub async fn VoiceClient::join_via(
  self : VoiceClient,
  port : VoiceGatewayPort,
  guild_id : @model.GuildId,
  channel_id : @model.ChannelId,
  self_mute~ : Bool = false,
  self_deaf~ : Bool = false,
  timeout_ms~ : Int32 = 10000,
  telemetry~ : (VoiceTelemetry) -> Unit = _ => (),
) -> VoiceConnection {
  let required_intents = @bot.Events::voice_state_update().required_intents()
  if !port.intents.contains(required_intents) {
    raise VoiceError::MissingIntent(intent="GUILD_VOICE_STATES")
  }
  let group = self.running_group(timeout_ms)
  let join_gate = self.join_gates.get_or_init(guild_id, () => {
    gate: @async.Semaphore(1),
    users: 0,
  })
  join_gate.users += 1
  defer {
    // The last join for the guild, finished or failed, takes the gate along:
    // one nobody holds or waits on is the same as a new one.
    join_gate.users -= 1
    if join_gate.users == 0 {
      self.join_gates.remove(guild_id)
    }
  }
  join_gate.gate.acquire()
  defer join_gate.gate.release()
  if self.connections.get(guild_id) is Some(existing) {
    guard existing.state() is Closed(..) else { return existing }
    // Wait out its teardown: a leave sent after the new join would take the
    // bot out of the channel it just joined.
    existing.disconnect()
    self.connections.remove(guild_id)
  }
  let credentials = request_voice_credentials(
    port, guild_id, channel_id, self_mute, self_deaf, timeout_ms,
  )
  let rejoin_in_progress = Ref(false)
  // Where the bot is, which a move made outside this API changes.
  let current_channel = Ref(channel_id)
  let leave = () => {
    defer self.connections.remove(guild_id)
    (port.update_voice_state)({
      guild_id,
      channel_id: None,
      self_mute,
      self_deaf,
    })
  }
  let rejoin = () => {
    rejoin_in_progress.val = true
    defer {
      rejoin_in_progress.val = false
    }
    request_voice_credentials(
      port,
      guild_id,
      current_channel.val,
      self_mute,
      self_deaf,
      timeout_ms,
    )
  }
  let next_server = () => {
    let pending = (port.expect_voice_server)(event => {
      event.guild_id == guild_id && !rejoin_in_progress.val
    })
    defer (pending.cancel)()
    guard (pending.wait)(None) is Some(update) else { return None }
    let endpoint = match update.endpoint {
      Value(endpoint) => Some(endpoint)
      Null => None
    }
    Some(VoiceServer::{ token: update.token, endpoint, })
  }
  let next_channel = () => {
    let user_id = port.user_id
    let pending = (port.expect_voice_state)(update => {
      update.user_id == user_id &&
      update.guild_id == Some(guild_id) &&
      update.channel_id is Value(_)
    })
    defer (pending.cancel)()
    guard (pending.wait)(None) is Some(update) &&
      update.channel_id is Value(moved_to) else {
      return None
    }
    current_channel.val = moved_to
    Some(moved_to.value())
  }
  let connection = VoiceConnection::start(
    group,
    credentials,
    user_id=port.user_id.to_string(),
    channel_id=channel_id.value(),
    leave~,
    rejoin~,
    next_server~,
    next_channel~,
    server_timeout_ms=timeout_ms,
    connector=self.connector_.val,
    telemetry~,
    clock=self.clock_.val,
  )
  wait_ready_or_disconnect(connection, timeout_ms)
  self.connections[guild_id] = connection
  connection
}

///|
/// The task group of `run`, waiting up to `timeout_ms` for it to start: a
/// READY handler can call `join` before the bot has started its services.
async fn VoiceClient::running_group(
  self : VoiceClient,
  timeout_ms : Int32,
) -> @async.TaskGroup[Unit] {
  if self.group is Some(group) {
    return group
  }
  @transport.with_timeout_opt(self.clock_.val, timeout_ms, () => {
    while self.group is None {
      self.started.wait()
    }
  })
  |> ignore
  guard self.group is Some(group) else { raise VoiceError::ClientNotRunning }
  group
}

///|
async fn request_voice_credentials(
  port : VoiceGatewayPort,
  guild_id : @model.GuildId,
  channel_id : @model.ChannelId,
  self_mute : Bool,
  self_deaf : Bool,
  timeout_ms : Int32,
) -> VoiceCredentials {
  let user_id = port.user_id
  let state = (port.expect_voice_state)(update => {
    update.user_id == user_id && update.guild_id == Some(guild_id)
  })
  let server = (port.expect_voice_server)(update => {
    update.guild_id == guild_id && update.endpoint is Value(_)
  })
  defer (state.cancel)()
  defer (server.cancel)()
  (port.update_voice_state)({
    guild_id,
    channel_id: Some(channel_id),
    self_mute,
    self_deaf,
  })
  @async.with_task_group(group => {
    let state_task = group.spawn(no_wait=true, () => {
      (state.wait)(Some(timeout_ms))
    })
    let server_task = group.spawn(no_wait=true, () => {
      (server.wait)(Some(timeout_ms))
    })
    guard state_task.wait() is Some(state_update) else {
      server_task.cancel()
      raise VoiceError::JoinTimeout
    }
    guard server_task.wait() is Some(server_update) else {
      raise VoiceError::JoinTimeout
    }
    guard server_update.endpoint is Value(endpoint) else {
      raise VoiceError::JoinTimeout
    }
    {
      server_id: guild_id.to_string(),
      session_id: state_update.session_id,
      token: server_update.token,
      endpoint,
    }
  })
}

///|
async fn wait_ready_or_disconnect(
  connection : VoiceConnection,
  timeout_ms : Int32,
) -> Unit {
  errdefer @async.protect_from_cancel(() => {
    connection.disconnect() catch {
      _ => ()
    }
  })
  connection.wait_ready(timeout_ms~) catch {
    error if @async.is_being_cancelled() => {
      @async.pause()
      raise error
    }
    error => raise error
  }
}
