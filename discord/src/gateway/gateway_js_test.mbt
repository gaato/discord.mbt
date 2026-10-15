///|
async test "JavaScript rejects default compressed shard before connecting" {
  assert_true(!@gateway.zlib_stream_supported())
  let calls = Ref(0)
  @async.with_task_group(group => {
    let shard = @gateway.Shard::start(
      group,
      token="tok",
      intents=@model.Intents::none(),
      compress=true,
      connector=_ => {
        calls.val += 1
        (FakeTransport() : &@gateway.GatewayTransport)
      },
    )
    guard! shard.next() is FatallyClosed(code=0)
    assert_eq(shard.state(), FatallyClosed(code=0))
    assert_eq(calls.val, 0)
  })
}
