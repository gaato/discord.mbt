///|
test "transport_failure keeps the phase and agrees on what was not sent" {
  let cases : Array[(@ghttp.TransportError, DiscordHttpError, Bool)] = [
    (
      wire_connect("refused"),
      Transport(phase=Dial, message="could not connect: refused"),
      true,
    ),
    (
      wire_proxy(status=407, message="auth"),
      Transport(phase=Dial, message="proxy refused the tunnel with 407: auth"),
      true,
    ),
    (wire_timeout(phase=Pool, ms=5), Timeout(phase=Pool, timeout_ms=5), true),
    (wire_timeout(phase=Dial, ms=5), Timeout(phase=Dial, timeout_ms=5), true),
    (wire_timeout(phase=Write, ms=5), Timeout(phase=Write, timeout_ms=5), false),
    (wire_timeout(phase=Head, ms=5), Timeout(phase=Head, timeout_ms=5), false),
    (wire_timeout(phase=Body, ms=5), Timeout(phase=Body, timeout_ms=5), false),
    (
      wire_timeout(phase=Unknown, ms=5),
      Timeout(phase=Unknown, timeout_ms=5),
      false,
    ),
    (
      wire_network(phase=Write, message="reset"),
      Transport(phase=Write, message="reset"),
      false,
    ),
    (
      wire_network(phase=Head, message="eof"),
      Transport(phase=Head, message="eof"),
      false,
    ),
    (
      wire_network(phase=Body, message="eof"),
      Transport(phase=Body, message="eof"),
      false,
    ),
    (
      wire_network(phase=Unknown, message="fetch failed"),
      Transport(phase=Unknown, message="fetch failed"),
      false,
    ),
    // a network failure claiming a pre-connection phase proves nothing
    (
      wire_network(phase=Dial, message="odd"),
      Transport(phase=Unknown, message="odd"),
      false,
    ),
    (
      wire_network(phase=Pool, message="odd"),
      Transport(phase=Unknown, message="odd"),
      false,
    ),
    (
      wire_protocol("garbled"),
      Transport(phase=Unknown, message="protocol error: garbled"),
      false,
    ),
    (
      @ghttp.TransportError(
        kind=TooLarge(limit=4),
        phase=Body,
        detail="body exceeds limit",
      ),
      Transport(phase=Unknown, message="body exceeds limit"),
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
