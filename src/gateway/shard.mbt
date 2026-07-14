///|
/// Events surfaced by `Shard::next`.
pub(all) enum ShardEvent {
  Dispatch(@model.Event)
  Connected(resumed~ : Bool)
  Disconnected(code~ : Int?, resuming~ : Bool)
  FatallyClosed(code~ : Int)
} derive(Debug)

///|
/// A single gateway connection with automatic heartbeat, resume, and
/// reconnect. Pull events with `next`; the shard's tasks live in the task
/// group passed to `start`, so cancelling the group tears the shard down.
pub struct Shard {
  priv events : @aqueue.Queue[ShardEvent]
  priv command_limiter : CommandLimiter
  priv send_gate : @async.Semaphore
  priv mut transport : &GatewayTransport?
  priv mut state : ShardState
  priv mut session : Session?
  priv mut latency : Int64?
  priv mut closing : Bool
  priv telemetry_ : (@telemetry.TelemetryEvent) -> Unit
}

///|
pub fn Shard::state(self : Shard) -> ShardState {
  self.state
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
  guard self.transport is Some(transport) else {
    raise TransportClosed(code=None, reason="shard is not connected")
  }
  self.send_gate.acquire()
  try transport.send(command.stringify()) catch {
    e => {
      self.send_gate.release()
      raise e
    }
  } noraise {
    _ => self.send_gate.release()
  }
}

///|
/// Request a graceful shutdown: closes the connection with code 1000 (which
/// invalidates the session — Discord will not allow a resume after it).
pub async fn Shard::close(self : Shard) -> Unit noraise {
  self.closing = true
  if self.transport is Some(t) {
    // the driver's read loop observes the close and exits
    t.close(code=1000) catch {
      _ => ()
    }
  }
}

