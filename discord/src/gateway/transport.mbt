///|
/// A complete WebSocket message received from the Gateway.
#derive(Debug)
pub(all) enum GatewayFrame {
  Text(String)
  Binary(Bytes)
}

///|
/// The seam between the shard driver and the network: implemented by the
/// real WebSocket connection in production and by an in-memory fake in tests.
pub(open) trait GatewayTransport {
  async fn recv(Self) -> GatewayFrame
  async fn send(Self, String) -> Unit
  async fn close(Self, code~ : Int32) -> Unit
  /// Interrupt pending I/O before shutdown joins the receiver. Transports
  /// with protected reads/writes must wake them here; the default is a
  /// no-op for transports whose I/O is already interrupted by cancellation.
  fn abort(Self) -> Unit = _
}

///|
impl GatewayTransport with fn abort(_) {

}

///|
/// Raised by transports when the peer closed the connection. `code` is the
/// WebSocket close code (Discord uses 4xxx application codes), `None` for
/// abnormal/transport-level termination.
#derive(Debug)
pub(all) suberror TransportClosed {
  TransportClosed(code~ : Int32?, reason~ : String)
}

///|
priv struct WsTransport {
  conn : &@ws.Session
  closed : Ref[Bool]
}

///|
/// The largest Gateway message a shard accepts by default, compressed or
/// not: far above anything Discord sends, but a bound on what one message can
/// make the process allocate.
pub const DEFAULT_MAX_MESSAGE_BYTES : Int32 = 67_108_864

///|
/// Raised for a Gateway configuration that cannot work.
#derive(Debug)
pub(all) suberror GatewayConfigError {
  /// `max_message_bytes` must be positive.
  InvalidMaxMessageBytes(value~ : Int32)
}

///|
/// Check a `max_message_bytes` setting: a limit below 1 refuses every
/// message, so the shard would reconnect forever without seeing Hello.
fn check_max_message_bytes(value : Int32) -> Unit raise GatewayConfigError {
  if value < 1 {
    raise InvalidMaxMessageBytes(value~)
  }
}

///|
impl GatewayTransport for WsTransport with fn recv(self) {
  let message = self.conn.recv() catch {
    error if @async.is_being_cancelled() => raise error
    error => raise transport_error(error)
  }
  match message {
    Text(text) => Text(text)
    Binary(data) => Binary(data)
  }
}

///|
fn transport_error(error : @ws.WsError) -> TransportClosed {
  match error {
    @core_ws.WsError(kind=Closed(frame), ..) =>
      TransportClosed(
        code=if frame.code is (Abnormal | NoStatus) {
          None
        } else {
          Some(frame.code.to_int())
        },
        reason=frame.reason,
      )
    // Preserve the portable status even when a JS host sends 4009 instead.
    @core_ws.WsError(kind=TooLarge(_), detail~) =>
      TransportClosed(code=Some(1009), reason=detail)
    _ => TransportClosed(code=None, reason="\{Repr(error)}")
  }
}

///|
impl GatewayTransport for WsTransport with fn send(self, text) {
  self.conn.send(Text(text)) catch {
    error if @async.is_being_cancelled() => raise error
    error => {
      if error is @core_ws.WsError(kind=TooLarge(_), ..) {
        GatewayTransport::close(self, code=1009)
      }
      raise transport_error(error)
    }
  }
}

///|
impl GatewayTransport for WsTransport with fn close(self, code~) {
  if self.closed.val {
    return
  }
  self.closed.val = true
  defer self.conn.abort()
  self.conn.close({ code: @ws.CloseCode::from_int(code), reason: "", })
}

///|
impl GatewayTransport for WsTransport with fn abort(self) {
  self.conn.abort()
}

///|
/// Connect to the gateway over WebSocket (the default connector). A message
/// larger than `max_message_bytes` ends the connection with local code 1009
/// (Message Too Big); JS hosts that forbid sending 1009 send 4009 instead.
/// The same bound applies to outgoing messages, and on JS to total queued
/// bytes. Discord's opcode heartbeat owns liveness; WebSocket Ping is off.
pub async fn connect_websocket(
  url : String,
  max_message_bytes~ : Int32 = DEFAULT_MAX_MESSAGE_BYTES,
) -> &GatewayTransport {
  check_max_message_bytes(max_message_bytes)
  let limits = {
    ..@ws.WsLimits::default(),
    max_frame_bytes: max_message_bytes.max(125),
    max_message_bytes,
    close_timeout_ms: 1000,
    ping_interval_ms: None,
    pong_timeout_ms: None,
  }
  let conn = @ws.connect(url, limits~)
  WsTransport::{ conn, closed: Ref(false), }
}
