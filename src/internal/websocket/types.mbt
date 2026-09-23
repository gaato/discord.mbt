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
fn CloseCode::from_int(code : Int) -> CloseCode {
  match code {
    1000 => Normal
    1001 => GoingAway
    1002 => ProtocolError
    1003 => UnsupportedData
    1006 => Abnormal
    1007 => InvalidFramePayload
    1008 => PolicyViolation
    1009 => MessageTooBig
    1010 => MissingExtension
    1011 => InternalError
    _ => Other(code.to_uint16())
  }
}

///|
fn CloseCode::to_int(self : CloseCode) -> Int {
  match self {
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
    Other(code) => code.to_int()
  }
}

///|
pub suberror WebSocketError {
  ConnectionClosed(CloseCode, String?)
  InvalidHandshake(String)
  ProtocolError(String)
} derive(Debug)
