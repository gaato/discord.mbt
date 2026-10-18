///|
/// Events surfaced by `Shard::next`.
#non_exhaustive
pub(all) enum ShardEvent {
  Dispatch(@model.Event)
  Connected(resumed~ : Bool)
  Disconnected(code~ : Int32?, resuming~ : Bool)
  FatallyClosed(code~ : Int32)
} derive(Debug)

///|
/// A single gateway connection with automatic heartbeat, resume, and
/// reconnect. Pull events with `next`; the shard's tasks live in the task
/// group passed to `start`, so cancelling the group tears the shard down.
pub struct Shard {
  priv events : @aqueue.Queue[ShardEvent]
  priv command_limiter : CommandLimiter
  priv presence_limiter : CommandLimiter
  priv presence_gate : @async.Semaphore
  priv send_gate : @async.Semaphore
  priv mut transport : &GatewayTransport?
  priv mut state : ShardState
  priv mut session : Session?
  priv mut latency : Int64?
  priv mut closing : Bool
  priv mut runner : @async.Task[Unit]?
  priv mut presence : @model.UpdatePresence?
  priv shard_id : Int32
  priv telemetry_ : (@telemetry.TelemetryEvent) -> Unit
}

///|
/// The current lifecycle state of this shard.
pub fn Shard::state(self : Shard) -> ShardState {
  self.state
}

///|
/// A copy of the current gateway session, or `None` before the first READY
/// and after the session was invalidated. Persist it to RESUME after a
/// restart.
pub fn Shard::session(self : Shard) -> Session? {
  self.session.map(s => {
    id: s.id,
    resume_url: s.resume_url,
    sequence: s.sequence,
  })
}

///|
/// Latest heartbeat round-trip time in milliseconds.
pub fn Shard::latency_ms(self : Shard) -> Int64? {
  self.latency
}

///|
/// Pull the next event. Blocks until one is available.
pub async fn Shard::next(self : Shard) -> ShardEvent {
  self.events.get()
}

///|
/// Send a gateway command (presence update, request guild members, ...).
/// Rate limited (120/60s minus heartbeat reserve) and serialized with the
/// shard's other writes.
pub async fn Shard::send(self : Shard, command : Json) -> Unit {
  self.command_limiter.acquire()
  self.send_after_limit(command)
}

///|
async fn Shard::send_after_limit(self : Shard, command : Json) -> Unit {
  guard self.transport is Some(transport) else {
    raise TransportClosed(code=None, reason="shard is not connected")
  }
  self.raw_send(transport, command)
}

///|
/// Send opcode 4 (Update Voice State) on this shard. Send it on the shard that
/// owns `state.guild_id`; `@bot.GatewayCtx::update_voice_state` picks it.
pub async fn Shard::update_voice_state(
  self : Shard,
  state : @model.UpdateVoiceState,
) -> Unit {
  self.send({ "op": 4, "d": state.to_json() })
}

///|
/// Send opcode 3 and retain a snapshot of the last successfully sent presence
/// for Identify. Serializes presence updates and waits for the general command
/// limit before pacing updates at five per 20-second sliding window. The
/// presence window records successful writes only, after they complete.
pub async fn Shard::update_presence(
  self : Shard,
  presence : @model.UpdatePresence,
) -> Unit {
  self.presence_gate.acquire()
  defer self.presence_gate.release()
  self.command_limiter.acquire()
  self.presence_limiter.wait_for_slot()
  self.send_after_limit({ "op": 3, "d": presence.to_json() })
  self.presence_limiter.record()
  self.presence = Some({ ..presence, activities: presence.activities.copy(), })
}

///|
/// Validate and send opcode 8 on the shard that owns the request's guild.
pub async fn Shard::request_guild_members(
  self : Shard,
  request : @model.RequestGuildMembers,
) -> Unit {
  request.validate()
  self.send({ "op": 8, "d": request.to_json() })
}

