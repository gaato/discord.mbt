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
