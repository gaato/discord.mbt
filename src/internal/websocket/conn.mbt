///|
struct Conn {
  handle : WsHandle
  mut closed : WebSocketError?
  mut pending : (MessageKind, @buffer.Buffer)?
}

///|
priv enum Payload {
  Text(String)
  Binary(Bytes)
}

///|
pub struct Message {
  kind : MessageKind
  priv payload : Payload
}

///|
/// The whole message. Text is returned as a `String`, binary as `Bytes`.
#warnings("-unused_async")
pub async fn Message::read_all(self : Message) -> &@io.Data {
  match self.payload {
    Text(text) => utf8_encode(text)
    Binary(data) => data
  }
}

///|
/// Open a client connection with the platform `WebSocket` API. Custom
/// headers cannot be set by that API, so a non-empty `headers` raises
/// `InvalidHandshake`.
pub async fn connect(
  url : String,
  headers? : Map[@http.CaseInsensitiveString, String] = Map([]),
) -> Conn {
  if !headers.is_empty() {
    raise WebSocketError::InvalidHandshake("custom headers are unsupported")
  }
  let controller = @js_async.AbortController::new()
  let handle = ws_open(url, controller.signal()).wait(
    abort_controller=controller,
  ) catch {
    error => raise WebSocketError::InvalidHandshake("\{error}")
  }
  { handle, closed: None, pending: None, }
}

///|
pub async fn Conn::recv(self : Conn) -> Message {
  if self.closed is Some(error) {
    raise error
  }
  let controller = @js_async.AbortController::new()
  let event = ws_next(self.handle, controller.signal()).wait(
    abort_controller=controller,
  ) catch {
    error if "\{error}".contains("concurrent recv") =>
      raise WebSocketError::ProtocolError("concurrent recv")
    error => raise error
  }
  match event.kind {
    0 => { kind: Text, payload: Text(event.text), }
    1 => { kind: Binary, payload: Binary(event.data), }
    2 => {
      let reason = if event.reason == "" { None } else { Some(event.reason) }
      let error = WebSocketError::ConnectionClosed(
        CloseCode::from_int(event.code),
        reason,
      )
      self.closed = Some(error)
      raise error
    }
    _ => raise WebSocketError::ProtocolError("unsupported message payload")
  }
}

///|
#warnings("-unused_async")
pub async fn Conn::send_text(self : Conn, text : StringView) -> Unit {
  if self.closed is Some(error) {
    raise error
  }
  if ws_ready_state(self.handle) != 1 {
    raise WebSocketError::ProtocolError("socket is not open")
  }
  let result = ws_send_text(self.handle, text.to_owned())
  if result != "" {
    raise WebSocketError::ProtocolError(result)
  }
}

///|
#warnings("-unused_async")
pub async fn Conn::send_binary(self : Conn, data : BytesView) -> Unit {
  if self.closed is Some(error) {
    raise error
  }
  if ws_ready_state(self.handle) != 1 {
    raise WebSocketError::ProtocolError("socket is not open")
  }
  let result = ws_send_binary(self.handle, data.to_owned())
  if result != "" {
    raise WebSocketError::ProtocolError(result)
  }
}

///|
/// Begin a streamed message; `write` appends to it and `end_message` sends
/// it as one frame. An unfinished message is discarded.
pub fn Conn::start_message(self : Conn, kind : MessageKind) -> Unit {
  self.pending = Some((kind, @buffer.Buffer()))
}

///|
#warnings("-unused_async")
pub impl @io.Writer for Conn with fn write_once(self, buf, offset~, len~) {
  guard self.pending is Some((_, pending)) else {
    raise WebSocketError::ProtocolError("no message started")
  }
  pending.write_bytes(buf[offset:offset + len])
  len
}

///|
pub extend Conn with @io.Writer::{write, write_reader}

///|
pub async fn Conn::end_message(self : Conn) -> Unit {
  guard self.pending is Some((kind, pending)) else {
    raise WebSocketError::ProtocolError("no message started")
  }
  let data = pending.to_bytes()
  match kind {
    Text => {
      let text = @utf8.decode(data) catch {
        _ => raise WebSocketError::ProtocolError("invalid UTF-8 text")
      }
      self.send_text(text)
    }
    Binary => self.send_binary(data)
  }
  self.pending = None
}

///|
#warnings("-unused_async")
pub async fn Conn::send_close(
  self : Conn,
  code? : CloseCode,
  reason? : String,
) -> Unit {
  if self.closed is Some(error) {
    raise error
  }
  let code = code.unwrap_or(Normal)
  self.closed = Some(WebSocketError::ConnectionClosed(code, reason))
  ws_close(self.handle, code.to_int(), reason.unwrap_or(""))
}

///|
pub fn Conn::close(self : Conn) -> Unit {
  if self.closed is None {
    self.closed = Some(WebSocketError::ConnectionClosed(Normal, None))
    ws_close(self.handle, -1, "")
  }
}
