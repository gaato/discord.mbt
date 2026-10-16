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
    let status = encoder.step(rest, out.mut_view(), action=SyncFlush)
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
