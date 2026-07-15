///|
fn hex_nibble(code : Int) -> Byte? {
  if code >= '0' && code <= '9' {
    Some((code - '0').to_byte())
  } else if code >= 'a' && code <= 'f' {
    Some((code - 'a' + 10).to_byte())
  } else {
    None
  }
}

///|
fn decode_test_hex(text : String) -> Bytes {
  let bytes : Array[Byte] = []
  for index in 0..<(text.length() / 2) {
    guard hex_nibble(text[index * 2].to_int()) is Some(high) &&
      hex_nibble(text[index * 2 + 1].to_int()) is Some(low) else {
      abort("invalid test hex")
    }
    bytes.push((high << 4) | low)
  }
  Bytes::from_array(bytes)
}

///|
test "AEAD known-answer vectors" {
  if !shim_available() {
    return
  }
  let aes = aead_seal_raw(
    AeadAes256GcmRtpsize,
    Bytes::new(32),
    Bytes::new(12),
    b"",
    Bytes::new(16),
  )
  assert_eq(
    aes,
    decode_test_hex(
      "cea7403d4d606b6e074ec5d3baf39d18d0d1c8a799996bf0265b98b5d48ab919",
    ),
  )

  let key = decode_test_hex(
    "808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f",
  )
  let nonce = decode_test_hex(
    "404142434445464748494a4b4c4d4e4f5051525354555657",
  )
  let aad = decode_test_hex("50515253c0c1c2c3c4c5c6c7")
  let plaintext = decode_test_hex(
    "4c616469657320616e642047656e746c656d656e206f662074686520636c617373206f66202739393a204966204920636f756c64206f6666657220796f75206f6e6c79206f6e652074697020666f7220746865206675747572652c2073756e73637265656e20776f756c642062652069742e",
  )
  let expected = decode_test_hex(
    "bd6d179d3e83d43b9576579493c0e939572a1700252bfaccbed2902c21396cbb731c7f1b0b4aa6440bf3a82f4eda7e39ae64c6708c54c216cb96b72e1213b4522f8c9ba40db5d945b11b69b982c1bb9e3f3fac2bc369488f76b2383565d3fff921f9664c97637da9768812f615c68b13b52ec0875924c1c7987947deafd8780acf49",
  )
  assert_eq(
    aead_seal_raw(AeadXChaCha20Poly1305Rtpsize, key, nonce, aad, plaintext),
    expected,
  )
}

///|
test "transport cipher round-trips, increments suffix, and rejects tampering" {
  if !shim_available() {
    return
  }
  for mode in [AeadAes256GcmRtpsize, AeadXChaCha20Poly1305Rtpsize] {
    let cipher = TransportCipher::new(mode, Bytes::new(32))
    let header = build_rtp_header(sequence=1, timestamp=960U, ssrc=42U)
    let first = cipher.seal(header~, b"first")
    let second = cipher.seal(header~, b"second")
    assert_eq(first[first.length() - 4:].to_owned(), b"\x00\x00\x00\x00")
    assert_eq(second[second.length() - 4:].to_owned(), b"\x00\x00\x00\x01")
    assert_eq(cipher.open(first, header_len=12), header + b"first")
    assert_eq(cipher.open(second, header_len=12), header + b"second")
    let tampered = first.to_array()
    tampered[12] = tampered[12] ^ b'\x01'
    try cipher.open(Bytes::from_array(tampered), header_len=12) catch {
      AuthenticationFailed(..) => ()
      _ => fail("unexpected crypto error")
    } noraise {
      _ => fail("expected authentication failure")
    }
  }
}
