///|
pub using @upstream {
  type Conn,
  type Message,
  type MessageKind,
  type CloseCode,
  type WebSocketError,
}

///|
/// Open a client connection; see `@upstream.connect`.
pub async fn connect(
  url : String,
  headers? : Map[@http.CaseInsensitiveString, String],
  proxy? : @http.Client,
) -> Conn {
  @upstream.connect(url, headers?, proxy?)
}

///|
/// Read the whole message, or `None` once it exceeds `max_bytes`, buffering
/// at most `max_bytes` plus one read. The rest of an oversized message is left
/// unread; close the connection after `None`.
pub async fn read_message(message : Message, max_bytes~ : Int32) -> Bytes? {
  let data = @buffer.Buffer()
  let chunk = FixedArray::make(65536, b'\x00')
  while message.read(chunk) is n && n > 0 {
    if data.length() + n > max_bytes {
      return None
    }
    for i in 0..<n {
      data.write_byte(chunk[i])
    }
  }
  Some(data.to_bytes())
}
