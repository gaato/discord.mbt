///|
fn expect_edit_application_validation(
  run : () -> Json raise DiscordHttpError,
  expected_message : String,
) -> Unit raise {
  try run() catch {
    Validation(message~) => assert_eq(message, expected_message)
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected to fail")
  }
}

///|
fn expect_json_validation(
  run : () -> Json raise DiscordHttpError,
  expected_message : String,
) -> Unit raise {
  try run() catch {
    Validation(message~) => assert_eq(message, expected_message)
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected to fail")
  }
}

///|
fn expect_search_validation(
  run : () -> String raise DiscordHttpError,
  expected_message : String,
) -> Unit raise {
  try run() catch {
    Validation(message~) => assert_eq(message, expected_message)
    error => fail("unexpected error: \{to_repr(error)}")
  } noraise {
    _ => fail("expected to fail")
  }
}

///|
test "edit current application rejects value and clear together" {
  expect_edit_application_validation(
    () => {
      edit_current_application_body(
        interactions_endpoint_url="https://example.com/interactions",
        clear_interactions_endpoint_url=true,
      )
    },
    "interactions_endpoint_url and clear_interactions_endpoint_url cannot both be set",
  )
}

///|
test "current user voice state rejects timestamp value and clear together" {
  let timestamp_fixture =
    #|"2026-08-01T10:00:00Z"
  let timestamp : @model.Timestamp = @json.from_json(
    @json.parse(timestamp_fixture),
  )
  try
    modify_current_user_voice_state_body(None, None, Some(timestamp), true)
  catch {
    err =>
      debug_inspect(
        err,
        content=(
          #|Validation(message="request_to_speak_timestamp and clear_request_to_speak_timestamp cannot both be set")
        ),
      )
  } noraise {
    _ => fail("expected to fail")
  }
}

///|
test "edit current application validates tags" {
  expect_edit_application_validation(
    () => {
      edit_current_application_body(tags=[
        "one", "two", "three", "four", "five", "six",
      ])
    },
    "application tags exceed 5 entries",
  )
  expect_edit_application_validation(
    () => edit_current_application_body(tags=[String::make(21, 'x')]),
    "application tag exceeds 20 characters",
  )
}

///|
test "edit current application validates URL lengths" {
  let overlong = String::make(2049, 'x')
  expect_edit_application_validation(
    () => edit_current_application_body(custom_install_url=overlong),
    "custom_install_url exceeds 2048 characters",
  )
  expect_edit_application_validation(
    () => {
      edit_current_application_body(role_connections_verification_url=overlong)
    },
    "role_connections_verification_url exceeds 2048 characters",
  )
  expect_edit_application_validation(
    () => edit_current_application_body(interactions_endpoint_url=overlong),
    "interactions_endpoint_url exceeds 2048 characters",
  )
  expect_edit_application_validation(
    () => edit_current_application_body(event_webhooks_url=overlong),
    "event_webhooks_url exceeds 2048 characters",
  )
}

///|
test "bulk delete validates the message count" {
  let one : Array[@model.MessageId] = [Id(1UL)]
  try validate_bulk_delete_messages(one) catch {
    err =>
      debug_inspect(
        err,
        content=(
          #|Validation(message="bulk delete requires between 2 and 100 messages")
        ),
      )
  } noraise {
    _ => fail("expected to fail")
  }
  let too_many : Array[@model.MessageId] = Array::make(101, Id(1UL))
  try validate_bulk_delete_messages(too_many) catch {
    err =>
      debug_inspect(
        err,
        content=(
          #|Validation(message="bulk delete requires between 2 and 100 messages")
        ),
      )
  } noraise {
    _ => fail("expected to fail")
  }
  validate_bulk_delete_messages([Id(1UL), Id(2UL)])
  validate_bulk_delete_messages(Array::make(100, Id(1UL)))
}

///|
test "voice channel status validates its length" {
  expect_json_validation(
    () => set_voice_channel_status_body(Some(String::make(501, 'x'))),
    "voice channel status exceeds 500 characters",
  )
  ignore(set_voice_channel_status_body(Some(String::make(500, 'x'))))
}

///|
test "guild message search validates ranges and array caps" {
  expect_search_validation(
    () => search_guild_messages_query(limit=0),
    "search limit must be between 1 and 25",
  )
  expect_search_validation(
    () => search_guild_messages_query(offset=9976),
    "search offset must be between 0 and 9975",
  )
  expect_search_validation(
    () => search_guild_messages_query(content=String::make(1025, 'x')),
    "search content exceeds 1024 characters",
  )
  let channel_id : @model.ChannelId = Id(1UL)
  expect_search_validation(
    () => search_guild_messages_query(channel_id=Array::make(501, channel_id)),
    "channel_id exceeds 500 entries",
  )
}