///|
/// Send opcode 31 for guilds owned by this shard.
pub async fn Shard::request_soundboard_sounds(
  self : Shard,
  request : @model.RequestSoundboardSounds,
) -> Unit {
  self.send({ "op": 31, "d": request.to_json() })
}

///|
/// Send opcode 43 on the shard that owns the request's guild.
pub async fn Shard::request_channel_info(
  self : Shard,
  request : @model.RequestChannelInfo,
) -> Unit {
  self.send({ "op": 43, "d": request.to_json() })
}

///|
/// Request a graceful shutdown: closes the connection with code 1000 (which
/// invalidates the session — Discord will not allow a resume after it).
pub async fn Shard::close(self : Shard) -> Unit noraise {
  if self.closing {
    @async.protect_from_cancel(() => self.wait_runner()) catch {
      _ => ()
    }
    return
  }
  self.closing = true
  @async.protect_from_cancel(() => self.stop_runner()) catch {
    _ => ()
  }
}

///|
async fn Shard::wait_runner(self : Shard) -> Unit noraise {
  if self.runner is Some(runner) {
    runner.wait() catch {
      _ => ()
    }
  }
}

///|
async fn Shard::stop_runner(self : Shard) -> Unit noraise {
  if self.runner is Some(runner) {
    runner.cancel()
    self.wait_runner()
  }
  self.runner = None
  self.transport = None
  self.latency = None
  self.session = None
  self.state = Disconnected(reconnect_attempts=0)
  self.emit_telemetry(
    ShardDisconnected(
      shard_id=self.shard_id,
      code=Some(1000),
      will_resume=false,
    ),
  )
  (self.events.try_put(Disconnected(code=Some(1000), resuming=false)) |> ignore) catch {
    _ => ()
  }
}

///|
/// Close code for a connection the shard will resume. Discord invalidates
/// the session when the client closes with 1000 or 1001.
const RESUMABLE_CLOSE_CODE : Int32 = 4000

///|
async fn Shard::finish_transport(
  self : Shard,
  transport : &GatewayTransport,
  code~ : Int32,
) -> Unit noraise {
  self.send_gate.acquire()
  defer self.send_gate.release()
  guard self.transport is Some(current) && physical_equal(current, transport) else {
    return
  }
  self.transport = None
  transport.close(code~) catch {
    _ => ()
  }
}

///|
/// Spawn a shard into `group` and return its handle. `resume` seeds the
/// session so the first connection attempts RESUME at its `resume_url`.
/// The initial presence is retained with a copy of its activities array.
/// A message larger than `max_message_bytes`, compressed or inflated, ends
/// the connection and the shard resumes; a limit below 1 closes the shard
/// fatally with code 0 before it connects.
pub fn[X] Shard::start(
  group : @async.TaskGroup[X],
  token~ : String,
  intents~ : @model.Intents,
  capabilities~ : @model.GatewayCapabilities = @model.GatewayCapabilities::none(),
  gateway_url~ : String = "wss://gateway.discord.gg",
  shard_id~ : Int32 = 0,
  shard_count~ : Int32 = 1,
  identify_queue? : &@queue.IdentifyQueue,
  event_filter~ : (@model.EventKind) -> Bool = _ => true,
  connector? : async (String) -> &GatewayTransport,
  compress~ : Bool = false,
  inflater_factory? : () -> &Inflater raise,
  max_message_bytes~ : Int32 = DEFAULT_MAX_MESSAGE_BYTES,
  queue_capacity~ : Int32 = 256,
  telemetry~ : (@telemetry.TelemetryEvent) -> Unit = _ => (),
  clock~ : &@hclock.Clock = @transport.AsyncClock::new(),
  rand~ : @random.Rand = @random.Rand(),
  resume? : Session,
  presence? : @model.UpdatePresence,
) -> Shard {
  let shard = Shard::{
    presence: presence.map(p => { ..p, activities: p.activities.copy(), }),
    events: Queue(kind=Blocking(queue_capacity)),
    command_limiter: CommandLimiter(clock~),
    presence_limiter: CommandLimiter(limit=5, window_ms=20000, clock~),
    presence_gate: Semaphore(1),
    send_gate: Semaphore(1),
    transport: None,
    state: Disconnected(reconnect_attempts=0),
    session: resume.map(s => {
      id: s.id,
      resume_url: s.resume_url,
      sequence: s.sequence,
    }),
    latency: None,
    closing: false,
    runner: None,
    shard_id,
    telemetry_: telemetry,
  }
  let connector = connector.unwrap_or(url => {
    connect_websocket(url, max_message_bytes~)
  })
  let inflater_factory = inflater_factory.unwrap_or(() => {
    ZlibStreamInflater(max_bytes=max_message_bytes)
  })
  let runner = group.spawn(no_wait=true, () => {
    if max_message_bytes < 1 {
      shard.close_before_connecting(shard_id~)
      return
    }
    shard.run(
      token~,
      intents~,
      capabilities~,
      gateway_url~,
      shard_id~,
      shard_count~,
      identify_queue?,
      event_filter~,
      connector~,
      compress~,
      inflater_factory~,
      clock~,
      rand~,
    )
  })
  shard.runner = Some(runner)
  shard
}

