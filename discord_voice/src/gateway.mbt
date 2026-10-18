///|
/// Events surfaced by `VoiceGateway::next`.
#non_exhaustive
pub(all) enum VoiceGatewayEvent {
  ReadyReceived
  SessionEstablished(
    mode~ : String,
    secret_key~ : Bytes,
    dave_protocol_version~ : Int32
  )
  Message(VoiceMessage)
  Connected(resumed~ : Bool)
  Disconnected(code~ : Int32?, resuming~ : Bool)
  ConnectFailed(reason~ : String)
  NeedsRejoin(code~ : Int32?)
  FatallyClosed(code~ : Int32)
} derive(Debug, Eq)

///|
/// Voice gateway v8 driver. The caller-owned task group controls its
/// lifetime; cancelling the group tears down connection and heartbeat tasks.
#doc(hidden)
pub struct VoiceGateway {
  priv events : @aqueue.Queue[VoiceGatewayEvent]
  priv send_gate : @async.Semaphore
  priv mut transport : &VoiceTransport?
  priv mut state_ : VoiceGatewayState
  priv mut latency : Int64?
  priv mut closing : Bool
  priv mut has_session : Bool
  priv mut last_seq : Int32
  priv mut runner : @async.Task[Unit]?
  priv telemetry_ : (VoiceGatewayEvent) -> Unit
}

///|
/// Current voice gateway lifecycle state.
#doc(hidden)
pub fn VoiceGateway::state(self : VoiceGateway) -> VoiceGatewayState {
  self.state_
}

///|
/// Latest matched heartbeat round-trip time in milliseconds.
#doc(hidden)
pub fn VoiceGateway::latency_ms(self : VoiceGateway) -> Int64? {
  self.latency
}

///|
/// Pull the next voice gateway event. Blocks until one is available.
#doc(hidden)
pub async fn VoiceGateway::next(self : VoiceGateway) -> VoiceGatewayEvent {
  self.events.get()
}

