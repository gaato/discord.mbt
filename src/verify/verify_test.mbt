///|
fn encode_hex_for_test(bytes : Bytes) -> String {
  let out = StringBuilder()
  for byte in bytes {
    out.write_string(byte.to_hex())
  }
  out.to_string()
}

///|
test "RFC 8032 test 1 verifies an empty message" {
  assert_true(
    @verify.verify_signature(
      public_key="d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a",
      signature="e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155" +
        "5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b",
      timestamp="",
      body=b"",
    ),
  )
}

///|
test "RFC 8032 test 2 verifies a non-empty message" {
  assert_true(
    @verify.verify_signature(
      public_key="3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c",
      signature="92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da" +
        "085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00",
      timestamp="",
      body=b"r",
    ),
  )
}

///|
test "cached verifier accepts Discord timestamp and raw body framing" {
  // Generated once with Node's node:crypto Ed25519 key generation and sign()
  // over Buffer.from(timestamp + body, "utf8"); tests never generate keys.
  let public_key = "b17f4787e67691b60c1d3c19e1c33f3d3df84bd6e20e212dbe5284c772de0704"
  let signature = "18bc501f1401f8c760948c22e08e9f7fec78206b8ef7a740b1f2b01f687429b52" +
    "cc352752102eccb7fd5aca53d92d49bb906d2aaba4a66d8ac89b6595bd85701"
  let timestamp = "1720951200"
  let body_text =
    #|{"type":1,"id":"123456789012345678","application_id":"987654321098765432"}
  let body = @utf8.encode(body_text)
  let verifier = @verify.InteractionVerifier::new(public_key)
  assert_true(verifier.verify(signature~, timestamp~, body~))
  assert_true(verifier.verify(signature~, timestamp~, body~))
}

///|
test "modified signed inputs are rejected" {
  let public_key = "b17f4787e67691b60c1d3c19e1c33f3d3df84bd6e20e212dbe5284c772de0704"
  let signature = "18bc501f1401f8c760948c22e08e9f7fec78206b8ef7a740b1f2b01f687429b52" +
    "cc352752102eccb7fd5aca53d92d49bb906d2aaba4a66d8ac89b6595bd85701"
  let timestamp = "1720951200"
  let body_text =
    #|{"type":1,"id":"123456789012345678","application_id":"987654321098765432"}
  let body = @utf8.encode(body_text)
  let verifier = @verify.InteractionVerifier::new(public_key)
  assert_false(
    verifier.verify(
      signature="19" + signature[2:].to_owned(),
      timestamp~,
      body~,
    ),
  )
  assert_false(verifier.verify(signature~, timestamp="1720951201", body~))
  assert_false(verifier.verify(signature~, timestamp~, body=body + b" "))
}

///|
test "constructor distinguishes invalid public key inputs" {
  try @verify.InteractionVerifier::new("00") |> ignore catch {
    InvalidPublicKeyLength(got~) => assert_eq(got, 2)
    error => fail("unexpected length error: \{Repr(error)}")
  } noraise {
    _ => fail("short public key was accepted")
  }
  try @verify.InteractionVerifier::new("z".repeat(64)) |> ignore catch {
    InvalidPublicKeyHex => ()
    error => fail("unexpected hex error: \{Repr(error)}")
  } noraise {
    _ => fail("non-hex public key was accepted")
  }
  try @verify.InteractionVerifier::new("00".repeat(32)) |> ignore catch {
    InvalidPublicKeyEncoding => ()
    error => fail("unexpected encoding error: \{Repr(error)}")
  } noraise {
    _ => fail("small-order public key was accepted")
  }
}

///|
test "malformed signatures and one-shot key errors return false" {
  let public_key = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
  let signature = "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155" +
    "5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"
  let verifier = @verify.InteractionVerifier::new(public_key)
  assert_false(
    verifier.verify(signature="g".repeat(128), timestamp="", body=b""),
  )
  assert_false(verifier.verify(signature="abc", timestamp="", body=b""))
  assert_false(verifier.verify(signature="00", timestamp="", body=b""))
  assert_false(
    @verify.verify_signature(
      public_key="z".repeat(64),
      signature~,
      timestamp="",
      body=b"",
    ),
  )
  assert_false(
    @verify.verify_signature(
      public_key="00",
      signature~,
      timestamp="",
      body=b"",
    ),
  )
}

///|
test "raw non-UTF-8 request bytes are verified without normalization" {
  let seed = b"\x9D\x61\xB1\x9D\xEF\xFD\x5A\x60\xBA\x84\x4A\xF4\x92\xEC\x2C\xC4\x44\x49\xC5\x69\x7B\x32\x69\x19\x70\x3B\xAC\x03\x1C\xAE\x7F\x60"
  let public_key = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
  let timestamp = "1720951200"
  let body = b"\xFF\x00\x80raw"
  let signature = encode_hex_for_test(
    @ed25519.sign(seed, @utf8.encode(timestamp) + body),
  )
  let verifier = @verify.InteractionVerifier::new(public_key)
  assert_true(verifier.verify(signature~, timestamp~, body~))
}
