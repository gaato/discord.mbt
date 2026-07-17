///|
fn expect_decode_error_with(
  json : Json,
  expected : String,
  decode : (Json) -> Unit raise @json.JsonDecodeError,
) -> Unit raise {
  try decode(json) catch {
    JsonDecodeError((_, message)) => assert_eq(message, expected)
  } noraise {
    _ => fail("expected JsonDecodeError: \{expected}")
  }
}

///|
test "timestamp, image hash, nonce, and template permissions reject bad JSON" {
  expect_decode_error_with(Json::number(1), "expected an ISO8601 timestamp", fn(
    json,
  ) raise @json.JsonDecodeError {
    let value : @model.Timestamp = @json.from_json(json)
    ignore(value)
  })
  expect_decode_error_with(Json::number(1), "expected an image hash", fn(
    json,
  ) raise @json.JsonDecodeError {
    let value : @model.ImageHash = @json.from_json(json)
    ignore(value)
  })
  expect_decode_error_with(
    Json::boolean(true),
    "expected a message nonce (string or integer)",
    fn(json) raise @json.JsonDecodeError {
      let value : @model.Nonce = @json.from_json(json)
      ignore(value)
    },
  )
  expect_decode_error_with(
    Json::number(1, repr="not-an-int"),
    "expected a message nonce (integer), got not-an-int",
    fn(json) raise @json.JsonDecodeError {
      let value : @model.Nonce = @json.from_json(json)
      ignore(value)
    },
  )
  for
    bad in [
      Json::number(1, repr="not-an-int"),
      Json::string("not-an-int"),
      Json::boolean(true),
    ] {
    expect_decode_error_with(
      bad,
      "expected template permissions (number or string)",
      fn(json) raise @json.JsonDecodeError {
        let value : @model.GuildTemplatePermissions = @json.from_json(json)
        ignore(value)
      },
    )
  }
}

///|
test "presence and gateway message decoders reject non-object payloads" {
  let wrong = Json::array([])
  expect_decode_error_with(wrong, "expected presence user (object)", fn(
    json,
  ) raise @json.JsonDecodeError {
    let value : @model.PresenceUser = @json.from_json(json)
    ignore(value)
  })
  expect_decode_error_with(wrong, "expected client status (object)", fn(
    json,
  ) raise @json.JsonDecodeError {
    let value : @model.ClientStatus = @json.from_json(json)
    ignore(value)
  })
  expect_decode_error_with(wrong, "expected presence update (object)", fn(
    json,
  ) raise @json.JsonDecodeError {
    let value : @model.PresenceUpdateEvent = @json.from_json(json)
    ignore(value)
  })
  expect_decode_error_with(wrong, "expected guild create event (object)", fn(
    json,
  ) raise @json.JsonDecodeError {
    let value : @model.GuildCreateEvent = @json.from_json(json)
    ignore(value)
  })
  expect_decode_error_with(wrong, "expected gateway message (object)", fn(
    json,
  ) raise @json.JsonDecodeError {
    let value : @model.MessageCreateEvent = @json.from_json(json)
    ignore(value)
  })
  expect_decode_error_with(wrong, "expected a component (object)", fn(
    json,
  ) raise @json.JsonDecodeError {
    let value : @model.Component = @json.from_json(json)
    ignore(value)
  })
  expect_decode_error_with(wrong, "expected role tags (object)", fn(
    json,
  ) raise @json.JsonDecodeError {
    let value : @model.RoleTags = @json.from_json(json)
    ignore(value)
  })
}

