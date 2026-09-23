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
