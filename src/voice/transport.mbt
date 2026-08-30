///|
/// A complete WebSocket message received from the voice gateway.
pub(all) enum VoiceFrame {
  Text(String)
  Binary(Bytes)
} derive(Debug, Eq)

///|
/// The network seam used by `VoiceGateway`. Tests can provide an in-memory
/// implementation without opening a WebSocket.
pub(open) trait VoiceTransport {
  async fn recv(Self) -> VoiceFrame
  async fn send_text(Self, String) -> Unit
  async fn send_binary(Self, Bytes) -> Unit
  async fn close(Self, code~ : Int) -> Unit
}

///|
/// Raised when a voice transport is closed or cannot continue.
pub(all) suberror VoiceTransportClosed {
  VoiceTransportClosed(code~ : Int?, reason~ : String)
} derive(Debug)

///|
priv struct VoiceWsTransport {
  conn : @websocket.Conn
  closed : Ref[Bool]
}

///|
impl VoiceTransport for VoiceWsTransport with fn recv(self) {
  let message = self.conn.recv() catch {
    error if @async.is_being_cancelled() || @async.is_cancellation_error(error) =>
      raise error
    @websocket.WebSocketError::ConnectionClosed(code, reason) =>
      raise VoiceTransportClosed(
        code=Some(voice_close_code_to_int(code)),
        reason=reason.unwrap_or(""),
      )
    error => raise VoiceTransportClosed(code=None, reason="\{error}")
  }
  let data = message.read_all() catch {
    error if @async.is_being_cancelled() || @async.is_cancellation_error(error) =>
      raise error
    error => raise VoiceTransportClosed(code=None, reason="\{error}")
  }
  match message.kind {
    Text =>
      Text(
        data.text() catch {
          error if @async.is_being_cancelled() ||
            @async.is_cancellation_error(error) => raise error
          error => raise VoiceTransportClosed(code=None, reason="\{error}")
        },
      )
    Binary => Binary(data.binary())
  }
}

///|
impl VoiceTransport for VoiceWsTransport with fn send_text(self, text) {
  self.conn.send_text(text)
}

///|
impl VoiceTransport for VoiceWsTransport with fn send_binary(self, bytes) {
  self.conn.send_binary(bytes)
}

///|
impl VoiceTransport for VoiceWsTransport with fn close(self, code~) {
  if self.closed.val {
    return
  }
  self.closed.val = true
  // A close frame does not close the underlying stream. Always finish with a
  // hard close, including timeout, I/O failure, and task cancellation paths.
  defer self.conn.close()
  let ws_code : @websocket.CloseCode = match code {
    1000 => Normal
    1001 => GoingAway
    other => Other(other.to_uint16())
  }
  @async.with_timeout(1000, () => self.conn.send_close(code=ws_code))
}

///|
fn voice_close_code_to_int(code : @websocket.CloseCode) -> Int {
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
    Other(value) => value.to_int()
  }
}

///|
/// Connect to a voice-gateway WebSocket. The caller supplies the complete
/// v8 URL, normally `wss://<endpoint>?v=8`.
pub async fn connect_voice_websocket(url : String) -> &VoiceTransport {
  let conn = @websocket.connect(url)
  VoiceWsTransport::{ conn, closed: Ref(false), }
}
