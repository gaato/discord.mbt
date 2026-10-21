///|
fn hex(text : String) -> Bytes {
  let bytes : Array[Byte] = []
  let mut high : Int32? = None
  for ch in text {
    let digit = match ch {
      '0'..<='9' => ch.to_int() - '0'.to_int()
      'a'..<='f' => ch.to_int() - 'a'.to_int() + 10
      _ => continue
    }
    match high {
      None => high = Some(digit)
      Some(h) => {
        bytes.push((h * 16 + digit).to_byte())
        high = None
      }
    }
  }
  Bytes::from_array(bytes)
}

///|
/// Compress `input` and sync-flush, as Discord does after every message.
fn sync_flush(encoder : @zlib.Encoder, input : Bytes) -> Bytes {
  let compressed : Array[Byte] = []
  let out = FixedArray::make(256, b'\x00')
  let mut rest = input[:]
  while true {
    let status = encoder.step(rest, out.mut_view(), action=Flush)
    for i in 0..<encoder.last_produced() {
      compressed.push(out[i])
    }
    rest = rest[encoder.last_consumed():]
    if status is NeedMoreInput && rest.length() == 0 {
      break
    }
  }
  Bytes::from_array(compressed)
}

///|
test "zlib-stream round-trips split and consecutive messages" {
  let inflater : &Inflater = ZlibStreamInflater()
  let encoder = @zlib.Encoder()
  let first =
    #|{"op":10,"d":{"heartbeat_interval":45000}}
  let second =
    #|{"op":11,"d":null}
  let compressed_first = sync_flush(encoder, @utf8.encode(first))
  assert_true(compressed_first.has_suffix(b"\x00\x00\xff\xff"))
  let split = compressed_first.length() - 2
  assert_true(inflater.push(compressed_first[:split].to_owned()) is None)
  debug_inspect(
    inflater.push(compressed_first[split:].to_owned()),
    content=(
      #|Some("{\"op\":10,\"d\":{\"heartbeat_interval\":45000}}")
    ),
  )
  let compressed_second = sync_flush(encoder, @utf8.encode(second))
  assert_true(compressed_second.has_suffix(b"\x00\x00\xff\xff"))
  debug_inspect(
    inflater.push(compressed_second),
    content=(
      #|Some("{\"op\":11,\"d\":null}")
    ),
  )
}

///|
/// A message whose compressed form exceeds the 64 KiB that one decoder step
/// accepts: random base64-alphabet text barely compresses.
fn incompressible_message(rand : @random.Rand) -> String {
  let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  let builder = StringBuilder()
  builder.write_string("{\"op\":0,\"s\":2,\"t\":\"BLOB\",\"d\":\"")
  for _ in 0..<120000 {
    builder.write_char(alphabet[rand.int(limit=64)].unsafe_to_char())
  }
  builder.write_string("\"}")
  builder.to_string()
}

///|
test "zlib-stream inflates messages past one decoder step at any split" {
  let rand = @random.Rand::chacha8()
  let inflater : &Inflater = ZlibStreamInflater()
  let encoder = @zlib.Encoder()
  for _ in 0..<3 {
    let message = incompressible_message(rand)
    let compressed = sync_flush(encoder, @utf8.encode(message))
    assert_true(compressed.length() > 65536)
    let mut start = 0
    let mut result = None
    while start < compressed.length() {
      assert_true(result is None)
      let end = (start + 1 + rand.int(limit=40000)).min(compressed.length())
      result = inflater.push(compressed[start:end].to_owned())
      start = end
    }
    // Compare without printing 120 KB on failure.
    let length = result.map(text => text.length()).unwrap_or(-1)
    assert_true(result == Some(message), msg="inflated \{length} chars")
  }
  let ack =
    #|{"op":11,"d":null}
  assert_eq(inflater.push(sync_flush(encoder, @utf8.encode(ack))), Some(ack))
}

// Output of CPython's zlib (compressobj + Z_SYNC_FLUSH after each message),
// so the decoder is checked against the reference encoder, not only itself.
// READY inflates past the initial 16 KiB output buffer.

///|
let zlib_hello : Bytes = hex(
  (
    #|789caa56ca2f50b23234d0514a51b2aa56ca484d2c2a494a4d2c89cfcc2b492d2a4bcc51
    #|b23231343235a8ad05000000ffff
  ),
)

