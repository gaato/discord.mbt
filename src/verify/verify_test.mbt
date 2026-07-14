///|
async test "RFC 8032 test 1 verifies an empty message" {
  assert_true(
    @verify.verify_signature(
      public_key="d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a",
      signature="e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155" +
        "5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b",
      timestamp="",
      body="",
    ),
  )
}

///|
async test "RFC 8032 test 2 verifies a non-empty message" {
  assert_true(
    @verify.verify_signature(
      public_key="3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c",
      signature="92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da" +
        "085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00",
      timestamp="",
      body="r",
    ),
  )
}

///|
async test "Discord-style timestamp and body framing verifies" {
  // Generated once with Node's node:crypto Ed25519 key generation and sign()
  // over Buffer.from(timestamp + body, "utf8"); tests never generate keys.
  let public_key = "b17f4787e67691b60c1d3c19e1c33f3d3df84bd6e20e212dbe5284c772de0704"
  let signature = "18bc501f1401f8c760948c22e08e9f7fec78206b8ef7a740b1f2b01f687429b52" +
    "cc352752102eccb7fd5aca53d92d49bb906d2aaba4a66d8ac89b6595bd85701"
  let timestamp = "1720951200"
  let body =
    #|{"type":1,"id":"123456789012345678","application_id":"987654321098765432"}
  assert_true(
    @verify.verify_signature(public_key~, signature~, timestamp~, body~),
  )
}

///|
async test "modified signed inputs are rejected" {
  let public_key = "b17f4787e67691b60c1d3c19e1c33f3d3df84bd6e20e212dbe5284c772de0704"
  let signature = "18bc501f1401f8c760948c22e08e9f7fec78206b8ef7a740b1f2b01f687429b52" +
    "cc352752102eccb7fd5aca53d92d49bb906d2aaba4a66d8ac89b6595bd85701"
  let timestamp = "1720951200"
  let body =
    #|{"type":1,"id":"123456789012345678","application_id":"987654321098765432"}
  assert_false(
    @verify.verify_signature(
      public_key~,
      signature="19" + signature[2:].to_owned(),
      timestamp~,
      body~,
    ),
  )
  assert_false(
    @verify.verify_signature(
      public_key="d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a",
      signature~,
      timestamp~,
      body~,
    ),
  )
  assert_false(
    @verify.verify_signature(
      public_key~,
      signature~,
      timestamp~,
      body=body + " ",
    ),
  )
}

///|
async test "malformed and wrong-length hex inputs are rejected" {
  let public_key = "b17f4787e67691b60c1d3c19e1c33f3d3df84bd6e20e212dbe5284c772de0704"
  let signature = "18bc501f1401f8c760948c22e08e9f7fec78206b8ef7a740b1f2b01f687429b52" +
    "cc352752102eccb7fd5aca53d92d49bb906d2aaba4a66d8ac89b6595bd85701"
  assert_false(
    @verify.verify_signature(
      public_key="z".repeat(64),
      signature~,
      timestamp="",
      body="",
    ),
  )
  assert_false(
    @verify.verify_signature(
      public_key~,
      signature="g".repeat(128),
      timestamp="",
      body="",
    ),
  )
  assert_false(
    @verify.verify_signature(
      public_key~,
      signature="abc",
      timestamp="",
      body="",
    ),
  )
  assert_false(
    @verify.verify_signature(public_key="00", signature~, timestamp="", body=""),
  )
  assert_false(
    @verify.verify_signature(public_key~, signature="00", timestamp="", body=""),
  )
}
