///|
#external
priv type CryptoKey

///|
extern "js" fn import_key(
  public_key : Bytes,
  _signal : @js_async.AbortSignal,
) -> @js_async.Promise[CryptoKey] =
  #| async (publicKey, _signal) => {
  #|   return globalThis.crypto.subtle.importKey(
  #|     "raw",
  #|     new Uint8Array(publicKey),
  #|     { name: "Ed25519" },
  #|     false,
  #|     ["verify"],
  #|   )
  #| }

///|
extern "js" fn verify_ed25519(
  key : CryptoKey,
  signature : Bytes,
  data : Bytes,
  _signal : @js_async.AbortSignal,
) -> @js_async.Promise[Bool] =
  #| (key, signature, data, _signal) => {
  #|   return globalThis.crypto.subtle.verify(
  #|     "Ed25519",
  #|     key,
  #|     new Uint8Array(signature),
  #|     new Uint8Array(data),
  #|   )
  #| }

///|
/// Verify a Discord HTTP interaction request signature with WebCrypto Ed25519.
///
/// `public_key` is the application's 32-byte public key as 64 hexadecimal
/// characters. `signature` is the request's 64-byte
/// `X-Signature-Ed25519` value as 128 hexadecimal characters. The signed
/// message is the UTF-8 encoding of `timestamp + body`.
///
/// Malformed inputs and WebCrypto failures return `false`.
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
  let data = @utf8.encode(timestamp + body)
  try {
    let key = @js_async.run_promise(signal => {
      import_key(public_key_bytes, signal)
    })
    @js_async.run_promise(signal => {
      verify_ed25519(key, signature_bytes, data, signal)
    })
  } catch {
    _ => false
  }
}
