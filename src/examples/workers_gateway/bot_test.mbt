///|
fn example_session(id : String, sequence : Int64) -> @discord.BotSession raise {
  let ready : @model.Ready = @json.from_json(
    @json.parse(
      (
        #|{"v":10,"user":{"id":"1","username":"bot","discriminator":"0","global_name":null,"avatar":null},"guilds":[],"session_id":"SESSION","resume_gateway_url":"wss://resume.example","application":{"id":"42"},"shard":[0,2]}
      ).replace(old="SESSION", new=id),
    ),
  )
  { gateway: { id, resume_url: ready.resume_gateway_url, sequence, }, ready, }
}

///|
test "BotSession persistence round trips two shards" {
  let sessions : Map[Int, @discord.BotSession] = {
    0: example_session("first", 41L),
    1: example_session("second", 99L),
  }
  let decoded = @workers_gateway.decode_sessions(
    @workers_gateway.encode_sessions(sessions),
  )
  assert_eq(decoded.length(), 2)
  assert_eq(decoded[0].gateway.sequence, 41L)
  assert_eq(decoded[0].ready.session_id, "first")
  assert_eq(decoded[1].gateway.sequence, 99L)
  assert_eq(decoded[1].ready.session_id, "second")
}

///|
test "invalid persisted sessions fail closed" {
  inspect(@workers_gateway.encode_sessions(Map([])), content="{}")
  for text in ["", "nope", "{\"x\":1}", "[]", "{\"0\":1}"] {
    assert_true(@workers_gateway.decode_sessions(text).is_empty())
  }
  let bad = example_session("ready-id", 5L)
  let mismatched : @discord.BotSession = {
    gateway: {
      id: "gateway-id",
      resume_url: "wss://resume.example",
      sequence: 5L,
    },
    ready: bad.ready,
  }
  assert_true(
    @workers_gateway.decode_sessions(
      @workers_gateway.encode_sessions({ 0: mismatched }),
    ).is_empty(),
  )
  assert_true(
    @workers_gateway.decode_sessions(
      @workers_gateway.encode_sessions({ -1: bad }),
    ).is_empty(),
  )
}
