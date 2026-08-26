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
  async fn close(Self, code~ : Int) -> Unit
}

///|
/// Raised by transports when the peer closed the connection. `code` is the
/// WebSocket close code (Discord uses 4xxx application codes), `None` for
/// abnormal/transport-level termination.
pub(all) suberror TransportClosed {
  TransportClosed(code~ : Int?, reason~ : String)
} derive(Debug)

///|
priv struct WsTransport {
  conn : @websocket.Conn
  closed : Ref[Bool]
}

///|
impl GatewayTransport for WsTransport with fn recv(self) {
  let message = self.conn.recv() catch {
    error if @async.is_being_cancelled() || @async.is_cancellation_error(error) =>
      raise error
    @websocket.WebSocketError::ConnectionClosed(code, reason) =>
      raise TransportClosed(
        code=Some(close_code_to_int(code)),
        reason=reason.unwrap_or(""),
      )
    e => raise TransportClosed(code=None, reason="\{e}")
  }
  let data = message.read_all() catch {
    error if @async.is_being_cancelled() || @async.is_cancellation_error(error) =>
      raise error
    e => raise TransportClosed(code=None, reason="\{e}")
  }
  match message.kind {
    Text =>
      Text(
        data.text() catch {
          error if @async.is_being_cancelled() ||
            @async.is_cancellation_error(error) => raise error
          e => raise TransportClosed(code=None, reason="\{e}")
        },
      )
    Binary => Binary(data.binary())
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
  let ws_code : @websocket.CloseCode = match code {
    1000 => Normal
    1001 => GoingAway
    other => Other(other.to_uint16())
  }
  @async.with_timeout(1000, () => self.conn.send_close(code=ws_code))
}

///|
fn close_code_to_int(code : @websocket.CloseCode) -> Int {
  match code {
    Normal => 1000
    GoingAway => 1001
    ProtocolError => 1002
    UnsupportedData => 1003
    Abnormal => 1006
    InvalidFramePayload => 1007
    PolicyViolation => 1008
    MessageTooBig => 1009
    MissingExtension => 1010
    InternalError => 1011
    Other(v) => v.to_int()
  }
}

///|
/// Connect to the gateway over WebSocket (the default connector).
pub async fn connect_websocket(url : String) -> &GatewayTransport {
  let conn = @websocket.connect(url)
  WsTransport::{ conn, closed: Ref(false) }
}