///|
/// Send an arbitrary JSON voice gateway envelope.
#doc(hidden)
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
#doc(hidden)
pub async fn VoiceGateway::send_binary(
  self : VoiceGateway,
  op~ : Int32,
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
#doc(hidden)
pub async fn VoiceGateway::close(self : VoiceGateway) -> Unit noraise {
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
async fn VoiceGateway::wait_runner(self : VoiceGateway) -> Unit noraise {
  if self.runner is Some(runner) {
    runner.wait() catch {
      _ => ()
    }
  }
}

///|
async fn VoiceGateway::stop_runner(self : VoiceGateway) -> Unit noraise {
  if self.runner is Some(runner) {
    runner.cancel()
    self.wait_runner()
  }
  self.runner = None
  self.transport = None
  self.latency = None
  self.state_ = Disconnected(reconnect_attempts=0)
  (self.telemetry_)(Disconnected(code=Some(1000), resuming=false))
  (self.events.try_put(Disconnected(code=Some(1000), resuming=false)) |> ignore) catch {
    _ => ()
  }
}

///|
/// Close code for a connection the gateway will resume, matching the main
/// gateway: a 1000 close is reserved for shutdown.
const RESUMABLE_CLOSE_CODE : Int32 = 4000

///|
async fn VoiceGateway::finish_transport(
  self : VoiceGateway,
  transport : &VoiceTransport,
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
/// Spawn a voice gateway driver into `group` and return its handle.
/// `max_dave_protocol_version` is advertised in Identify. It defaults to zero
/// so low-level callers do not negotiate DAVE without an active backend; pass
/// a supported maximum explicitly to enable it. `clock` times the heartbeat
/// and the reconnect backoff and stamps heartbeat nonces.
#doc(hidden)
pub fn[X] VoiceGateway::start(
  group : @async.TaskGroup[X],
  server_id~ : String,
  user_id~ : String,
  session_id~ : String,
  token~ : String,
  endpoint~ : String,
  max_dave_protocol_version~ : UInt16 = 0,
  select_protocol~ : async (UInt32, String, Int32, Array[String]) -> (
    String,
    Int32,
    String,
  ),
  connector~ : async (String) -> &VoiceTransport = connect_voice_websocket,
  queue_capacity~ : Int32 = 256,
  telemetry~ : (VoiceGatewayEvent) -> Unit = _ => (),
  clock~ : &@hclock.Clock = @transport.AsyncClock::new(),
  rand~ : @random.Rand = @random.Rand(),
) -> VoiceGateway {
  let gateway = VoiceGateway::{
    events: Queue(kind=Blocking(queue_capacity)),
    send_gate: Semaphore(1),
    transport: None,
    state_: Disconnected(reconnect_attempts=0),
    latency: None,
    closing: false,
    has_session: false,
    last_seq: -1,
    runner: None,
    telemetry_: telemetry,
  }
  let runner = group.spawn(no_wait=true, () => {
    gateway.run(
      server_id~,
      user_id~,
      session_id~,
      token~,
      endpoint~,
      max_dave_protocol_version~,
      select_protocol~,
      connector~,
      clock~,
      rand~,
    )
  })
  gateway.runner = Some(runner)
  gateway
}

///|
priv suberror VoiceConnectionEnded {
  VoiceConnectionEnded(code~ : Int32?, reason~ : String)
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
  max_dave_protocol_version~ : UInt16,
  select_protocol~ : async (UInt32, String, Int32, Array[String]) -> (
    String,
    Int32,
    String,
  ),
  connector~ : async (String) -> &VoiceTransport,
  clock~ : &@hclock.Clock,
  rand~ : @random.Rand,
) -> Unit noraise {
  let mut attempts = 0
  while !self.closing {
    if attempts > 0 {
      // Full-jitter exponential backoff.
      clock.sleep(rand.int(limit=reconnect_delay_limit(attempts)) + 250)
    }
    self.state_ = Connecting
    let transport = connector(voice_gateway_url(endpoint)) catch {
      _ if @async.is_being_cancelled() => return
      error => {
        (self.telemetry_)(ConnectFailed(reason="\{Repr(error)}"))
        attempts += 1
        self.state_ = Disconnected(reconnect_attempts=attempts)
        continue
      }
    }
    self.transport = Some(transport)
    let is_resuming = self.has_session
    let ended = try {
      defer {
        let code = if self.closing || @async.is_being_cancelled() {
          1000
        } else {
          RESUMABLE_CLOSE_CODE
        }
        @async.protect_from_cancel(() => self.finish_transport(transport, code~))
      }
      self.run_connection(
        transport,
        is_resuming~,
        server_id~,
        user_id~,
        session_id~,
        token~,
        max_dave_protocol_version~,
        select_protocol~,
        clock~,
      )
      VoiceConnectionEnded(code=Some(1000), reason="connection loop exited")
    } catch {
      _ if @async.is_being_cancelled() => return
      VoiceConnectionEnded(code~, reason~) =>
        VoiceConnectionEnded(code~, reason~)
      VoiceTransportClosed(code~, reason~) =>
        VoiceConnectionEnded(code~, reason~)
      error => VoiceConnectionEnded(code=None, reason="\{Repr(error)}")
    } noraise {
      ended => ended
    }
    self.transport = None
    self.latency = None
    guard ended is VoiceConnectionEnded(code~, ..)
    // A connection that got as far as READY/RESUMED starts the backoff over;
    // only consecutive failures should push the delay toward its cap.
    if self.state_ is Active {
      attempts = 0
    }
    let outcome = close_outcome(
      code,
      closing=self.closing,
      has_session=self.has_session,
      attempts~,
    )
    attempts = outcome.attempts
    self.state_ = outcome.state
    self.emit(outcome.event) catch {
      _ => ()
    }
    if outcome.stop {
      break
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
  max_dave_protocol_version~ : UInt16,
  select_protocol~ : async (UInt32, String, Int32, Array[String]) -> (
    String,
    Int32,
    String,
  ),
  clock~ : &@hclock.Clock,
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
      clock.sleep(heartbeat_interval)
      for ;; {
        if !heartbeat_acked.val {
          raise VoiceConnectionEnded(
            code=Some(4000),
            reason="heartbeat ACK timed out",
          )
        }
        let nonce = clock.now_unix_ms()
        heartbeat_nonce.val = nonce
        heartbeat_sent_at.val = nonce
        heartbeat_acked.val = false
        self.raw_send_json(
          transport,
          encode_heartbeat(t=nonce, seq_ack=self.last_seq),
        )
        clock.sleep(heartbeat_interval)
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
        encode_identify(
          server_id~,
          user_id~,
          session_id~,
          token~,
          max_dave_protocol_version~,
        ),
      )
    }

    for ;; {
      let (message, seq) = recv_voice_message(transport) catch {
        error if @async.is_being_cancelled() => raise error
        VoiceTransportClosed(code~, reason~) =>
          raise VoiceConnectionEnded(code~, reason~)
        error =>
          raise VoiceConnectionEnded(
            code=None,
            reason="bad voice frame: \{Repr(error)}",
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
            self.latency = Some(clock.now_unix_ms() - heartbeat_sent_at.val)
          }
        other => self.emit(Message(other))
      }
    }
  })
}

///|
async fn recv_voice_message(
  transport : &VoiceTransport,
) -> (VoiceMessage, Int32?) {
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
  guard !self.closing &&
    self.transport is Some(current) &&
    physical_equal(current, transport) else {
    raise VoiceTransportClosed(
      code=None,
      reason="voice gateway is not connected",
    )
  }
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
  guard !self.closing &&
    self.transport is Some(current) &&
    physical_equal(current, transport) else {
    raise VoiceTransportClosed(
      code=None,
      reason="voice gateway is not connected",
    )
  }
  transport.send_binary(payload)
}