///|
fn Shard::emit_telemetry(
  self : Shard,
  event : @telemetry.TelemetryEvent,
) -> Unit {
  (self.telemetry_)(event)
}

///|
/// End the shard fatally, with code 0, over a configuration that cannot
/// connect.
async fn Shard::close_before_connecting(
  self : Shard,
  shard_id~ : Int32,
) -> Unit noraise {
  self.state = FatallyClosed(code=0)
  self.emit_telemetry(
    ShardDisconnected(shard_id~, code=None, will_resume=false),
  )
  self.events.put(FatallyClosed(code=0)) catch {
    _ => ()
  }
}

///|
/// The reconnect loop: connect, run one connection to completion, classify
/// the close, back off, repeat.
async fn Shard::run(
  self : Shard,
  token~ : String,
  intents~ : @model.Intents,
  capabilities~ : @model.GatewayCapabilities,
  gateway_url~ : String,
  shard_id~ : Int32,
  shard_count~ : Int32,
  identify_queue? : &@queue.IdentifyQueue,
  event_filter~ : (@model.EventKind) -> Bool,
  connector~ : async (String) -> &GatewayTransport,
  compress~ : Bool,
  inflater_factory~ : () -> &Inflater raise,
  clock~ : &@hclock.Clock,
  rand~ : @random.Rand,
) -> Unit noraise {
  let reconnect = Reconnect::new()
  while !self.closing {
    if reconnect.delay is Some(delay) {
      clock.sleep(delay.sample_ms(rand))
    }
    self.state = Connecting
    self.emit_telemetry(ShardConnecting(shard_id~))
    let base = match self.session {
      Some(session) => session.resume_url
      None => gateway_url
    }
    let compression_query = if compress { "&compress=zlib-stream" } else { "" }
    let inflater = if compress {
      Some(inflater_factory()) catch {
        _ if @async.is_being_cancelled() => return
        _ => {
          self.close_before_connecting(shard_id~)
          break
        }
      }
    } else {
      None
    }
    let transport = connector("\{base}/?v=10&encoding=json\{compression_query}") catch {
      _ if @async.is_being_cancelled() => return
      _ => {
        if reconnect.on_connector_failure(has_session=self.session is Some(_)) {
          self.session = None
        }
        self.state = Disconnected(reconnect_attempts=reconnect.attempts)
        self.emit_telemetry(
          ShardDisconnected(shard_id~, code=None, will_resume=false),
        )
        continue
      }
    }
    reconnect.on_connected()
    self.transport = Some(transport)
    let ended = try {
      defer {
        let code = if self.closing || @async.is_being_cancelled() {
          1000
        } else {
          RESUMABLE_CLOSE_CODE
        }
        @async.protect_from_cancel(() => self.finish_transport(transport, code~))
      }
      if compress {
        self.emit_telemetry(ShardCompressionEnabled(shard_id~))
      }
      self.run_connection(
        transport,
        inflater~,
        token~,
        intents~,
        capabilities~,
        shard_id~,
        shard_count~,
        identify_queue?,
        event_filter~,
        clock~,
        rand~,
      )
      ConnectionEnded(code=Some(1000), reason="loop exited")
    } catch {
      _ if @async.is_being_cancelled() => return
      ConnectionEnded(code~, reason~) => ConnectionEnded(code~, reason~)
      ConnectionEnded::InvalidSession(resumable~) =>
        ConnectionEnded::InvalidSession(resumable~)
      TransportClosed(code~, reason~) => ConnectionEnded(code~, reason~)
      e => ConnectionEnded(code=None, reason="\{Repr(e)}")
    } noraise {
      ended => ended
    }
    self.transport = None
    self.latency = None
    match
      reconnect.after_close(
        ended,
        closing=self.closing,
        was_active=self.state is Active,
        has_session=self.session is Some(_),
      ) {
      Stop(code~) => {
        self.state = Disconnected(reconnect_attempts=0)
        self.emit_telemetry(
          ShardDisconnected(shard_id~, code~, will_resume=false),
        )
        self.events.put(Disconnected(code~, resuming=false)) catch {
          _ => ()
        }
        break
      }
      Fatal(code~) => {
        let fatal_code = code.unwrap_or(0)
        self.state = FatallyClosed(code=fatal_code)
        self.emit_telemetry(
          ShardDisconnected(shard_id~, code~, will_resume=false),
        )
        self.events.put(FatallyClosed(code=fatal_code)) catch {
          _ => ()
        }
        break
      }
      Reconnect(code~, resuming~, clear_session~) => {
        if clear_session {
          self.session = None
        }
        self.state = Disconnected(reconnect_attempts=reconnect.attempts)
        self.emit_telemetry(
          ShardDisconnected(shard_id~, code~, will_resume=resuming),
        )
        self.events.put(Disconnected(code~, resuming~)) catch {
          _ => ()
        }
      }
    }
  }
}

