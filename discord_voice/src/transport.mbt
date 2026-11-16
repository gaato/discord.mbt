///|
/// A complete WebSocket message received from the voice gateway.
#derive(Debug, Eq)
pub(all) enum VoiceFrame {
  Text(String)
  Binary(Bytes)
}

///|
/// The network seam used by `VoiceGateway`. Tests can provide an in-memory
/// implementation without opening a WebSocket.
pub(open) trait VoiceTransport {
  async fn recv(Self) -> VoiceFrame
  async fn send_text(Self, String) -> Unit
  async fn send_binary(Self, Bytes) -> Unit
  async fn close(Self, code~ : Int32) -> Unit
  /// Interrupt pending I/O before shutdown joins the receiver. Transports
  /// with protected reads/writes must wake them here; the default is a
  /// no-op for transports whose I/O is already interrupted by cancellation.
  fn abort(Self) -> Unit = _
}

///|
impl VoiceTransport with fn abort(_) {

}

///|
/// Raised when a voice transport is closed or cannot continue.
#derive(Debug)
pub(all) suberror VoiceTransportClosed {
  VoiceTransportClosed(code~ : Int32?, reason~ : String)
}

///|
priv struct VoiceWsTransport {
  conn : &@ws.Session
  closed : Ref[Bool]
}

///|
impl VoiceTransport for VoiceWsTransport with fn recv(self) {
  let message = self.conn.recv() catch {
    error if @async.is_being_cancelled() => raise error
    error => raise voice_transport_error(error)
  }
  match message {
    Text(text) => Text(text)
    Binary(data) => Binary(data)
  }
}

///|
/// The largest voice gateway message, incoming or outgoing: far above the
/// JSON payloads and DAVE MLS messages Discord sends, but a bound on what
/// one message can make the connection allocate.
const MAX_VOICE_MESSAGE_BYTES : Int32 = 4_194_304

///|
fn voice_transport_error(error : @ws.WsError) -> VoiceTransportClosed {
  match error {
    @core_ws.WsError(kind=Closed(frame), ..) =>
      VoiceTransportClosed(
        code=if frame.code is (Abnormal | NoStatus) {
          None
        } else {
          Some(frame.code.to_int())
        },
        reason=frame.reason,
      )
    @core_ws.WsError(kind=TooLarge(_), detail~) =>
      VoiceTransportClosed(code=Some(1009), reason=detail)
    _ => VoiceTransportClosed(code=None, reason="\{Repr(error)}")
  }
}

///|
impl VoiceTransport for VoiceWsTransport with fn send_text(self, text) {
  self.conn.send(Text(text)) catch {
    error if @async.is_being_cancelled() => raise error
    error => {
      if error is @core_ws.WsError(kind=TooLarge(_), ..) {
        VoiceTransport::close(self, code=1009)
      }
      raise voice_transport_error(error)
    }
  }
}

///|
impl VoiceTransport for VoiceWsTransport with fn send_binary(self, bytes) {
  self.conn.send(Binary(bytes)) catch {
    error if @async.is_being_cancelled() => raise error
    error => {
      if error is @core_ws.WsError(kind=TooLarge(_), ..) {
        VoiceTransport::close(self, code=1009)
      }
      raise voice_transport_error(error)
    }
  }
}

///|
impl VoiceTransport for VoiceWsTransport with fn close(self, code~) {
  if self.closed.val {
    return
  }
  self.closed.val = true
  defer self.conn.abort()
  self.conn.close({ code: @ws.CloseCode::from_int(code), reason: "", })
}

///|
impl VoiceTransport for VoiceWsTransport with fn abort(self) {
  self.conn.abort()
}

///|
/// Connect to a voice-gateway WebSocket. The caller supplies the complete
/// v8 URL, normally `wss://<endpoint>?v=8`.
#doc(hidden)
pub async fn connect_voice_websocket(url : String) -> &VoiceTransport {
  let limits = {
    ..@ws.WsLimits::default(),
    max_frame_bytes: MAX_VOICE_MESSAGE_BYTES,
    max_message_bytes: MAX_VOICE_MESSAGE_BYTES,
    close_timeout_ms: 1000,
    ping_interval_ms: None,
    pong_timeout_ms: None,
  }
  let conn = @ws.connect(url, limits~)
  VoiceWsTransport::{ conn, closed: Ref(false), }
}