///|
let zlib_ready : Bytes = hex(
  (
    #|94d8b18aa4550084d177e97803abaafbefbf3713f405cc440c465c646030d09d4d967977
    #|073112363837bcb76ef465e7ebbfcbf7e1dfeffb0f97cf978f979f7efcfe879f2fff7dfd
    #|e3f5f9e5f7f7b75fbe5e9edf2f2ef9eeffe77df9fae7d397a7e797a7df5e3e5d3e7efeeb
    #|f5d3db876fcd63f3da7c36bfdafc66f3c3e6779b9f367fd03c5635563556355635563556
    #|3556355635563556b556b556b556b556b556b556b556b556b556b5567556755675567556
    #|755675567556755675567556f56a55af56f56a55af56f56a55af56f56a55af56f56a55af
    #|56f566556f56f566556f56f566556f56f566556f56f566556f56f5b0aa87553dacea6155
    #|0fab7a58d5c3aa1e56f5b0aa8755bd5bd5bb55bd5bd5bb55bd5bd5bb55bd5bd5bb55bd5b
    #|d5bb553dadea69554fab7a5ad5d3aa9e56f5b4aaa7553dadea69551f56f561551f56f561
    #|551f56f561551f56f561551f56f5415563b614b3a5982dc56c29664b315b8ad952cc9662
    #|b614b3a5982dc56c29664b315b8ad952cc9662b614b3a5982dc56c29664b315b8ad952cc
    #|9662b614b3a5982dc56c29664b315b8ad952cc9662b614b3a5982dc56c29664b315b8ad9
    #|52cc9662b614b3a5982dc56c29664b315b8ad952cc9662b614b3a5982dc56c29664b315b
    #|8ad952cc9662b614b3a5982dc56c29664b315b8ad952cc9662b614b3a5982dc56c29664b
    #|315b8ad952cc9662b614b3a5982dc56c29664b315b8ad952cc9662b614b3a5982dc56c29
    #|664b315b8ad952cc9662b614b3a5982dc56c29664b315b8ad952cc9662b614b3a5982dc5
    #|6ca9664b355baad952cd966ab654b3a59a2dd56ca9664b355baad952cd966ab654b3a59a
    #|2dd56ca9664b355baad952cd966ab654b3a59a2dd56ca9664b355baad952cd966ab654b3
    #|a59a2dd56ca9664b355baad952cd966ab654b3a59a2dd56ca9664b355baad952cd966ab6
    #|54b3a59a2dd56ca9664b355baad952cd966ab654b3a59a2dd56ca9664b355baad952cd96
    #|6ab654b3a59a2dd56ca9664b355baad952cd966ab654b3a59a2dd56ca9664b355baad952
    #|cd966ab654b3a59a2dd56ca9664b355baad952cd966ab654b3a59a2dd56ca9664b355baa
    #|d952cd966ab654b3a59a2dd56ca9664b355baad952cd9666b634b3a5992dcd6c69664b33
    #|5b9ad9d2cc9666b634b3a5992dcd6c69664b335b9ad9d2cc9666b634b3a5992dcd6c6966
    #|4b335b9ad9d2cc9666b634b3a5992dcd6c69664b335b9ad9d2cc9666b634b3a5992dcd6c
    #|69664b335b9ad9d2cc9666b634b3a5992dcd6c69664b335b9ad9d2cc9666b634b3a5992d
    #|cd6c69664b335b9ad9d2cc9666b634b3a5992dcd6c69664b335b9ad9d2cc9666b634b3a5
    #|992dcd6c69664b335b9ad9d2cc9666b634b3a5992dcd6c69664b335b9ad9d2cc9666b634
    #|b3a5992dcd6c69664b335b9ad9d2cc9666b634b3a5992dcd6c69664b335b9ad9d2cc9666
    #|b634b3a5992ded1bb6f4ebdbdb3f000000ffff
  ),
)

///|
let zlib_heartbeat_ack : Bytes = hex(
  (
    #|821ccd6468580b000000ffff
  ),
)

///|
fn ready_guilds() -> String {
  let builder = StringBuilder()
  builder.write_string("{\"op\":0,\"s\":1,\"t\":\"READY\",\"d\":{\"guilds\":[")
  for i in 0..<400 {
    if i > 0 {
      builder.write_char(',')
    }
    builder.write_string(
      "{\"id\":\"\{100000000000000000L + i.to_int64()}\",\"unavailable\":true}",
    )
  }
  builder.write_string("]}}")
  builder.to_string()
}

///|
test "zlib-stream decodes reference zlib output message by message" {
  let inflater : &Inflater = ZlibStreamInflater()
  for i in 0..<(zlib_hello.length() - 1) {
    assert_true(inflater.push(zlib_hello[i:i + 1].to_owned()) is None)
  }
  debug_inspect(
    inflater.push(zlib_hello[zlib_hello.length() - 1:].to_owned()),
    content=(
      #|Some("{\"op\":10,\"d\":{\"heartbeat_interval\":41250}}")
    ),
  )
  assert_eq(inflater.push(zlib_ready), Some(ready_guilds()))
  debug_inspect(
    inflater.push(zlib_heartbeat_ack),
    content=(
      #|Some("{\"op\":11}")
    ),
  )
}

///|
test "zlib-stream reports corrupt streams and invalid UTF-8" {
  let cases : Array[(String, Bytes)] = [
    ("header", b"\x00\x00\x00\xff\xff"),
    ("finished", @zlib.compress(b"x") + b"\x00\x00\xff\xff"),
    ("utf8", sync_flush(@zlib.Encoder(), b"\xff\xfe")),
  ]
  for case in cases {
    let (name, input) = case
    let inflater : &Inflater = ZlibStreamInflater()
    try inflater.push(input) catch {
      Malformed(_) if name != "utf8" => ()
      InvalidUtf8 if name == "utf8" => ()
      error => fail("\{name}: unexpected \{error}")
    } noraise {
      _ => fail("\{name}: expected an error")
    }
  }
}

///|
test "zlib-stream refuses messages over its limit" {
  let message = @utf8.encode("{\"op\":0,\"d\":\"" + "a".repeat(5000) + "\"}")
  // Inflated: 5000 repeated bytes compress to a few dozen, so only the
  // output check can stop them; the buffer stops growing near the limit.
  let bomb : ZlibStreamInflater = ZlibStreamInflater(max_bytes=1000)
  let inflater : &Inflater = bomb
  try inflater.push(sync_flush(@zlib.Encoder(), message)) catch {
    TooLarge(limit=1000) => ()
    error => fail("unexpected \{Repr(error)}")
  } noraise {
    _ => fail("an oversized message inflated")
  }
  assert_true(bomb.message.out.length() <= 16384)
  // Compressed: a message that never reaches its sync-flush suffix stops
  // accumulating at the limit.
  let endless : &Inflater = ZlibStreamInflater(max_bytes=1000)
  assert_true(endless.push(Bytes::make(600, b'\x01')) is None)
  try endless.push(Bytes::make(600, b'\x01')) catch {
    TooLarge(limit=1000) => ()
    error => fail("unexpected \{Repr(error)}")
  } noraise {
    _ => fail("compressed bytes accumulated past the limit")
  }
}

// Output of python-zstandard (one compressobj, FLUSH_BLOCK after each
// message), as Discord's zstd-stream sends it: one frame that never ends.
// READY inflates to 141141 bytes, past the 16 KiB output buffer and the
// 128 KiB zstd block limit.

///|
let zstd_hello : Bytes = hex(
  (
    #|28b52ffd00585001007b226f70223a31302c2264223a7b226865617274626561745f696e
    #|74657276616c223a34313235307d7d
  ),
)

