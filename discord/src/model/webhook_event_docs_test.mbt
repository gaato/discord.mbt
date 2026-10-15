// Source: discord/discord-api-docs @ 845fcaa38e1653d19420311a8e42635eca8de7e5
// Page: developers/events/webhook-events.mdx
// Documentation excerpts are attributed under CC-BY-SA 4.0.
// Reconstructed fixtures: lines 171, 206, 353, 387, 451, 485, and 516.
// Each reconstruction replaces the docs' `// user data` placeholder with a
// complete, plausible User object; all other documented fields are unchanged.

///|
test "discord docs: application authorized example (line 171)" {
  // Reconstructed: replaced the non-JSON user placeholder as noted above.
  let fixture =
    #|{
    #|  "version": 1,
    #|  "application_id": "1234560123453231555",
    #|  "type": 1,
    #|  "event": {
    #|    "type": "APPLICATION_AUTHORIZED",
    #|    "timestamp": "2024-10-18T14:42:53.064834",
    #|    "data": {
    #|      "integration_type": 1,
    #|      "scopes": [
    #|        "applications.commands"
    #|      ],
    #|      "user": {
    #|        "id": "111178765189277770",
    #|        "username": "Webhook User",
    #|        "discriminator": "0",
    #|        "global_name": "Webhook User",
    #|        "avatar": null
    #|      }
    #|    }
    #|  }
    #|}
  let first : @model.WebhookEventPayload = @json.from_json(@json.parse(fixture))
  let second : @model.WebhookEventPayload = @json.from_json(first.to_json())
  assert_eq("\{Repr(first)}", "\{Repr(second)}")
  inspect(first.application_id.to_string(), content="1234560123453231555")
  assert_true(first.typ == Event)
  guard first.event is Some(body) else {
    fail("event webhook payload is missing its body")
  }
  match body.project() {
    ApplicationAuthorized(data) => {
      inspect(data.user.id.to_string(), content="111178765189277770")
      inspect(data.scopes.length(), content="1")
    }
    event => fail("expected application authorized, got \{Repr(event)}")
  }
}

///|
test "discord docs: application deauthorized example (line 206)" {
  // Reconstructed: replaced the non-JSON user placeholder as noted above.
  let fixture =
    #|{
    #|  "version": 1,
    #|  "application_id": "1234560123453231555",
    #|  "type": 1,
    #|  "event": {
    #|    "type": "APPLICATION_DEAUTHORIZED",
    #|    "timestamp": "2024-10-18T14:42:53.064834",
    #|    "data": {
    #|      "user": {
    #|        "id": "111178765189277770",
    #|        "username": "Webhook User",
    #|        "discriminator": "0",
    #|        "global_name": "Webhook User",
    #|        "avatar": null
    #|      }
    #|    }
    #|  }
    #|}
  let first : @model.WebhookEventPayload = @json.from_json(@json.parse(fixture))
  let second : @model.WebhookEventPayload = @json.from_json(first.to_json())
  assert_eq("\{Repr(first)}", "\{Repr(second)}")
  inspect(first.application_id.to_string(), content="1234560123453231555")
  assert_true(first.typ == Event)
  guard first.event is Some(body) else {
    fail("event webhook payload is missing its body")
  }
  match body.project() {
    ApplicationDeauthorized(data) =>
      inspect(data.user.id.to_string(), content="111178765189277770")
    event => fail("expected application deauthorized, got \{Repr(event)}")
  }
}

///|
test "discord docs: entitlement create example (line 246)" {
  let fixture =
    #|{
    #|  "version": 1,
    #|  "application_id": "1234560123453231555",
    #|  "type": 1,
    #|  "event": {
    #|    "type": "ENTITLEMENT_CREATE",
    #|    "timestamp": "2024-10-18T18:41:21.109604",
    #|    "data": {
    #|      "application_id": "1234560123453231555",
    #|      "consumed": false,
    #|      "deleted": false,
    #|      "gift_code_flags": 0,
    #|      "id": "1234505980407808808",
    #|      "promotion_id": null,
    #|      "sku_id": "123489045643835123",
    #|      "type": 4,
    #|      "user_id": "111178765189277770"
    #|    }
    #|  }
    #|}
  let first : @model.WebhookEventPayload = @json.from_json(@json.parse(fixture))
  let second : @model.WebhookEventPayload = @json.from_json(first.to_json())
  assert_eq("\{Repr(first)}", "\{Repr(second)}")
  inspect(first.application_id.to_string(), content="1234560123453231555")
  assert_true(first.typ == Event)
  guard first.event is Some(body) else {
    fail("event webhook payload is missing its body")
  }
  match body.project() {
    EntitlementCreate(data) => {
      inspect(data.id.to_string(), content="1234505980407808808")
      assert_false(data.deleted)
    }
    event => fail("expected entitlement create, got \{Repr(event)}")
  }
}

