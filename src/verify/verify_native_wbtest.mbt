///|
#borrow(private_key, message, out_signature)
extern "C" fn sign_ed25519_native(
  private_key : Bytes,
  message : Bytes,
  out_signature : Bytes,
) -> Int = "discord_verify_ed25519_sign"

///|
fn sign_ed25519(private_key : Bytes, message : Bytes) -> Bytes? {
  guard private_key.length() == 32 else { return None }
  let signature = Bytes::make(64, b'\x00')
  if sign_ed25519_native(private_key, message, signature) == 1 {
    Some(signature)
  } else {
    None
  }
}

///|
fn encode_hex_for_test(bytes : Bytes) -> String {
  let out = StringBuilder()
  for byte in bytes {
    out.write_string(byte.to_hex())
  }
  out.to_string()
}

///|
async test "RFC 8032 test 1 verifies an empty message" {
  assert_true(
    verify_signature(
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
    verify_signature(
      public_key="3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c",
      signature="92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da" +
        "085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00",
      timestamp="",
      body="r",
    ),
  )
}

///|
async test "native signing round-trips through verify_signature" {
  guard decode_hex(
      "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60",
    )
    is Some(private_key) else {
    fail("invalid RFC 8032 private key fixture")
  }
  let public_key = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
  let timestamp = "1720951200"
  let body =
    #|{"type":1,"id":"123456789012345678","application_id":"987654321098765432"}
  guard sign_ed25519(private_key, @utf8.encode(timestamp + body))
    is Some(signed) else {
    fail("libcrypto failed to sign the test message")
  }
  assert_true(
    verify_signature(
      public_key~,
      signature=encode_hex_for_test(signed),
      timestamp~,
      body~,
    ),
  )
}

///|
async test "malformed, wrong-length, and modified signatures are rejected" {
  let public_key = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
  let signature = "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155" +
    "5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"
  assert_false(
    verify_signature(
      public_key="z".repeat(64),
      signature~,
      timestamp="",
      body="",
    ),
  )
  assert_false(
    verify_signature(public_key="00", signature~, timestamp="", body=""),
  )
  assert_false(
    verify_signature(public_key~, signature="00", timestamp="", body=""),
  )
  assert_false(
    verify_signature(
      public_key~,
      signature="f5" + signature[2:].to_owned(),
      timestamp="",
      body="",
    ),
  )
}
