///|
/// Errors surfaced while joining or operating a voice connection.
pub(all) suberror VoiceError {
  /// The main Gateway session lacks an intent required by the voice
  /// handshake.
  MissingIntent(intent~ : String)
  JoinTimeout
  ShimUnavailable(reason~ : String)
  NoCompatibleMode(offered~ : Array[String])
  GatewayClosed(code~ : Int?)
  IpDiscoveryFailed(reason~ : String)
  Disconnected
} derive(Debug)

///|
/// Public voice connection lifecycle.
pub(all) enum VoiceConnectionState {
  Connecting
  Ready
  Reconnecting
  Rejoining
  Closed(code~ : Int?)
} derive(Debug, Eq)

///|
/// Credentials supplied by the main Discord gateway voice-state handshake.
pub(all) struct VoiceCredentials {
  server_id : String
  session_id : String
  token : String
  endpoint : String
} derive(Debug, Eq)

///|
priv struct PlaybackRequest {
  generation : Int
  source : &AudioSource
}

///|
/// High-level owner of voice gateway, UDP media, DAVE, sender, and receiver
/// tasks. All background work is attached to the task group passed to `start`.
pub struct VoiceConnection {
  priv events : @aqueue.Queue[VoiceEvent]
  priv playback : @aqueue.Queue[PlaybackRequest]
  priv subscriptions : Array[VoiceReceiveStream]
  priv user_id : String
  priv channel_id : UInt64
  priv leave_ : async () -> Unit
  priv rejoin_ : async () -> VoiceCredentials
  priv connector_ : async (String) -> &VoiceTransport
  priv udp_opener_ : async (String, Int) -> &VoiceUdp
  priv telemetry_ : (VoiceTelemetry) -> Unit
  priv sleeper_ : async (Int) -> Unit
  priv rand_ : @random.Rand
  priv receiver : ReceivePipeline
  priv roster : Set[String]
  priv mut gateway : VoiceGateway?
  priv mut udp : &VoiceUdp?
  priv mut cipher : TransportCipher?
  priv mut dave : DaveMachine?
  priv mut pending_dave_external_sender : Bytes?
  priv mut ssrc : UInt?
  priv mut state_ : VoiceConnectionState
  priv mut failure : VoiceError?
  priv mut closing : Bool
  priv mut disconnecting : Bool
  priv mut session_generation : Int
  priv mut playback_generation : Int
  priv mut playback_stop : Ref[Bool]?
}

///|
fn EncryptionMode::wire_name(self : EncryptionMode) -> String {
  match self {
    AeadAes256GcmRtpsize => "aead_aes256_gcm_rtpsize"
    AeadXChaCha20Poly1305Rtpsize => "aead_xchacha20_poly1305_rtpsize"
  }
}

///|
fn VoiceConnection::set_failure(
  self : VoiceConnection,
  error : VoiceError,
  code~ : Int?,
) -> Unit {
  if self.failure is None {
    self.failure = Some(error)
  }
  self.state_ = Closed(code~)
}

///|
async fn VoiceConnection::close_udp(self : VoiceConnection) -> Unit noraise {
  if self.udp is Some(udp) {
    udp.close() catch {
      _ => ()
    }
  }
  self.udp = None
}

///|
async fn VoiceConnection::reset_session(self : VoiceConnection) -> Unit noraise {
  self.session_generation += 1
  self.playback_generation += 1
  if self.playback_stop is Some(stop) {
    stop.val = true
  }
  self.close_udp()
  self.cipher = None
  self.dave = None
  self.pending_dave_external_sender = None
  self.ssrc = None
  self.receiver.reset_session()
}

///|
async fn VoiceConnection::terminal_teardown(
  self : VoiceConnection,
  notify_leave~ : Bool,
) -> Unit noraise {
  if self.closing {
    return
  }
  // Publish the terminal flag before any await so every worker stops even if
  // one of the best-effort transport cleanups stalls or fails.
  self.closing = true
  self.disconnecting = true
  if !(self.state_ is Closed(..)) {
    self.state_ = Closed(code=None)
  }
  self.playback_generation += 1
  if self.playback_stop is Some(stop) {
    stop.val = true
  }
  if notify_leave {
    (self.leave_)() catch {
      _ => ()
    }
  }
  if self.gateway is Some(gateway) {
    gateway.close()
  }
  self.gateway = None
  self.close_udp()
  self.close_subscriptions()
  self.playback.close(error=VoiceError::Disconnected)
  self.events.close(error=VoiceError::Disconnected)
}

