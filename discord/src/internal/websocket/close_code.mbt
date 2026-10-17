///|
/// The numeric WebSocket close code. Functions rather than methods because
/// native and Wasm re-export the upstream `CloseCode`, whose conversions are
/// private.
pub fn close_code_to_int(code : CloseCode) -> Int32 {
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
    Other(code) => code.to_int()
  }
}

///|
pub fn close_code_from_int(code : Int32) -> CloseCode {
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
