///|
test "flattened event decoders pin missing-field and wrong-shape failures" {
  let wrong = Json::array([])
  expect_model_decode_error(
    wrong,
    "expected guild member add event (object)",
    (
      @json.from_json(
        @json.parse(
          "{\"guild_id\":\"1\",\"roles\":[],\"joined_at\":null,\"flags\":0}",
        ),
      ) : @model.GuildMemberAddEvent),
  )
  expect_model_decode_error(
    wrong,
    "expected integration event (object)",
    (@json.from_json({ "guild_id": "1" }) : @model.IntegrationEvent),
  )
  expect_model_decode_error(
    wrong,
    "expected thread create event (object)",
    (
      @json.from_json(@json.parse("{\"id\":\"1\",\"type\":0,\"flags\":0}")) :
      @model.ThreadCreateEvent),
  )
  expect_model_decode_error(
    wrong,
    "expected thread member update event (object)",
    (
      @json.from_json(
        @json.parse(
          "{\"guild_id\":\"1\",\"id\":\"2\",\"join_timestamp\":\"2026-07-18T00:00:00Z\",\"flags\":0}",
        ),
      ) : @model.ThreadMemberUpdateEvent),
  )
  expect_model_decode_error(
    wrong,
    "expected guild audit log entry create event (object)",
    (
      @json.from_json(
        @json.parse(
          "{\"guild_id\":\"1\",\"target_id\":null,\"user_id\":null,\"id\":\"2\",\"action_type\":10}",
        ),
      ) : @model.GuildAuditLogEntryCreateEvent),
  )
  try
    (
      @json.from_json(
        @json.parse("{\"roles\":[],\"joined_at\":null,\"flags\":0}"),
      ) : @model.GuildMemberAddEvent)
    |> ignore
  catch {
    @json.JsonDecodeError((path, message)) => {
      assert_eq(Repr(path).to_string(), "Key(Root, key=\"guild_id\")")
      assert_eq(message, "missing required field")
    }
    error => fail("unexpected missing-field error: \{Repr(error)}")
  } noraise {
    _ => fail("expected missing guild_id to fail")
  }
}

///|
test "lossless webhook message views emit their original payloads" {
  let lobby_json = @json.parse(
    "{\"id\":\"10\",\"type\":0,\"content\":\"hello\",\"lobby_id\":\"11\",\"channel_id\":\"12\",\"author\":{\"id\":\"13\",\"username\":\"Nelly\",\"discriminator\":\"0\",\"avatar\":null},\"flags\":0,\"future\":true}",
  )
  let lobby : @model.LobbyMessage = @json.from_json(lobby_json)
  assert_eq(lobby.to_json().stringify(), lobby_json.stringify())
  let lobby_again : @model.LobbyMessage = @json.from_json(lobby.to_json())
  assert_eq(lobby_again.id.value(), 10UL)
  assert_eq(lobby_again.content, "hello")

  let deleted_json = @json.parse(
    "{\"id\":\"20\",\"lobby_id\":\"21\",\"future\":\"kept\"}",
  )
  let deleted : @model.LobbyMessageDeleteEvent = @json.from_json(deleted_json)
  assert_eq(deleted.to_json().stringify(), deleted_json.stringify())
  let deleted_again : @model.LobbyMessageDeleteEvent = @json.from_json(
    deleted.to_json(),
  )
  assert_eq(deleted_again.lobby_id.value(), 21UL)

  let direct_json = @json.parse(
    "{\"id\":\"30\",\"content\":\"dm\",\"recipient_id\":\"31\",\"future\":{\"kept\":true}}",
  )
  let direct : @model.GameDirectMessage = @json.from_json(direct_json)
  assert_eq(direct.to_json().stringify(), direct_json.stringify())
  let direct_again : @model.GameDirectMessage = @json.from_json(
    direct.to_json(),
  )
  assert_eq(direct_again.id.value(), 30UL)
  assert_eq(direct_again.recipient_id.map(id => id.value()), Some(31UL))
}