///|
let zstd_ready : Bytes = hex(
  (
    #|8406010ac9aa4e22606993e5133590f41c40b9a70d35a27ae268ac9a5924a524a5942905
    #|ff85d35114822e05d904c304bfdc51f65c2f6ab22c439e1a93c545ba33bbc2f7fb7827c4
    #|9d513b6c75e4d419990e9174aaecf4eb78eb58a2737a4dd8350bd770aa468a6ac6534331
    #|3545a9a9614d6b3576d43ca266649ab5347cd1c88a6684688886862a3475d274a43905cd
    #|fb9988cf8c9ee17446aa66c434334133c4996971c6de8c633367cc045d66b50c5f19ae32
    #|2225431d99bac8d444a64219d364de90890899e0391b73c4c599280e913834c3a9124e4d
    #|8e839c739c4f70766f386f44ba11aacd9436f4d9d46653914d899b3f36c1d86c1ec3720c
    #|dd1889c60c2b868662aa26a6213126633e8b89464cfcdf7e8a2fd44feb347ac9bc2477f9
    #|7ffff698f8eaa66d613d53a62297c78d7129f6d0af391ea6bc2457a4adccab42ab4a0955
    #|8aa6d24ac567256695a8a8cc2f61bc44e89299964c5509994a2aa8c423252f96dc2b89ad
    #|641225a493484d222fc9ac244544d20e492f249e905c4812359239481641427e64aa23e4
    #|1aa9a891228d7466c425233747621c09d9087b11b945661619a90851895449a41f116f44
    #|2c22129ec862226488c89c2265cab8148a528a45e910c516ca432821a48c465983c27f22
    #|fb64c413a24eea34e9686299c94926614e22381937e1c444ea21130e2136a4a6425a1462
    #|4f8863424e090962c8ba10598488fc433eb5afd7bb7a856e9abff291dfecacb8f89eb889
    #|364d5d55aec9e738481ca5f7999b45c243efd425bd65a54a1395ee94bf944129372c592b
    #|e92825a2a471b1aac5ba8a8d2a9a54fc4c312ac59dc58d45a1284e4fa49b4833b1a4c452
    #|115d22fe43fc86b822911e5162c46110673ea4f2b0dc61a343b386af19c665b8c990c221
    #|6943690ce717d22e2cb1b02da14fc28f8431235c8970a69041a170c29910924d56982c4b
    #|7a8a7c11790f191b72222489e43cc85990241f8b3cb61dfd1abd1a2f3446cdc89091e428
    #|b3712a46f283150f161dec34e8aa608c8293098e24c832285f70b620490489feaaeff597
    #|fa891e9e2fe6a45c8697dac7f1e2ddb15db55d7e9443c8a3312be6e99199285c7debee3a
    #|779676a7eac2d44550c7914e8add781dc53a627435afb55cb35b7bb41644b5756abcd464
    #|5213616d68356ad4eaa775a7994a7b8b1651b491689ca1b18426266d8234e268559fd59e
    #|393c3b3b0baa599466fbccb89989c88cba193d66b598552e3359f656f6972c58b20dc9c4
    #|229310d990329ac9aa42569f6b9c33cd7dcaedc471c4518613126e4a8e3eae36ae24b8d2
    #|b7bf5bb05b4c6d2bdae8d924661bca36c38d6a5b2336f3b18f63afc6e215db2a46a198d0
    #|c4a412a33156b2582962edeffb9f1fd3afea335d389f9153f1e5bd622fe39efb65c7eb49
    #|9944968ee7e29998842e9adbb0ff7e9f2f664555661e328a42486599694d89877c563056
    #|6eef4459d785ee91986993d647d5b264925f661324914511e9eaa4fa192f8a78794594eb
    #|b06bd10f592132b44d0d3f9652c85091249dd55c41bded3e7e0a71cca8235b0cb9584653
    #|23434324c52a1bbddded6589093a7d12e616968f9d728a488a4ac61dc5f844796b18d5da
    #|c6261f2112211f07996a6d0d5fcaca3142f7d044a932aa533aca2c9b9b82d4b728e295d1
    #|1ea73fabc2e2d504718823ac918916c97595639d336606fdb13abeaf5c492225324433ea
    #|d0e9d59a942ab498f6bd070b505860d000c1a0b0208184050a121a485860c17060081b14
    #|500004c301c102050b090c078604090c40c08001050e0a101890c081353824281c382c1c
    #|38e00084c301010604c302060b08242001010a0d121220a0708085830203c381c1000a08
    #|144820e16ed108170604030205082cc08082c341e1d0808100010080000660403034301c
    #|0cc170301c445bac26166b3d62b623e670c4ce462ca822c64fc4b8899888446c8811a32e
    #|62f588582d2256f94d7e443fd63774d65c2c9f9013799abd2a5edf8efbb43f75b4bc9339
    #|b2c858483ca5e9736dae844dafebfe6f1f6cbfa99e453d3dfd507a1af655ebcbd137a237
    #|5fffb81e6d3d5e750ad585a63e953a9d751aeb25ab97a2ee9efe9b1e53faaae834d12588
    #|2e1cfa8cd0a9482f8fde18ddf3f9cbf378e75be7949a93682e9df95ce63499176ddec6dc
    #|bffcbb3cc6f2a8cae792334a2e243995c8c99457505e4eee09f9ebfc6d3e667e525e4abc
    #|7cf8d9f024c217916fc7f7c17bc15fbecfdd19ddc9da65689f9a9d2c7b85ec45ee9dedf7
    #|e3b1c7431c1f35ce565c4ef119c547264e24f17e716ff14bc44f7fd85ff8642f5397a253
    #|cc8bf20edfdaedf8231e728fecb5e6cbb2f20899685c15d7e98eb6cca770f81d5d735a4b
    #|553da67a826ae2d43552b758dbab1fabcfa8835e5e5de65b96b52c52e5212a53a75c9772
    #|8565d3ca6f9423a23c9ebc319955b2b8c81345ae197295906b921d249f23070539faf1ee
    #|31e7f1508da734a6cfb836e38a8c4d1cbb1bff310ec69865b1b862898a8725a62171d588
    #|6b1137446c521c0df17e7a3b4d312d547a5a349d681ad12543bba4ffd1c1d13141af3ed3
    #|9e253c0f3bcfd45c9eb931b329b387f36b733ce62d66cac32487e715a655b884c2a509b7
    #|12f619fe188e597815e1f967fc427fa6a7aa93e915f472ee91bff8d83e89936ea93daf67
    #|3549b988dc8e3df1858e9ae730234cbe326ea7da92ab2da9ed4ceb92f6661b633b593b8a
    #|967d55ee2a49ab4455ad52b59faa37d58b544fac86575dac2a73ea94a9e352294a2d16b5
    #|4354d7506da13e843a1a950d2affa9ecd3114f893aadd6b44ed38ea6279986395d703a6e
    #|ca89a9d4a5634b292c2556da22a93dd2c7484f910651ba4eca8754165291b3d4b2f562bb
    #|622dc49a867d858d107624cb192bfe3af195e8b5a66b55ad35ad0e5acf598364ddb7725b
    #|45621d7a94ea28bdd15aa3ed2fd1b6e2884a4474f8d3f855bda36ed23ff3a87ce7399eb2
    #|0bc5a777cd2ea94b6597fc8f83e318f18aa6e76198e6a572abdc56a32db35a1f6abda615
    #|9716852da1b5a4d19abf8af6aa1257955ad556954f553153b5922a9a550c560957351355
    #|54a72a9baac2549ea27a11557ca8624335112a12a9a4a39a07d52ca88a3cd576caafa9af
    #|a62e34153553b34c31644ac8a9a998225faae252a5a53a957295d44d5231929a8c144b29
    #|f9a466932209a9a2b3aa66f56579655d8a151ed66258a4b064c89a1a6b1c2c8a6015bfea
    #|7875d7ea51ab105a8d66c5ca4ace958cab91ad8862d53baa7394a551a78a0a53d482a2c6
    #|89e2489414a32816558ca89abfe5dbfda30fa907d1d7b94c3ec20fedd478fdee6e8b6daa
    #|dff248e68ca5c4627a8226ce35e1d65bbb74b61454a5954afb94b8298948698825ea4af4
    #|28555e6472d1dba2881605ab684345ac29124bd18414d1aca82a8aea13394e649ae853a2
    #|6811ed44c4119190104d49441f516d4495202a7dc8f5d0dfa16087563444cf90c40c0d65
    #|888643541b2ac7502386cc0b452b142fa1ad84282424344253119a538846a19209b927f9
    #|267d26c594b42a124d24069184439a115279a4c64865903c1fbd3c8a77b47534a9118946
    #|7319d16444c251d1466d8cfc077d0fba3828aa418c0a1252d0cc044d49109941150c2a17
    #|e48920d71ff3273da9ced2e5f3d99c445ec457f73eee45a74d9d56749ae7b498d3444edb
    #|e3b4d3e4a6914d7b99b6324dc8b48598469a3633adc234bfb478697469d3d216541aa734
    #|92d2cad2bed2b6d2244aa3176d6bd1a48a4654b44ed1628a4629dab068b5a28d27da9868
    #|55a2b9881645341a8d46a3d168341a8d46a3d168341a8d46a3d168341a8d46a3d168341a
    #|8d46a3d168341a8d46a3d168341a8d46a3d168341a8d46a3d1fccf66b3e967b3d96c369b
    #|cd6674cf5ecf66b399c7b3d96c369bf19d8d3b9bcd66b3d96c369bf535bb6b36d76c369b
    #|cd466a369bcd66739a9569369bcd66b3d98c46b3d93f33f1cc66b3d96c369bcd667599d9
    #|320bcb6c369bcd66449975327bc86c46e66c369bcd66b3d96ce66f16df8cde6c369bcd66
    #|b3d96c369bcd66334fcc6262369b3962161133feb2f165ed65afcb5697095d4673d979d9
    #|7899ec328acb7acb6ecb68cba6965559166419c7b211cb8a967996c52c635836afac5cd9
    #|5a9954654495752abb5436a94c5819adb246657bc9c625ab96cc55b2a892914a3653b292
    #|929925e34a3651b23ac96e92cd2493928c8a6425927d4826423222c93a923d48261f5979
    #|64eec8a2231b1a59cdc82c230b191939b2d9c82a46e68b6c171955642d919d443612998c
    #|c84844568aec13d926b23a65366561ca58caa6282ba2cc43590c6514ca6a9439288ba04c
    #|3e1979b276b2d764abc98426ab4c764e364e269b8c62323f64f190d1219b86cc14b2a090
    #|71423612b262c8bc90c91821a39f7bcfade7a4ce119deb9cbb9c9b9c139ea39d8b38c79b
    #|1b9bab9a73998b3247323763aec45cd01c678ec25c5fee2e37979396a32a572ab7292752
    #|8e58ae2bf728c728372fae5c9c5b1cabb8a1e26a8ab31417521c59dcacb846713f7162e2
    #|a8c4b5883b1137224e863812e24ae23ee22688ab0f670f171e8e1d6e6ab8a2e13cc3c50c
    #|371cae36dc63b8e1e4c291856b857b09b712ae22dc29dc28dc4cb80ae17c72717234b92a
    #|72267241e438e446c815c97de4367212e4ea71efb8759cd438a2719d7197719371c2718e
    #|7111e3f8e0c6c15583730517151c29b899e0cce0c6e064c15104d77fbbbfcddfa4dfa8be
    #|7dbe6dbe897c2b7e8b7d637c9b7b2b7b8b7a63791bf256e3cde22dc49bd01bcd5bc3dbde
    #|4ddc8ddaadd5edd46dd44da61b4937b31bd76da25bbd36bbb6706d6c6d53b515d5e6a94d
    #|a436626d5d6d8fda16b5c96923d3d6d2f6a24d88361ada2ab485d046d236a3ad82367fb6
    #|f86cd3d9aa6633cd16341b673692d9cad9bed9b6d9e8b2d5b2bdb2adb249c946245b47b6
    #|18d928b2d56473c816211bcf6dccadcacdc52d8a1b895b85dbc96de426e346c1addf766f
    #|9bb749b795b67db671b68d6cf3b6c5b631b6cd6373638bc6c68a6d28b64e6c97d826b109
    #|63a3c5f63fb63f267e8cfa58ebb1d363a3c7661e2b792cf818f7d8c46375c76cc7c28eb1
    #|8e4d3956e4d8c63111c7888e758e3d1c5b38266f8cdc58dbd8aab1a1c66a1ab33416d218
    #|d9d8acb18ac6fc8ad1159b56acaa62a68a8d2a265331928a9515fb2a2651313ac56a8abd
    #|145b292645b1228a79281643b121c56a1473502c8262fcc4c613ab4ecc35b1a889d14cac
    #|32b17362e3c46413a398582fb15b62b3c4a82466925890c4381293a2c4c69318c524560c
    #|89b5cc985dc61e652ca4181b1163eb30c60b6332616c848c5183b1fa17ebbe98c58b9dba
    #|d85b8b45d462232dc699c5c65c6c828b11034341d60469093224485604b97f147fa47e6c
    #|7d3c7d1c7d64f9f1fbb87d94f858f7687b0c7b643dd2e331c623c5e3d063cda3c3a34779
    #|47be3aae3a0a75a4e958e978761c3bca3a325e235de3b4c6aa1a4d3506d5c8a971a4c662
    #|8d354ad448a7b1a6f1a571a5518a46221a3b344e6814d248a3d141233fe378c6ea8c24cd
    #|383363c98ce68cdc8c1433f632522a23958c25193f326e6414919128632723e71ccb1c5d
    #|8e518e2c8e431c6b385a388670a4711cc7711cc791e3388ee368c73872f4c4388ee3f888
    #|711123db075f0fae1e147a90e6c1ca83e783e383f41d8c3b483b3875b0ca419383410e72
    #|1ce4e7e0e6a08483f406eb06df06d706a51a246af0d2e0a4c16183b5061d0d4634c85770
    #|5c4146559054c1990a9654d0ace058415905292ac89982520a5251b044c10f05371414a1
    #|6091826450703ec1f204dd094627c89ae0d0046b2648e10469136c4cf097e02e41b104a9
    #|126c49903212342518942027c10909d619b419e41483450c7a188c6150844122830c3e18
    #|247941be16a4d08224493f82f108d2119c46b02a82a6080645906504bf08522282f4bffe
    #|df7ffda5fece1ff353fee15ffb1d7fc4cffb2e3fca27f9347ec53ffdd197f97d7ff7732f
    #|eda9fa52ffe939fd481feb19fdbc5eaebbf5689d551faa77ea93bab04eab37ea3f7da78b
    #|e9543a893e432fa19bf4209d3e41afcfd9f9d4bc68fe996fe62273e2bc9bcbe564792b7f
    #|c957f221798ddc229fc92be43e1fe7697eca57f1277ec493f025fff11b2fc1d3f77a7ff7
    #|752fda3d7bcc4ed9877b6d77ec117b35ee8aafe242719a78257ec6c7787fdff77c4befaa
    #|db7407dd9cdbbb6337e39edb65dbb5a3b6944d645fec892db46dfbaff75a5c47d5a47aa6
    #|2ea9cd3a5873f5441d2e4bcb54e552f953de9445cac4f2a22c2793c92d394a669187c835
    #|64923c235790fd717c4c8fa9e3d6f8349619938ccbf137dec61263bab816bfe2297191d8
    #|238e1153c443714dec108fe9967ed12b5a88a6a12bf449cb680aba9fef999ea773d56c9a
    #|83e6e2eccdb19931cfc3e5f01b5ec39df0253c090bc36e84ff777f5d6fd44b7a67de92d7
    #|7c832ff76eb7bbd99dd41d95bb92bb8fbb8d3b11777bb85bb893b72bb773db45dbb1da0d
    #|b55b483bb2ddac5d453bbfbabd3a7175d4ea5ad58daa93a98ea4bab2baafbaad3a89eaea
    #|d4d9d4b1d44d5157449d87ba18ea28d40da9ab5137f974e4e9dae95ed3094d47335d65ba
    #|c9a6a398ce972e2e1d2ddd54ba2ae94cd26d44baa2749e7431e924a4a3b3abd9bdec46c4
    #|aec3eec26ec24ec88ec6aec12e82ddaaeb5ceba2d691d6cdac2b5967ae0bae5b1fdd1ddd
    #|1c9d343aaae84ad17da2db44b72eba8e11ddfcb5f26bee6bd1d758afcdf25ac86be46bb3
    #|d71aaffdaeedae895da3ba76726de49a8c6b24ae95ae7dae71ae4db8566f2ddc1adbda54
    #|6b45ad795a8b698dd2dab0b52d5a93578d5cb5b66aabaa09558da66a1bab36ab5a45d57c
    #|aac5a946536d4ab52aaa8d43b511aa15a9f6516da39a04d5e853aba736a9a9114dad33b5
    #|cbd426531b4ead3635c7d436965a556a2ea945498d24b519a99548cd94da28a4d6b376b3
    #|36b326658d8ab5126b1fd65664cd632dc61a83b5f96ae5d5dcd5a2abad6635cb6a93d584
    #|abd1566bacf6476d8f9a386aada89da2368a9a4cd448a266462d18b5da44d4ecd3c2a7b1
    #|018cf7a8f44761034089fef6435004331d0001000000008061147b1420171213011f40c0
    #|0004fceb62fb0ff7f156cd1becefe25afe06747cfcd9bb0477a602ac43b5c9b596cb4542
    #|4a0720393b20773fab42c2e0fe60a90dfd035aa539339669c9569cfd0a00ab103071afb5
    #|7262d8650c4f3b0a92dc3f5fe64bb6930b9e3f721f9d928ee54c6ccfd9fc4fa547d8be92
    #|bc57f77f370f7d9ec4b7bdcdad4e1a058ece431f6fd79366da0bb7d6d57d0cd872f158d8
    #|70a7687ef80737880e214c284a144afedf99b0ff20c5915534a6dde979c9356fd2ca6b3f
    #|66584166a12d9c929542b62cffd9f79d52651914b41b98662e07697eccd3a441bc955750
    #|3bd9eab93b4a4c1619ba4d754986b6c68bcc91fbc6358517f7d3185ecbb73f4b9138fa1d
    #|7aad0ead4dda74fa842a2e3a0393b26d1def9377cf0e4bf63e6dca23b7ca698bae6859af
    #|9601a9494392f76cad6e69cb91e678a2f970bf5af5a449d1fb79c9ad15942adfd3b64d10
    #|2092b0e6a9a8c5a9922ed6bd9f30668a9a450a9cae691e62f14db9b87887f2a0b4325ba5
    #|aba906027cc97cbdb85137c305ec83562e91422aa8640aced2272513da5119a233b7cbb5
    #|7ecc0c69e74c7583287bbf4f73264f19280713c6dacc4085908d3b35cd0f8dccd04a1302
    #|fef57c30607044a49861b0135f31c001888c4c82a04288ee817095cbc46dde18183a4262
    #|ee301c5550ca991f5c3c3e09191b2c8cb2ee442a1ac1e409302829f9bac090342085c39a
    #|90cee7f82c7fda080e29437618da25360853584dc90832d222f0f8c8b8658a9d94129749
    #|31990381911217018495ef616442e48dcc40818504c5c21ffc316672a1b2a3c7e1e88543
    #|2793ed1c472e333d050f89951a45510a622e2bc96848581ca9e97c507446828611d0bae2
    #|8705894f42c208cdc7148228f1a7c761afdad98b3e67850652600292799a41bcbcf33065
    #|e34766b3c343e21d6f0c341bf68516770a89132a3b852cb1f92f997f22b44c19d9d9509c
    #|c8fc097f7c4920aae04b1fc36346ca00c323183a20f0c5c3d326937183e43305a1f5f7c3
    #|e270499133a0602c2b6575c16c1f479c9d86e3c74bc07666f4f2a498387cc66436381089
    #|fc55525ca6870160a141f17293a091ada220e5be7812820b11b38155d42c8a123394ab8c
    #|1ebdb8133cd151706cb404d60d3a88d3ae81ab33e9e9a79b12ece13d983cd79f77a98e70
    #|6e03fb5144ae6f79d25d80eec1adf62b9adf036a37bdf3b8447e8991f4475adaacfa5bf1
    #|73bf5bffd8715482be1fd99b7409cd6357dc89fa4ed3b54e3254e47930268d83a6f4d847
    #|e81a8a30cd4da419d9b11621ef81803863ea64bca6ab4329a2ed21c20f8d119c082322bd
    #|9e077561a6ab68c11966f7eb9b0ee5fa2fa636fbde37eee485f6d71e65943ef8a885d7fd
    #|fa0044714f0d09824b8b110c60abd31eb94822f0046274565675979ae2d592c68a09d9ab
    #|22a75e8a7f178d31de2d58c94ea7166f64ff851127a362df7297926a549e06a6570aed57
    #|ab94626fe53b4c1651a8df89065feeeda9baa7eac6f6feaa4f03c84df5399f88a7883b94
    #|7618e1271de18dbb5f64126595b9d32d42b820f594f4e7279252b11a8c424e23a9595e15
    #|a587c34e65c3724476d71625971ce4132d2ce29febf5c491f299198e5a19fdefd7320bc3
    #|2445ea3d443501a5463006cd9ede319822fcc7a025f71b831feeef18c6459c68145f79d1
    #|f8cbe8466330d889903742df35552b9be8998025a399a8cc47cf9e7c8ae6b7ff35bae80c
    #|cc864234a88dfe3a11370b49a36c5a4820150a054f60f3e670c1cda74bc39bb76a8736ff
    #|f920dc7c8c48b079519e68f33faec2cd07c605db37dd07854acd74b1a969e0ed8649dbfd
    #|4d6deb731bbf40d04e8b548148285004d7efdf17e3ccf03c967328d4b3ee5076259c6926
    #|19b042ea38f3440b7fa0e53f6204bb8f97094c2fd6144afef759b0ff20c198552dcdc5ae
    #|729b39dd64746cf504f6fae97606d2e2f73736e5ad1db575c955a6276de0c42dfbaae8d8
    #|f1e873762882bfe609ecb345497ca337f619ed30984128e583dfa6789d76aac49bf6486e
    #|c2998b841f1f6768253e3e63997fa926ce05e00f4d639017dc6002aa1ed10cf07f7b4058
    #|3957a6366eab74d5a155012948f855f9118f0ed351e5ba16ee163ea5556288449647232e
    #|b37f1add842876a6feb1ff44ddbf6f422217467389a92674a7e9f36fa4ac7521ac626a2a
    #|d6cc0a42215ce14873fb820ba4576c72dc37fab7b75e85e6fe7f1269f796436cccd9302d
    #|7db6653179f02ce61787b6ea9429fadf966d648558d479b9576b05187941723cc1c71f86
    #|ba159b9af4d7b811d47720e256ef82edeb7a53aa5bb58f57ce98cb96ce480aefff0c5ecc
    #|2cb49764b252f898e53f2b3f53aa2c637aad1733ebfc9069b39525cbcba21a7028f0a979
    #|3b13db9beabf86b7bf3709bd5f7c73f7ae7204ebf3134b837dedce470bb056e55245811c
    #|53615d173f0ccc4d316fa002b15b8a0ce2d244c0e0735b02076f821428f89f6201830fe8
    #|0b10bcdc658c4599ebf8e468687443f8661b363235448492b5597b35e11b72959b1a13de
    #|bf185d2391faa68d22b669e867a5890cc44437e0b175dce39ecfbc0551e673176c5fb15f
    #|e1320ebf918c26f4734203625896611ec959f9de5da84a8b3c6f5a5bdedf9510bbedfca3
    #|414bf8719a32ff78cbee0e6e4bef4e9fd386e375396a76411f355e32f1e89cb0fc7da1e8
    #|18246d96efeb2ae8a29bb759ffe6342bd8dfe49d06f7fc44ef49b3dd853249a86e4f34fb
    #|86a510abfbc0f4a815e2e1a5f17748df65cdacda55c3d3377fabec0bbba0fd9f3d5cb409
    #|0ab32dfb1e6a258690dff6ca7cbb760ddadfa2ed06384541a755f3d91db60d908f0cc0d6
    #|f66cbfdbb4350e2090473dec5eb5db18ff0070cb795fbf643cff7bff37d9518ce6dbb27d
    #|bd97b8cade7a6f5751d40ee667fa10197afd5b4518f7bda455b3d91dd6d8cf9be7b647d5
    #|917eaaf46fb57ccfe5d65bf385510b141f49d9ff74cbcc77f7a6bde3e1946fbf2a6fdb2d
    #|d025f665ea74691c92aac74af7ed6eb51ffdbc118945e7dfe5c9b33af7fbbfc98fd26b99
    #|9ccdde6b892390595fba8ba2364c2cda32dde996bae0beb77d87c335f17d759ea45f606c
    #|dd4aeab6d23828deced54adbdf8a8776f9e9dbeaf8dd61ed9d72f3166aba02704527267f
    #|3e68ab053dda55dd18372ebd20e452aa197463dcbaf4d2aceaa8bc159c4a72ebea45bba2
    #|13e366efca76b4006da54e8c5bd762d8c268a0860a969f1f890d8e0b000505c94c4f4245
    #|c58a86432462f98b1a1eff2ce955f65ed96026a95ee635b88d3f9aafcc5fbb5532b66ded
    #|7fc6769468af3abfca965f68b5b2bfc16d55d07c65fedaadebaf6d6bff33b6073e7bd5f9
    #|55b6603cab55c500412182b1e5ea4af0d4341e3248761e1d182906180e10323a0c1bb6b5
    #|5b739d962471de27c0ae8346dbf76583c84e56f55ddfc3f0334ce5cbf1b259945769d765
    #|a5b081ad8b9ff50172daab232fcbb5e566544b5defa5c130a26ef22cef21202a02188d0e
    #|29028b8b4fa9474282d10333b3c1c1925e8e50381a10216698ab700e1f127b69df569d04
    #|aaebdbae0ca5a867d7b7bd15f53e67ba675b824aaacddc4ffbb6ead6cc79df7665280d30
    #|bbbeedada8bf2cd33ddb1254e252e67e5aafabf97f62532b8265336222fb3d643129077e
    #|ab72d718fa7afed03cd96a110b87c74b000687c4c6e31d7ea888d1707488f82472fc7e0e
    #|c7169ad0fc5e0c561d839bf74b2b91b3a2e5adde06e19344c98bf36559c0c3d2afe5ca60
    #|b30b97beeb43e16408275e9665c82d0a8a5ade4bcb9003def429df06d3f397bc3e5f88b3
    #|ec9f7ec091916185a05b78df7116201a3a349b8e8c481349bfa2a3c000a9c191b0602742
    #|71cf962d13c5faf69fe377cf86a7ea8a97e70bb1acf3d2abc5ca660be48bdff503715ef0
    #|93abc5dae66edd92d677133110ed9b3ac5db66d2d692d7e70b71c2e9d32bc7869b6fa015
    #|12351d87448a95cd0648c44a9e0f42a3060b8ddd4c5ae4192e82f6281b33197fdee7ac02
    #|fe854daf9c6b8cc1fecab6bc35c0c4784abed62b8355e44eb6ae4fc48e6b4faa9e2f9be5
    #|c94eb6ae4fc4565e4faa9e2f9b75af4eb6ae4fc41e514f2aa214303e7edba01205460c81
    #|41d124256752c8875236382e0014144832bf49a9e76528fffba2ec6a93bfa6f5da7b0286
    #|fa65efa14d9792f6b6d5d95b5b84fa77efa3fdc3d1bfa4d5d93bb4c2eb77eea26df090fe
    #|a4d5db1b0d817a65efa3cd1c90f634ddd9b7ccde9c013052237320e80295748e2a350b4a
    #|8b949c1d4581dff65369b848e119189d9d779d3ff9aba7820c83fd7bf31b544ab47c6f53
    #|af7d2f4efdbdf14fb1db997e7fb32bb4a78cfcafe9cfbe6b7fbebeb157b13772febff90d
    #|da7d32beb7a9d7bec757fedeb8275b005109d320a1c1b125e09080e8ab1e2c193b349e8f
    #|0c243edd8701f38374405ebe2b105ce4e95d4f408c5aa1b6ec95ddd92df2e9efdd8aecb3
    #|37dfdbe5ecb6c0edf5dbfdc0fb0c36dfdbe5ecb672eaf5dbfdc0fb6534dfdbe5ecb624e7
    #|f5dbfdc0fbbe321f650e0022447457aca786404361129367e168f0f7220d2e3a3b8a1b0e
    #|17018544e14b3eabf4e586ece3493f7854a400502be1fb86dbd9007a37e0eb876e4980b2
    #|2c6e3d6c66dac43637fc1d844d09fce6a35fbf847d6c581e427c2dd9efbff3ff6d18f257
    #|fe7bfe6a57f873d2be7fdca6f70f088c1300b6355612b015248d010c206a9239697bef2d
    #|d30f734e49004d00540072307218b9c83299ca81900759c6ae608fdaa2f668cfec923db6
    #|77ef0a7b8c8b71094ef5805ee4b4071f5ec2698847203e24ae110f110b116fe2292e211e
    #|419c827050e150e1140e08c1a18253b04c304970b0e0b0e08307a30ea31ed45375513da6
    #|16534fea43d442d40bf50cba023a04f4a285e841e8a3254d820e021d027dcc12cc05cd9b
    #|7964aecde32cce13f384f9409692890213db09db1af7ea12dd606e985baeecd21b881bc4
    #|95219602b141890d25762476466c89d831b162624788ad20768cb062849d0a1b50d84061
    #|d3c206c3ee2e8d71108c43305e331e321632dec6735c623cc278bc2a8100c0905a21b55b
    #|edacad1da1b67683f6205a195a12da60b461b4d38aa01dc6ec60566a966876ccac98d9c9
    #|ec6cb610b30bb333642b901d252b4af6c94a5912b241900d41f6d84ab0a5dade6c47b6b5
    #|edb815b7018109a8311521023f31c79f88980712c83128c1ff0842f0d7fc01da90226449
    #|bafa0b0474272c4c53ac9e07772df80fde7c3b06f83f15c3a0b1d3755fcd0b96694c10ac
    #|4e57af08b75c91113720d6ce5852be8c467abd7715bf288c620573e7f57693f83216ba95
    #|3097efdb4fb2944ac8dded3dd34e7ee2faf6eedf2b6d84c58d232e730d5e99116459f345
    #|ae5611bfd6d5fc50f76209c79a6b08986fbeee079bafcd5e28059219192476d7d55b9a4b
    #|dee54d22bead4f7f6928d29565cc8eb63efdada1ac50922128b1f9baafc64228298669b7
    #|a6ebbe9a976ec898c0a89aaedef2fbf1396df6bdbd3ec38fa60d58a0613ce70258f4450c
    #|aee8ecffc58c5b7b214a9062c8d0ce5fd77d35209a8830c340335d5bb3e98e
  ),
)

