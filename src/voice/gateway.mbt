///|
/// Events surfaced by `VoiceGateway::next`.
pub(all) enum VoiceGatewayEvent {
  ReadyReceived
  SessionEstablished(
    mode~ : String,
    secret_key~ : Bytes,
    dave_protocol_version~ : Int
  )
  Message(VoiceMessage)
  Connected(resumed~ : Bool)
  Disconnected(code~ : Int?, resuming~ : Bool)
  ConnectFailed(reason~ : String)
  NeedsRejoin(code~ : Int?)
  FatallyClosed(code~ : Int)
} derive(Debug, Eq)

///|
/// Voice gateway v8 driver. The caller-owned task group controls its
/// lifetime; cancelling the group tears down connection and heartbeat tasks.
pub struct VoiceGateway {
  priv events : @aqueue.Queue[VoiceGatewayEvent]
  priv send_gate : @async.Semaphore
  priv mut transport : &VoiceTransport?
  priv mut state_ : VoiceGatewayState
  priv mut latency : Int64?
  priv mut closing : Bool
  priv mut has_session : Bool
  priv mut last_seq : Int
  priv telemetry_ : (VoiceGatewayEvent) -> Unit
}

///|
/// Current voice gateway lifecycle state.
pub fn VoiceGateway::state(self : VoiceGateway) -> VoiceGatewayState {
  self.state_
}

///|
/// Latest matched heartbeat round-trip time in milliseconds.
pub fn VoiceGateway::latency_ms(self : VoiceGateway) -> Int64? {
  self.latency
}

///|
/// Pull the next voice gateway event. Blocks until one is available.
pub async fn VoiceGateway::next(self : VoiceGateway) -> VoiceGatewayEvent {
  self.events.get()
}

///|
/// Send an arbitrary JSON voice gateway envelope.
pub async fn VoiceGateway::send_json(
  self : VoiceGateway,
  payload : Json,
) -> Unit {
  guard self.transport is Some(transport) else {
    raise VoiceTransportClosed(
      code=None,
      reason="voice gateway is not connected",
    )
  }
  self.raw_send_json(transport, payload)
}

///|
/// Send a client-to-server DAVE binary envelope.
pub async fn VoiceGateway::send_binary(
  self : VoiceGateway,
  op~ : Int,
  payload : Bytes,
) -> Unit {
  guard self.transport is Some(transport) else {
    raise VoiceTransportClosed(
      code=None,
      reason="voice gateway is not connected",
    )
  }
  self.raw_send_binary(transport, encode_binary_client_frame(op, payload))
}

///|
/// Request graceful shutdown of the voice WebSocket.
pub async fn VoiceGateway::close(self : VoiceGateway) -> Unit noraise {
  self.closing = true
  if self.transport is Some(transport) {
    transport.close(code=1000) catch {
      _ => ()
    }
  }
}

///|
/// Spawn a voice gateway driver into `group` and return its handle.
pub fn[X] VoiceGateway::start(
  group : @async.TaskGroup[X],
  server_id~ : String,
  user_id~ : String,
  session_id~ : String,
  token~ : String,
  endpoint~ : String,
  select_protocol~ : async (UInt, String, Int, Array[String]) -> (
    String,
    Int,
    String,
  ),
  connector? : async (String) -> &VoiceTransport = connect_voice_websocket,
  queue_capacity? : Int = 256,
  telemetry? : (VoiceGatewayEvent) -> Unit = _ => (),
  sleeper? : async (Int) -> Unit = @async.sleep,
  rand? : @random.Rand = @random.Rand::chacha8(),
) -> VoiceGateway {
  let gateway : VoiceGateway = {
    events: Queue(kind=Blocking(queue_capacity)),
    send_gate: Semaphore(1),
    transport: None,
    state_: Disconnected(reconnect_attempts=0),
    latency: None,
    closing: false,
    has_session: false,
    last_seq: -1,
    telemetry_: telemetry,
  }
  group.spawn_bg(no_wait=true, () => {
    gateway.run(
      server_id~,
      user_id~,
      session_id~,
      token~,
      endpoint~,
      select_protocol~,
      connector~,
      sleeper~,
      rand~,
    )
  })
  gateway
}