///|
/// Drive one connection: Hello, identify/resume, heartbeats, dispatch until
/// the connection ends (always by raising ConnectionEnded/TransportClosed).
async fn Shard::run_connection(
  self : Shard,
  transport : &GatewayTransport,
  inflater~ : &Inflater?,
  token~ : String,
  intents~ : @model.Intents,
  capabilities~ : @model.GatewayCapabilities,
  shard_id~ : Int32,
  shard_count~ : Int32,
  identify_queue? : &@queue.IdentifyQueue,
  event_filter~ : (@model.EventKind) -> Bool,
  clock~ : &@hclock.Clock,
  rand~ : @random.Rand,
) -> Unit {
  // --- Hello ---
  let hello_frame = @json.parse(recv_payload(transport, inflater~))
  guard decode_hello(hello_frame) is Some(heartbeat_interval) else {
    raise ConnectionEnded(code=None, reason="expected Hello")
  }
  let heartbeat = Heartbeat::new()

  @async.with_task_group(conn_group => {
    // --- heartbeat task (single writer discipline via send_gate) ---
    conn_group.spawn_bg(no_wait=true, () => {
      // jittered first beat per the docs
      clock.sleep(rand.int(limit=heartbeat_interval))
      for ;; {
        if heartbeat.awaiting_ack() {
          // previous beat never acked: the connection is a zombie
          raise ConnectionEnded(
            code=Some(4000),
            reason="heartbeat ACK timed out",
          )
        }
        heartbeat.beat(clock.now_unix_ms())
        self.send_heartbeat(transport)
        clock.sleep(heartbeat_interval)
      }
    })

    // --- identify or resume ---
    match self.session {
      Some(session) => {
        self.state = Resuming
        self.raw_send(transport, resume_payload(token~, session))
      }
      None => {
        self.state = Identifying
        if identify_queue is Some(q) {
          q.wait_for_identify(shard_id)
        }
        self.raw_send(
          transport,
          identify_payload(
            token~,
            intents~,
            shard_id~,
            shard_count~,
            capabilities~,
            presence=self.presence,
          ),
        )
      }
    }

    // --- read loop ---
    for ;; {
      let frame = @json.parse(recv_payload(transport, inflater~)) catch {
        error if @async.is_being_cancelled() => raise error
        TransportClosed(code~, reason~) => raise ConnectionEnded(code~, reason~)
        e => raise ConnectionEnded(code=None, reason="bad frame: \{Repr(e)}")
      }
      match decode_frame(frame) {
        Dispatch(t~, seq~, d~) => {
          if self.session is Some(session) && seq is Some(seq) {
            session.sequence = seq
          }
          match t {
            "READY" => {
              guard ready_session(d, seq) is Some(session) else { continue }
              self.session = Some(session)
              self.state = Active
              self.emit_telemetry(ShardIdentified(shard_id~))
              self.emit_telemetry(ShardConnected(shard_id~))
              self.events.put(Connected(resumed=false))
            }
            "RESUMED" => {
              self.state = Active
              self.emit_telemetry(ShardResumed(shard_id~))
              self.emit_telemetry(ShardConnected(shard_id~))
              self.events.put(Connected(resumed=true))
            }
            _ => ()
          }
          let kind = @model.EventKind::of_name(t)
          if event_filter(kind) {
            let event = @model.dispatch_event(t, d) catch {
              e =>
                // a known event failed to decode: surface it as Unknown
                // rather than killing the connection
                Unknown(t="DECODE_ERROR:\{t}:\{e}", d~)
            }
            self.events.put(Dispatch(event))
          }
        }
        HeartbeatRequest => {
          heartbeat.beat(clock.now_unix_ms())
          self.send_heartbeat(transport)
        }
        Reconnect =>
          // Reconnect request: close and resume
          raise ConnectionEnded(code=None, reason="server requested reconnect")
        InvalidSession(resumable~) =>
          raise ConnectionEnded::InvalidSession(resumable~)
        HeartbeatAck =>
          if heartbeat.ack(clock.now_unix_ms()) is Some(latency_ms) {
            self.latency = Some(latency_ms)
            self.emit_telemetry(ShardHeartbeatLatency(shard_id~, latency_ms~))
          }
        Ignored => ()
      }
    }
  })
}