///|
test "discord docs: entitlement update example (line 279)" {
  let fixture =
    #|{
    #|  "version": 1,
    #|  "application_id": "1234560123453231555",
    #|  "type": 1,
    #|  "event": {
    #|    "type": "ENTITLEMENT_UPDATE",
    #|    "timestamp": "2024-10-18T18:41:21.109604",
    #|    "data": {
    #|      "application_id": "1234560123453231555",
    #|      "consumed": false,
    #|      "deleted": false,
    #|      "gift_code_flags": 0,
    #|      "id": "1234505980407808808",
    #|      "promotion_id": null,
    #|      "sku_id": "123489045643835123",
    #|      "type": 4,
    #|      "user_id": "111178765189277770"
    #|    }
    #|  }
    #|}
  let first : @model.WebhookEventPayload = @json.from_json(@json.parse(fixture))
  let second : @model.WebhookEventPayload = @json.from_json(first.to_json())
  assert_eq("\{Repr(first)}", "\{Repr(second)}")
  inspect(first.application_id.to_string(), content="1234560123453231555")
  assert_true(first.typ == Event)
  guard first.event is Some(body) else {
    fail("event webhook payload is missing its body")
  }
  match body.project() {
    EntitlementUpdate(data) => {
      inspect(data.id.to_string(), content="1234505980407808808")
      assert_false(data.deleted)
    }
    event => fail("expected entitlement update, got \{Repr(event)}")
  }
}

///|
test "discord docs: entitlement delete example (line 312)" {
  let fixture =
    #|{
    #|  "version": 1,
    #|  "application_id": "1234560123453231555",
    #|  "type": 1,
    #|  "event": {
    #|    "type": "ENTITLEMENT_DELETE",
    #|    "timestamp": "2024-10-18T18:41:21.109604",
    #|    "data": {
    #|      "application_id": "1234560123453231555",
    #|      "consumed": false,
    #|      "deleted": true,
    #|      "gift_code_flags": 0,
    #|      "id": "1234505980407808808",
    #|      "promotion_id": null,
    #|      "sku_id": "123489045643835123",
    #|      "type": 4,
    #|      "user_id": "111178765189277770"
    #|    }
    #|  }
    #|}
  let first : @model.WebhookEventPayload = @json.from_json(@json.parse(fixture))
  let second : @model.WebhookEventPayload = @json.from_json(first.to_json())
  assert_eq("\{Repr(first)}", "\{Repr(second)}")
  inspect(first.application_id.to_string(), content="1234560123453231555")
  assert_true(first.typ == Event)
  guard first.event is Some(body) else {
    fail("event webhook payload is missing its body")
  }
  match body.project() {
    EntitlementDelete(data) => {
      inspect(data.id.to_string(), content="1234505980407808808")
      assert_true(data.deleted)
    }
    event => fail("expected entitlement delete, got \{Repr(event)}")
  }
}

///|
test "discord docs: lobby message create example (line 353)" {
  // Reconstructed: replaced the non-JSON user placeholder as noted above.
  let fixture =
    #|{
    #|  "version": 1,
    #|  "application_id": "1234567765431056709",
    #|  "type": 1,
    #|  "event": {
    #|    "type": "LOBBY_MESSAGE_CREATE",
    #|    "timestamp": "2024-10-18T18:41:21.109604",
    #|    "data": {
    #|      "id": "1397729799727878254",
    #|      "type": 0,
    #|      "content": "welcome to the party!",
    #|      "lobby_id": "1397729744753266719",
    #|      "channel_id": "1397729744753266719",
    #|      "author": {
    #|        "id": "111178765189277770",
    #|        "username": "Webhook User",
    #|        "discriminator": "0",
    #|        "global_name": "Webhook User",
    #|        "avatar": null
    #|      },
    #|      "flags": 65536,
    #|      "application_id": "1234567765431056709"
    #|    }
    #|  }
    #|}
  let first : @model.WebhookEventPayload = @json.from_json(@json.parse(fixture))
  let second : @model.WebhookEventPayload = @json.from_json(first.to_json())
  assert_eq("\{Repr(first)}", "\{Repr(second)}")
  inspect(first.application_id.to_string(), content="1234567765431056709")
  assert_true(first.typ == Event)
  guard first.event is Some(body) else {
    fail("event webhook payload is missing its body")
  }
  match body.project() {
    LobbyMessageCreate(data) => {
      inspect(data.lobby_id.to_string(), content="1397729744753266719")
      assert_eq(data.content, "welcome to the party!")
    }
    event => fail("expected lobby message create, got \{Repr(event)}")
  }
}

