///|
test "public BotSession JSON round trip" {
  let saved : @bot.BotSession = @json.from_json(
    @json.parse(
      (
        #|{"gateway":{"id":"sess","resume_url":"wss://resume.example","sequence":"41"},"ready":{"v":10,"user":{"id":"1","username":"bot","discriminator":"0","global_name":null,"avatar":null},"guilds":[],"session_id":"sess","resume_gateway_url":"wss://resume.example","application":{"id":"42"},"shard":[0,1]}}
      ),
    ),
  )
  let encoded = saved.to_json()
  let decoded : @bot.BotSession = @json.from_json(encoded)
  assert_eq(decoded.gateway.id, "sess")
  assert_eq(decoded.gateway.sequence, 41L)
  assert_eq(decoded.ready.session_id, "sess")
  assert_eq(decoded.ready.application.id.to_string(), "42")
}
