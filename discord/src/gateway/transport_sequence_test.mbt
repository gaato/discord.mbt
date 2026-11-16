///|
/// Shared by the native loopback test and Node's real host WebSocket test.
async fn exercise_gateway_sequence(
  url : String,
  compress~ : Bool = false,
  after_send~ : async () -> Unit = () => (),
  watchdog_ms~ : Int32 = 5000,
) -> Unit {
  @async.with_timeout(watchdog_ms, () => {
    @async.with_task_group(group => {
      let shard = @gateway.Shard::start(
        group,
        gateway_url=url,
        token="local-test",
        intents=@model.Intents::none(),
        clock=@transport.VirtualClock(),
        compress~,
      )
      guard! shard.next() is Connected(resumed=false)
      guard! shard.next() is Dispatch(Ready(_))
      assert_true(shard.session() is Some(_))
      shard.send({ "op": 3, "d": null })
      after_send()
      guard! shard.next() is FatallyClosed(code=4014)
      assert_eq(shard.state(), FatallyClosed(code=4014))
    })
  })
}