///|
async fn VoiceConnection::select_protocol(
  self : VoiceConnection,
  ssrc : UInt,
  ip : String,
  port : Int,
  modes : Array[String],
) -> (String, Int, String) {
  let mode = EncryptionMode::negotiate(modes) catch {
    NoCompatibleMode(modes~) => {
      self.set_failure(NoCompatibleMode(offered=modes), code=None)
      raise VoiceCryptoError::NoCompatibleMode(modes~)
    }
    error => raise error
  }
  let udp = (self.udp_opener_)(ip, port) catch {
    error if @async.is_being_cancelled() => raise error
    error => {
      self.set_failure(IpDiscoveryFailed(reason="\{Repr(error)}"), code=None)
      raise error
    }
  }
  errdefer @async.protect_from_cancel(() => udp.close() catch { _ => () })
  let discovered = discover_external_address(udp, ssrc) catch {
    error if @async.is_being_cancelled() => raise error
    VoiceUdpError::IpDiscoveryFailed(reason~, ..) => {
      self.set_failure(IpDiscoveryFailed(reason~), code=None)
      raise VoiceUdpError::IpDiscoveryFailed(attempts=3, reason~)
    }
    error => {
      self.set_failure(IpDiscoveryFailed(reason="\{Repr(error)}"), code=None)
      raise error
    }
  }
  self.close_udp()
  self.udp = Some(udp)
  self.ssrc = Some(ssrc)
  self.session_generation += 1
  let (address, external_port) = discovered
  (address, external_port, mode.wire_name())
}

///|
fn[X] VoiceConnection::new_gateway(
  self : VoiceConnection,
  group : @async.TaskGroup[X],
  credentials : VoiceCredentials,
) -> VoiceGateway {
  VoiceGateway::start(
    group,
    server_id=credentials.server_id,
    user_id=self.user_id,
    session_id=credentials.session_id,
    token=credentials.token,
    endpoint=credentials.endpoint,
    max_dave_protocol_version=@dave.max_supported_protocol_version(),
    select_protocol=(ssrc, ip, port, modes) => {
      self.select_protocol(ssrc, ip, port, modes)
    },
    connector=self.connector_,
    telemetry=event => (self.telemetry_)(GatewayEvent(event)),
    sleeper=self.sleeper_,
    rand=self.rand_,
  )
}

///|
async fn VoiceConnection::emit(
  self : VoiceConnection,
  event : VoiceEvent,
) -> Unit {
  if event is OpusReceived(user_id=Some(user_id), opus~, ..) {
    let matched : Array[VoiceReceiveStream] = []
    for subscription in self.subscriptions {
      if !subscription.closed && subscription.user_id == user_id {
        matched.push(subscription)
      }
    }
    for subscription in matched {
      (subscription.queue.try_put(opus) |> ignore) catch {
        _ => self.remove_subscription(subscription)
      }
    }
  }
  self.events.put(event)
}

