///|
#borrow(public_key, signature, message)
extern "C" fn verify_ed25519_native(
  public_key : Bytes,
  signature : Bytes,
  message : Bytes,
) -> Int = "discord_verify_ed25519"

///|
/// Verify a Discord HTTP interaction request signature with libcrypto Ed25519.
///
/// `public_key` is the application's 32-byte public key as 64 hexadecimal
/// characters. `signature` is the request's 64-byte
/// `X-Signature-Ed25519` value as 128 hexadecimal characters. The signed
/// message is the UTF-8 encoding of `timestamp + body`.
///
/// Malformed inputs and libcrypto failures return `false`.
#warnings("-unused_async")
pub async fn verify_signature(
  public_key~ : String,
  signature~ : String,
  timestamp~ : String,
  body~ : String,
) -> Bool {
  guard public_key.length() == 64 && signature.length() == 128 else {
    return false
  }
  guard decode_hex(public_key) is Some(public_key_bytes) else { return false }
  guard decode_hex(signature) is Some(signature_bytes) else { return false }
  let message = @utf8.encode(timestamp + body)
  verify_ed25519_native(public_key_bytes, signature_bytes, message) == 1
}
