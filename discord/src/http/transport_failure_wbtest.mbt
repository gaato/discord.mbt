///|
test "transport_failure keeps the phase and agrees on what was not sent" {
  let cases : Array[(@ghttp.HttpError, DiscordHttpError, Bool)] = [
    (
      Connect("refused"),
      Transport(phase=Dial, message="could not connect: refused"),
      true,
    ),
    (
      Proxy(status=407, message="auth"),
      Transport(phase=Dial, message="proxy refused the tunnel with 407: auth"),
      true,
    ),
    (Timeout(phase=Pool, ms=5), Timeout(phase=Pool, timeout_ms=5), true),
    (Timeout(phase=Dial, ms=5), Timeout(phase=Dial, timeout_ms=5), true),
    (Timeout(phase=Write, ms=5), Timeout(phase=Write, timeout_ms=5), false),
    (Timeout(phase=Head, ms=5), Timeout(phase=Head, timeout_ms=5), false),
    (Timeout(phase=Body, ms=5), Timeout(phase=Body, timeout_ms=5), false),
    (Timeout(phase=Unknown, ms=5), Timeout(phase=Unknown, timeout_ms=5), false),
    (
      Network(phase=Write, message="reset"),
      Transport(phase=Write, message="reset"),
      false,
    ),
    (
      Network(phase=Head, message="eof"),
      Transport(phase=Head, message="eof"),
      false,
    ),
    (
      Network(phase=Body, message="eof"),
      Transport(phase=Body, message="eof"),
      false,
    ),
    (
      Network(phase=Unknown, message="fetch failed"),
      Transport(phase=Unknown, message="fetch failed"),
      false,
    ),
    // a network failure claiming a pre-connection phase proves nothing
    (
      Network(phase=Dial, message="odd"),
      Transport(phase=Unknown, message="odd"),
      false,
    ),
    (
      Network(phase=Pool, message="odd"),
      Transport(phase=Unknown, message="odd"),
      false,
    ),
    (
      Protocol("garbled"),
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