///|
async fn VoiceConnection::establish_session(
  self : VoiceConnection,
  mode_name : String,
  secret_key : Bytes,
  dave_protocol_version : Int,
) -> Unit {
  let mode = EncryptionMode::negotiate([mode_name]) catch {
    NoCompatibleMode(modes~) => {
      self.set_failure(NoCompatibleMode(offered=modes), code=None)
      return
    }
    error => {
      self.set_failure(ShimUnavailable(reason="\{Repr(error)}"), code=None)
      return
    }
  }
  let cipher = TransportCipher::new(mode, secret_key) catch {
    ShimUnavailable(reason~) => {
      self.set_failure(ShimUnavailable(reason~), code=None)
      return
    }
    error => {
      self.set_failure(ShimUnavailable(reason="\{Repr(error)}"), code=None)
      return
    }
  }
  let mut dave = self.dave
  let max_dave_protocol_version = @dave.max_supported_protocol_version().to_int()
  if dave_protocol_version >= 1 || max_dave_protocol_version >= 1 {
    let session_protocol_version = if dave_protocol_version >= 1 {
      dave_protocol_version
    } else {
      max_dave_protocol_version
    }
    let machine = match dave {
      Some(machine) => machine
      None =>
        DaveMachine::new(
          protocol_version=session_protocol_version,
          self_user_id=self.user_id,
          channel_id=self.channel_id,
          roster=self.roster.to_array(),
        ) catch {
          DaveUnavailable(reason~)
          | DaveInvalid(reason~)
          | DaveInternal(reason~) => {
            self.set_failure(
              ShimUnavailable(reason="DAVE: \{reason}"),
              code=None,
            )
            return
          }
        }
    }
    if self.pending_dave_external_sender is Some(external_sender) {
      let _ = machine.handle(DaveMlsExternalSender(payload=external_sender)) catch {
        DaveUnavailable(reason~)
        | DaveInvalid(reason~)
        | DaveInternal(reason~) => {
          self.set_failure(ShimUnavailable(reason="DAVE: \{reason}"), code=None)
          return
        }
      }
      self.pending_dave_external_sender = None
    }
    let actions = machine.handle(
      SessionDescription(mode=mode_name, secret_key~, dave_protocol_version~),
    ) catch {
      DaveUnavailable(reason~) | DaveInvalid(reason~) | DaveInternal(reason~) => {
        self.set_failure(ShimUnavailable(reason="DAVE: \{reason}"), code=None)
        return
      }
    }
    dave = Some(machine)
    self.dave = dave
    self.apply_dave_actions(actions) catch {
      error =>
        (self.telemetry_)(PacketDropped(reason="DAVE send: \{Repr(error)}"))
    }
  }
  self.cipher = Some(cipher)
  self.dave = dave
  self.failure = None
  self.state_ = Ready
  self.emit(ConnectionReady)
}

///|
async fn VoiceConnection::apply_dave_actions(
  self : VoiceConnection,
  actions : Array[DaveAction],
) -> Unit {
  guard self.gateway is Some(gateway) else { return }
  for action in actions {
    match action {
      SendJson(payload) => gateway.send_json(payload)
      SendBinary(op~, payload~) => {
        gateway.send_binary(op~, payload)
        (self.telemetry_)(
          DaveBinaryControlSent(opcode=op, payload_bytes=payload.length()),
        )
      }
      SwitchMediaContext(protocol_version~) =>
        (self.telemetry_)(DaveMediaContextActivated(protocol_version~))
    }
  }
}

///|
async fn VoiceConnection::handle_message(
  self : VoiceConnection,
  message : VoiceMessage,
) -> Unit {
  match message {
    ClientsConnect(user_ids~) =>
      for user_id in user_ids {
        self.roster.add(user_id)
      }
    ClientDisconnect(user_id~) => self.roster.remove(user_id)
    DaveMlsExternalSender(payload~) if self.dave is None =>
      self.pending_dave_external_sender = Some(payload)
    _ => ()
  }
  if self.dave is Some(machine) {
    let actions = machine.handle(message) catch {
      error => {
        (self.telemetry_)(PacketDropped(reason="DAVE control: \{Repr(error)}"))
        []
      }
    }
    self.apply_dave_actions(actions) catch {
      error =>
        (self.telemetry_)(PacketDropped(reason="DAVE send: \{Repr(error)}"))
    }
  }
  for event in self.receiver.handle_gateway_message(message) {
    self.emit(event)
  }
}

///|
async fn[X] VoiceConnection::run_event_pump(
  self : VoiceConnection,
  group : @async.TaskGroup[X],
) -> Unit noraise {
  defer self.terminal_teardown(notify_leave=true)
  while !self.closing {
    guard self.gateway is Some(gateway) else {
      @async.sleep(5)
      continue
    }
    let event = gateway.next() catch {
      _ => {
        if !self.closing {
          self.set_failure(Disconnected, code=None)
          self.reset_session()
        }
        return
      }
    }
    match event {
      SessionEstablished(mode~, secret_key~, dave_protocol_version~) => {
        self.establish_session(mode, secret_key, dave_protocol_version) catch {
          _ => ()
        }
        if self.failure is Some(_) {
          self.reset_session()
          gateway.close()
          return
        }
      }
      Message(message) => self.handle_message(message) catch { _ => () }
      Connected(resumed=true) => {
        self.state_ = Ready
        self.emit(ConnectionResumed) catch {
          _ => return
        }
      }
      Connected(resumed=false) | ReadyReceived => ()
      ConnectFailed(..) => ()
      Disconnected(code~, resuming=true) => {
        ignore(code)
        self.state_ = Reconnecting
      }
      Disconnected(..) => ()
      NeedsRejoin(code~) => {
        ignore(code)
        if self.failure is Some(_) {
          self.reset_session()
          return
        }
        self.state_ = Rejoining
        self.reset_session()
        let credentials = (self.rejoin_)() catch {
          _ => {
            self.set_failure(Disconnected, code=None)
            return
          }
        }
        if self.closing {
          return
        }
        self.state_ = Connecting
        self.gateway = Some(self.new_gateway(group, credentials))
      }
      FatallyClosed(code~) => {
        self.set_failure(GatewayClosed(code=Some(code)), code=Some(code))
        self.reset_session()
        return
      }
    }
  }
}

