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
