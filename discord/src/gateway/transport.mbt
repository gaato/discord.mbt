///|
/// A complete WebSocket message received from the Gateway.
pub(all) enum GatewayFrame {
  Text(String)
  Binary(Bytes)
} derive(Debug)

///|
/// The seam between the shard driver and the network: implemented by the
/// real WebSocket connection in production and by an in-memory fake in tests.
pub(open) trait GatewayTransport {
  async fn recv(Self) -> GatewayFrame
  async fn send(Self, String) -> Unit
  async fn close(Self, code~ : Int32) -> Unit
}

///|
/// Raised by transports when the peer closed the connection. `code` is the
/// WebSocket close code (Discord uses 4xxx application codes), `None` for
/// abnormal/transport-level termination.
pub(all) suberror TransportClosed {
  TransportClosed(code~ : Int32?, reason~ : String)
} derive(Debug)

///|
priv struct WsTransport {
  conn : @websocket.Conn
  closed : Ref[Bool]
  max_message_bytes : Int32
}

///|
/// The largest Gateway message a shard accepts by default, compressed or
/// not: far above anything Discord sends, but a bound on what one message can
/// make the process allocate.
pub const DEFAULT_MAX_MESSAGE_BYTES : Int32 = 67_108_864

///|
impl GatewayTransport for WsTransport with fn recv(self) {
  let message = self.conn.recv() catch {
    error if @async.is_being_cancelled() => raise error
    @websocket.WebSocketError::ConnectionClosed(code, reason) =>
      raise TransportClosed(
        code=Some(@websocket.close_code_to_int(code)),
        reason=reason.unwrap_or(""),
      )
    e => raise TransportClosed(code=None, reason="\{Repr(e)}")
  }
  let data = @websocket.read_message(message, max_bytes=self.max_message_bytes) catch {
    error if @async.is_being_cancelled() => raise error
    e => raise TransportClosed(code=None, reason="\{Repr(e)}")
  }
  guard data is Some(data) else {
    // 1009: Message Too Big, sent to the peer too; the shard's own close
    // that follows is a no-op. The session survives, so the shard resumes.
    GatewayTransport::close(self, code=1009) catch {
      error if @async.is_being_cancelled() => raise error
      _ => ()
    }
    raise TransportClosed(
      code=Some(1009),
      reason="message larger than \{self.max_message_bytes} bytes",
    )
  }
  match message.kind {
    Text =>
      Text(
        @utf8.decode(data) catch {
          e => raise TransportClosed(code=None, reason="\{Repr(e)}")
        },
      )
    Binary => Binary(data)
  }
}

///|
impl GatewayTransport for WsTransport with fn send(self, text) {
  self.conn.send_text(text)
}

///|
impl GatewayTransport for WsTransport with fn close(self, code~) {
  if self.closed.val {
    return
  }
  self.closed.val = true
  // `send_close` only writes the WebSocket close frame. The underlying
  // transport must be closed even when that write fails or is cancelled.
  defer self.conn.close()
  @async.with_timeout(1000, () => {
    self.conn.send_close(code=@websocket.close_code_from_int(code))
  })
}

///|
/// Connect to the gateway over WebSocket (the default connector). A message
/// larger than `max_message_bytes` ends the connection with code 1009.
pub async fn connect_websocket(
  url : String,
  max_message_bytes~ : Int32 = DEFAULT_MAX_MESSAGE_BYTES,
) -> &GatewayTransport {
  let conn = @websocket.connect(url)
  WsTransport::{ conn, closed: Ref(false), max_message_bytes, }
}