///|
async fn VoiceConnection::run_receiver(self : VoiceConnection) -> Unit noraise {
  let buffer : FixedArray[Byte] = FixedArray::make(65535, 0)
  while !self.closing {
    guard self.udp is Some(udp) && self.cipher is Some(cipher) else {
      @async.sleep(5)
      continue
    }
    let generation = self.session_generation
    let received = udp.recv(buffer) catch {
      _ => {
        if self.closing {
          return
        }
        @async.sleep(5)
        continue
      }
    }
    if generation != self.session_generation || received <= 0 {
      continue
    }
    let datagram = Bytes::from_array(buffer[:received])
    for
      event in self.receiver.process_udp_packet(
        datagram,
        cipher,
        self.dave,
        arrival_ms=@clock.now_ms(),
      ) {
      self.emit(event) catch {
        _ => return
      }
    }
  }
}

///|
fn keepalive_packet(counter : UInt64) -> Bytes {
  Bytes::makei(8, index => (counter >> (index * 8)).to_byte())
}

///|
async fn VoiceConnection::run_keepalive(self : VoiceConnection) -> Unit noraise {
  let mut counter = 0UL
  while !self.closing {
    (self.sleeper_)(5000) catch {
      _ => return
    }
    if self.udp is Some(udp) {
      udp.send(keepalive_packet(counter)) catch {
        _ => ()
      }
      counter += 1
    }
  }
}

///|
async fn VoiceConnection::run_playback(self : VoiceConnection) -> Unit noraise {
  while !self.closing {
    let request = self.playback.get() catch { _ => return }
    if request.generation != self.playback_generation {
      continue
    }
    while !self.closing &&
          request.generation == self.playback_generation &&
          (
            self.cipher is None ||
            self.udp is None ||
            self.gateway is None ||
            self.ssrc is None
          ) {
      @async.sleep(5)
    }
    if self.closing || request.generation != self.playback_generation {
      continue
    }
    guard self.cipher is Some(cipher) &&
      self.udp is Some(udp) &&
      self.gateway is Some(gateway) &&
      self.ssrc is Some(ssrc) else {
      continue
    }
    let stop = Ref(false)
    self.playback_stop = Some(stop)
    run_send_loop(
      request.source,
      cipher,
      udp,
      gateway,
      ssrc~,
      stop~,
      dave?=self.dave,
      on_dave_error=reason => (self.telemetry_)(DaveEncryptDropped(reason~)),
    ) catch {
      error =>
        (self.telemetry_)(PacketDropped(reason="send loop: \{Repr(error)}"))
    }
    self.playback_stop = None
  }
}

