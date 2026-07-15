///|
priv type TestDeflater

///|
extern "C" fn test_deflater_new() -> TestDeflater = "discord_gateway_test_deflater_new"

///|
#borrow(deflater, input)
extern "C" fn test_deflate(deflater : TestDeflater, input : Bytes) -> Bytes = "discord_gateway_test_deflate"

///|
test "zlib-stream round-trips split and consecutive messages" {
  let inflater : &Inflater = ZlibStreamInflater()
  let deflater = test_deflater_new()
  let first =
    #|{"op":10,"d":{"heartbeat_interval":45000}}
  let second =
    #|{"op":11,"d":null}
  let compressed_first = test_deflate(deflater, @utf8.encode(first))
  assert_true(compressed_first.has_suffix(b"\x00\x00\xff\xff"))
  let split = compressed_first.length() - 2
  assert_true(inflater.push(compressed_first[:split].to_owned()) is None)
  debug_inspect(
    inflater.push(compressed_first[split:].to_owned()),
    content=(
      #|Some("{\"op\":10,\"d\":{\"heartbeat_interval\":45000}}")
    ),
  )
  let compressed_second = test_deflate(deflater, @utf8.encode(second))
  assert_true(compressed_second.has_suffix(b"\x00\x00\xff\xff"))
  debug_inspect(
    inflater.push(compressed_second),
    content=(
      #|Some("{\"op\":11,\"d\":null}")
    ),
  )
}
