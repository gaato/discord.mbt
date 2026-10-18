///|
/// Errors surfaced while joining or operating a voice connection.
pub(all) suberror VoiceError {
  /// The main Gateway session lacks an intent required by the voice
  /// handshake.
  MissingIntent(intent~ : String)
  JoinTimeout
  ShimUnavailable(reason~ : String)
  NoCompatibleMode(offered~ : Array[String])
  GatewayClosed(code~ : Int32?)
  IpDiscoveryFailed(reason~ : String)
  Disconnected
  /// A receive backlog below 2 or an event backlog below 1 was requested.
  InvalidBacklog(value~ : Int32)
  /// `VoiceClient::join` ran while the client's `run` (the service `attach`
  /// registers) was not running.
  ClientNotRunning
} derive(Debug)

///|
/// Public voice connection lifecycle.
pub(all) enum VoiceConnectionState {
  Connecting
  Ready
  Reconnecting
  Rejoining
  Closed(code~ : Int32?)
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
/// A voice server change Discord reported after the session started: the
/// token and endpoint of a VOICE_SERVER_UPDATE. A `None` endpoint means the
/// server went away and another is being allocated.
pub(all) struct VoiceServer {
  token : String
  endpoint : String?
} derive(Debug, Eq)

///|
/// A server change the event pump has yet to act on.
priv enum ServerChange {
  MoveTo(VoiceCredentials)
  Lost
}

///|
priv struct PlaybackRequest {
  generation : Int32
  source : &AudioSource
}

///|
/// Default number of unread `VoiceEvent`s a connection keeps for
/// `next_event`.
pub const DEFAULT_VOICE_EVENT_BACKLOG : Int32 = 256

///|
/// High-level owner of voice gateway, UDP media, DAVE, sender, and receiver
/// tasks. All background work is attached to the task group passed to `start`
/// and ends when the connection closes.
pub struct VoiceConnection {
  priv events : @aqueue.Queue[VoiceEvent]
  priv event_backlog : Int32
  priv playback : @aqueue.Queue[PlaybackRequest]
  priv subscriptions : Array[VoiceReceiveStream]
  priv user_id : String
  priv mut channel_id : UInt64
  priv leave_ : async () -> Unit
  priv rejoin_ : async () -> VoiceCredentials
  priv next_server_ : async () -> VoiceServer?
  priv next_channel_ : async () -> UInt64?
  priv server_timeout_ms : Int32
  priv connector_ : async (String) -> &VoiceTransport
  priv udp_opener_ : async (String, Int32) -> &VoiceUdp
  priv telemetry_ : (VoiceTelemetry) -> Unit
  priv clock_ : &@hclock.Clock
  priv rand_ : @random.Rand
  priv receiver : ReceivePipeline
  priv roster : Set[String]
  priv mut dave : DaveMachine?
  priv mut pending_dave_external_sender : Bytes?
  /// The credentials of the current gateway, and the server change the event
  /// pump acts on next.
  priv mut credentials : VoiceCredentials
  priv mut server_change : ServerChange?
  /// Broadcast after every write to the fields below, which the background
  /// tasks and `wait_ready`/`stop` wait on. Write them only through the
  /// setters next to `VoiceConnection::changed` so no change misses a waiter.
  priv state_changed : @cond_var.Cond
  priv mut gateway : VoiceGateway?
  priv mut udp : &VoiceUdp?
  priv mut cipher : TransportCipher?
  priv mut ssrc : UInt32?
  priv mut state_ : VoiceConnectionState
  priv mut failure : VoiceError?
  priv mut closing : Bool
  priv mut torn_down : Bool
  priv mut session_generation : Int32
  priv mut playback_generation : Int32
  priv mut playback_stop : Ref[Bool]?
}

///|
/// Delay before retrying after `VoiceUdp::recv` fails on the live socket.
const RECV_RETRY_DELAY_MS : Int32 = 5

///|
/// Wake every task blocked in `wait_until` so it re-checks its condition.
fn VoiceConnection::changed(self : VoiceConnection) -> Unit {
  self.state_changed.broadcast()
}

///|
/// Block until `ready` holds. The condition is re-checked after every change
/// to a watched field; cancellation unwinds the wait.
async fn VoiceConnection::wait_until(
  self : VoiceConnection,
  ready : () -> Bool,
) -> Unit noraise {
  while !ready() {
    self.state_changed.wait()
  }
}

///|
fn VoiceConnection::set_gateway(
  self : VoiceConnection,
  gateway : VoiceGateway?,
) -> Unit {
  self.gateway = gateway
  self.changed()
}

///|
fn VoiceConnection::set_udp(self : VoiceConnection, udp : &VoiceUdp?) -> Unit {
  self.udp = udp
  self.changed()
}

///|
fn VoiceConnection::set_cipher(
  self : VoiceConnection,
  cipher : TransportCipher?,
) -> Unit {
  self.cipher = cipher
  self.changed()
}

///|
fn VoiceConnection::set_ssrc(self : VoiceConnection, ssrc : UInt32?) -> Unit {
  self.ssrc = ssrc
  self.changed()
}

///|
fn VoiceConnection::set_state(
  self : VoiceConnection,
  state : VoiceConnectionState,
) -> Unit {
  self.state_ = state
  self.changed()
}

///|
fn VoiceConnection::clear_failure(self : VoiceConnection) -> Unit {
  self.failure = None
  self.changed()
}

///|
fn VoiceConnection::mark_closing(self : VoiceConnection) -> Unit {
  self.closing = true
  self.changed()
}

///|
fn VoiceConnection::mark_torn_down(self : VoiceConnection) -> Unit {
  self.torn_down = true
  self.changed()
}

///|
fn VoiceConnection::set_playback_stop(
  self : VoiceConnection,
  stop : Ref[Bool]?,
) -> Unit {
  self.playback_stop = stop
  self.changed()
}

///|
/// Invalidate packets received for the previous media session.
fn VoiceConnection::next_session_generation(self : VoiceConnection) -> Unit {
  self.session_generation += 1
  self.changed()
}

///|
/// Supersede the queued and active playback: bump the generation, ask the
/// running send loop to stop, and return the new generation.
fn VoiceConnection::supersede_playback(self : VoiceConnection) -> Int32 {
  self.playback_generation += 1
  if self.playback_stop is Some(stop) {
    stop.val = true
  }
  self.changed()
  self.playback_generation
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
  code~ : Int32?,
) -> Unit {
  if self.failure is None {
    self.failure = Some(error)
  }
  // `set_state` wakes the waiters for the failure as well.
  self.set_state(Closed(code~))
}

///|
async fn VoiceConnection::close_udp(self : VoiceConnection) -> Unit noraise {
  if self.udp is Some(udp) {
    udp.close() catch {
      _ => ()
    }
  }
  self.set_udp(None)
}

///|
async fn VoiceConnection::reset_session(self : VoiceConnection) -> Unit noraise {
  self.next_session_generation()
  self.supersede_playback() |> ignore
  self.close_udp()
  self.set_cipher(None)
  self.dave = None
  self.pending_dave_external_sender = None
  self.set_ssrc(None)
  self.receiver.reset_session()
  // A new session lists the users present again with `ClientsConnect`; a
  // disconnect lost with the old one would otherwise stay forever.
  self.roster.clear()
}

///|
/// Run `body` until it returns or the connection closes, whichever comes
/// first: a background task this wraps cannot outlive the connection, however
/// long it waits on a source, a timer, or the main gateway.
async fn VoiceConnection::while_open(
  self : VoiceConnection,
  body : async () -> Unit noraise,
) -> Unit noraise {
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, () => {
      self.wait_until(() => self.closing)
      group.return_immediately(())
    })
    body()
  }) catch {
    _ => ()
  }
}

