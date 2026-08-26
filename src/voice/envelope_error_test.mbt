///|
fn expect_text_error(text : String, expected : String) -> Unit raise {
  try @voice.parse_text_frame(text) catch {
    InvalidTextFrame(reason~) => assert_eq(reason, expected)
    _ => fail("unexpected envelope error for: \{expected}")
  } noraise {
    _ => fail("expected invalid text frame: \{expected}")
  }
}

///|
test "text envelope parsing reports each malformed payload" {
  try @voice.parse_text_frame("not-json") catch {
    InvalidTextFrame(reason~) => assert_true(reason.has_prefix("invalid JSON:"))
    _ => fail("unexpected envelope error")
  } noraise {
    _ => fail("expected a JSON parse failure")
  }
  expect_text_error(
    (
      #|{"d":{}}
    ),
    "expected top-level op and d",
  )
  expect_text_error(
    (
      #|{"op":true,"d":null}
    ),
    "expected numeric field op",
  )
  expect_text_error(
    (
      #|{"op":1.5,"d":null}
    ),
    "expected integer field op",
  )
  expect_text_error(
    (
      #|{"op":9,"d":null,"seq":true}
    ),
    "expected numeric field seq",
  )
  expect_text_error(
    (
      #|{"op":2,"d":{}}
    ),
    "invalid Ready payload",
  )
  expect_text_error(
    (
      #|{"op":2,"d":{"ssrc":true,"ip":"a","port":1,"modes":[]}}
    ),
    "expected unsigned field ssrc",
  )
  expect_text_error(
    (
      #|{"op":2,"d":{"ssrc":1.5,"ip":"a","port":1,"modes":[]}}
    ),
    "expected unsigned integer field ssrc",
  )
  expect_text_error(
    (
      #|{"op":2,"d":{"ssrc":1,"ip":"a","port":1,"modes":5}}
    ),
    "expected array field modes",
  )
  expect_text_error(
    (
      #|{"op":2,"d":{"ssrc":1,"ip":"a","port":1,"modes":[1]}}
    ),
    "expected string values in modes",
  )
  expect_text_error(
    (
      #|{"op":4,"d":{}}
    ),
    "invalid Session Description payload",
  )
  expect_text_error(
    (
      #|{"op":4,"d":{"mode":"m","secret_key":true,"dave_protocol_version":0}}
    ),
    "expected array field secret_key",
  )
  expect_text_error(
    (
      #|{"op":4,"d":{"mode":"m","secret_key":[256],"dave_protocol_version":0}}
    ),
    "byte outside 0..255 in secret_key",
  )
  expect_text_error(
    (
      #|{"op":5,"d":{}}
    ),
    "invalid Speaking payload",
  )
  expect_text_error(
    (
      #|{"op":6,"d":{}}
    ),
    "invalid Heartbeat ACK payload",
  )
  expect_text_error(
    (
      #|{"op":6,"d":{"t":true}}
    ),
    "expected numeric field t",
  )
  expect_text_error(
    (
      #|{"op":6,"d":{"t":1.5}}
    ),
    "expected integer field t",
  )
  expect_text_error(
    (
      #|{"op":8,"d":{}}
    ),
    "invalid Hello payload",
  )
  expect_text_error(
    (
      #|{"op":11,"d":{}}
    ),
    "invalid Clients Connect payload",
  )
  expect_text_error(
    (
      #|{"op":13,"d":{}}
    ),
    "invalid Client Disconnect payload",
  )
  expect_text_error(
    (
      #|{"op":21,"d":{}}
    ),
    "invalid DAVE Prepare Transition payload",
  )
  expect_text_error(
    (
      #|{"op":22,"d":{}}
    ),
    "invalid DAVE Execute Transition payload",
  )
  expect_text_error(
    (
      #|{"op":24,"d":{}}
    ),
    "invalid DAVE Prepare Epoch payload",
  )
}

///|
test "unrecognized opcodes stay decodable instead of raising" {
  guard @voice.parse_text_frame(
      (
        #|{"op":99,"d":null}
      ),
    )
    is (Unknown(op=99), None) else {
    fail("expected an unknown text opcode")
  }
  guard @voice.parse_binary_frame(b"\x00\x07\x1F\x01\x02")
    is (Unknown(op=31), Some(7)) else {
    fail("expected an unknown binary opcode with its sequence")
  }
}

///|
test "binary envelope parsing rejects truncated frames" {
  try @voice.parse_binary_frame(b"\x00\x01") catch {
    InvalidBinaryFrame(reason~) =>
      assert_eq(reason, "frame is shorter than sequence and opcode")
    _ => fail("unexpected envelope error")
  } noraise {
    _ => fail("expected a short binary frame error")
  }
  try @voice.parse_binary_frame(b"\x00\x01\x1D\x00") catch {
    InvalidBinaryFrame(reason~) =>
      assert_eq(reason, "opcode 29 payload is missing transition_id")
    _ => fail("unexpected envelope error")
  } noraise {
    _ => fail("expected a missing transition_id error")
  }
}