///|
test "discord docs: lobby message update example (line 387)" {
  // Reconstructed: replaced the non-JSON user placeholder as noted above.
  let fixture =
    #|{
    #|  "version": 1,
    #|  "application_id": "1234567765431056709",
    #|  "type": 1,
    #|  "event": {
    #|    "type": "LOBBY_MESSAGE_UPDATE",
    #|    "timestamp": "2025-08-05T20:39:19.587872",
    #|    "data": {
    #|      "id": "1402390388030832792",
    #|      "type": 0,
    #|      "content": "noice",
    #|      "lobby_id": "1402385687281537066",
    #|      "channel_id": "1402389638311841883",
    #|      "author": {
    #|        "id": "111178765189277770",
    #|        "username": "Webhook User",
    #|        "discriminator": "0",
    #|        "global_name": "Webhook User",
    #|        "avatar": null
    #|      },
    #|      "edited_timestamp": "2025-08-05T20:39:19.557970+00:00",
    #|      "flags": 0,
    #|      "timestamp": "2025-08-05T20:38:43.660000+00:00"
    #|    }
    #|  }
    #|}
  let first : @model.WebhookEventPayload = @json.from_json(@json.parse(fixture))
  let second : @model.WebhookEventPayload = @json.from_json(first.to_json())
  assert_eq("\{Repr(first)}", "\{Repr(second)}")
  inspect(first.application_id.to_string(), content="1234567765431056709")
  assert_true(first.typ == Event)
  guard first.event is Some(body) else {
    fail("event webhook payload is missing its body")
  }
  match body.project() {
    LobbyMessageUpdate(data) => {
      inspect(data.id.to_string(), content="1402390388030832792")
      assert_eq(data.content, "noice")
    }
    event => fail("expected lobby message update, got \{Repr(event)}")
  }
}

///|
test "discord docs: lobby message delete example (line 425)" {
  let fixture =
    #|{
    #|  "version": 1,
    #|  "application_id": "1234567765431056709",
    #|  "type": 1,
    #|  "event": {
    #|    "type": "LOBBY_MESSAGE_DELETE",
    #|    "timestamp": "2025-08-05T21:44:09.412957",
    #|    "data": {
    #|      "id": "1402406637632884857",
    #|      "lobby_id": "1402399883394285659"
    #|    }
    #|  }
    #|}
  let first : @model.WebhookEventPayload = @json.from_json(@json.parse(fixture))
  let second : @model.WebhookEventPayload = @json.from_json(first.to_json())
  assert_eq("\{Repr(first)}", "\{Repr(second)}")
  inspect(first.application_id.to_string(), content="1234567765431056709")
  assert_true(first.typ == Event)
  guard first.event is Some(body) else {
    fail("event webhook payload is missing its body")
  }
  match body.project() {
    LobbyMessageDelete(data) => {
      inspect(data.id.to_string(), content="1402406637632884857")
      inspect(data.lobby_id.to_string(), content="1402399883394285659")
    }
    event => fail("expected lobby message delete, got \{Repr(event)}")
  }
}