///|
/// Tear the connection down once. A later call waits for that teardown to
/// finish, so whoever learns the connection is gone also knows its leave has
/// been sent.
async fn VoiceConnection::terminal_teardown(
  self : VoiceConnection,
  notify_leave~ : Bool,
) -> Unit noraise {
  if self.closing {
    self.wait_until(() => self.torn_down)
    return
  }
  // Publish the terminal flag before any await so every worker stops even if
  // one of the best-effort transport cleanups stalls or fails.
  self.mark_closing()
  defer self.mark_torn_down()
  if !(self.state_ is Closed(..)) {
    self.set_state(Closed(code=None))
  }
  self.supersede_playback() |> ignore
  if notify_leave {
    (self.leave_)() catch {
      _ => ()
    }
  }
  if self.gateway is Some(gateway) {
    gateway.close()
  }
  self.set_gateway(None)
  self.close_udp()
  self.close_subscriptions()
  self.playback.close(error=VoiceError::Disconnected)
  self.events.close(error=VoiceError::Disconnected)
}

///|
async fn VoiceConnection::select_protocol(
  self : VoiceConnection,
  ssrc : UInt32,
  ip : String,
  port : Int32,
  modes : Array[String],
) -> (String, Int32, String) {
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
  let discovered = discover_external_address(udp, ssrc, clock=self.clock_) catch {
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
  self.set_udp(Some(udp))
  self.set_ssrc(Some(ssrc))
  self.next_session_generation()
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
    clock=self.clock_,
    rand=self.rand_,
  )
}