///|
let zstd_ack : Bytes = hex(
  (
    #|9000007b226f70223a31312c2264223a6e756c6c7d
  ),
)

///|
let zstd_ready_length : Int32 = 141141

///|
test "zstd-stream decodes reference zstd output message by message" {
  let inflater : &Inflater = ZstdStreamInflater()
  debug_inspect(
    inflater.push(zstd_hello),
    content=(
      #|Some("{\"op\":10,\"d\":{\"heartbeat_interval\":41250}}")
    ),
  )
  // Compare without printing 141 KB on failure.
  guard inflater.push(zstd_ready) is Some(ready) else {
    fail("READY did not decode")
  }
  assert_eq(ready.length(), zstd_ready_length)
  assert_true(ready.has_prefix("{\"op\":0,\"s\":1,\"t\":\"READY\""))
  assert_true(ready.has_suffix("}]}}"))
  debug_inspect(
    inflater.push(zstd_ack),
    content=(
      #|Some("{\"op\":11,\"d\":null}")
    ),
  )
}

///|
test "zstd-stream reports corrupt streams and invalid UTF-8" {
  let cases : Array[(String, Bytes)] = [
    ("magic", b"\x00\x01\x02\x03\x04\x05"),
    ("utf8", hex("28b52ffd0058100000fffe")),
  ]
  for case in cases {
    let (name, input) = case
    let inflater : &Inflater = ZstdStreamInflater()
    try inflater.push(input) catch {
      Malformed(_) if name != "utf8" => ()
      InvalidUtf8 if name == "utf8" => ()
      error => fail("\{name}: unexpected \{error}")
    } noraise {
      _ => fail("\{name}: expected an error")
    }
  }
}