///|
test "remaining rare enum decoders reject wrong JSON shapes" {
  let wrong = Json::boolean(false)
  expect_model_decode_error(
    wrong,
    "expected scheduled-event recurrence frequency (number)",
    @model.GuildScheduledEventRecurrenceRuleFrequency::from_int(0),
  )
  expect_model_decode_error(
    wrong,
    "expected scheduled-event recurrence weekday (number)",
    @model.GuildScheduledEventRecurrenceRuleWeekday::from_int(0),
  )
  expect_model_decode_error(
    wrong,
    "expected scheduled-event recurrence month (number)",
    @model.GuildScheduledEventRecurrenceRuleMonth::from_int(1),
  )
  expect_model_decode_error(
    wrong,
    "expected the audience allowed to access a scheduled event (number)",
    @model.GuildScheduledEventPrivacyLevel::from_int(2),
  )
  expect_model_decode_error(
    wrong,
    "expected the lifecycle state of a scheduled event (number)",
    @model.GuildScheduledEventStatus::from_int(1),
  )
  expect_model_decode_error(
    wrong,
    "expected the hosting entity used by a scheduled event (number)",
    @model.GuildScheduledEventEntityType::from_int(1),
  )
  expect_model_decode_error(
    wrong,
    "expected the audience allowed to discover a stage instance (number)",
    @model.StagePrivacyLevel::from_int(2),
  )
  expect_model_decode_error(
    wrong,
    "expected a sticker type (number)",
    @model.StickerType::from_int(1),
  )
  expect_model_decode_error(
    wrong,
    "expected an outbound webhook payload type (number)",
    @model.WebhookPayloadType::from_int(0),
  )
  expect_model_decode_error(
    wrong,
    "expected an outbound webhook event type (string)",
    @model.WebhookEventType::from_string("ENTITLEMENT_CREATE"),
  )
  expect_model_decode_error(
    wrong,
    "expected the presentation layout used by a poll (number)",
    @model.PollLayoutType::from_int(1),
  )
}

///|
test "timestamp rare timezone branches and malformed branches are pinned" {
  inspect(@model.Timestamp("1970-01-01T00:00:01").unix_ms(), content="1000")
  inspect(
    @model.Timestamp("1970-01-01T00:00:00-01:30").unix_ms(),
    content="5400000",
  )
  for malformed in ["197x-01-01T00:00:00Z", "1970-01-01T00:00:00 UTC"] {
    try @model.Timestamp(malformed).unix_ms() |> ignore catch {
      InvalidTimestamp(value) => assert_eq(value, malformed)
    } noraise {
      _ => fail("expected invalid timestamp: \{malformed}")
    }
  }
}

///|
test "undefinable JSON helpers cover value, null, and missing fallbacks" {
  let value : @model.Undefinable[Int] = Value(7)
  assert_eq(value.to_option(), Some(7))
  assert_eq(value.to_json().stringify(), "7")
  let null_value : @model.Undefinable[Int] = Null
  assert_eq(null_value.to_json().stringify(), "null")
  let missing : @model.Undefinable[Int] = Missing
  assert_eq(missing.to_json().stringify(), "null")
  let decoded_null : @model.Undefinable[Int] = @json.from_json(Json::null())
  assert_true(decoded_null is Null)
  let decoded_value : @model.Undefinable[Int] = @json.from_json(Json::number(8))
  assert_eq(decoded_value.to_option(), Some(8))
}

///|
test "activity timestamps preserve optional 64-bit endpoints" {
  let timestamps : @model.ActivityTimestamps = @json.from_json(
    @json.parse("{\"start\":1700000000000,\"end\":1700000000123}"),
  )
  assert_eq(timestamps.start, Some(1700000000000L))
  assert_eq(timestamps.end, Some(1700000000123L))
  assert_eq(
    timestamps.to_json().stringify(),
    "{\"start\":1700000000000,\"end\":1700000000123}",
  )
}

///|
test "component decoder covers user select and unknown discriminators" {
  let select : @model.Component = @json.from_json(
    @json.parse(
      "{\"type\":5,\"custom_id\":\"choose-user\",\"min_values\":1,\"max_values\":2}",
    ),
  )
  assert_true(select is UserSelect(_))
  assert_eq(
    select.to_json().stringify(),
    "{\"custom_id\":\"choose-user\",\"min_values\":1,\"max_values\":2,\"type\":5}",
  )
  let unknown : @model.Component = @json.from_json(
    @json.parse("{\"type\":999,\"future\":true}"),
  )
  assert_true(unknown is Unknown(_))
  assert_eq(unknown.to_json().stringify(), "{\"type\":999,\"future\":true}")
}

///|
test "gateway opcodes cover every current and unknown wire value" {
  let values = [0, 1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 31, 999]
  for wire in values {
    assert_eq(@model.GatewayOpcode::from_int(wire).to_int(), wire)
  }
}
