///|
pub(all) enum MessageKind {
  Binary
  Text
} derive(Debug)

///|
pub(all) enum CloseCode {
  Normal
  GoingAway
  ProtocolError
  UnsupportedData
  Abnormal
  InvalidFramePayload
  PolicyViolation
  MessageTooBig
  MissingExtension
  InternalError
  Other(UInt16)
} derive(Debug, Eq)

///|
pub suberror WebSocketError {
  ConnectionClosed(CloseCode, String?)
  InvalidHandshake(String)
  ProtocolError(String)
} derive(Debug)
