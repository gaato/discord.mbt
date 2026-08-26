///|
test "webhook PING envelope has no event body" {
  let fixture =
    #|{
    #|  "version": 1,
    #|  "application_id": "1234560123453231555",
    #|  "type": 0
    #|}
  let first : @model.WebhookEventPayload = @json.from_json(@json.parse(fixture))
  let second : @model.WebhookEventPayload = @json.from_json(first.to_json())
  assert_eq("\{Repr(first)}", "\{Repr(second)}")
  assert_true(first.typ == Ping)
  assert_true(first.event is None)
}

///|
test "unknown webhook event type preserves its name and data" {
  let fixture =
    #|{
    #|  "version": 1,
    #|  "application_id": "1234560123453231555",
    #|  "type": 1,
    #|  "event": {
    #|    "type": "FUTURE_EVENT",
    #|    "timestamp": "2026-07-14T00:00:00Z",
    #|    "data": {"future": true, "value": 42}
    #|  }
    #|}
  let first : @model.WebhookEventPayload = @json.from_json(@json.parse(fixture))
  let second : @model.WebhookEventPayload = @json.from_json(first.to_json())
  assert_eq("\{Repr(first)}", "\{Repr(second)}")
  guard first.event is Some(body) else {
    fail("event webhook payload is missing its body")
  }
  match body.project() {
    Unknown(typ~, data~) => {
      assert_eq(typ, "FUTURE_EVENT")
      guard data is Some(data) else {
        fail("unknown webhook event lost its data")
      }
      inspect(data.stringify(), content="{\"future\":true,\"value\":42}")
    }
    event => fail("expected unknown webhook event, got \{Repr(event)}")
  }
}

///|
test "webhook event type covers every documented wire name" {
  let names = [
    "APPLICATION_AUTHORIZED", "APPLICATION_DEAUTHORIZED", "ENTITLEMENT_CREATE", "ENTITLEMENT_UPDATE",
    "ENTITLEMENT_DELETE", "LOBBY_MESSAGE_CREATE", "LOBBY_MESSAGE_UPDATE", "LOBBY_MESSAGE_DELETE",
    "GAME_DIRECT_MESSAGE_CREATE", "GAME_DIRECT_MESSAGE_UPDATE", "GAME_DIRECT_MESSAGE_DELETE",
    "QUEST_USER_ENROLLMENT",
  ]
  for name in names {
    let first : @model.WebhookEventType = @json.from_json(Json::string(name))
    let second : @model.WebhookEventType = @json.from_json(first.to_json())
    assert_eq(first.to_string(), name)
    assert_true(first == second)
  }
}

///|
test "quest enrollment is a known projection without undocumented fields" {
  let fixture =
    #|{
    #|  "version": 1,
    #|  "application_id": "1234560123453231555",
    #|  "type": 1,
    #|  "event": {
    #|    "type": "QUEST_USER_ENROLLMENT",
    #|    "timestamp": "2026-07-14T00:00:00Z"
    #|  }
    #|}
  let payload : @model.WebhookEventPayload = @json.from_json(
    @json.parse(fixture),
  )
  guard payload.event is Some(body) else {
    fail("event webhook payload is missing its body")
  }
  assert_true(body.project() is QuestUserEnrollment)
}