///|
priv suberror VoiceConnectionEnded {
  VoiceConnectionEnded(code~ : Int?, reason~ : String)
} derive(Debug)

///|
async fn VoiceGateway::emit(
  self : VoiceGateway,
  event : VoiceGatewayEvent,
) -> Unit {
  (self.telemetry_)(event)
  self.events.put(event)
}

///|
fn voice_gateway_url(endpoint : String) -> String {
  let base = if endpoint.has_prefix("wss://") {
    endpoint
  } else {
    "wss://\{endpoint}"
  }
  let (location, query) = match base.split_once("?") {
    Some((location, query)) => (location.to_owned(), Some(query.to_owned()))
    None => (base, None)
  }
  let location = if location["wss://".length():].to_owned().contains("/") {
    location
  } else {
    "\{location}/"
  }
  match query {
    Some("") | None => "\{location}?v=8"
    Some(query) => "\{location}?\{query}&v=8"
  }
}

///|
async fn VoiceGateway::run(
  self : VoiceGateway,
  server_id~ : String,
  user_id~ : String,
  session_id~ : String,
  token~ : String,
  endpoint~ : String,
  select_protocol~ : async (UInt, String, Int, Array[String]) -> (
    String,
    Int,
    String,
  ),
  connector~ : async (String) -> &VoiceTransport,
  sleeper~ : async (Int) -> Unit,
  rand~ : @random.Rand,
) -> Unit noraise {
  let mut attempts = 0
  while !self.closing {
    if attempts > 0 {
      // Full-jitter exponential reconnect delay, capped at 30 seconds.
      let exponent = if attempts > 5 { 5 } else { attempts }
      let max_delay = 1000 * (1 << exponent)
      let capped = if max_delay > 30000 { 30000 } else { max_delay }
      sleeper(rand.int(limit=capped) + 250) catch {
        _ => return
      }
    }
    self.state_ = Connecting
    let transport = connector(voice_gateway_url(endpoint)) catch {
      error if @async.is_being_cancelled() ||
        @async.is_cancellation_error(error) => return
      error => {
        (self.telemetry_)(ConnectFailed(reason="\{to_repr(error)}"))
        attempts += 1
        self.state_ = Disconnected(reconnect_attempts=attempts)
        continue
      }
    }
    self.transport = Some(transport)
    let is_resuming = self.has_session
    let ended = try {
      self.run_connection(
        transport,
        is_resuming~,
        server_id~,
        user_id~,
        session_id~,
        token~,
        select_protocol~,
        sleeper~,
      )
      VoiceConnectionEnded(code=Some(1000), reason="connection loop exited")
    } catch {
      VoiceConnectionEnded(code~, reason~) =>
        VoiceConnectionEnded(code~, reason~)
      VoiceTransportClosed(code~, reason~) =>
        VoiceConnectionEnded(code~, reason~)
      error if @async.is_being_cancelled() ||
        @async.is_cancellation_error(error) => return
      error => VoiceConnectionEnded(code=None, reason="\{error}")
    } noraise {
      ended => ended
    }
    self.transport = None
    self.latency = None
    guard ended is VoiceConnectionEnded(code~, ..)
    if self.closing {
      self.state_ = Disconnected(reconnect_attempts=0)
      self.emit(Disconnected(code~, resuming=false)) catch {
        _ => ()
      }
      break
    }
    match voice_on_close(code, self.has_session) {
      Fatal => {
        let fatal_code = code.unwrap_or(0)
        self.state_ = FatallyClosed(code=fatal_code)
        self.emit(FatallyClosed(code=fatal_code)) catch {
          _ => ()
        }
        break
      }
      Rejoin => {
        attempts += 1
        self.state_ = Disconnected(reconnect_attempts=attempts)
        self.emit(NeedsRejoin(code~)) catch {
          _ => ()
        }
        break
      }
      Resume => {
        attempts += 1
        self.state_ = Disconnected(reconnect_attempts=attempts)
        self.emit(Disconnected(code~, resuming=true)) catch {
          _ => ()
        }
      }
    }
  }
}

