///|
test "transport shim availability can be required by coverage" {
  if @env.get_env_var("DISCORD_VOICE_REQUIRE_SHIM") == Some("1") &&
    !@voice.shim_available() {
    fail(
      @voice.shim_unavailable_reason().unwrap_or(
        "transport AEAD shim is unavailable",
      ),
    )
  }
}

///|
test "voice encryption mode negotiation prefers AES and requires a common mode" {
  assert_eq(
    @voice.EncryptionMode::negotiate([
      "aead_xchacha20_poly1305_rtpsize", "aead_aes256_gcm_rtpsize",
    ]),
    AeadAes256GcmRtpsize,
  )
  assert_eq(
    @voice.EncryptionMode::negotiate(["aead_xchacha20_poly1305_rtpsize"]),
    AeadXChaCha20Poly1305Rtpsize,
  )
  try @voice.EncryptionMode::negotiate(["xsalsa20_poly1305"]) catch {
    NoCompatibleMode(modes=["xsalsa20_poly1305"]) => ()
    _ => fail("unexpected crypto error")
  } noraise {
    _ => fail("expected NoCompatibleMode")
  }
}

///|
test "transport cipher validates its secret key before loading the shim" {
  try @voice.TransportCipher::new(AeadAes256GcmRtpsize, b"too short") catch {
    InvalidSecretKey(length=9) => ()
    _ => fail("unexpected crypto error")
  } noraise {
    _ => fail("expected InvalidSecretKey")
  }
}
