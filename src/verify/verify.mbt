///|
/// Errors raised while constructing a reusable Discord interaction verifier.
pub(all) suberror InteractionVerifierError {
  InvalidPublicKeyLength(got~ : Int)
  InvalidPublicKeyHex
  InvalidPublicKeyEncoding
} derive(Eq, Debug)

///|
/// A validated and expanded Discord interaction public key.
///
/// Construct one verifier per application public key and reuse it across
/// requests. The expanded Ed25519 key is immutable and safe to share.
pub struct InteractionVerifier {
  priv key : @ed25519.VerifyingKey
}

///|
/// Validate a Discord application's 64-character hexadecimal public key.
pub fn InteractionVerifier::new(
  public_key : String,
) -> InteractionVerifier raise InteractionVerifierError {
  if public_key.length() != 64 {
    raise InvalidPublicKeyLength(got=public_key.length())
  }
  guard decode_hex(public_key) is Some(public_key_bytes) else {
    raise InvalidPublicKeyHex
  }
  let key = @ed25519.VerifyingKey::from_public_key(public_key_bytes) catch {
    _ => raise InvalidPublicKeyEncoding
  }
  { key, }
}

///|
/// Verify a Discord HTTP interaction request signature.
///
/// `signature` is the request's 64-byte `X-Signature-Ed25519` value as 128
/// hexadecimal characters. The signed message is the UTF-8 encoding of
/// `timestamp` followed by the exact raw request `body` bytes.
///
/// Malformed signatures and verification failures return `false`.
pub fn InteractionVerifier::verify(
  self : InteractionVerifier,
  signature~ : String,
  timestamp~ : String,
  body~ : BytesView,
) -> Bool {
  guard signature.length() == 128 else { return false }
  guard decode_hex(signature) is Some(signature_bytes) else { return false }
  let message = @utf8.encode(timestamp) + body.to_owned()
  self.key.verify(message, signature_bytes)
}

///|
/// Verify a Discord HTTP interaction signature without retaining the key.
///
/// This convenience function validates and expands `public_key` on every
/// call. Long-lived adapters should construct and reuse an
/// `InteractionVerifier` instead. Malformed keys and signatures return
/// `false`.
pub fn verify_signature(
  public_key~ : String,
  signature~ : String,
  timestamp~ : String,
  body~ : BytesView,
) -> Bool {
  let verifier = InteractionVerifier::new(public_key) catch {
    _ => return false
  }
  verifier.verify(signature~, timestamp~, body~)
}