///|
test "entitlement list validates its documented limit" {
  expect_search_validation(
    () => list_entitlements_query(limit=0),
    "entitlement limit must be 1 through 100",
  )
  expect_search_validation(
    () => list_entitlements_query(limit=101),
    "entitlement limit must be 1 through 100",
  )
  ignore(list_entitlements_query(limit=1))
  ignore(list_entitlements_query(limit=100))
}

///|
test "SKU subscription list validates its documented limit" {
  expect_search_validation(
    () => list_sku_subscriptions_query(limit=0),
    "SKU subscription limit must be 1 through 100",
  )
  expect_search_validation(
    () => list_sku_subscriptions_query(limit=101),
    "SKU subscription limit must be 1 through 100",
  )
  ignore(list_sku_subscriptions_query(limit=1))
  ignore(list_sku_subscriptions_query(limit=100))
}

///|
test "execute webhook requires message content" {
  try validate_execute_webhook(None, None, None, None) catch {
    err =>
      debug_inspect(
        err,
        content=(
          #|Validation(message="one of content/embeds/components/files is required")
        ),
      )
  } noraise {
    _ => fail("expected to fail")
  }
  validate_execute_webhook(Some("hello"), None, None, None)
  validate_execute_webhook(
    None,
    None,
    None,
    Some([FileUpload("hello.txt", b"hello")]),
  )
}

///|
test "execute webhook validates content length" {
  let content = String::make(4001, 'x')
  try validate_execute_webhook(Some(content), None, None, None) catch {
    err =>
      debug_inspect(
        err,
        content=(
          #|Validation(message="content exceeds 4000 UTF-16 units")
        ),
      )
  } noraise {
    _ => fail("expected to fail")
  }
}

///|
test "modify webhook with token validates its name" {
  expect_json_validation(
    () => modify_webhook_with_token_body(Some(""), None, false),
    "webhook name must be between 1 and 80 characters",
  )
  ignore(
    modify_webhook_with_token_body(Some(String::make(80, 'x')), None, false),
  )
}

///|
test "guild template fields validate documented limits" {
  expect_json_validation(
    () => create_guild_from_template_body("x", None),
    "guild name must be between 2 and 100 characters",
  )
  expect_json_validation(
    () => create_guild_from_template_body(String::make(101, 'x'), None),
    "guild name must be between 2 and 100 characters",
  )
  expect_json_validation(
    () => create_guild_template_body("", None),
    "guild template name must be between 1 and 100 characters",
  )
  expect_json_validation(
    () => create_guild_template_body(String::make(101, 'x'), None),
    "guild template name must be between 1 and 100 characters",
  )
  expect_json_validation(
    () => modify_guild_template_body(Some(""), None, false),
    "guild template name must be between 1 and 100 characters",
  )
  expect_json_validation(
    () => modify_guild_template_body(Some(String::make(101, 'x')), None, false),
    "guild template name must be between 1 and 100 characters",
  )
  expect_json_validation(
    () => create_guild_template_body("valid", Some(String::make(121, 'x'))),
    "guild template description exceeds 120 characters",
  )
  expect_json_validation(
    () => modify_guild_template_body(None, Some(String::make(121, 'x')), false),
    "guild template description exceeds 120 characters",
  )
  ignore(create_guild_from_template_body(String::make(2, 'x'), None))
  ignore(create_guild_from_template_body(String::make(100, 'x'), None))
  ignore(create_guild_template_body(String::make(1, 'x'), Some("")))
  ignore(
    modify_guild_template_body(
      Some(String::make(100, 'x')),
      Some(String::make(120, 'x')),
      false,
    ),
  )
}

///|
test "guild template description rejects value and clear together" {
  expect_json_validation(
    () => modify_guild_template_body(None, Some("description"), true),
    "description and clear_description cannot both be set",
  )
}

///|
test "application command permissions validate the record limit" {
  let permission : @model.ApplicationCommandPermission = {
    id: Id(1UL),
    typ: Role,
    permission: true,
  }
  expect_json_validation(
    () => {
      edit_application_command_permissions_body(Array::make(101, permission))
    },
    "application command permissions exceed 100 entries",
  )
}

///|
test "application role connection metadata validates the record limit" {
  let fixture =
    #|{"type":3,"key":"level","name":"Level","description":"Account level"}
  let record : @model.ApplicationRoleConnectionMetadata = @json.from_json(
    @json.parse(fixture),
  )
  expect_json_validation(
    () => {
      update_application_role_connection_metadata_records_body(
        Array::make(6, record),
      )
    },
    "role connection metadata records exceed 5 entries",
  )
}

///|
test "current user application role connection validates platform lengths" {
  expect_json_validation(
    () => {
      update_current_user_application_role_connection_body(
        Some(String::make(51, 'x')),
        None,
        None,
      )
    },
    "platform_name exceeds 50 characters",
  )
  expect_json_validation(
    () => {
      update_current_user_application_role_connection_body(
        None,
        Some(String::make(101, 'x')),
        None,
      )
    },
    "platform_username exceeds 100 characters",
  )
}