///|
async fn recv_payload(
  transport : &GatewayTransport,
  inflater~ : &Inflater?,
) -> String {
  for ;; {
    match transport.recv() {
      Text(text) => {
        if inflater is Some(_) {
          raise ConnectionEnded(
            code=None,
            reason="received text while zlib-stream compression is enabled",
          )
        }
        return text
      }
      Binary(bytes) => {
        guard inflater is Some(decoder) else {
          raise ConnectionEnded(
            code=None,
            reason="received binary without a configured Gateway inflater",
          )
        }
        match decoder.push(bytes) {
          Some(text) => return text
          None => continue
        }
      }
    }
  }
}

///|
async fn Shard::send_heartbeat(
  self : Shard,
  transport : &GatewayTransport,
) -> Unit {
  let seq : Json = match self.session {
    Some(session) => Json::number(session.sequence.to_double())
    None => Json::null()
  }
  self.raw_send(transport, { "op": 1, "d": seq })
}

///|
/// Serialize writes; heartbeats and protocol frames bypass the command
/// limiter but share the single-writer gate.
async fn Shard::raw_send(
  self : Shard,
  transport : &GatewayTransport,
  payload : Json,
) -> Unit {
  self.send_gate.acquire()
  defer self.send_gate.release()
  guard !self.closing &&
    self.transport is Some(current) &&
    physical_equal(current, transport) else {
    raise TransportClosed(code=None, reason="shard is not connected")
  }
  transport.send(payload.stringify())
}
