///|
test "transport_failure keeps the phase and agrees on what was not sent" {
  let cases : Array[(@ghttp.TransportError, DiscordHttpError, Bool)] = [
    (
      @ghttp.TransportError(kind=Connect, phase=Dial, detail="refused"),
      Transport(phase=Dial, message="could not connect: refused"),
      true,
    ),
    (
      @ghttp.TransportError(kind=Proxy(status=407), phase=Dial, detail="auth"),
      Transport(phase=Dial, message="proxy refused the tunnel with 407: auth"),
      true,
    ),
    (
      @ghttp.TransportError(kind=Timeout(ms=5), phase=Pool, detail="timeout"),
      Timeout(phase=Pool, timeout_ms=5),
      true,
    ),
    (
      @ghttp.TransportError(kind=Timeout(ms=5), phase=Dial, detail="timeout"),
      Timeout(phase=Dial, timeout_ms=5),
      true,
    ),
    (
      @ghttp.TransportError(kind=Timeout(ms=5), phase=Write, detail="timeout"),
      Timeout(phase=Write, timeout_ms=5),
      false,
    ),
    (
      @ghttp.TransportError(kind=Timeout(ms=5), phase=Head, detail="timeout"),
      Timeout(phase=Head, timeout_ms=5),
      false,
    ),
    (
      @ghttp.TransportError(kind=Timeout(ms=5), phase=Body, detail="timeout"),
      Timeout(phase=Body, timeout_ms=5),
      false,
    ),
    (
      @ghttp.TransportError(kind=Timeout(ms=5), phase=Unknown, detail="timeout"),
      Timeout(phase=Unknown, timeout_ms=5),
      false,
    ),
    (
      @ghttp.TransportError(kind=Network, phase=Write, detail="reset"),
      Transport(phase=Write, message="reset"),
      false,
    ),
    (
      @ghttp.TransportError(kind=Network, phase=Head, detail="eof"),
      Transport(phase=Head, message="eof"),
      false,
    ),
    (
      @ghttp.TransportError(kind=Network, phase=Body, detail="eof"),
      Transport(phase=Body, message="eof"),
      false,
    ),
    (
      @ghttp.TransportError(kind=Network, phase=Unknown, detail="fetch failed"),
      Transport(phase=Unknown, message="fetch failed"),
      false,
    ),
    // The Backend contract makes Pool and Dial failures provably unsent.
    (
      @ghttp.TransportError(kind=Network, phase=Dial, detail="odd"),
      Transport(phase=Dial, message="odd"),
      true,
    ),
    (
      @ghttp.TransportError(kind=Network, phase=Pool, detail="odd"),
      Transport(phase=Pool, message="odd"),
      true,
    ),
    (
      @ghttp.TransportError(kind=Protocol, phase=Unknown, detail="garbled"),
      Transport(phase=Unknown, message="protocol error: garbled"),
      false,
    ),
  ]
  for case in cases {
    let (error, expected, unsent) = case
    let mapped = transport_failure(error)
    assert_eq(@debug.to_string(mapped), @debug.to_string(expected))
    assert_eq(mapped.is_unsent(), unsent)
    assert_eq(error.is_unsent(), unsent)
  }
}

///|
test "is_unsent holds for validation and pre-connection failures only" {
  let cases : Array[(DiscordHttpError, Bool)] = [
    (Validation(message="bad"), true),
    (Transport(phase=Pool, message="client is closed"), true),
    (Transport(phase=Dial, message="refused"), true),
    (Timeout(phase=Pool, timeout_ms=1), true),
    (Timeout(phase=Dial, timeout_ms=1), true),
    (Transport(phase=Write, message="reset"), false),
    (Transport(phase=Head, message="eof"), false),
    (Transport(phase=Body, message="eof"), false),
    (Transport(phase=Unknown, message="?"), false),
    (Timeout(phase=Write, timeout_ms=1), false),
    (Timeout(phase=Head, timeout_ms=1), false),
    (Timeout(phase=Body, timeout_ms=1), false),
    (Timeout(phase=Unknown, timeout_ms=1), false),
    (
      Api(status=400, error={ code: 50035, message: "invalid", errors: None, }),
      false,
    ),
    (RateLimited(retry_after_ms=1L, global=false), false),
    (Deserialize(message="bad"), false),
  ]
  for case in cases {
    let (error, expected) = case
    assert_eq(error.is_unsent(), expected)
  }
}
