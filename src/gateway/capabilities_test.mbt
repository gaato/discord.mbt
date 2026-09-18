///|
async test "identify sends capabilities only when opted in" {
  for
    capabilities in [
      None,
      Some(@model.GatewayCapabilities::channel_obfuscation()),
    ] {
    let transport = FakeTransport()
    @async.with_task_group(group => {
      let shard = @gateway.Shard::start(
        group,
        token="tok",
        intents=@model.Intents::none(),
        capabilities?,
        connector=_ => (transport : &@gateway.GatewayTransport),
      )
      transport.incoming.put(HELLO)
      let identify : Json = transport.outgoing.get()
      guard identify is { "op": Number(2, ..), "d": data, .. } else {
        fail("unexpected identify: \{identify.stringify()}")
      }
      guard data is Object(fields) else {
        fail("identify data is not an object")
      }
      debug_inspect(
        fields.get("capabilities"),
        content=if capabilities is Some(_) {
          "Some(Number(32768))"
        } else {
          "None"
        },
      )
      shard.close()
    })
  }
}