///|
/// Start a gateway for `credentials` and make it the current one.
fn[X] VoiceConnection::switch_gateway(
  self : VoiceConnection,
  group : @async.TaskGroup[X],
  credentials : VoiceCredentials,
) -> VoiceGateway {
  let gateway = self.new_gateway(group, credentials)
  self.credentials = credentials
  self.set_gateway(Some(gateway))
  gateway
}

///|
/// Ask the main gateway for a fresh session and connect to it. `None` when
/// that fails, which closes the connection, or when it closed meanwhile.
async fn[X] VoiceConnection::rejoin_session(
  self : VoiceConnection,
  group : @async.TaskGroup[X],
) -> VoiceGateway? noraise {
  self.set_state(Rejoining)
  self.reset_session()
  let credentials = (self.rejoin_)() catch {
    _ => {
      self.set_failure(Disconnected, code=None)
      return None
    }
  }
  if self.closing {
    return None
  }
  // The rejoin's server is newer than any change reported meanwhile.
  self.server_change = None
  Some(self.connect_to(group, credentials))
}

///|
/// Connect a new session to `credentials`, replacing the current gateway.
fn[X] VoiceConnection::connect_to(
  self : VoiceConnection,
  group : @async.TaskGroup[X],
  credentials : VoiceCredentials,
) -> VoiceGateway {
  self.set_state(Connecting)
  self.switch_gateway(group, credentials)
}

///|
/// Follow a server change. Closing the current gateway wakes the event pump,
/// the one task that replaces gateways: for a new server it identifies there
/// with the session it already has; for one that went away it waits for the
/// next, as Discord asks, instead of resuming against the old one.
async fn VoiceConnection::follow_server(
  self : VoiceConnection,
  server : VoiceServer,
) -> Unit noraise {
  self.server_change = Some(
    match server.endpoint {
      Some(endpoint) =>
        MoveTo({ ..self.credentials, token: server.token, endpoint, })
      None => Lost
    },
  )
  self.changed()
  if self.gateway is Some(gateway) {
    gateway.close()
  }
}

///|
/// Wait without a voice server for Discord to name the next one, for at most
/// `server_timeout_ms`, and connect to it; rejoin when none came. `None` when
/// the connection closed or the rejoin failed.
async fn[X] VoiceConnection::replace_lost_server(
  self : VoiceConnection,
  group : @async.TaskGroup[X],
) -> VoiceGateway? noraise {
  self.set_state(Reconnecting)
  self.set_gateway(None)
  let moved = () => self.server_change is Some(MoveTo(_))
  let _ = @transport.with_timeout_opt(self.clock_, self.server_timeout_ms, () => {
    self.wait_until(() => self.closing || moved())
  }) catch {
    _ => None
  }
  if self.closing {
    return None
  }
  if self.server_change is Some(MoveTo(credentials)) {
    self.server_change = None
    return Some(self.connect_to(group, credentials))
  }
  // No server in time: ask the main gateway for one.
  self.rejoin_session(group)
}

