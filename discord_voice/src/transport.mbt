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
  async fn close(Self, code~ : Int32) -> Unit
}

///|
/// Raised when a voice transport is closed or cannot continue.
pub(all) suberror VoiceTransportClosed {
  VoiceTransportClosed(code~ : Int32?, reason~ : String)
} derive(Debug)

///|
priv struct VoiceWsTransport {
  conn : @websocket.Conn
  closed : Ref[Bool]
}

///|
impl VoiceTransport for VoiceWsTransport with fn recv(self) {
  let message = self.conn.recv() catch {
    error if @async.is_being_cancelled() => raise error
    @websocket.WebSocketError::ConnectionClosed(code, reason) =>
      raise VoiceTransportClosed(
        code=Some(voice_close_code_to_int(code)),
        reason=reason.unwrap_or(""),
      )
    error => raise VoiceTransportClosed(code=None, reason="\{Repr(error)}")
  }
  let data = read_bounded(chunk => message.read(chunk), MAX_VOICE_MESSAGE_BYTES) catch {
    error if @async.is_being_cancelled() => raise error
    error => raise VoiceTransportClosed(code=None, reason="\{Repr(error)}")
  }
  guard data is Some(data) else {
    // 1009: Message Too Big, sent to the peer too; the connection's own
    // close that follows is a no-op. The session survives, so it resumes.
    VoiceTransport::close(self, code=1009) catch {
      error if @async.is_being_cancelled() => raise error
      _ => ()
    }
    raise VoiceTransportClosed(
      code=Some(1009),
      reason="message larger than \{MAX_VOICE_MESSAGE_BYTES} bytes",
    )
  }
  match message.kind {
    Text =>
      Text(
        @utf8.decode(data) catch {
          error =>
            raise VoiceTransportClosed(code=None, reason="\{Repr(error)}")
        },
      )
    Binary => Binary(data)
  }
}

///|
/// The largest voice gateway message accepted: far above the JSON payloads
/// and DAVE MLS messages Discord sends, but a bound on what one message can
/// make the connection allocate.
const MAX_VOICE_MESSAGE_BYTES : Int32 = 4_194_304

///|
/// Read a message through `read` until it returns 0, or `None` as soon as it
/// grows past `max_bytes`.
async fn read_bounded(
  read : async (FixedArray[Byte]) -> Int32,
  max_bytes : Int32,
) -> Bytes? {
  let data = @buffer.Buffer()
  let chunk = FixedArray::make(65536, b'\x00')
  while read(chunk) is n && n > 0 {
    if data.length() + n > max_bytes {
      return None
    }
    for i in 0..<n {
      data.write_byte(chunk[i])
    }
  }
  Some(data.to_bytes())
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
fn voice_close_code_to_int(code : @websocket.CloseCode) -> Int32 {
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
#doc(hidden)
pub async fn connect_voice_websocket(url : String) -> &VoiceTransport {
  let conn = @websocket.connect(url)
  VoiceWsTransport::{ conn, closed: Ref(false), }
}
