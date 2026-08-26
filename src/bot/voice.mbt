///|
fn voice_state_command(
  guild_id : @model.Id[@model.GuildMarker],
  channel_id : @model.Id[@model.ChannelMarker]?,
  self_mute : Bool,
  self_deaf : Bool,
) -> Json {
  let channel : Json = match channel_id {
    Some(id) => id.to_json()
    None => Json::null()
  }
  {
    "op": 4,
    "d": {
      "guild_id": guild_id.to_json(),
      "channel_id": channel,
      "self_mute": self_mute,
      "self_deaf": self_deaf,
    },
  }
}

///|
async fn GatewayCtx::request_voice_credentials(
  self : GatewayCtx,
  guild_id : @model.Id[@model.GuildMarker],
  channel_id : @model.Id[@model.ChannelMarker],
  self_mute : Bool,
  self_deaf : Bool,
  timeout_ms : Int,
) -> @voice.VoiceCredentials {
  let user_id = self.ready_.user.id
  let state = self.collector_.register(Events::voice_state_update(), update => {
    update.user_id == user_id && update.guild_id == Some(guild_id)
  })
  let server = self.collector_.register(Events::voice_server_update(), update => {
    update.guild_id == guild_id && update.endpoint is Value(_)
  })
  defer state.cancel()
  defer server.cancel()
  self.shard_.send(
    voice_state_command(guild_id, Some(channel_id), self_mute, self_deaf),
  )
  @async.with_task_group(group => {
    let state_task = group.spawn(no_wait=true, () => state.wait(timeout_ms~))
    let server_task = group.spawn(no_wait=true, () => server.wait(timeout_ms~))
    guard state_task.wait() is Some(state_update) else {
      server_task.cancel()
      raise @voice.VoiceError::JoinTimeout
    }
    guard server_task.wait() is Some(server_update) else {
      raise @voice.VoiceError::JoinTimeout
    }
    guard server_update.endpoint is Value(endpoint) else {
      raise @voice.VoiceError::JoinTimeout
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
async fn GatewayCtx::watch_voice_server_updates(
  self : GatewayCtx,
  guild_id : @model.Id[@model.GuildMarker],
  channel_id : @model.Id[@model.ChannelMarker],
  self_mute : Bool,
  self_deaf : Bool,
  timeout_ms : Int,
  connection : @voice.VoiceConnection,
  rejoin_in_progress : Ref[Bool],
) -> Unit noraise {
  let update = self.wait_for(Events::voice_server_update(), event => {
    event.guild_id == guild_id &&
    event.endpoint is Value(_) &&
    !rejoin_in_progress.val
  }) catch {
    _ => None
  }
  guard update is Some(_) && connection.state() is Ready else { return }
  connection.disconnect() catch {
    _ => return
  }
  try
    self.join_voice(guild_id, channel_id, self_mute~, self_deaf~, timeout_ms~)
  catch {
    _ => ()
  } noraise {
    _ => ()
  }
}

///|
async fn wait_ready_or_disconnect(
  connection : @voice.VoiceConnection,
  timeout_ms : Int,
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
/// that intent is absent.
///
/// Pass `telemetry` to observe non-fatal voice gateway and media diagnostics.
pub async fn GatewayCtx::join_voice(
  self : GatewayCtx,
  guild_id : @model.Id[@model.GuildMarker],
  channel_id : @model.Id[@model.ChannelMarker],
  self_mute? : Bool = false,
  self_deaf? : Bool = false,
  timeout_ms? : Int = 10000,
  telemetry? : (@voice.VoiceTelemetry) -> Unit = _ => (),
) -> @voice.VoiceConnection {
  let required_intents = Events::voice_state_update().required_intents()
  if !self.intents_.contains(required_intents) {
    raise @voice.VoiceError::MissingIntent(intent="GUILD_VOICE_STATES")
  }
  let join_gate = match self.voice_join_gates_.get(guild_id) {
    Some(gate) => gate
    None => {
      let gate = @async.Semaphore(1)
      self.voice_join_gates_[guild_id] = gate
      gate
    }
  }
  join_gate.acquire()
  defer join_gate.release()
  if self.voice_connections_.get(guild_id) is Some(existing) {
    if existing.state() is Closed(..) {
      self.voice_connections_.remove(guild_id)
    } else {
      return existing
    }
  }
  let credentials = self.request_voice_credentials(
    guild_id, channel_id, self_mute, self_deaf, timeout_ms,
  )
  let rejoin_in_progress = Ref(false)
  let leave = () => {
    defer self.voice_connections_.remove(guild_id)
    self.shard_.send(voice_state_command(guild_id, None, self_mute, self_deaf))
  }
  let rejoin = () => {
    rejoin_in_progress.val = true
    defer {
      rejoin_in_progress.val = false
    }
    self.request_voice_credentials(
      guild_id, channel_id, self_mute, self_deaf, timeout_ms,
    )
  }
  let connection = @voice.VoiceConnection::start(
    self.group_,
    credentials,
    user_id=self.ready_.user.id.to_string(),
    channel_id=channel_id.value(),
    leave~,
    rejoin~,
    telemetry~,
  )
  wait_ready_or_disconnect(connection, timeout_ms)
  self.voice_connections_[guild_id] = connection
  self.group_.spawn_bg(no_wait=true, allow_failure=true, () => {
    self.watch_voice_server_updates(
      guild_id, channel_id, self_mute, self_deaf, timeout_ms, connection, rejoin_in_progress,
    )
  })
  connection
}