///|
/// Spawn a shard into `group` and return its handle.
pub fn[X] Shard::start(
  group : @async.TaskGroup[X],
  token~ : String,
  intents~ : @model.Intents,
  gateway_url? : String = "wss://gateway.discord.gg",
  shard_id? : Int = 0,
  shard_count? : Int = 1,
  identify_queue? : &@queue.IdentifyQueue,
  event_filter? : (@model.EventKind) -> Bool = _ => true,
  connector? : async (String) -> &GatewayTransport = connect_websocket,
  queue_capacity? : Int = 256,
  telemetry? : (@telemetry.TelemetryEvent) -> Unit = _ => (),
) -> Shard {
  let shard : Shard = {
    events: @aqueue.Queue::new(kind=Blocking(queue_capacity)),
    command_limiter: CommandLimiter::new(),
    send_gate: @async.Semaphore::new(1),
    transport: None,
    state: Disconnected(reconnect_attempts=0),
    session: None,
    latency: None,
    closing: false,
    telemetry_: telemetry,
  }
  group.spawn_bg(no_wait=true, () => {
    shard.run(
      token~,
      intents~,
      gateway_url~,
      shard_id~,
      shard_count~,
      identify_queue?,
      event_filter~,
      connector~,
    )
  })
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
priv suberror ConnectionEnded {
  ConnectionEnded(code~ : Int?, reason~ : String)
} derive(Debug)

///|
/// The reconnect loop: connect, run one connection to completion, classify
/// the close, back off, repeat.
async fn Shard::run(
  self : Shard,
  token~ : String,
  intents~ : @model.Intents,
  gateway_url~ : String,
  shard_id~ : Int,
  shard_count~ : Int,
  identify_queue? : &@queue.IdentifyQueue,
  event_filter~ : (@model.EventKind) -> Bool,
  connector~ : async (String) -> &GatewayTransport,
) -> Unit noraise {
  let rand = @random.Rand::chacha8()
  let mut attempts = 0
  while !self.closing {
    if attempts > 0 {
      // full-jitter exponential backoff, capped at 30s
      let max_delay = 1000 * (1 << (if attempts > 5 { 5 } else { attempts }))
      let capped = if max_delay > 30000 { 30000 } else { max_delay }
      @async.sleep(rand.int(limit=capped) + 250) catch {
        _ => return
      }
    }
    self.state = Connecting
    self.emit_telemetry(@telemetry.TelemetryEvent::ShardConnecting(shard_id~))
    let base = match self.session {
      Some(session) => session.resume_url
      None => gateway_url
    }
    let transport = connector("\{base}/?v=10&encoding=json") catch {
      _ => {
        attempts += 1
        self.state = Disconnected(reconnect_attempts=attempts)
        self.emit_telemetry(
          @telemetry.TelemetryEvent::ShardDisconnected(
            shard_id~,
            code=None,
            will_resume=false,
          ),
        )
        continue
      }
    }
    self.transport = Some(transport)
    let ended = try {
      self.run_connection(
        transport,
        token~,
        intents~,
        shard_id~,
        shard_count~,
        identify_queue?,
        event_filter~,
        rand,
      )
      ConnectionEnded(code=Some(1000), reason="loop exited")
    } catch {
      ConnectionEnded(code~, reason~) => ConnectionEnded(code~, reason~)
      TransportClosed(code~, reason~) => ConnectionEnded(code~, reason~)
      e => ConnectionEnded(code=None, reason="\{e}")
    } noraise {
      ended => ended
    }
    self.transport = None
    self.latency = None
    guard ended is ConnectionEnded(code~, ..)
    if self.closing {
      self.state = Disconnected(reconnect_attempts=0)
      self.emit_telemetry(
        @telemetry.TelemetryEvent::ShardDisconnected(
          shard_id~,
          code~,
          will_resume=false,
        ),
      )
      self.events.put(Disconnected(code~, resuming=false)) catch {
        _ => ()
      }
      break
    }
    match on_close(code, self.session is Some(_)) {
      Fatal => {
        let fatal_code = code.unwrap_or(0)
        self.state = FatallyClosed(code=fatal_code)
        self.emit_telemetry(
          @telemetry.TelemetryEvent::ShardDisconnected(
            shard_id~,
            code~,
            will_resume=false,
          ),
        )
        self.events.put(FatallyClosed(code=fatal_code)) catch {
          _ => ()
        }
        break
      }
      Reidentify => {
        self.session = None
        attempts += 1
        self.state = Disconnected(reconnect_attempts=attempts)
        self.emit_telemetry(
          @telemetry.TelemetryEvent::ShardDisconnected(
            shard_id~,
            code~,
            will_resume=false,
          ),
        )
        self.events.put(Disconnected(code~, resuming=false)) catch {
          _ => ()
        }
      }
      Resume => {
        attempts += 1
        self.state = Disconnected(reconnect_attempts=attempts)
        self.emit_telemetry(
          @telemetry.TelemetryEvent::ShardDisconnected(
            shard_id~,
            code~,
            will_resume=true,
          ),
        )
        self.events.put(Disconnected(code~, resuming=true)) catch {
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
  token~ : String,
  intents~ : @model.Intents,
  shard_id~ : Int,
  shard_count~ : Int,
  identify_queue? : &@queue.IdentifyQueue,
  event_filter~ : (@model.EventKind) -> Bool,
  rand : @random.Rand,
) -> Unit {
  // --- Hello ---
  let hello_frame = @json.parse(transport.recv())
  guard hello_frame
    is {
      "op": Number(10, ..),
      "d": { "heartbeat_interval": Number(iv, ..), .. },
      ..
    } else {
    raise ConnectionEnded(code=None, reason="expected Hello")
  }
  let heartbeat_interval = iv.to_int()
  let heartbeat_state : Ref[Bool] = Ref(true) // last heartbeat was acked
  let heartbeat_sent_at : Ref[Int64] = Ref(0)

  @async.with_task_group(conn_group => {
    // --- heartbeat task (single writer discipline via send_gate) ---
    conn_group.spawn_bg(no_wait=true, () => {
      // jittered first beat per the docs
      @async.sleep(rand.int(limit=heartbeat_interval))
      for ;; {
        if !heartbeat_state.val {
          // previous beat never acked: the connection is a zombie
          transport.close(code=4000) catch {
            _ => ()
          }
          break
        }
        self.send_heartbeat(transport)
        heartbeat_state.val = false
        heartbeat_sent_at.val = @async.now()
        @async.sleep(heartbeat_interval)
      }
    })

    // --- identify or resume ---
    match self.session {
      Some(session) => {
        self.state = Resuming
        let resume_payload : Json = {
          "op": 6,
          "d": {
            "token": Json::string(token),
            "session_id": Json::string(session.id),
            "seq": Json::number(session.sequence.to_double()),
          },
        }
        self.raw_send(transport, resume_payload)
      }
      None => {
        self.state = Identifying
        if identify_queue is Some(q) {
          q.wait_for_identify(shard_id)
        }
        let identify : Json = {
          "op": 2,
          "d": {
            "token": Json::string(token),
            "intents": intents.to_json(),
            "shard": [
              Json::number(shard_id.to_double()),
              Json::number(shard_count.to_double()),
            ],
            "properties": {
              "os": "linux",
              "browser": "discord.mbt",
              "device": "discord.mbt",
            },
          },
        }
        self.raw_send(transport, identify)
      }
    }

    // --- read loop ---
    for ;; {
      let frame = @json.parse(transport.recv()) catch {
        TransportClosed(code~, reason~) => raise ConnectionEnded(code~, reason~)
        e => raise ConnectionEnded(code=None, reason="bad frame: \{e}")
      }
      guard frame is { "op": Number(op, ..), .. } else { continue }
      match op.to_int() {
        0 => {
          guard frame is { "t": String(t), "s": s, "d": d, .. } else {
            continue
          }
          if self.session is Some(session) && s is Number(seq, ..) {
            session.sequence = seq.to_int64()
          }
          match t {
            "READY" => {
              guard d
                is {
                  "session_id": String(session_id),
                  "resume_gateway_url": String(resume_url),
                  ..
                } else {
                continue
              }
              let sequence = if s is Number(seq, ..) {
                seq.to_int64()
              } else {
                0L
              }
              self.session = Some({ id: session_id, resume_url, sequence })
              self.state = Active
              self.emit_telemetry(
                @telemetry.TelemetryEvent::ShardIdentified(shard_id~),
              )
              self.emit_telemetry(
                @telemetry.TelemetryEvent::ShardConnected(shard_id~),
              )
              self.events.put(Connected(resumed=false))
            }
            "RESUMED" => {
              self.state = Active
              self.emit_telemetry(
                @telemetry.TelemetryEvent::ShardResumed(shard_id~),
              )
              self.emit_telemetry(
                @telemetry.TelemetryEvent::ShardConnected(shard_id~),
              )
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
                @model.Event::Unknown(t="DECODE_ERROR:\{t}:\{e}", d~)
            }
            self.events.put(Dispatch(event))
          }
        }
        1 => {
          self.send_heartbeat(transport)
          heartbeat_state.val = false
          heartbeat_sent_at.val = @async.now()
        }
        7 =>
          // Reconnect request: close and resume
          raise ConnectionEnded(code=None, reason="server requested reconnect")
        9 => {
          let resumable = frame is { "d": True, .. }
          if !resumable {
            self.session = None
            // wait 1-5s before re-identifying, per the docs
            @async.sleep(1000 + rand.int(limit=4000))
          }
          raise ConnectionEnded(code=None, reason="invalid session")
        }
        11 => {
          heartbeat_state.val = true
          self.latency = Some(@async.now() - heartbeat_sent_at.val)
          guard self.latency is Some(latency_ms)
          self.emit_telemetry(
            @telemetry.TelemetryEvent::ShardHeartbeatLatency(
              shard_id~,
              latency_ms~,
            ),
          )
        }
        _ => ()
      }
    }
  })
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
  try transport.send(payload.stringify()) catch {
    e => {
      self.send_gate.release()
      raise e
    }
  } noraise {
    _ => self.send_gate.release()
  }
}
