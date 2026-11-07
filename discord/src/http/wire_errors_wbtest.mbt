///|
fn wire_connect(message : String) -> @ghttp.TransportError {
  @ghttp.TransportError(kind=Connect, phase=Dial, detail=message)
}

///|
fn wire_proxy(status~ : Int32, message~ : String) -> @ghttp.TransportError {
  @ghttp.TransportError(kind=Proxy(status~), phase=Dial, detail=message)
}

///|
fn wire_network(
  phase~ : @ghttp.Phase,
  message~ : String,
) -> @ghttp.TransportError {
  @ghttp.TransportError(kind=Network, phase~, detail=message)
}

///|
fn wire_protocol(message : String) -> @ghttp.TransportError {
  @ghttp.TransportError(kind=Protocol, phase=Unknown, detail=message)
}

///|
fn wire_timeout(phase~ : @ghttp.Phase, ms~ : Int32) -> @ghttp.TransportError {
  @ghttp.TransportError(kind=Timeout(ms~), phase~, detail="test timeout")
}