///|
async fn VoiceGateway::run_connection(
  self : VoiceGateway,
  transport : &VoiceTransport,
  is_resuming~ : Bool,
  server_id~ : String,
  user_id~ : String,
  session_id~ : String,
  token~ : String,
  select_protocol~ : async (UInt, String, Int, Array[String]) -> (
    String,
    Int,
    String,
  ),
  sleeper~ : async (Int) -> Unit,
) -> Unit {
  let (hello, hello_seq) = recv_voice_message(transport)
  if hello_seq is Some(seq) {
    self.last_seq = seq
  }
  guard hello is Hello(heartbeat_interval~) && heartbeat_interval > 0 else {
    raise VoiceConnectionEnded(code=None, reason="expected Hello")
  }
  let heartbeat_acked : Ref[Bool] = Ref(true)
  let heartbeat_nonce : Ref[Int64] = Ref(-1L)
  let heartbeat_sent_at : Ref[Int64] = Ref(0L)
  @async.with_task_group(connection_group => {
    connection_group.spawn_bg(no_wait=true, () => {
      // Voice v8 does not require the gateway-identify jitter used by op 2.
      sleeper(heartbeat_interval)
      for ;; {
        if !heartbeat_acked.val {
          transport.close(code=4000) catch {
            _ => ()
          }
          break
        }
        let nonce = @clock.now_ms()
        heartbeat_nonce.val = nonce
        heartbeat_sent_at.val = nonce
        self.raw_send_json(
          transport,
          encode_heartbeat(t=nonce, seq_ack=self.last_seq),
        )
        heartbeat_acked.val = false
        sleeper(heartbeat_interval)
      }
    })

    if is_resuming {
      self.state_ = Resuming
      self.raw_send_json(
        transport,
        encode_resume(server_id~, session_id~, token~, seq_ack=self.last_seq),
      )
    } else {
      self.state_ = Identifying
      self.raw_send_json(
        transport,
        encode_identify(server_id~, user_id~, session_id~, token~),
      )
    }

    for ;; {
      let (message, seq) = recv_voice_message(transport) catch {
        VoiceTransportClosed(code~, reason~) =>
          raise VoiceConnectionEnded(code~, reason~)
        error =>
          raise VoiceConnectionEnded(
            code=None,
            reason="bad voice frame: \{error}",
          )
      }
      if seq is Some(sequence) {
        self.last_seq = sequence
      }
      match message {
        Ready(ssrc~, ip~, port~, modes~) => {
          self.emit(ReadyReceived)
          self.state_ = SelectingProtocol
          let (address, external_port, mode) = select_protocol(
            ssrc, ip, port, modes,
          )
          self.raw_send_json(
            transport,
            encode_select_protocol(address~, port=external_port, mode~),
          )
        }
        SessionDescription(mode~, secret_key~, dave_protocol_version~) => {
          self.has_session = true
          self.state_ = Active
          self.emit(
            SessionEstablished(mode~, secret_key~, dave_protocol_version~),
          )
          self.emit(Connected(resumed=false))
        }
        Resumed => {
          self.state_ = Active
          self.emit(Connected(resumed=true))
        }
        HeartbeatAck(nonce~) =>
          if nonce == heartbeat_nonce.val {
            heartbeat_acked.val = true
            self.latency = Some(@clock.now_ms() - heartbeat_sent_at.val)
          }
        other => self.emit(Message(other))
      }
    }
  })
}

///|
async fn recv_voice_message(
  transport : &VoiceTransport,
) -> (VoiceMessage, Int?) {
  match transport.recv() {
    Text(text) => parse_text_frame(text)
    Binary(bytes) => parse_binary_frame(bytes)
  }
}

///|
async fn VoiceGateway::raw_send_json(
  self : VoiceGateway,
  transport : &VoiceTransport,
  payload : Json,
) -> Unit {
  self.send_gate.acquire()
  defer self.send_gate.release()
  transport.send_text(payload.stringify())
}

///|
async fn VoiceGateway::raw_send_binary(
  self : VoiceGateway,
  transport : &VoiceTransport,
  payload : Bytes,
) -> Unit {
  self.send_gate.acquire()
  defer self.send_gate.release()
  transport.send_binary(payload)
}