///|
/// Apply each value `next` reports until it reports none or fails.
async fn[T] watch_updates(
  next : async () -> T?,
  apply : async (T) -> Unit noraise,
) -> Unit noraise {
  for ;; {
    let update = next() catch { _ => return }
    guard update is Some(update) else { return }
    apply(update)
  }
}

///|
/// Queue an event for `next_event`. The queue discards its oldest entry when
/// full, so a connection whose events nobody reads stays bounded.
async fn VoiceConnection::emit(
  self : VoiceConnection,
  event : VoiceEvent,
) -> Unit {
  if !self.events.try_put(event) {
    (self.telemetry_)(EventDropped(backlog=self.event_backlog))
    self.events.put(event)
  }
}

///|
fn VoiceConnection::is_subscribed(
  self : VoiceConnection,
  user_id : String,
) -> Bool {
  self.subscriptions.iter().any(stream => stream.user_id == user_id)
}

///|
fn VoiceConnection::deliver_audio(
  self : VoiceConnection,
  user_id : String,
  audio : ReceivedAudio,
) -> Unit {
  for subscription in self.subscriptions.copy() {
    if subscription.user_id == user_id {
      subscription.deliver(audio) catch {
        _ => self.remove_subscription(subscription)
      }
    }
  }
}

///|
async fn VoiceConnection::establish_session(
  self : VoiceConnection,
  mode_name : String,
  secret_key : Bytes,
  dave_protocol_version : Int32,
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
  if dave_session_version(
      dave_protocol_version,
      @dave.max_supported_protocol_version().to_int(),
    )
    is Some(session_protocol_version) {
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
  self.set_cipher(Some(cipher))
  self.dave = dave
  self.clear_failure()
  self.set_state(Ready)
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
  gateway : VoiceGateway,
) -> Unit noraise {
  defer self.terminal_teardown(notify_leave=true)
  // The pump is the only task that replaces the gateway, and terminal
  // teardown is the only one that clears it, so it follows its own handle
  // instead of waiting on `self.gateway`.
  let mut gateway = gateway
  while !self.closing {
    let event = gateway.next() catch {
      _ => {
        if !self.closing {
          self.set_failure(Disconnected, code=None)
          self.reset_session()
        }
        return
      }
    }
    // `follow_server` closed the old gateway, so its remaining events are
    // moot.
    if self.server_change is Some(change) && !self.closing {
      self.server_change = None
      self.reset_session()
      match change {
        MoveTo(credentials) => gateway = self.connect_to(group, credentials)
        Lost => {
          guard self.replace_lost_server(group) is Some(replaced) else {
            return
          }
          gateway = replaced
        }
      }
      continue
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
        self.set_state(Ready)
        self.emit(ConnectionResumed) catch {
          _ => return
        }
      }
      Connected(resumed=false) | ReadyReceived => ()
      ConnectFailed(..) => ()
      Disconnected(code~, resuming=true) => {
        ignore(code)
        self.set_state(Reconnecting)
      }
      Disconnected(..) => ()
      NeedsRejoin(code~) => {
        ignore(code)
        if self.failure is Some(_) {
          self.reset_session()
          return
        }
        guard self.rejoin_session(group) is Some(rejoined) else { return }
        gateway = rejoined
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
    self.wait_until(() => {
      self.closing || (self.udp is Some(_) && self.cipher is Some(_))
    })
    guard self.udp is Some(udp) && self.cipher is Some(cipher) else { continue }
    let generation = self.session_generation
    let received = udp.recv(buffer) catch {
      _ => {
        // A failure on the socket still in use is an I/O error worth backing
        // off from; one caused by a session reset just waits for the next.
        // A close cancels the receiver, during this wait at the latest.
        if generation == self.session_generation {
          self.clock_.sleep(RECV_RETRY_DELAY_MS)
        }
        continue
      }
    }
    if generation != self.session_generation || received <= 0 {
      continue
    }
    let datagram = Bytes::from_array(buffer[:received])
    let delivered = self.receiver.process_udp_packet(
      datagram,
      cipher,
      self.dave,
      arrival_ms=self.clock_.now_unix_ms(),
      wants=user_id => self.is_subscribed(user_id),
    )
    for item in delivered {
      let (user_id, audio) = item
      self.deliver_audio(user_id, audio)
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
    self.clock_.sleep(5000)
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
    // A superseded or closed request falls through the wait to the guard.
    self.wait_until(() => {
      self.closing ||
      request.generation != self.playback_generation ||
      (
        self.cipher is Some(_) &&
        self.udp is Some(_) &&
        self.gateway is Some(_) &&
        self.ssrc is Some(_)
      )
    })
    guard !self.closing &&
      request.generation == self.playback_generation &&
      self.cipher is Some(cipher) &&
      self.udp is Some(udp) &&
      self.gateway is Some(gateway) &&
      self.ssrc is Some(ssrc) else {
      continue
    }
    let stop = Ref(false)
    self.set_playback_stop(Some(stop))
    run_send_loop(
      request.source,
      cipher,
      udp,
      gateway,
      ssrc~,
      stop~,
      dave?=self.dave,
      on_dave_error=reason => (self.telemetry_)(DaveEncryptDropped(reason~)),
      clock=self.clock_,
    ) catch {
      error =>
        (self.telemetry_)(PacketDropped(reason="send loop: \{Repr(error)}"))
    }
    self.set_playback_stop(None)
  }
}

///|
/// Start a voice connection and attach all of its tasks to `group`; they end
/// when the connection closes. `clock`
/// times everything the connection waits for: the gateway heartbeat and
/// reconnect backoff, UDP keepalives, playback pacing, receive backoff and
/// reordering, `wait_ready`, and subscription silence.
///
/// `next_server` waits for the next server change (a later
/// VOICE_SERVER_UPDATE for the guild) and returns `None` when there will be
/// none. On a new endpoint the connection identifies there with the same
/// session; on a null one it drops the current server and waits up to
/// `server_timeout_ms` for the next, then calls `rejoin`. `next_channel` waits
/// for the channel the bot's own VOICE_STATE_UPDATE puts it in, which DAVE
/// uses from the next session on. Each is called again after every update, in
/// a task that ends with the connection, so whatever it registers to wait
/// should be released when the call is cancelled.
pub fn[X] VoiceConnection::start(
  group : @async.TaskGroup[X],
  credentials : VoiceCredentials,
  user_id~ : String,
  channel_id~ : UInt64,
  leave~ : async () -> Unit,
  rejoin~ : async () -> VoiceCredentials,
  next_server~ : async () -> VoiceServer? = () => None,
  next_channel~ : async () -> UInt64? = () => None,
  server_timeout_ms~ : Int32 = 10000,
  connector~ : async (String) -> &VoiceTransport = connect_voice_websocket,
  udp_opener~ : async (String, Int32) -> &VoiceUdp = open_voice_udp,
  receive~ : Bool = true,
  event_backlog~ : Int32 = DEFAULT_VOICE_EVENT_BACKLOG,
  telemetry~ : (VoiceTelemetry) -> Unit = _ => (),
  clock~ : &@hclock.Clock = @transport.AsyncClock::new(),
  rand~ : @random.Rand = @random.Rand(),
) -> VoiceConnection raise VoiceError {
  if event_backlog < 1 {
    raise InvalidBacklog(value=event_backlog)
  }
  let receiver = ReceivePipeline::new(telemetry)
  let connection = VoiceConnection::{
    events: Queue(kind=DiscardOldest(event_backlog)),
    event_backlog,
    // Only the newest request matters: `play` supersedes earlier sources.
    playback: Queue(kind=DiscardOldest(1)),
    subscriptions: [],
    user_id,
    channel_id,
    leave_: leave,
    rejoin_: rejoin,
    next_server_: next_server,
    next_channel_: next_channel,
    server_timeout_ms,
    connector_: connector,
    udp_opener_: udp_opener,
    telemetry_: telemetry,
    clock_: clock,
    rand_: rand,
    receiver,
    roster: Set([]),
    state_changed: @cond_var.Cond(),
    gateway: None,
    udp: None,
    cipher: None,
    dave: None,
    pending_dave_external_sender: None,
    credentials,
    server_change: None,
    ssrc: None,
    state_: Connecting,
    failure: None,
    closing: false,
    torn_down: false,
    session_generation: 0,
    playback_generation: 0,
    playback_stop: None,
  }
  let gateway = connection.switch_gateway(group, credentials)
  // The pump runs the teardown itself; every other task is cut off by it.
  group.spawn_bg(no_wait=true, () => connection.run_event_pump(group, gateway))
  let workers : Array[async () -> Unit noraise] = []
  if receive {
    workers.push(() => connection.run_receiver())
  }
  workers.push(() => connection.run_keepalive())
  workers.push(() => connection.run_playback())
  workers.push(() => {
    watch_updates(connection.next_server_, server => {
      connection.follow_server(server)
    })
  })
  workers.push(() => {
    watch_updates(connection.next_channel_, channel_id => {
      connection.channel_id = channel_id
    })
  })
  for worker in workers {
    group.spawn_bg(no_wait=true, () => connection.while_open(worker))
  }
  connection
}

///|
/// Wait until the current connection handshake reaches `Ready`.
pub async fn VoiceConnection::wait_ready(
  self : VoiceConnection,
  timeout_ms~ : Int32 = 10000,
) -> Unit raise VoiceError {
  let settled = @transport.with_timeout_opt(self.clock_, timeout_ms, () => {
    self.wait_until(() => {
      self.state_ is Ready || self.failure is Some(_) || self.closing
    })
  }) catch {
    _ => raise Disconnected
  }
  guard settled is Some(_) else { raise JoinTimeout }
  if self.state_ is Ready {
    return
  }
  if self.failure is Some(error) {
    raise error
  }
  raise Disconnected
}

///|
/// Replace the current source. The old sender is asked to stop and flush its
/// five silence frames before the latest source begins.
pub async fn VoiceConnection::play(
  self : VoiceConnection,
  source : &AudioSource,
) -> Unit {
  let generation = self.supersede_playback()
  self.playback.put({ generation, source, })
}

///|
/// Stop the active source; the send loop emits five silence frames and clears
/// the speaking flag.
pub async fn VoiceConnection::stop(self : VoiceConnection) -> Unit {
  self.supersede_playback() |> ignore
  self.wait_until(() => self.playback_stop is None || self.closing)
}

///|
/// Send a Speaking (opcode 5) frame with the given flag bits. The playback
/// loop manages this automatically; call it directly only for custom
/// speaking indicators.
pub async fn VoiceConnection::set_speaking(
  self : VoiceConnection,
  flags : Int32,
) -> Unit {
  guard self.gateway is Some(gateway) && self.ssrc is Some(ssrc) else {
    raise VoiceError::Disconnected
  }
  gateway.send_json(encode_speaking(ssrc~, flags~))
}

///|
/// Pull the next membership or lifecycle event. At most `event_backlog`
/// unread events are kept; older ones are discarded first. Received audio is
/// read through `subscribe`.
pub async fn VoiceConnection::next_event(self : VoiceConnection) -> VoiceEvent {
  self.events.get()
}

///|
/// The voice channel the bot is in, following moves made outside this API.
pub fn VoiceConnection::channel_id(self : VoiceConnection) -> UInt64 {
  self.channel_id
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
/// Leave the Discord voice state and tear down media transports, returning
/// once that is done. Repeated and concurrent calls wait for the same
/// teardown, including one the connection started itself after a fatal close.
pub async fn VoiceConnection::disconnect(self : VoiceConnection) -> Unit {
  self.terminal_teardown(notify_leave=true)
}