///|
test "a stream that ends is malformed" {
  // A whole zstd frame: the stream that should never end ends after it.
  let frame = hex("28b52ffd20136d00003868656c6c6f2c200100e28a11")
  let zstd : &Inflater = ZstdStreamInflater()
  try zstd.push(frame) catch {
    Malformed(message~) => assert_eq(message, "zstd-stream ended")
    error => fail("unexpected \{error}")
  } noraise {
    _ => fail("expected an error")
  }
  // A whole zlib stream, followed by a sync flush's suffix.
  let zlib : &Inflater = ZlibStreamInflater()
  try zlib.push(@zlib.compress(b"x") + b"\x00\x00\xff\xff") catch {
    Malformed(message~) => assert_eq(message, "zlib-stream ended")
    error => fail("unexpected \{error}")
  } noraise {
    _ => fail("expected an error")
  }
}

///|
test "zstd-stream refuses messages over its limit" {
  // Inflated: READY decodes to far more than its compressed size, so only
  // the output check can stop it; the buffer stops growing near the limit.
  let bomb : ZstdStreamInflater = ZstdStreamInflater(max_bytes=20000)
  let inflater : &Inflater = bomb
  assert_true(inflater.push(zstd_hello) is Some(_))
  try inflater.push(zstd_ready) catch {
    TooLarge(limit=20000) => ()
    error => fail("unexpected \{Repr(error)}")
  } noraise {
    _ => fail("an oversized message inflated")
  }
  assert_true(bomb.message.out.length() <= 32768)
  // Compressed: one WebSocket message is one Gateway message, so a message
  // over the limit is refused before it is decoded.
  let compressed : &Inflater = ZstdStreamInflater(max_bytes=1000)
  try compressed.push(Bytes::make(1001, b'\x01')) catch {
    TooLarge(limit=1000) => ()
    error => fail("unexpected \{Repr(error)}")
  } noraise {
    _ => fail("an oversized message decoded")
  }
}

///|
test "the default inflater follows the requested compression" {
  let zstd = default_inflater(ZstdStream, max_bytes=1000)
  assert_true(zstd.push(zstd_hello) is Some(_))
  // zlib-stream waits for its sync-flush suffix, which zstd input lacks.
  let zlib = default_inflater(ZlibStream, max_bytes=1000)
  assert_eq(zlib.push(zstd_hello), None)
}