///|
/// Start a voice connection and attach all of its tasks to `group`.
pub fn[X] VoiceConnection::start(
  group : @async.TaskGroup[X],
  credentials : VoiceCredentials,
  user_id~ : String,
  channel_id~ : UInt64,
  leave~ : async () -> Unit,
  rejoin~ : async () -> VoiceCredentials,
  connector? : async (String) -> &VoiceTransport = connect_voice_websocket,
  udp_opener? : async (String, Int) -> &VoiceUdp = open_voice_udp,
  receive? : Bool = true,
  telemetry? : (VoiceTelemetry) -> Unit = _ => (),
  sleeper? : async (Int) -> Unit = ms => @async.sleep(ms),
  rand? : @random.Rand = @random.Rand::new(),
) -> VoiceConnection {
  let receiver = ReceivePipeline::new(telemetry)
  let connection = VoiceConnection::{
    events: Queue(kind=Unbounded),
    playback: Queue(kind=Unbounded),
    subscriptions: [],
    user_id,
    channel_id,
    leave_: leave,
    rejoin_: rejoin,
    connector_: connector,
    udp_opener_: udp_opener,
    telemetry_: telemetry,
    sleeper_: sleeper,
    rand_: rand,
    receiver,
    roster: Set([]),
    gateway: None,
    udp: None,
    cipher: None,
    dave: None,
    pending_dave_external_sender: None,
    ssrc: None,
    state_: Connecting,
    failure: None,
    closing: false,
    disconnecting: false,
    session_generation: 0,
    playback_generation: 0,
    playback_stop: None,
  }
  connection.gateway = Some(connection.new_gateway(group, credentials))
  group.spawn_bg(no_wait=true, () => connection.run_event_pump(group))
  if receive {
    group.spawn_bg(no_wait=true, () => connection.run_receiver())
  }
  group.spawn_bg(no_wait=true, () => connection.run_keepalive())
  group.spawn_bg(no_wait=true, () => connection.run_playback())
  connection
}

///|
/// Wait until the current connection handshake reaches `Ready`.
pub async fn VoiceConnection::wait_ready(
  self : VoiceConnection,
  timeout_ms? : Int = 10000,
) -> Unit raise VoiceError {
  @async.with_timeout(
    timeout_ms,
    () => {
      for ;; {
        if self.state_ is Ready {
          return
        }
        if self.failure is Some(error) {
          raise error
        }
        if self.closing {
          raise VoiceError::Disconnected
        }
        @async.sleep(5)
      }
    },
    error=JoinTimeout,
  ) catch {
    JoinTimeout => raise JoinTimeout
    VoiceError::ShimUnavailable(reason~) => raise ShimUnavailable(reason~)
    VoiceError::NoCompatibleMode(offered~) => raise NoCompatibleMode(offered~)
    GatewayClosed(code~) => raise GatewayClosed(code~)
    VoiceError::IpDiscoveryFailed(reason~) => raise IpDiscoveryFailed(reason~)
    VoiceError::Disconnected => raise Disconnected
    _ => raise Disconnected
  }
}

///|
/// Replace the current source. The old sender is asked to stop and flush its
/// five silence frames before the latest source begins.
pub async fn VoiceConnection::play(
  self : VoiceConnection,
  source : &AudioSource,
) -> Unit {
  self.playback_generation += 1
  if self.playback_stop is Some(stop) {
    stop.val = true
  }
  self.playback.put({ generation: self.playback_generation, source, })
}

///|
/// Stop the active source; the send loop emits five silence frames and clears
/// the speaking flag.
#warnings("-unused_async")
pub async fn VoiceConnection::stop(self : VoiceConnection) -> Unit {
  self.playback_generation += 1
  if self.playback_stop is Some(stop) {
    stop.val = true
  }
  while self.playback_stop is Some(_) && !self.closing {
    @async.sleep(5)
  }
}

///|
/// Send a Speaking (opcode 5) frame with the given flag bits. The playback
/// loop manages this automatically; call it directly only for custom
/// speaking indicators.
pub async fn VoiceConnection::set_speaking(
  self : VoiceConnection,
  flags : Int,
) -> Unit {
  guard self.gateway is Some(gateway) && self.ssrc is Some(ssrc) else {
    raise VoiceError::Disconnected
  }
  gateway.send_json(encode_speaking(ssrc~, flags~))
}

///|
/// Pull the next received media or voice membership event.
pub async fn VoiceConnection::next_event(self : VoiceConnection) -> VoiceEvent {
  self.events.get()
}

///|
/// The current lifecycle state of this voice connection.
pub fn VoiceConnection::state(self : VoiceConnection) -> VoiceConnectionState {
  self.state_
}

///|
/// Latest voice gateway heartbeat round-trip in milliseconds, if measured.
pub fn VoiceConnection::latency_ms(self : VoiceConnection) -> Int64? {
  match self.gateway {
    Some(gateway) => gateway.latency_ms()
    None => None
  }
}

///|
/// Leave the Discord voice state and tear down media transports. Repeated
/// calls are harmless.
pub async fn VoiceConnection::disconnect(self : VoiceConnection) -> Unit {
  if self.disconnecting || self.closing {
    return
  }
  self.disconnecting = true
  self.terminal_teardown(notify_leave=true)
}