///|
test "discord docs: game direct message create example (line 451)" {
  // Reconstructed: replaced the non-JSON user placeholder as noted above.
  let fixture =
    #|{
    #|  "version": 1,
    #|  "application_id": "1234567765431056709",
    #|  "type": 1,
    #|  "event": {
    #|    "type": "GAME_DIRECT_MESSAGE_CREATE",
    #|    "timestamp": "2025-08-14T18:09:38.063234",
    #|    "data": {
    #|      "id": "1405614357781545021",
    #|      "type": 0,
    #|      "content": "get in friend, we're going raiding",
    #|      "channel_id": "1405604229820715098",
    #|      "author": {
    #|        "id": "111178765189277770",
    #|        "username": "Webhook User",
    #|        "discriminator": "0",
    #|        "global_name": "Webhook User",
    #|        "avatar": null
    #|      },
    #|      "timestamp": "2025-08-14T18:09:37.947000+00:00",
    #|      "application_id": "1234567765431056709",
    #|      "attachments": []
    #|    }
    #|  }
    #|}
  let first : @model.WebhookEventPayload = @json.from_json(@json.parse(fixture))
  let second : @model.WebhookEventPayload = @json.from_json(first.to_json())
  assert_eq("\{Repr(first)}", "\{Repr(second)}")
  inspect(first.application_id.to_string(), content="1234567765431056709")
  assert_true(first.typ == Event)
  guard first.event is Some(body) else {
    fail("event webhook payload is missing its body")
  }
  match body.project() {
    GameDirectMessageCreate(data) => {
      inspect(data.id.to_string(), content="1405614357781545021")
      assert_true(data.attachments is Some([]))
    }
    event => fail("expected game direct message create, got \{Repr(event)}")
  }
}

///|
test "discord docs: game direct message update example (line 485)" {
  // Reconstructed: replaced the non-JSON user placeholder as noted above.
  let fixture =
    #|{
    #|  "version": 1,
    #|  "application_id": "1234567765431056709",
    #|  "type": 1,
    #|  "event": {
    #|    "type": "GAME_DIRECT_MESSAGE_UPDATE",
    #|    "timestamp": "2025-08-14T16:44:31.847073",
    #|    "data": {
    #|      "id": "1405591838810706081",
    #|      "content": "almost ready to queue?",
    #|      "channel_id": "1404960877324533784",
    #|      "author": {
    #|        "id": "111178765189277770",
    #|        "username": "Webhook User",
    #|        "discriminator": "0",
    #|        "global_name": "Webhook User",
    #|        "avatar": null
    #|      },
    #|      "recipient_id": "1404960877324533784"
    #|    }
    #|  }
    #|}
  let first : @model.WebhookEventPayload = @json.from_json(@json.parse(fixture))
  let second : @model.WebhookEventPayload = @json.from_json(first.to_json())
  assert_eq("\{Repr(first)}", "\{Repr(second)}")
  inspect(first.application_id.to_string(), content="1234567765431056709")
  assert_true(first.typ == Event)
  guard first.event is Some(body) else {
    fail("event webhook payload is missing its body")
  }
  match body.project() {
    GameDirectMessageUpdate(data) => {
      inspect(data.id.to_string(), content="1405591838810706081")
      assert_true(data.content == Some("almost ready to queue?"))
    }
    event => fail("expected game direct message update, got \{Repr(event)}")
  }
}

///|
test "discord docs: game direct message delete example (line 516)" {
  // Reconstructed: replaced the non-JSON user placeholder as noted above.
  let fixture =
    #|{
    #|  "version": 1,
    #|  "application_id": "1234567765431056709",
    #|  "type": 1,
    #|  "event": {
    #|    "type": "GAME_DIRECT_MESSAGE_DELETE",
    #|    "timestamp": "2025-08-20T17:01:50.099204",
    #|    "data": {
    #|      "id": "1407771600643686503",
    #|      "type": 0,
    #|      "content": "cant make it in time",
    #|      "channel_id": "1405604229820715098",
    #|      "author": {
    #|        "id": "111178765189277770",
    #|        "username": "Webhook User",
    #|        "discriminator": "0",
    #|        "global_name": "Webhook User",
    #|        "avatar": null
    #|      },
    #|      "timestamp": "2025-08-20T17:01:44.725000+00:00",
    #|      "flags": 0,
    #|      "attachments": [],
    #|      "components": []
    #|    }
    #|  }
    #|}
  let first : @model.WebhookEventPayload = @json.from_json(@json.parse(fixture))
  let second : @model.WebhookEventPayload = @json.from_json(first.to_json())
  assert_eq("\{Repr(first)}", "\{Repr(second)}")
  inspect(first.application_id.to_string(), content="1234567765431056709")
  assert_true(first.typ == Event)
  guard first.event is Some(body) else {
    fail("event webhook payload is missing its body")
  }
  match body.project() {
    GameDirectMessageDelete(data) => {
      inspect(data.id.to_string(), content="1407771600643686503")
      assert_true(data.components is Some([]))
    }
    event => fail("expected game direct message delete, got \{Repr(event)}")
  }
}
